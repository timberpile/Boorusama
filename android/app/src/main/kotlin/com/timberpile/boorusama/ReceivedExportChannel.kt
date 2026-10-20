package com.timberpile.boorusama

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class ReceivedExportChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL_NAME)
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lock = Any()
    private val pendingExports = mutableListOf<Map<String, String>>()
    private var eventSink: EventChannel.EventSink? = null

    fun register() {
        eventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    val pending = synchronized(lock) {
                        eventSink = events
                        pendingExports.toList().also { pendingExports.clear() }
                    }
                    pending.forEach(events::success)
                }

                override fun onCancel(arguments: Any?) {
                    synchronized(lock) { eventSink = null }
                }
            },
        )
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePendingExports" -> {
                    val pending = synchronized(lock) {
                        pendingExports.toList().also { pendingExports.clear() }
                    }
                    result.success(pending)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun receive(intent: Intent?) {
        if (intent == null) return
        val isLink = intent.type == LINK_MIME_TYPE || intent.getBooleanExtra(LINK_DELIVERY, false)
        if (!isLink && intent.type != EXPORT_MIME_TYPE) return
        val uris = if (isLink) linkFileUris(intent) else listOfNotNull(intent.exportUri())
        executor.execute {
            for (uri in uris) {
                if (uri.scheme != ContentResolver.SCHEME_CONTENT) continue
                // In a mixed image/document share, ignore the preview attachment.
                if (isLink && intent.action == Intent.ACTION_SEND_MULTIPLE && !linkCandidate(uri)) continue
                val event = stage(uri, isLink) ?: continue
                mainHandler.post { publish(event) }
            }
        }
    }

    private fun linkCandidate(uri: Uri): Boolean {
        if (displayName(uri)?.endsWith(".bslink", ignoreCase = true) == true) return true
        val mime = try { context.contentResolver.getType(uri) } catch (_: Exception) { null }
        return mime == LINK_MIME_TYPE || mime == "application/octet-stream" || mime == "application/json"
    }

    fun close() {
        executor.shutdown()
    }

    private fun stage(uri: Uri, isLink: Boolean = false): Map<String, String>? {
        return try {
            val input = context.contentResolver.openInputStream(uri)
                ?: throw java.io.IOException("Document unavailable")
            val delivery = ReceivedExportStaging.stage(
                input,
                File(context.cacheDir, "received_exports"),
                if (isLink) MAX_LINK_BYTES else MAX_EXPORT_BYTES,
            )
            mapOf(
                "id" to delivery.id,
                "path" to delivery.file.absolutePath,
                "displayName" to (displayName(uri) ?: if (isLink) "received.bslink" else "received.bsexport"),
                "kind" to if (isLink) "link" else "export",
            )
        } catch (_: Exception) {
            if (isLink) mapOf("id" to java.util.UUID.randomUUID().toString(),
                "kind" to "link", "error" to "unreadable") else null
        }
    }

    private fun displayName(uri: Uri): String? =
        try {
            context.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (_: Exception) {
            null
        }

    private fun publish(event: Map<String, String>) {
        val sink = synchronized(lock) { eventSink }
        if (sink != null) {
            sink.success(event)
        } else {
            synchronized(lock) { pendingExports.add(event) }
        }
    }

    private fun Intent.exportUri(): Uri? =
        when (action) {
            Intent.ACTION_VIEW -> data
            Intent.ACTION_SEND -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                getParcelableExtra(Intent.EXTRA_STREAM)
            }
            else -> null
        }

    companion object {
        const val LINK_MIME_TYPE = "application/vnd.boorusama.link"
        const val LINK_DELIVERY = "com.timberpile.boorusama.link_delivery"
        private const val MAX_LINK_BYTES = 16L * 1024
        const val EXPORT_MIME_TYPE = "application/vnd.boorusama.export"
        private const val MAX_EXPORT_BYTES = 512L * 1024 * 1024
        private const val EVENT_CHANNEL_NAME = "com.timberpile.boorusama/received_exports"
        private const val METHOD_CHANNEL_NAME =
            "com.timberpile.boorusama/received_exports_methods"
    }
}
