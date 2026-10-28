package com.timberpile.boorusama

import java.io.IOException
import java.io.InputStream

/** SAF permits an unknown size; verify those documents by reading their bytes. */
internal fun readBackupDocumentSize(
    reportedSize: Long?,
    openInput: () -> InputStream?,
): Long {
    if (reportedSize != null && reportedSize >= 0) return reportedSize
    val input = openInput() ?: throw IOException("Backup unavailable")
    return input.use {
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var size = 0L
        while (true) {
            val count = it.read(buffer)
            if (count < 0) break
            size += count
        }
        size
    }
}
