package com.timberpile.boorusama

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeFalse
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class ImageClipboardChannelTest {
    @Test
    fun copyUsesNormalImageCacheFileWithoutCreatingClipboardCopy() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val directory = File(context.cacheDir, "cacheimage")
        directory.mkdirs()
        val file = File(directory, "normal_cache_${System.nanoTime()}")
        val bytes = byteArrayOf(0x89.toByte(), 0x50, 0x4e, 0x47)
        file.writeBytes(bytes)

        val channel = ImageClipboardChannel(context, null)
        val uri = channel.copyImageFile(file.path, "image/png")
        val clipboardDirectory = File(context.cacheDir, "boorusama-clipboard")

        assertEquals("content", uri.scheme)
        assertEquals("image/png", context.contentResolver.getType(uri))
        assertArrayEquals(bytes, context.contentResolver.openInputStream(uri)!!.use { it.readBytes() })
        assertTrue(file.exists())
        assertFalse(clipboardDirectory.listFiles()?.any() == true)
    }
    @Test
    fun shareSendsNormalCacheUriWithoutMakingAnotherFile() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val directory = File(context.cacheDir, "cacheimage")
        directory.mkdirs()
        val file = File(directory, "share_cache_${System.nanoTime()}")
        val bytes = byteArrayOf(0x89.toByte(), 0x50, 0x4e, 0x47)
        file.writeBytes(bytes)
        var launched: android.content.Intent? = null
        ImageClipboardChannel(context, null) { launched = it }
            .shareImageFile(file.path, "image/png")
        val chooser = launched!!
        val send = chooser.getParcelableExtra<android.content.Intent>(android.content.Intent.EXTRA_INTENT)!!
        val uri = send.getParcelableExtra<android.net.Uri>(android.content.Intent.EXTRA_STREAM)!!
        assertEquals(android.content.Intent.ACTION_SEND, send.action)
        assertEquals("image/png", send.type)
        assertArrayEquals(bytes, context.contentResolver.openInputStream(uri)!!.use { it.readBytes() })
        assertTrue(file.exists())
        assertFalse(File(context.cacheDir, "boorusama-share").listFiles()?.any() == true)
    }

    @Test
    fun foregroundCopyLeavesContentUriOnSystemClipboard() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        // The emulator host clipboard bridge replaces URI clips with plain text.
        assumeFalse(Build.HARDWARE == "ranchu" || Build.HARDWARE == "goldfish")
        val directory = File(context.cacheDir, "cacheimage")
        directory.mkdirs()
        val file = File(directory, "boorusama_share_foreground_${System.nanoTime()}")
        val bytes = byteArrayOf(0xff.toByte(), 0xd8.toByte(), 0x01, 0x02, 0xff.toByte(), 0xd9.toByte())
        file.writeBytes(bytes)

        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            scenario.onActivity { activity ->
                val clipboard = activity.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val channel = ImageClipboardChannel(activity.applicationContext, null)
                val expected = channel.copyImageFile(file.path, "image/jpeg")
                val clip = clipboard.primaryClip

                assertEquals(expected, clip?.getItemAt(0)?.uri)
                assertTrue(clip!!.description.hasMimeType("image/jpeg"))
                assertArrayEquals(bytes, activity.contentResolver.openInputStream(expected)!!.use { it.readBytes() })
            }
        }
    }

    @Test
    fun copiedImageRetainsExactBytesAndMimeThroughProvider() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val directory = File(context.cacheDir, "cacheimage")
        directory.mkdirs()
        val channel = ImageClipboardChannel(context, null)
        val cases = listOf(
            Triple("jpg", "image/jpeg", byteArrayOf(0xff.toByte(), 0xd8.toByte(), 0xff.toByte(), 0xd9.toByte())),
            Triple("webp", "image/webp", byteArrayOf(0x52, 0x49, 0x46, 0x46, 0x01, 0x02, 0x03, 0x04)),
            Triple("png", "image/png", byteArrayOf(0x89.toByte(), 0x50, 0x4e, 0x47)),
            Triple("avif", "image/avif", byteArrayOf(0x00, 0x00, 0x00, 0x18)),
        )
        val stamp = System.nanoTime()
        for ((extension, mime, bytes) in cases) {
            val file = File(directory, "boorusama_share_native_test_${stamp}_$extension")
            file.writeBytes(bytes)

            val uri = channel.copyImageFile(file.path, mime)
            val clip = ClipData.newUri(context.contentResolver, file.name, uri)
            val oldClipboardDirectory = File(context.cacheDir, "boorusama-clipboard")

            assertEquals("content", uri.scheme)
            assertTrue(clip.description.hasMimeType(mime))
            assertEquals(mime, context.contentResolver.getType(uri))
            assertArrayEquals(bytes, context.contentResolver.openInputStream(uri)!!.use { it.readBytes() })
            assertTrue(file.exists())
            assertFalse(oldClipboardDirectory.listFiles()?.any() == true)
        }
    }
}
