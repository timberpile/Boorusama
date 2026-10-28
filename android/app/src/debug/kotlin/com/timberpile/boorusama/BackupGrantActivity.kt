package com.timberpile.boorusama

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/** A disabled-by-default debug fixture for real persistable Intent URI grants. */
class BackupGrantActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uri = intent.data
        if (uri?.authority == "com.timberpile.boorusama.backup.test.documents" && uri.path == "/tree/root") {
            contentResolver.takePersistableUriPermission(uri,
                intent.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
        }
        finish()
    }
}
