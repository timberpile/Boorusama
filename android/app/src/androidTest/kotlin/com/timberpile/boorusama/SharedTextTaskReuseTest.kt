package com.timberpile.boorusama

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.runner.lifecycle.ActivityLifecycleCallback
import androidx.test.runner.lifecycle.ActivityLifecycleMonitorRegistry
import androidx.test.runner.lifecycle.Stage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

@RunWith(AndroidJUnit4::class)
class SharedTextTaskReuseTest {
    @Test
    fun normalizationPreservesPayloadAndGrantsWithoutMutatingTheSenderIntent() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val text = "Caption #pixiv https://www.pixiv.net/en/artworks/12345"
        val uri = Uri.parse("content://share-test/text")
        val originalFlags = Intent.FLAG_ACTIVITY_NEW_DOCUMENT or
            Intent.FLAG_ACTIVITY_MULTIPLE_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK or
            Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_GRANT_READ_URI_PERMISSION
        val shared = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            putExtra(Intent.EXTRA_SUBJECT, "Shared artwork")
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newPlainText("Shared text", text).apply {
                addItem(ClipData.Item(uri))
            }
            flags = originalFlags
        }
        val forwarded = IncomingTextShareActivity.forwardIntent(context, shared)
        assertEquals(Intent.ACTION_SEND, forwarded.action)
        assertEquals("text/plain", forwarded.type)
        assertEquals(text, forwarded.getStringExtra(Intent.EXTRA_TEXT))
        assertEquals("Shared artwork", forwarded.getStringExtra(Intent.EXTRA_SUBJECT))
        assertEquals(uri, forwarded.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java))
        assertEquals(text, forwarded.clipData!!.getItemAt(0).text)
        assertEquals(uri, forwarded.clipData!!.getItemAt(1).uri)
        assertEquals(MainActivity::class.java.name, forwarded.component!!.className)
        assertEquals(context.packageName, forwarded.`package`)
        assertEquals(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_GRANT_READ_URI_PERMISSION,
            forwarded.flags,
        )
        assertEquals(originalFlags, shared.flags)
    }

    @Test
    fun repeatedDocumentSharesReuseTheBackgroundFlutterActivity() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val monitor = ActivityLifecycleMonitorRegistry.getInstance()
        val resumed = AtomicReference<CompletableFuture<Activity>?>(null)
        val stopped = AtomicReference<CompletableFuture<Activity>?>(null)
        val created = mutableSetOf<Activity>()
        val callback = ActivityLifecycleCallback { activity, stage ->
            if (activity is MainActivity) {
                if (stage == Stage.CREATED) created.add(activity)
                if (stage == Stage.RESUMED) resumed.get()?.complete(activity)
                if (stage == Stage.STOPPED) stopped.get()?.complete(activity)
            }
        }
        val launch = Intent(context, MainActivity::class.java)
            .setAction(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        instrumentation.runOnMainSync { monitor.addLifecycleCallback(callback) }
        try {
            val initial = CompletableFuture<Activity>()
            resumed.set(initial)
            context.startActivity(launch)
            val original = initial.get(15, TimeUnit.SECONDS)
            val taskId = original.taskId
            repeat(3) {
                val background = CompletableFuture<Activity>()
                stopped.set(background)
                instrumentation.runOnMainSync { original.moveTaskToBack(true) }
                assertSame(original, background.get(15, TimeUnit.SECONDS))
                val delivery = CompletableFuture<Activity>()
                resumed.set(delivery)
                // Android's chooser supplies document/multiple-task flags even
                // when the sender's ACTION_SEND did not explicitly set them.
                context.startActivity(
                    Intent()
                        .setPackage(context.packageName)
                        .setAction(Intent.ACTION_SEND)
                        .setType("text/plain")
                        .putExtra(Intent.EXTRA_TEXT, "https://www.pixiv.net/artworks/12345")
                        .addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_NEW_DOCUMENT or
                                Intent.FLAG_ACTIVITY_MULTIPLE_TASK,
                        ),
                )
                val activity = delivery.get(15, TimeUnit.SECONDS)
                assertSame("A share must reach the existing Flutter host", original, activity)
                assertEquals("A share must keep the existing Android task", taskId, activity.taskId)
            }
        } finally {
            instrumentation.runOnMainSync {
                monitor.removeLifecycleCallback(callback)
                created.forEach { it.finishAndRemoveTask() }
            }
        }
    }
}
