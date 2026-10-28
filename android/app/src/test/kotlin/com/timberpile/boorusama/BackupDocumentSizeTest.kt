package com.timberpile.boorusama

import java.io.ByteArrayInputStream
import java.io.IOException
import java.io.InputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class BackupDocumentSizeTest {
    @Test
    fun `known sizes including empty documents do not open a stream`() {
        for (size in listOf(0L, 123L)) {
            assertEquals(size, readBackupDocumentSize(size) { error("Unexpected read") })
        }
    }

    @Test
    fun `unknown sizes are measured across buffers and the stream is closed`() {
        for (reported in listOf(null, -1L)) {
            var closed = false
            val input = object : ByteArrayInputStream(ByteArray(20000)) {
                override fun close() {
                    closed = true
                    super.close()
                }
            }
            assertEquals(20000L, readBackupDocumentSize(reported) { input })
            assertTrue(closed)
        }
    }

    @Test
    fun `unknown empty documents remain empty rather than assumed complete`() {
        assertEquals(0L, readBackupDocumentSize(null) { ByteArrayInputStream(byteArrayOf()) })
    }

    @Test(expected = IOException::class)
    fun `an unavailable stream fails verification`() {
        readBackupDocumentSize(null) { null }
    }

    @Test
    fun `read failures propagate and close the stream`() {
        var closed = false
        val input = object : InputStream() {
            override fun read(): Int = throw IOException("Read failed")
            override fun close() { closed = true }
        }
        try {
            readBackupDocumentSize(null) { input }
            fail("Expected a read failure")
        } catch (_: IOException) {
            assertTrue(closed)
        }
    }
}
