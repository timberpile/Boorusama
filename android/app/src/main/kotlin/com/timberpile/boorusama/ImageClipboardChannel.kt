package com.timberpile.boorusama

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class ImageClipboardChannel(
    private val context: Context,
    messenger: BinaryMessenger?,
    private val launchActivity: (Intent) -> Unit = context::startActivity,
) {
    private val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    private val transfer = OwnedImageTransfer(context.cacheDir)
    private val main = Handler(Looper.getMainLooper())

    init {
        imageIo.execute { pruneOldFiles() }
        messenger?.let { binaryMessenger ->
            MethodChannel(binaryMessenger, "boorusama/image_clipboard")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "copyImageFile", "shareImageFile" -> dispatch(
                            call.argument<String>("path"),
                            call.argument<String>("mimeType"),
                            call.method == "copyImageFile",
                            result,
                        )
                        else -> result.notImplemented()
                    }
                }
        }
    }

    private fun dispatch(path: String?, mimeType: String?, copy: Boolean, result: MethodChannel.Result) {
        // The Dart source lease remains owned until this result completes. Large
        // originals copy and sync off the UI thread; only final URI publication
        // and the channel result run on the main thread.
        imageIo.execute {
            try {
                require(path != null && mimeType != null)
                pruneOldFiles()
                val uri = imageUri(path, mimeType)
                main.post {
                    try {
                        if (copy) publishCopy(uri) else publishShare(uri, mimeType)
                        result.success(null)
                    } catch (_: SecurityException) {
                        result.error("CLIPBOARD_DENIED", "Image clipboard access was denied", null)
                    } catch (_: Exception) {
                        result.error(if (copy) "CLIPBOARD_FAILED" else "SHARE_FAILED", "Image handoff failed", null)
                    }
                }
            } catch (_: IllegalArgumentException) {
                main.post { result.error("INVALID_IMAGE", "Image handoff payload is unavailable", null) }
            } catch (_: Exception) {
                main.post { result.error(if (copy) "CLIPBOARD_FAILED" else "SHARE_FAILED", "Image handoff failed", null) }
            }
        }
    }

    fun copyImageFile(path: String?, mimeType: String?): Uri {
        require(path != null && mimeType != null)
        pruneOldFiles()
        val uri = imageUri(path, mimeType)
        publishCopy(uri)
        return uri
    }

    fun shareImageFile(path: String?, mimeType: String?) {
        require(path != null && mimeType != null)
        pruneOldFiles()
        publishShare(imageUri(path, mimeType), mimeType)
    }

    private fun publishCopy(uri: Uri) {
        clipboard.setPrimaryClip(ClipData.newUri(context.contentResolver, "Image", uri))
    }

    private fun publishShare(uri: Uri, mimeType: String) {
        val sendIntent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newUri(context.contentResolver, "Image", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        launchActivity(Intent.createChooser(sendIntent, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun imageUri(path: String, mimeType: String): Uri {
        val file = transfer.copy(File(path), mimeType)
        try {
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.provider", file)
                .buildUpon()
                .appendQueryParameter("mime", mimeType)
                .build()
            require(context.contentResolver.getType(uri) == mimeType)
            return uri
        } catch (error: Exception) {
            file.delete()
            throw error
        }
    }

    private fun pruneOldFiles() = transfer.pruneExpired(System.currentTimeMillis())

    private companion object {
        val imageIo = Executors.newSingleThreadExecutor()
    }
}
