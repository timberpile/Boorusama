package com.timberpile.boorusama

import java.io.IOException
import java.io.OutputStream

/** Operates only on the newly created probe; existing documents are never selected. */
internal fun <T : Any> verifyBackupDirectoryWrite(
    create: () -> T?,
    open: (T) -> OutputStream?,
    delete: (T) -> Boolean,
) {
    val probe = create() ?: throw IOException("Could not validate backup folder")
    try {
        open(probe)?.use { it.write(byteArrayOf(0)) }
            ?: throw IOException("Could not write backup probe")
    } finally {
        if (!delete(probe)) throw IOException("Could not remove backup probe")
    }
}
