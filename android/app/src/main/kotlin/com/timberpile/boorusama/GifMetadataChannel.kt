package com.timberpile.boorusama

import android.content.Context
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** The minimal FFprobe build omits display-matrix side data from its JSON. */
class GifMetadataChannel(context: Context, messenger: BinaryMessenger) {
    private val roots = listOf(context.cacheDir, context.codeCacheDir).map { it.canonicalFile }
    private val main = Handler(Looper.getMainLooper())

    init {
        MethodChannel(messenger, "boorusama/gif_metadata").setMethodCallHandler { call, result ->
            if (call.method != "rotation") {
                result.notImplemented()
            } else {
                val path = call.argument<String>("path")
                metadataIo.execute {
                    try {
                        require(path != null)
                        val file = File(path).canonicalFile
                        require(file.isFile && roots.any { file.path.startsWith(it.path + File.separator) })
                        val retriever = MediaMetadataRetriever()
                        val rotation = try {
                            retriever.setDataSource(file.path)
                            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                                ?.toIntOrNull() ?: 0
                        } finally {
                            retriever.release()
                        }
                        main.post { result.success(rotation) }
                    } catch (_: Exception) {
                        main.post { result.error("GIF_METADATA_FAILED", "Video rotation unavailable", null) }
                    }
                }
            }
        }
    }

    private companion object {
        val metadataIo = Executors.newSingleThreadExecutor()
    }
}
