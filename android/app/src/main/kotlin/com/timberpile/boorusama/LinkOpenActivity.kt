package com.timberpile.boorusama

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle

/** A document-only entry point. Generic MIME is accepted only for explicit
 * Share-to, never registered as the viewer for every file on the device. */
class LinkOpenActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            val sources = linkFileUris(intent).filter { it.scheme == "content" }
            if (sources.isEmpty()) return
            startActivity(Intent(this, MainActivity::class.java).apply {
                action = if (sources.size == 1) Intent.ACTION_SEND else Intent.ACTION_SEND_MULTIPLE
                type = ReceivedExportChannel.LINK_MIME_TYPE
                putExtra(ReceivedExportChannel.LINK_DELIVERY, true)
                if (sources.size == 1) putExtra(Intent.EXTRA_STREAM, sources.first())
                else putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(sources))
                clipData = ClipData.newRawUri("Boorusama link", sources.first()).apply {
                    sources.drop(1).forEach { addItem(ClipData.Item(it)) }
                }
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP)
            })
        } catch (_: SecurityException) {
            // A revoked URI grant must never cause an app crash.
        } catch (_: IllegalArgumentException) {
            // Malformed external intents carry no executable navigation.
        } finally {
            finish()
        }
    }
}

/** Bound the number of attachments before querying a remote content provider. */
internal fun linkFileUris(intent: Intent): List<Uri> = when (intent.action) {
    Intent.ACTION_VIEW -> listOfNotNull(intent.data)
    Intent.ACTION_SEND -> listOfNotNull(if (Build.VERSION.SDK_INT >= 33) {
        intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
    } else {
        @Suppress("DEPRECATION")
        intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
    })
    Intent.ACTION_SEND_MULTIPLE -> (if (Build.VERSION.SDK_INT >= 33) {
        intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
    } else {
        @Suppress("DEPRECATION")
        intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
    })?.take(8) ?: emptyList()
    else -> emptyList()
}
