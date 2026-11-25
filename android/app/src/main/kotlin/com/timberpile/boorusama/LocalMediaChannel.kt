package com.timberpile.boorusama

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.util.ArrayDeque
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/** Holds only temporary read access for one explicit user selection. */
internal class LocalMediaChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private data class Document(val uri: Uri, val depth: Int, val directory: Boolean)

    private val resolver = activity.contentResolver
    private val root = File(activity.noBackupFilesDir, "local-media")
    private val thumbnails = File(activity.cacheDir, "local-media-thumbnails")
    private val channel = MethodChannel(messenger, "boorusama/local_media")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val openInput = AtomicReference<InputStream?>()
    private val signal = AtomicReference<CancellationSignal?>()
    private val cancelled = AtomicBoolean()
    private var picker: MethodChannel.Result? = null
    private var pickingFolder = false

    // The worker owns the selection and all provider cursor operations.
    private val documents = ArrayDeque<Document>()
    private val visitedDirectories = mutableSetOf<Uri>()
    private var tree: Uri? = null
    private var current: Uri? = null
    private var enumerated = 0
    private var reachedLimit = false

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "root" -> result.success(root.path)
                "pick" -> pick(call.argument<Boolean>("folder") == true, result)
                "cancel" -> {
                    cancelled.set(true)
                    signal.get()?.cancel()
                    val input = openInput.getAndSet(null)
                    if (input != null) Thread { runCatching { input.close() } }.start()
                    result.success(null)
                }
                else -> worker.execute {
                    try {
                        val value: Any? = when (call.method) {
                            "prepare" -> prepare()
                            "next" -> next()
                            "open" -> openDocument()
                            "read" -> read()
                            "closeDocument" -> closeDocument()
                            "finish" -> reset()
                            "thumbnailBytes" -> thumbnails.listFiles()
                                ?.filter { it.isFile }?.sumOf { it.length() } ?: 0L
                            "clearThumbnails" -> check(thumbnails.deleteRecursively()) {
                                "Local media thumbnails could not be removed"
                            }
                            "inspect" -> inspectLocalMedia(
                                File(root, "staging/incoming"),
                                requireNotNull(call.argument<String>("format")),
                            )
                            "thumbnail" -> thumbnail(
                                requireNotNull(call.argument<String>("sha256")),
                                requireNotNull(call.argument<String>("format")),
                            )
                            else -> {
                                main.post { result.notImplemented() }
                                return@execute
                            }
                        }
                        main.post { result.success(if (value == Unit) null else value) }
                    } catch (_: LocalMediaFormatException) {
                        main.post { result.error("unsupported", "Unsupported media", null) }
                    } catch (_: LocalMediaBoundsException) {
                        main.post { result.error("limit", "Media limit reached", null) }
                    } catch (_: Exception) {
                        main.post { result.error("unavailable", "Local media access failed", null) }
                    }
                }
            }
        }
    }

    private fun pick(folder: Boolean, result: MethodChannel.Result) {
        if (picker != null) {
            result.error("busy", "A document selection is already open", null)
            return
        }
        cancelled.set(false)
        picker = result
        pickingFolder = folder
        val intent = if (folder) {
            Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        } else {
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                // A provider's MIME/extension can be unreliable. Inspect the bytes.
                type = "*/*"
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            }
        }
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        try {
            activity.startActivityForResult(intent, PICK_REQUEST)
        } catch (_: Exception) {
            picker = null
            result.error("unavailable", "Document picker unavailable", null)
        }
    }

    fun onActivityResult(request: Int, status: Int, data: Intent?): Boolean {
        if (request != PICK_REQUEST) return false
        val result = picker ?: return true
        val folder = pickingFolder
        picker = null
        if (status != Activity.RESULT_OK || data == null) {
            result.success(false)
            return true
        }
        worker.execute {
            try {
                reset()
                val selected = data.data
                if (folder) {
                    val selectedTree = requireNotNull(selected)
                    require(selectedTree.scheme == "content" && DocumentsContract.isTreeUri(selectedTree))
                    tree = selectedTree
                    documents.add(Document(
                        DocumentsContract.buildDocumentUriUsingTree(
                            selectedTree, DocumentsContract.getTreeDocumentId(selectedTree),
                        ),
                        0,
                        true,
                    ))
                } else {
                    val clips = data.clipData
                    if (clips == null) {
                        if (selected?.scheme == "content") {
                            documents.add(Document(selected, 0, false))
                        }
                    } else {
                        reachedLimit = clips.itemCount > MAX_FILES
                        for (index in 0 until minOf(clips.itemCount, MAX_FILES)) {
                            val uri = clips.getItemAt(index).uri
                            if (uri?.scheme == "content") documents.add(Document(uri, 0, false))
                        }
                    }
                }
                val hasSelection = documents.isNotEmpty()
                main.post { result.success(hasSelection) }
            } catch (_: Exception) {
                main.post { result.error("unavailable", "Document selection unavailable", null) }
            }
        }
        return true
    }

    private fun prepare(): Map<String, Any> {
        val files = ArrayDeque<Document>()
        var failed = 0
        while (documents.isNotEmpty() && !cancelled.get()) {
            if (files.size == MAX_FILES) {
                reachedLimit = true
                break
            }
            val document = documents.removeFirst()
            if (!document.directory) {
                files.add(document)
            } else if (visitedDirectories.add(document.uri)) {
                if (document.depth >= MAX_DEPTH || enumerated >= MAX_DOCUMENTS) {
                    reachedLimit = true
                } else {
                    try {
                        enqueueChildren(document)
                    } catch (_: Exception) {
                        if (!cancelled.get()) failed++
                    }
                }
            }
        }
        documents.clear()
        documents.addAll(files)
        return mapOf("total" to files.size, "failed" to failed, "limit" to reachedLimit)
    }

    private fun next(): Boolean {
        closeDocument()
        if (cancelled.get()) return false
        current = documents.pollFirst()?.uri
        return current != null
    }

    private fun enqueueChildren(document: Document) {
        val selectedTree = requireNotNull(tree)
        val parent = DocumentsContract.getDocumentId(document.uri)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(selectedTree, parent)
        val querySignal = CancellationSignal()
        signal.set(querySignal)
        if (cancelled.get()) querySignal.cancel()
        try {
            resolver.query(
                children,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                ),
                null, null, null, querySignal,
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    if (enumerated++ >= MAX_DOCUMENTS) {
                        reachedLimit = true
                        break
                    }
                    val uri = DocumentsContract.buildDocumentUriUsingTree(selectedTree, cursor.getString(0))
                    val directory = cursor.getString(1) == DocumentsContract.Document.MIME_TYPE_DIR
                    documents.add(Document(uri, document.depth + 1, directory))
                }
            } ?: throw IOException("Document folder unavailable")
        } finally {
            signal.compareAndSet(querySignal, null)
        }
    }

    private fun openDocument() {
        val uri = requireNotNull(current)
        val readSignal = CancellationSignal()
        signal.set(readSignal)
        if (cancelled.get()) readSignal.cancel()
        val descriptor = resolver.openAssetFileDescriptor(uri, "r", readSignal)
            ?: throw IOException("Document unavailable")
        try {
            openInput.set(descriptor.createInputStream())
        } catch (error: Exception) {
            descriptor.close()
            throw error
        }
    }

    private fun read(): ByteArray? {
        val stream = openInput.get() ?: return null
        val bytes = ByteArray(256 * 1024)
        val length = stream.read(bytes)
        return if (length < 0) null else bytes.copyOf(length)
    }

    private fun closeDocument() {
        signal.set(null)
        openInput.getAndSet(null)?.let { runCatching { it.close() } }
        current = null
    }

    private fun reset() {
        closeDocument()
        documents.clear()
        visitedDirectories.clear()
        enumerated = 0
        reachedLimit = false
        tree = null
    }

    private fun thumbnail(hash: String, format: String): String? {
        if (!hash.matches(Regex("[a-f0-9]{64}")) || format !in setOf("gif", "mp4", "webm")) return null
        val source = File(root, "media/${hash.take(2)}/$hash.$format")
        if (!source.isFile) return null
        return localMediaThumbnail(source, File(thumbnails, "$hash.jpg"), video = format != "gif")
    }

    fun close() {
        channel.setMethodCallHandler(null)
        picker?.success(false)
        picker = null
        signal.get()?.cancel()
        worker.execute { reset() }
        worker.shutdown()
    }

    private companion object {
        const val PICK_REQUEST = 0x1840
        const val MAX_FILES = 1000
        const val MAX_DOCUMENTS = 5000
        const val MAX_DEPTH = 16
    }
}
