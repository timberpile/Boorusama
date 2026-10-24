package com.timberpile.boorusama

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.util.Log
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

    // Exception messages and payloads can contain document URIs, local paths or
    // export data. Report only our stage, the exception type and stack locations.
    private fun reportFailure(result: MethodChannel.Result, stage: String, error: Exception) {
        val code = if (error is SecurityException) "backup_folder_access_required" else "backup_storage_failed"
        val causeType = error.javaClass.simpleName
        Log.e("BoorusamaBackup", "Backup failed at $stage ($causeType)\n" +
            error.stackTrace.take(8).joinToString("\n"))
        main.post {
            result.error(code, "Backup failed at $stage", mapOf("stage" to stage, "causeType" to causeType))
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
                        reportFailure(result, "open_folder_picker", error)
                    }
                }
                return@setMethodCallHandler
            }
            worker.execute {
                var stage = "validate_location"
                try {
                    val location = Uri.parse(call.argument<String>("location") ?: "")
                    require(location.scheme == "content" && location.pathSegments.firstOrNull() == "tree")
                    require(location.pathSegments.size in 2..3)
                    val tree = location.buildUpon().path(null).appendPath("tree")
                        .appendPath(location.pathSegments[1]).build()
                    stage = "check_persisted_permission"
                    if (!resolver.persistedUriPermissions.any { it.uri == tree && it.isReadPermission && it.isWritePermission }) {
                        throw SecurityException("Folder approval required")
                    }
                    stage = "resolve_root"
                    val root = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                    if (call.method == "directoryDisplayName") {
                        // Display lookup must not create or require a backup subfolder.
                        stage = "read_folder_name"
                        val name = resolver.query(root,
                            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use {
                            if (it.moveToFirst()) it.getString(0) else null
                        }
                        main.post { result.success(name) }
                        return@execute
                    }
                    stage = "find_backup_folder"
                    val existingFolder = children(tree, root).firstOrNull { it.name == folderName }
                    if (existingFolder != null && existingFolder.mime != DocumentsContract.Document.MIME_TYPE_DIR) {
                        throw IOException("Backup folder unavailable")
                    }
                    val folder = existingFolder?.uri ?: if (call.method == "prepare") {
                        stage = "create_backup_folder"
                        DocumentsContract.createDocument(resolver, root, DocumentsContract.Document.MIME_TYPE_DIR, folderName)
                            ?: throw IOException("Could not create folder")
                    } else throw IOException("Backup folder unavailable")
                    val name = location.pathSegments.getOrNull(2)
                    stage = "list_backup_folder"
                    val items = children(tree, folder)
                    val file = items.firstOrNull { it.name == name && it.mime != DocumentsContract.Document.MIME_TYPE_DIR }
                    val value: Any = when (call.method) {
                        "prepare" -> true
                        "list" -> items.filter { it.mime != DocumentsContract.Document.MIME_TYPE_DIR &&
                            (it.name.endsWith(".zip") || it.name.endsWith(".bsexport")) }.map { it.name }
                        "exists" -> file != null
                        "size" -> {
                            stage = "read_backup_size"
                            file?.size ?: throw IOException("Backup missing")
                        }
                        "delete" -> {
                            stage = "delete_retained_backup"
                            require(name != null && (name.endsWith(".zip") || name.endsWith(".bsexport")))
                            if (file != null && !DocumentsContract.deleteDocument(resolver, file.uri)) throw IOException("Delete failed")
                            true
                        }
                        "readManifest" -> {
                            stage = "read_manifest"
                            val manifest = items.firstOrNull { it.name == manifestName }
                            if (manifest == null) "{\"backups\":[]}" else resolver.openInputStream(manifest.uri)?.bufferedReader()?.use { it.readText() }
                                ?: throw IOException("Manifest unavailable")
                        }
                        "writeManifest" -> {
                            stage = "open_manifest"
                            val manifest = items.firstOrNull { it.name == manifestName }?.uri
                                ?: DocumentsContract.createDocument(resolver, folder, "application/json", manifestName)
                                ?: throw IOException("Manifest unavailable")
                            val content = call.argument<String>("content") ?: throw IOException("Missing manifest")
                            stage = "write_manifest"
                            resolver.openOutputStream(manifest, "wt")?.bufferedWriter()?.use { it.write(content) }
                                ?: throw IOException("Manifest write failed")
                            true
                        }
                        "writeBackup" -> {
                            stage = "validate_staged_package"
                            require(name != null && name.endsWith(".bsexport") && file == null)
                            val source = File(call.argument<String>("source") ?: "").canonicalFile
                            require(listOf(cache, codeCache).any { source.path.startsWith(it.canonicalPath + File.separator) })
                            stage = "create_backup_document"
                            val document = DocumentsContract.createDocument(resolver, folder, ReceivedExportChannel.EXPORT_MIME_TYPE, name)
                                ?: throw IOException("Backup creation failed")
                            try {
                                stage = "copy_backup_document"
                                resolver.openOutputStream(document, "w")?.use { output ->
                                    source.inputStream().use { input -> input.copyTo(output) }
                                } ?: throw IOException("Backup write failed")
                                stage = "verify_backup_document"
                                // Providers may rename files; do not record a mismatched manifest entry.
                                if (children(tree, folder).none { it.uri == document && it.name == name && it.size == source.length() }) {
                                    throw IOException("Incomplete backup")
                                }
                            } catch (error: Exception) {
                                // Cleanup must not replace the original copy/verification failure.
                                try {
                                    if (!DocumentsContract.deleteDocument(resolver, document)) {
                                        Log.w("BoorusamaBackup", "Incomplete backup cleanup was rejected")
                                    }
                                } catch (cleanup: Exception) {
                                    Log.w("BoorusamaBackup", "Incomplete backup cleanup failed (${cleanup.javaClass.simpleName})")
                                }
                                throw error
                            }
                            true
                        }
                        else -> {
                            stage = "dispatch_operation"
                            throw IllegalArgumentException("Unknown operation")
                        }
                    }
                    main.post { result.success(value) }
                } catch (error: Exception) {
                    reportFailure(result, stage, error)
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
            if (flags != (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)) {
                throw SecurityException("Folder approval required")
            }
            resolver.takePersistableUriPermission(tree, flags)
            result.success(tree.toString())
        } catch (error: Exception) {
            reportFailure(result, "persist_folder_permission", error)
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