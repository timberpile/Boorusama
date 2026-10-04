package com.timberpile.boorusama

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

class ImageClipboardChannel(
    private val context: Context,
    messenger: BinaryMessenger?,
    private val launchActivity: (Intent) -> Unit = context::startActivity,
) {
    private val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    private val sourceDirectory = File(context.cacheDir, "cacheimage").canonicalFile
    private val directory = File(context.cacheDir, "boorusama-clipboard").canonicalFile

    init {
        pruneOldFiles()
        messenger?.let { binaryMessenger ->
            MethodChannel(binaryMessenger, "boorusama/image_clipboard")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "copyImageFile" -> try {
                            copyImageFile(
                                call.argument<String>("path"),
                                call.argument<String>("mimeType"),
                            )
                            result.success(null)
                        } catch (_: IllegalArgumentException) {
                            result.error("INVALID_IMAGE", "Image clipboard payload is unavailable", null)
                        } catch (_: SecurityException) {
                            result.error("CLIPBOARD_DENIED", "Image clipboard access was denied", null)
                        } catch (_: Exception) {
                            result.error("CLIPBOARD_FAILED", "Image clipboard copy failed", null)
                        }
                        "shareImageFile" -> try {
                            shareImageFile(
                                call.argument<String>("path"),
                                call.argument<String>("mimeType"),
                            )
                            result.success(null)
                        } catch (_: IllegalArgumentException) {
                            result.error("INVALID_IMAGE", "Image share payload is unavailable", null)
                        } catch (_: Exception) {
                            result.error("SHARE_FAILED", "Image share failed", null)
                        }
                        else -> result.notImplemented()
                    }
                }
        }
    }

    fun copyImageFile(path: String?, mimeType: String?): Uri {
        require(path != null && mimeType != null)
        require(mimeType in supportedImageMimeTypes)
        val uri = imageUri(path, mimeType)
        clipboard.setPrimaryClip(ClipData.newUri(context.contentResolver, File(path).name, uri))
        pruneOldFiles()
        return uri
    }

    fun shareImageFile(path: String?, mimeType: String?) {
        require(path != null && mimeType != null)
        val uri = imageUri(path, mimeType)
        val sendIntent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newUri(context.contentResolver, File(path).name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        launchActivity(
            Intent.createChooser(sendIntent, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    private fun imageUri(path: String, mimeType: String): Uri {
        require(mimeType in supportedImageMimeTypes)
        val file = File(path).canonicalFile
        require(file.parentFile == sourceDirectory && file.isFile && file.length() > 0L)
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.provider", file)
            .buildUpon()
            .appendQueryParameter("mime", mimeType)
            .build()
        require(context.contentResolver.getType(uri) == mimeType)
        return uri
    }

    private fun pruneOldFiles() {
        directory.listFiles()?.filter { it.isFile }?.forEach { it.delete() }
    }

    private companion object {
        val supportedImageMimeTypes = setOf(
            "image/jpeg", "image/png", "image/gif", "image/webp",
            "image/avif", "image/bmp",
        )
    }
}
