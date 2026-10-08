package com.timberpile.boorusama

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.storage.StorageManager
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.OutputStream
import java.util.concurrent.Executors

class GifSaveChannel(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "boorusama/gif_save")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val resolver = context.contentResolver
    private val transfer = GifDocumentTransfer(context.cacheDir, context.codeCacheDir)

    private interface Target : GifDocumentTransfer.Destination {
        fun complete()
    }

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "saveToDirectory") {
                result.notImplemented()
            } else {
                val source = call.argument<String>("source")
                val name = call.argument<String>("name")
                val directory = call.argument<String>("directory")
                if (source == null || directory.isNullOrEmpty() || name == null ||
                    !name.matches(Regex("[A-Za-z0-9._-]+\\.gif"))) {
                    result.error("gif_save_failed", "GIF destination is unavailable", null)
                } else {
                    worker.execute {
                        var target: Target? = null
                        try {
                            target = destination(directory, name)
                            transfer.copy(File(source), target)
                            target.complete()
                            main.post { result.success(true) }
                        } catch (error: Exception) {
                            try { target?.delete() } catch (_: Exception) { }
                            main.post { result.error("gif_save_failed", "Could not save GIF to download folder", null) }
                        }
                    }
                }
            }
        }
    }

    private fun destination(directory: String, name: String): Target {
        val uri = Uri.parse(directory)
        if (uri.scheme == "content" && DocumentsContract.isTreeUri(uri)) {
            val parent = DocumentsContract.buildDocumentUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri))
            val document = DocumentsContract.createDocument(resolver, parent, "image/gif", name)
                ?: throw IOException("Download folder is unavailable")
            return uriTarget(document, mediaStore = false)
        }
        if (!File(directory).isAbsolute) throw IOException("Download folder is unavailable")
        val folder = File(directory).canonicalFile
        if (Build.VERSION.SDK_INT >= 29) return mediaStoreTarget(folder, name)

        val file = GifDownloadLocation.reserve(folder, name)
        return object : Target {
            override fun open(): OutputStream = FileOutputStream(file)
            override fun delete() { if (file.exists() && !file.delete()) throw IOException("Could not remove incomplete GIF") }
            override fun complete() {
                MediaScannerConnection.scanFile(context, arrayOf(file.path), arrayOf("image/gif"), null)
            }
        }
    }

    @androidx.annotation.RequiresApi(29)
    private fun mediaStoreTarget(folder: File, name: String): Target {
        var root = Environment.getExternalStorageDirectory().canonicalFile
        var volume = MediaStore.VOLUME_EXTERNAL_PRIMARY
        if (Build.VERSION.SDK_INT >= 30) {
            val manager = context.getSystemService(Context.STORAGE_SERVICE) as StorageManager
            val storage = manager.storageVolumes.firstOrNull { candidate ->
                candidate.directory?.canonicalFile?.let { directory ->
                    folder.path.startsWith(directory.path + File.separator)
                } == true
            } ?: throw IOException("Download volume is unavailable")
            root = storage.directory!!.canonicalFile
            volume = storage.mediaStoreVolumeName ?: throw IOException("Download volume is unavailable")
        } else if (!folder.path.startsWith(root.path + File.separator)) {
            val secondary = MediaStore.getExternalVolumeNames(context).firstOrNull { candidate ->
                folder.path.startsWith("/storage/$candidate/", ignoreCase = true)
            } ?: throw IOException("Download volume is unavailable")
            root = File("/storage/" + folder.path.split('/')[2]).canonicalFile
            volume = secondary
        }
        val location = GifDownloadLocation.shared(folder, root)
        val collection = if (location.primaryDirectory() == "Pictures") {
            MediaStore.Images.Media.getContentUri(volume)
        } else {
            MediaStore.Downloads.getContentUri(volume)
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/gif")
            put(MediaStore.MediaColumns.RELATIVE_PATH, location.relativePath())
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val document = resolver.insert(collection, values) ?: throw IOException("Download folder is unavailable")
        return uriTarget(document, mediaStore = true)
    }

    private fun uriTarget(document: Uri, mediaStore: Boolean) = object : Target {
        private var deleted = false
        override fun open(): OutputStream? = resolver.openOutputStream(document, "w")
        override fun delete() {
            if (deleted) return
            val removed = if (mediaStore) resolver.delete(document, null, null) > 0
                else DocumentsContract.deleteDocument(resolver, document)
            if (!removed) throw IOException("Could not remove incomplete GIF")
            deleted = true
        }
        override fun complete() {
            if (mediaStore && Build.VERSION.SDK_INT >= 29) {
                val values = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
                if (resolver.update(document, values, null, null) != 1) throw IOException("Could not publish GIF")
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
