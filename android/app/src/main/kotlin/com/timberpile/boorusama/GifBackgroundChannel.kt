package com.timberpile.boorusama

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class GifBackgroundChannel(context: Context, messenger: BinaryMessenger) {
    private val context = context.applicationContext
    private val channel = MethodChannel(messenger, "boorusama/gif_background")
    private var job: Long? = null
    private var pending: MethodChannel.Result? = null

    init {
        GifConversionForegroundService.onStarted = { id, error ->
            if (job == id) {
                val result = pending
                pending = null
                if (error == null) result?.success(null)
                else result?.error("gif_background_failed", "Could not start GIF conversion", null)
            }
        }
        GifConversionForegroundService.onCancel = { id ->
            if (job == id) channel.invokeMethod("cancel", id)
        }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val id = call.argument<Number>("job")?.toLong()
                    val title = call.argument<String>("title")
                    val cancel = call.argument<String>("cancelLabel")
                    if (id == null || title.isNullOrEmpty() || cancel.isNullOrEmpty() || job != null) {
                        result.error("gif_background_failed", "GIF conversion is unavailable", null)
                    } else {
                        job = id
                        pending = result
                        GifConversionForegroundService.activeJob = id
                        try {
                            ContextCompat.startForegroundService(this.context,
                                Intent(this.context, GifConversionForegroundService::class.java)
                                    .putExtra("job", id).putExtra("title", title).putExtra("cancelLabel", cancel))
                        } catch (_: Exception) {
                            pending = null
                            result.error("gif_background_failed", "Could not start GIF conversion", null)
                        }
                    }
                }
                "stop" -> {
                    if ((call.arguments as? Number)?.toLong() == job) {
                        this.context.stopService(Intent(this.context, GifConversionForegroundService::class.java))
                        GifConversionForegroundService.activeJob = null
                        job = null
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun close() {
        GifConversionForegroundService.onCancel?.let { callback -> job?.let(callback) }
        context.stopService(Intent(context, GifConversionForegroundService::class.java))
        GifConversionForegroundService.activeJob = null
        GifConversionForegroundService.onStarted = null
        GifConversionForegroundService.onCancel = null
        pending?.error("gif_background_failed", "GIF engine closed", null)
        pending = null
        job = null
        channel.setMethodCallHandler(null)
    }
}
