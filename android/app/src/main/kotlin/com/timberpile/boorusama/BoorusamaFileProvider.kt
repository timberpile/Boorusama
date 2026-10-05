package com.timberpile.boorusama

import android.net.Uri
import androidx.core.content.FileProvider

class BoorusamaFileProvider : FileProvider() {
    override fun getType(uri: Uri): String {
        uri.getQueryParameter("mime")?.takeIf { it in supportedImageMimeTypes }?.let {
            return it
        }
        return when (uri.lastPathSegment?.substringAfterLast('.')?.lowercase()) {
        "jpg", "jpeg" -> "image/jpeg"
        "png" -> "image/png"
        "gif" -> "image/gif"
        "webp" -> "image/webp"
        "avif" -> "image/avif"
        "bmp" -> "image/bmp"
        else -> super.getType(uri) ?: "application/octet-stream"
        }
    }

    private companion object {
        val supportedImageMimeTypes = setOf(
            "image/jpeg", "image/png", "image/gif", "image/webp",
            "image/avif", "image/bmp",
        )
    }
}
