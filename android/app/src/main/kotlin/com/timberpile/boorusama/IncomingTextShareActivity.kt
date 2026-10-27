package com.timberpile.boorusama

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log

/** Normalizes chooser task flags before the existing Flutter share receiver. */
class IncomingTextShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            if (intent.action == Intent.ACTION_SEND && intent.type?.startsWith("text/") == true) {
                startActivity(forwardIntent(this, intent))
            }
        } catch (error: SecurityException) {
            Log.w("IncomingTextShare", "Cannot forward text share: ${error.javaClass.simpleName}")
        } catch (error: IllegalArgumentException) {
            Log.w("IncomingTextShare", "Cannot forward text share: ${error.javaClass.simpleName}")
        } finally {
            finish()
        }
    }

    companion object {
        internal fun forwardIntent(context: Context, shared: Intent): Intent = Intent(shared).apply {
            selector = null
            setClass(context, MainActivity::class.java)
            setPackage(context.packageName)
            // Choosers add NEW_DOCUMENT/MULTIPLE_TASK to ordinary text shares.
            // REORDER_TO_FRONT preserves native activities (including billing)
            // above the Flutter host instead of destroying them with CLEAR_TOP.
            val grants = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            flags = (shared.flags and grants) or Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        }
    }
}
