package com.timberpile.boorusama

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors

/** Bounded immutable operations confined to a persisted, explicitly selected SAF tree. */
class FolderSyncChannel(context: Context, messenger: BinaryMessenger) {
    private val resolver = context.applicationContext.contentResolver
    private val channel = MethodChannel(messenger, "boorusama/folder_sync")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val maxBytes = 32 * 1024 * 1024
    private val maxEntries = 4096
    private data class Child(val uri: Uri, val name: String, val directory: Boolean)

    private fun children(tree: Uri, parent: Uri): List<Child> {
        val query = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getDocumentId(parent))
        return (resolver.query(query, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE), null, null, null)
            ?: throw IOException("Directory unavailable")).use { cursor ->
            val result = mutableListOf<Child>()
            val names = mutableSetOf<String>()
            while (cursor.moveToNext()) {
                if (result.size >= maxEntries) throw IOException("Directory exceeds limit")
                val name = cursor.getString(1) ?: throw IOException("Missing name")
                if (!names.add(name)) throw IOException("Ambiguous document name")
                result.add(Child(DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(0)), name,
                    cursor.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR))
            }
            result
        }
    }
    private fun safe(path: String): Boolean = path.length <= 512 &&
        (path.isEmpty() || path.split('/').let { parts -> parts.size <= 8 && parts.all {
            it != "." && it != ".." && it.matches(Regex("[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}")) } })

    private fun read(uri: Uri, limit: Int): ByteArray {
        require(limit in 0..maxBytes)
        return (resolver.openInputStream(uri) ?: throw IOException("Read unavailable")).use { input ->
            val output = ByteArrayOutputStream(minOf(limit, 65536))
            val buffer = ByteArray(32768)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                if (output.size().toLong() + count > limit) throw IOException("Document exceeds limit")
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        }
    }
    private fun directory(tree: Uri, root: Uri, parts: List<String>, create: Boolean): Uri? {
        var current = root
        for (name in parts) {
            val child = children(tree, current).singleOrNull { it.name == name }
            if (child != null) {
                if (!child.directory) throw IOException("Expected directory")
                current = child.uri
            } else if (create) {
                current = DocumentsContract.createDocument(resolver, current, DocumentsContract.Document.MIME_TYPE_DIR, name)
                    ?: throw IOException("Cannot create directory")
            } else return null
        }
        return current
    }
    private fun owned(path: String, owner: String): Boolean {
        if (!safe(path)) return false
        try { if (UUID.fromString(owner).toString() != owner) return false } catch (_: Exception) { return false }
        val parts = path.split('/')
        if (parts.size !in setOf(4, 6) || parts[0] != "devices" || parts[1] != owner) return false
        if (parts.size == 4 && parts[2] != "catalog") return false
        if (parts.size == 6) {
            if (parts[2] != "collections" || parts[3] !in setOf("bookmarks", "following_topics")) return false
            try { if (UUID.fromString(parts[4]).toString() != parts[4]) return false } catch (_: Exception) { return false }
        }
        val file = parts.last()
        if (!file.matches(Regex("[1-9][0-9]{0,15}\\.(json|bsexport)"))) return false
        if (parts.size == 4 && !file.endsWith(".json")) return false
        return (file.substringBefore('.').toLongOrNull() ?: return false) <= 9007199254740991L
    }
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method !in setOf("list", "read", "writeImmutable", "deleteOwnedRevision")) {
                result.notImplemented(); return@setMethodCallHandler
            }
            worker.execute {
                try {
                    val tree = Uri.parse(call.argument<String>("location") ?: "")
                    require(tree.scheme == "content" && tree.pathSegments.size == 2 && tree.pathSegments[0] == "tree")
                    if (!resolver.persistedUriPermissions.any { it.uri == tree && it.isReadPermission && it.isWritePermission }) {
                        throw SecurityException("Folder permission required")
                    }
                    val path = call.argument<String>("path") ?: ""
                    require(safe(path))
                    val root = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                    val create = call.method == "writeImmutable"
                    val namespace = directory(tree, root, listOf("v1"), create)
                    val parts = if (path.isEmpty()) emptyList() else path.split('/')
                    val value: Any? = if (call.method == "list") {
                        val dir = namespace?.let { directory(tree, it, parts, false) }
                        if (dir == null) emptyList<String>() else children(tree, dir).map { it.name }.filter { !it.contains('/') && safe(it) }.sorted()
                    } else {
                        require(parts.isNotEmpty())
                        val parent = namespace?.let { directory(tree, it, parts.dropLast(1), create) }
                        val existing = parent?.let { children(tree, it).singleOrNull { child -> child.name == parts.last() } }
                        if (existing?.directory == true) throw IOException("Expected file")
                        when (call.method) {
                            "read" -> existing?.let { read(it.uri, call.argument<Int>("maxBytes") ?: maxBytes) }
                            "deleteOwnedRevision" -> {
                                require(owned(path, call.argument<String>("owner") ?: ""))
                                if (existing != null && !DocumentsContract.deleteDocument(resolver, existing.uri)) throw IOException("Delete failed")
                                true
                            }
                            else -> {
                                val bytes = call.argument<ByteArray>("bytes") ?: throw IOException("Missing bytes")
                                require(bytes.size <= maxBytes && parent != null)
                                if (existing != null) {
                                    if (!read(existing.uri, bytes.size).contentEquals(bytes)) throw IOException("Immutable document differs")
                                } else {
                                    val mime = if (path.endsWith(".json")) "application/json" else "application/octet-stream"
                                    // createDocument creates a new document; rename has no
                                    // no-replace guarantee and could clobber another writer.
                                    // Partial files are harmless: receivers require the complete
                                    // signed descriptor/hash and never infer deletion from absence.
                                    val created = DocumentsContract.createDocument(resolver, parent, mime, parts.last())
                                        ?: throw IOException("Create failed")
                                    var actual = children(tree, parent).singleOrNull { it.name == parts.last() }
                                    if (actual == null || actual.uri != created) throw IOException("Document name collision")
                                    (resolver.openOutputStream(created, "w") ?: throw IOException("Write unavailable")).use { it.write(bytes); it.flush() }
                                    actual = children(tree, parent).singleOrNull { it.name == parts.last() }
                                    if (actual == null || actual.uri != created || !read(created, bytes.size).contentEquals(bytes)) {
                                        throw IOException("Published document verification failed")
                                    }
                                    // Never remove a partially published final name: it is immutable
                                    // evidence, and durable sequence allocation will skip it on retry.
                                }
                                true
                            }
                        }
                    }
                    main.post { result.success(value) }
                } catch (error: Exception) {
                    val code = if (error is SecurityException) "sync_folder_access_required" else "sync_storage_failed"
                    // Do not return paths, document URIs, private keys or package content.
                    main.post { result.error(code, "Folder Sync storage operation failed", null) }
                }
            }
        }
    }
    fun close() { channel.setMethodCallHandler(null); worker.shutdown() }
}
