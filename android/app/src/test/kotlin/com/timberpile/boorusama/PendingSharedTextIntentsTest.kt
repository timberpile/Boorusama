package com.timberpile.boorusama

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PendingSharedTextIntentsTest {
    @Test
    fun `shares arriving before Dart listens are replayed once in delivery order`() {
        val delivered = mutableListOf<String>()
        val buffer = PendingSharedTextIntents<String> { delivered.add(it) }
        assertTrue(buffer.enqueueIfWaiting("first"))
        assertTrue(buffer.enqueueIfWaiting("second"))
        assertTrue(delivered.isEmpty())
        buffer.resume()
        buffer.resume()
        assertEquals(listOf("first", "second"), delivered)
        assertFalse(buffer.enqueueIfWaiting("already listening"))
    }

    @Test
    fun `a detached receiver holds new shares until its replacement listens`() {
        val delivered = mutableListOf<String>()
        val buffer = PendingSharedTextIntents<String> { delivered.add(it) }
        buffer.resume()
        buffer.pause()
        assertTrue(buffer.enqueueIfWaiting("next"))
        assertTrue(delivered.isEmpty())
        buffer.resume()
        assertEquals(listOf("next"), delivered)
    }

    @Test
    fun `destroying the activity discards its undelivered shares`() {
        val delivered = mutableListOf<String>()
        val buffer = PendingSharedTextIntents<String> { delivered.add(it) }
        buffer.enqueueIfWaiting("old activity")
        buffer.clear()
        buffer.resume()
        assertTrue(delivered.isEmpty())
    }
}
