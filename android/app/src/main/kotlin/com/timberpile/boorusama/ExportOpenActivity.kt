package com.timberpile.boorusama

import android.app.Activity
import android.content.ClipData
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle

class ExportOpenActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            val incoming = intent
            val uri = incoming.exportUri()
            if (incoming.type == ReceivedExportChannel.EXPORT_MIME_TYPE &&
                uri?.scheme == ContentResolver.SCHEME_CONTENT
            ) {
                startActivity(
                    Intent(this, MainActivity::class.java).apply {
                        action = Intent.ACTION_SEND
                        type = ReceivedExportChannel.EXPORT_MIME_TYPE
                        putExtra(Intent.EXTRA_STREAM, uri)
                        clipData = ClipData.newRawUri("Boorusama export", uri)
                        addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP,
                        )
                    },
                )
            }
        } catch (_: SecurityException) {
            return
        } catch (_: IllegalArgumentException) {
            return
        } finally {
            finish()
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
}
