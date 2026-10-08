package com.timberpile.boorusama

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private var gifSaveChannel: GifSaveChannel? = null
    private var gifBackgroundChannel: GifBackgroundChannel? = null
    private var exportSaveChannel: ExportSaveChannel? = null
    private var receivedExportChannel: ReceivedExportChannel? = null
    private var searchRefreshEnvironmentChannel: SearchRefreshEnvironmentChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        searchRefreshEnvironmentChannel = SearchRefreshEnvironmentChannel(applicationContext, messenger)
        MediaScannerChannel(applicationContext, messenger).register()
        registerExportClipboardChannel(messenger)
        ImageClipboardChannel(applicationContext, messenger)
        GifMetadataChannel(applicationContext, messenger)
        gifSaveChannel = GifSaveChannel(this, messenger)
        gifBackgroundChannel = GifBackgroundChannel(applicationContext, messenger)
        exportSaveChannel = ExportSaveChannel(applicationContext, messenger)
        receivedExportChannel = ReceivedExportChannel(applicationContext, messenger).also {
            it.register()
            it.receive(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receivedExportChannel?.receive(intent)
    }

    override fun onDestroy() {
        receivedExportChannel?.close()
        exportSaveChannel?.close()
        gifSaveChannel?.close()
        gifBackgroundChannel?.close()
        searchRefreshEnvironmentChannel?.close()
        super.onDestroy()
    }

    private fun registerExportClipboardChannel(messenger: io.flutter.plugin.common.BinaryMessenger) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        MethodChannel(messenger, EXPORT_CLIPBOARD_CHANNEL).setMethodCallHandler { call, result ->
            val mimeType = call.argument<String>("mimeType")
            when (call.method) {
                "writeExport" -> {
                    val text = call.argument<String>("text")
                    if (mimeType != ReceivedExportChannel.EXPORT_MIME_TYPE || text == null) {
                        result.error("invalid_export", "Missing export clipboard data", null)
                    } else {
                        clipboard.setPrimaryClip(
                            ClipData(
                                "Boorusama export",
                                arrayOf(
                                    ReceivedExportChannel.EXPORT_MIME_TYPE,
                                    ClipDescription.MIMETYPE_TEXT_PLAIN,
                                ),
                                ClipData.Item(text),
                            ),
                        )
                        result.success(null)
                    }
                }
                "containsExport" -> result.success(
                    mimeType == ReceivedExportChannel.EXPORT_MIME_TYPE &&
                        clipboard.primaryClipDescription?.hasMimeType(
                            ReceivedExportChannel.EXPORT_MIME_TYPE,
                        ) == true,
                )
                "readExport" -> {
                    val hasExport = mimeType == ReceivedExportChannel.EXPORT_MIME_TYPE &&
                        clipboard.primaryClipDescription?.hasMimeType(
                            ReceivedExportChannel.EXPORT_MIME_TYPE,
                        ) == true
                    val value = if (hasExport && clipboard.primaryClip?.itemCount != 0) {
                        clipboard.primaryClip?.getItemAt(0)?.coerceToText(this)?.toString()
                    } else {
                        null
                    }
                    result.success(value)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val EXPORT_CLIPBOARD_CHANNEL =
            "com.timberpile.boorusama/export_clipboard"
    }
}
