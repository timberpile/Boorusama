package com.timberpile.boorusama

import java.io.ByteArrayOutputStream
import java.io.IOException
import org.junit.Assert.*
import org.junit.Test

class BackupDirectoryWriteProbeTest {
    @Test fun `writes one byte closes output and removes only its own probe`() {
        val existing = mutableSetOf("backup.zip", "manifest.json")
        var closed = false
        val stream = object : ByteArrayOutputStream() {
            override fun close() { closed = true; super.close() }
        }
        verifyBackupDirectoryWrite(
            create = { existing.add("unique-probe"); "unique-probe" },
            open = { assertEquals("unique-probe", it); stream },
            delete = { assertEquals("unique-probe", it); existing.remove(it) },
        )
        assertArrayEquals(byteArrayOf(0), stream.toByteArray())
        assertTrue(closed)
        assertEquals(setOf("backup.zip", "manifest.json"), existing)
    }
    @Test fun `failed or unavailable writes still remove the probe`() {
        for (missing in listOf(false, true)) {
            var deleted = false
            try {
                verifyBackupDirectoryWrite(
                    create = { "probe" },
                    open = { if (missing) null else throw IOException("write") },
                    delete = { deleted = true; true },
                )
                fail("Expected failure")
            } catch (_: IOException) { assertTrue(deleted) }
        }
    }
    @Test fun `write failure closes stream and removes probe`() {
        var closed = false
        var deleted = false
        val stream = object : java.io.OutputStream() {
            override fun write(value: Int) { throw IOException("write failed") }
            override fun close() { closed = true }
        }
        try {
            verifyBackupDirectoryWrite(create = { "probe" }, open = { stream },
                delete = { deleted = true; true })
            fail("Expected failure")
        } catch (_: IOException) {
            assertTrue(closed)
            assertTrue(deleted)
        }
    }
    @Test fun `failed creation cannot delete existing documents`() {
        try {
            verifyBackupDirectoryWrite<String>(
                create = { null }, open = { error("Unexpected open") },
                delete = { error("Unexpected delete") },
            )
            fail("Expected failure")
        } catch (_: IOException) { }
    }
    @Test fun `failed cleanup does not validate the folder`() {
        try {
            verifyBackupDirectoryWrite(create = { "probe" },
                open = { ByteArrayOutputStream() }, delete = { false })
            fail("Expected failure")
        } catch (_: IOException) { }
    }
}
