package com.timberpile.boorusama

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

/** All external operations stay inside the persisted, user-selected document tree. */
class AutoBackupChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val context = activity.applicationContext
    private val resolver = context.contentResolver
    private var pickerResult: MethodChannel.Result? = null
    private val cache = context.cacheDir
    private val codeCache = context.codeCacheDir
    private val channel = MethodChannel(messenger, "boorusama/auto_backup")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val folderName = "boorusama_auto_backups"
    private val manifestName = "auto_backup_manifest.json"

    private data class Child(val uri: Uri, val name: String, val mime: String, val size: Long)

    private fun children(tree: Uri, parent: Uri): List<Child> {
        val query = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getDocumentId(parent))
        val columns = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE)
        val cursor = resolver.query(query, columns, null, null, null)
            ?: throw IOException("Folder unavailable")
        return cursor.use {
            val items = mutableListOf<Child>()
            while (it.moveToNext()) {
                items.add(Child(DocumentsContract.buildDocumentUriUsingTree(tree, it.getString(0)),
                    it.getString(1) ?: "", it.getString(2) ?: "", if (it.isNull(3)) 0 else it.getLong(3)))
            }
            items
        }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "pickDirectory") {
                if (pickerResult != null) {
                    result.error("backup_picker_busy", "Folder selection already open", null)
                } else {
                    pickerResult = result
                    try {
                        activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                        }, PICK_FOLDER)
                    } catch (error: Exception) {
                        pickerResult = null
                        result.error("backup_folder_access_required", "Folder selection unavailable", null)
                    }
                }
                return@setMethodCallHandler
            }
            worker.execute {
                try {
                    val location = Uri.parse(call.argument<String>("location") ?: "")
                    require(location.scheme == "content" && location.pathSegments.firstOrNull() == "tree")
                    require(location.pathSegments.size in 2..3)
                    val tree = location.buildUpon().path(null).appendPath("tree")
                        .appendPath(location.pathSegments[1]).build()
                    if (!resolver.persistedUriPermissions.any { it.uri == tree && it.isReadPermission && it.isWritePermission }) {
                        throw SecurityException("Folder approval required")
                    }
                    val root = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                    if (call.method == "directoryDisplayName") {
                        // Display lookup must not create or require a backup subfolder.
                        val name = resolver.query(root,
                            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use {
                            if (it.moveToFirst()) it.getString(0) else null
                        }
                        main.post { result.success(name) }
                        return@execute
                    }
                    val existingFolder = children(tree, root).firstOrNull { it.name == folderName }
                    if (existingFolder != null && existingFolder.mime != DocumentsContract.Document.MIME_TYPE_DIR) {
                        throw IOException("Backup folder unavailable")
                    }
                    val folder = existingFolder?.uri ?: if (call.method == "prepare") {
                        DocumentsContract.createDocument(resolver, root, DocumentsContract.Document.MIME_TYPE_DIR, folderName)
                            ?: throw IOException("Could not create folder")
                    } else throw IOException("Backup folder unavailable")
                    val name = location.pathSegments.getOrNull(2)
                    val items = children(tree, folder)
                    val file = items.firstOrNull { it.name == name && it.mime != DocumentsContract.Document.MIME_TYPE_DIR }
                    val value: Any = when (call.method) {
                        "prepare" -> true
                        "list" -> items.filter { it.mime != DocumentsContract.Document.MIME_TYPE_DIR &&
                            (it.name.endsWith(".zip") || it.name.endsWith(".bsexport")) }.map { it.name }
                        "exists" -> file != null
                        "size" -> file?.size ?: throw IOException("Backup missing")
                        "delete" -> {
                            require(name != null && (name.endsWith(".zip") || name.endsWith(".bsexport")))
                            if (file != null && !DocumentsContract.deleteDocument(resolver, file.uri)) throw IOException("Delete failed")
                            true
                        }
                        "readManifest" -> {
                            val manifest = items.firstOrNull { it.name == manifestName }
                            if (manifest == null) "{\"backups\":[]}" else resolver.openInputStream(manifest.uri)?.bufferedReader()?.use { it.readText() }
                                ?: throw IOException("Manifest unavailable")
                        }
                        "writeManifest" -> {
                            val manifest = items.firstOrNull { it.name == manifestName }?.uri
                                ?: DocumentsContract.createDocument(resolver, folder, "application/json", manifestName)
                                ?: throw IOException("Manifest unavailable")
                            val content = call.argument<String>("content") ?: throw IOException("Missing manifest")
                            resolver.openOutputStream(manifest, "wt")?.bufferedWriter()?.use { it.write(content) }
                                ?: throw IOException("Manifest write failed")
                            true
                        }
                        "writeBackup" -> {
                            require(name != null && name.endsWith(".bsexport") && file == null)
                            val source = File(call.argument<String>("source") ?: "").canonicalFile
                            require(listOf(cache, codeCache).any { source.path.startsWith(it.canonicalPath + File.separator) })
                            val document = DocumentsContract.createDocument(resolver, folder, ReceivedExportChannel.EXPORT_MIME_TYPE, name)
                                ?: throw IOException("Backup creation failed")
                            try {
                                resolver.openOutputStream(document, "w")?.use { output ->
                                    source.inputStream().use { input -> input.copyTo(output) }
                                } ?: throw IOException("Backup write failed")
                                // Providers may rename files; do not record a mismatched manifest entry.
                                if (children(tree, folder).none { it.uri == document && it.name == name && it.size == source.length() }) {
                                    throw IOException("Incomplete backup")
                                }
                            } catch (error: Exception) {
                                DocumentsContract.deleteDocument(resolver, document)
                                throw error
                            }
                            true
                        }
                        else -> throw IllegalArgumentException("Unknown operation")
                    }
                    main.post { result.success(value) }
                } catch (error: Exception) {
                    val code = if (error is SecurityException || error is IllegalArgumentException) "backup_folder_access_required" else "backup_storage_failed"
                    main.post { result.error(code, "Backup folder access failed", null) }
                }
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_FOLDER) return false
        val result = pickerResult ?: return true
        pickerResult = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return true
        }
        try {
            val tree = data?.data ?: throw SecurityException("Missing folder")
            val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            require(flags == (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
            resolver.takePersistableUriPermission(tree, flags)
            result.success(tree.toString())
        } catch (error: Exception) {
            result.error("backup_folder_access_required", "Could not keep folder access", null)
        }
        return true
    }

    companion object {
        private const val PICK_FOLDER = 17017
    }

    fun close() {
        pickerResult?.error("backup_folder_access_required", "Folder selection interrupted", null)
        pickerResult = null
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
