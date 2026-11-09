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
import java.util.concurrent.Executors
import java.util.UUID

/** Read/write only within the approved SAF tree and the protocol subdirectory. */
class FolderSyncChannel(context: Context, messenger: BinaryMessenger) {
    private val resolver = context.applicationContext.contentResolver
    private val channel = MethodChannel(messenger, "boorusama/folder_sync")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val segment = Regex("^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$")
    private data class Child(val uri: Uri, val name: String, val directory: Boolean)

    private fun children(tree: Uri, parent: Uri): List<Child> {
        val query = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getDocumentId(parent))
        val columns = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE)
        return resolver.query(query, columns, null, null, null)?.use { cursor ->
            val result = mutableListOf<Child>()
            while (cursor.moveToNext()) {
                if (result.size >= 4096) throw IOException("Directory entry limit")
                result.add(Child(DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(0)),
                    cursor.getString(1) ?: "", cursor.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR))
            }
            result
        } ?: throw IOException("Directory unavailable")
    }

    private fun boundedRead(uri: Uri, maximum: Int): ByteArray {
        require(maximum in 1..MAX_BYTES)
        return resolver.openInputStream(uri)?.use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                if (output.size() + count > maximum) throw IOException("Byte limit")
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        } ?: throw IOException("Document unavailable")
    }

    init {
        channel.setMethodCallHandler { call, result -> worker.execute {
            try {
                val tree = Uri.parse(call.argument<String>("tree") ?: "")
                require(tree.scheme == "content" && tree.pathSegments.size == 2 && tree.pathSegments[0] == "tree")
                if (!resolver.persistedUriPermissions.any { it.uri == tree && it.isReadPermission && it.isWritePermission }) {
                    throw SecurityException("Folder approval required")
                }
                val relative = call.argument<String>("path") ?: ""
                require(relative.length <= 512)
                val parts = if (relative.isEmpty()) emptyList() else relative.split('/')
                require(parts.size <= 8 && parts.all { segment.matches(it) && it != "." && it != ".." })
                val writing = call.method == "write"
                val deleting = call.method == "deleteOwnedRevision"
                if (deleting) {
                    val owner = call.argument<String>("owner") ?: ""
                    require(isOwnedRevision(parts, owner))
                }
                var parent = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                val directories = listOf("BoorusamaSync", "v1") + if (writing || deleting || call.method == "read") parts.dropLast(1) else parts
                var missing = false
                for (name in directories) {
                    val matches = children(tree, parent).filter { it.name == name }
                    require(matches.size <= 1)
                    val found = matches.firstOrNull()
                    if (found != null) {
                        require(found.directory)
                        parent = found.uri
                    } else if (writing) {
                        parent = DocumentsContract.createDocument(resolver, parent, DocumentsContract.Document.MIME_TYPE_DIR, name)
                            ?: throw IOException("Directory creation failed")
                    } else { missing = true; break }
                }
                val value: Any? = when (call.method) {
                    "list" -> if (missing) emptyList<String>() else children(tree, parent).map { it.name }.filter { segment.matches(it) }.sorted()
                    "read" -> if (missing) null else {
                        require(parts.isNotEmpty())
                        val found = children(tree, parent).filter { it.name == parts.last() }
                        require(found.size <= 1)
                        found.firstOrNull()?.let { require(!it.directory); boundedRead(it.uri, call.argument<Int>("maxBytes") ?: MAX_BYTES) }
                    }
                    "deleteOwnedRevision" -> {
                        if (!missing) {
                            val found = children(tree, parent).filter { it.name == parts.last() }
                            require(found.size <= 1)
                            found.firstOrNull()?.let { require(!it.directory); require(DocumentsContract.deleteDocument(resolver, it.uri)) }
                        }
                        true
                    }
                    "write" -> {
                        require(parts.isNotEmpty())
                        val bytes = call.argument<ByteArray>("bytes") ?: throw IllegalArgumentException()
                        require(bytes.size <= MAX_BYTES)
                        val finalName = parts.last()
                        val temporaryName = "$finalName.${UUID.randomUUID()}.partial"
                        publishImmutableSyncDocument(
                            bytes = bytes,
                            findFinal = {
                                val found = children(tree, parent).filter { it.name == finalName }
                                require(found.size <= 1 && found.none { it.directory })
                                found.firstOrNull()?.uri
                            },
                            createStaged = {
                                val created = DocumentsContract.createDocument(resolver, parent, "application/octet-stream", temporaryName)
                                    ?: throw IOException("Document staging failed")
                                require(children(tree, parent).any { it.uri == created && it.name == temporaryName && !it.directory })
                                created
                            },
                            writeStaged = { document, content ->
                                resolver.openOutputStream(document, "w")?.use { it.write(content); it.flush() }
                                    ?: throw IOException("Document write failed")
                            },
                            read = { document -> boundedRead(document, MAX_BYTES) },
                            promote = { document ->
                                val renamed = DocumentsContract.renameDocument(resolver, document, finalName)
                                    ?: throw IOException("Document rename unavailable")
                                require(children(tree, parent).count { it.uri == renamed && it.name == finalName && !it.directory } == 1)
                                renamed
                            },
                            discardStaged = { document ->
                                // A provider may complete rename before returning an error.
                                // Never delete that final document through its old URI.
                                if (children(tree, parent).any { it.uri == document && it.name == temporaryName && !it.directory }) {
                                    DocumentsContract.deleteDocument(resolver, document)
                                }
                            }
                        )
                        true
                    }
                    else -> throw IllegalArgumentException("Unsupported sync operation")
                }
                main.post { result.success(value) }
            } catch (error: Exception) {
                val code = if (error is SecurityException) "sync_folder_access_required" else "sync_storage_failed"
                main.post { result.error(code, "Folder sync storage failed", mapOf("causeType" to error.javaClass.simpleName)) }
            }
        } }
    }
    fun close() { channel.setMethodCallHandler(null); worker.shutdown() }
    companion object {
        private const val MAX_BYTES = 32 * 1024 * 1024
        internal fun isOwnedRevision(parts: List<String>, owner: String): Boolean {
            fun uuid(value: String): Boolean = try { UUID.fromString(value).toString() == value } catch (_: IllegalArgumentException) { false }
            if (!uuid(owner) || parts.size < 4 || parts[0] != "devices" || parts[1] != owner) return false
            val file = when {
                parts.size == 4 && parts[2] == "catalog" -> parts[3].takeIf { it.endsWith(".json") }
                parts.size == 6 && parts[2] == "collections" && parts[3] in setOf("bookmarks", "following_topics") && uuid(parts[4]) -> parts[5]
                else -> null
            } ?: return false
            if (!Regex("^[1-9][0-9]{0,15}\\.(json|bsexport)$").matches(file)) return false
            return (file.substringBefore('.').toLongOrNull() ?: return false) <= 9007199254740991L
        }
    }
}
