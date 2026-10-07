package com.timberpile.boorusama

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.io.OutputStream
import java.util.concurrent.Executors

class ExportSaveChannel(context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "boorusama/export_save")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val transfer = ExportDocumentTransfer(context.cacheDir, context.codeCacheDir)
    private val resolver = context.contentResolver

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "saveToDirectory") {
                result.notImplemented()
            } else {
                val source = call.argument<String>("source")
                val tree = call.argument<String>("directory")?.let(Uri::parse)
                if (source == null || tree?.scheme != "content" || !DocumentsContract.isTreeUri(tree)) {
                    result.error("invalid_destination", "Export destination is unavailable", null)
                } else {
                    worker.execute {
                        try {
                            val saved = transfer.copy(File(source), destination(tree))
                            main.post { result.success(saved) }
                        } catch (error: Exception) {
                            // Do not expose source paths or export contents in errors.
                            main.post { result.error("export_save_failed", "Could not write export to the selected folder", null) }
                        }
                    }
                }
            }
        }
    }

    private fun destination(tree: Uri) = object : ExportDocumentTransfer.Destination {
        private val parent = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))

        override fun names(): Set<String> {
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
            val names = mutableSetOf<String>()
            val cursor = resolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)
                ?: throw IOException("Could not read export folder")
            cursor.use {
                while (it.moveToNext()) it.getString(0)?.let(names::add)
            }
            return names
        }

        override fun create(name: String): String? = DocumentsContract.createDocument(
            resolver, parent, ReceivedExportChannel.EXPORT_MIME_TYPE, name,
        )?.toString()

        override fun open(document: String): OutputStream? = resolver.openOutputStream(Uri.parse(document), "w")

        override fun delete(document: String) {
            if (!DocumentsContract.deleteDocument(resolver, Uri.parse(document))) {
                throw IOException("Could not remove incomplete export")
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
