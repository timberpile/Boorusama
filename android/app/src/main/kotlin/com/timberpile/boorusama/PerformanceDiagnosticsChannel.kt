package com.timberpile.boorusama

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.concurrent.Executors

class PerformanceDiagnosticsChannel(context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "boorusama/performance_diagnostics")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val resolver = context.contentResolver

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "save") {
                result.notImplemented()
            } else {
                val contents = call.argument<String>("contents")
                val fileName = call.argument<String>("fileName")
                if (Build.VERSION.SDK_INT < 29 || contents == null ||
                    fileName == null || !SAFE_FILE_NAME.matches(fileName)) {
                    result.error(
                        "diagnostic_export_failed",
                        "Performance report destination is unavailable",
                        null,
                    )
                } else {
                    worker.execute {
                        try {
                            val path = save(contents, fileName)
                            main.post { result.success(path) }
                        } catch (error: Exception) {
                            Log.e(TAG, "Could not save performance report", error)
                            main.post {
                                result.error(
                                    "diagnostic_export_failed",
                                    "Could not save performance report",
                                    null,
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    @androidx.annotation.RequiresApi(29)
    private fun save(contents: String, fileName: String): String {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
            put(MediaStore.MediaColumns.RELATIVE_PATH, RELATIVE_PATH)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val document = resolver.insert(collection, values)
            ?: throw IOException("Performance report destination is unavailable")
        try {
            resolver.openOutputStream(document, "w")?.use {
                it.write(contents.toByteArray(Charsets.UTF_8))
                it.flush()
            } ?: throw IOException("Performance report destination is unavailable")
            val published = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            if (resolver.update(document, published, null, null) != 1) {
                throw IOException("Could not publish performance report")
            }
        } catch (error: Exception) {
            resolver.delete(document, null, null)
            throw error
        }
        return "/storage/emulated/0/$RELATIVE_PATH$fileName"
    }

    fun close() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }

    companion object {
        internal val RELATIVE_PATH = "${Environment.DIRECTORY_DOWNLOADS}/Dev/diagnostics/"
        private const val TAG = "PerformanceDiagnostics"
        internal val SAFE_FILE_NAME = Regex(
            "boorusama-performance-(debug|profile|release)-" +
                "[0-9]{8}T[0-9]{9}Z-([a-fA-F0-9]{8}|unknown)\\.json",
        )
    }
}
