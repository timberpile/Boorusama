package com.timberpile.boorusama

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.DocumentsContract
import android.app.Activity
import android.app.ActivityOptions
import android.app.PendingIntent
import android.os.Build
import android.app.UiAutomation
import android.content.Context
import android.content.ComponentName
import android.content.pm.PackageManager
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.StandardMethodCodec
import io.flutter.plugin.common.MethodCall
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class AutoBackupDocumentsProviderTest {
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    private val context get() = instrumentation.targetContext
    private val resolver get() = context.contentResolver
    private val tree get() = BackupTestDocumentsProvider.tree()
    private val automation get() = instrumentation.getUiAutomation(UiAutomation.FLAG_DONT_USE_ACCESSIBILITY)
    private val rw = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION

    private fun provider(method: String, arg: String? = null, extras: Bundle? = null) {
        automation.adoptShellPermissionIdentity("android.permission.MANAGE_DOCUMENTS",
            "android.permission.START_ACTIVITIES_FROM_BACKGROUND")
        try {
            val response = checkNotNull(resolver.call(Uri.parse("content://${BackupTestDocumentsProvider.AUTHORITY}"), method, arg, extras))
            val grant = response.getParcelable<PendingIntent>("grant")
            if (grant != null) {
                val options = ActivityOptions.makeBasic()
                if (Build.VERSION.SDK_INT >= 34) options.setPendingIntentBackgroundActivityStartMode(
                    ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
                val monitor = instrumentation.addMonitor(BackupGrantActivity::class.java.name, null, false)
                try {
                    grant.send(context, 0, null, null, null, null, options.toBundle())
                    checkNotNull(instrumentation.waitForMonitorWithTimeout(monitor, 30_000))
                    instrumentation.waitForIdleSync()
                } finally { instrumentation.removeMonitor(monitor) }
            }
        } finally { automation.dropShellPermissionIdentity() }
    }

    private fun fixture(behavior: String) {
        provider("fixture", extras = Bundle().apply {
            putString("behavior", behavior); putString("package", context.packageName)
        })
        resolver.takePersistableUriPermission(tree, rw)
    }

    private fun withChannel(body: (TestMessenger, AutoBackupChannel) -> Unit) {
        val messenger = TestMessenger()
        val source = File(context.cacheDir, "issue84-provider-test.bsexport")
        source.writeBytes(ByteArray(4097) { (it % 251).toByte() })
        var channel: AutoBackupChannel? = null
        val grantActivity = ComponentName(context.packageName, BackupGrantActivity::class.java.name)
        context.packageManager.setComponentEnabledSetting(grantActivity,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
        try {
            val target = context
            // These storage operations need the real resolver, not a Flutter UI.
            instrumentation.runOnMainSync {
                val activity = object : Activity() {
                    override fun getApplicationContext(): Context = target
                    override fun startActivityForResult(intent: Intent, requestCode: Int) = Unit
                }
                channel = AutoBackupChannel(activity, messenger)
            }
            try { body(messenger, channel!!) } finally { instrumentation.runOnMainSync { channel!!.close() } }
        } finally {
            source.delete()
            context.packageManager.setComponentEnabledSetting(grantActivity,
                PackageManager.COMPONENT_ENABLED_STATE_DEFAULT, PackageManager.DONT_KILL_APP)
            runCatching { resolver.releasePersistableUriPermission(tree, rw) }
        }
    }

    private fun TestMessenger.operation(method: String, name: String? = null): Any? = invoke(method, mapOf(
        "location" to (if (name == null) tree else tree.buildUpon().appendPath(name).build()).toString(),
        "source" to File(context.cacheDir, "issue84-provider-test.bsexport").path,
    ))

    @Test fun unknownNullAndNegativeSizesVerifyActualBytesAndCanBeReopened() = withChannel { channel, _ ->
        for (mode in listOf("null", "negative", "known")) {
            fixture(mode)
            assertEquals(true, channel.operation("writeBackup", "new.bsexport"))
            assertEquals(4097L, channel.operation("size", "new.bsexport"))
            assertEquals(listOf("older.bsexport", "new.bsexport"), channel.operation("list"))
            assertEquals(3L, channel.operation("size", "older.bsexport"))
            val older = DocumentsContract.buildDocumentUriUsingTree(tree, "old")
            assertArrayEquals(byteArrayOf(9, 8, 7), resolver.openInputStream(older)!!.use { it.readBytes() })
            assertEquals("{\"backups\":[\"older.bsexport\"]}", channel.operation("readManifest"))
        }
    }

    @Test fun zeroTruncatedReadFailureAndRenameCleanOnlyFailedDocumentThenRetry() = withChannel { channel, _ ->
        for (mode in listOf("zero", "truncated", "read-failure", "renamed")) {
            fixture(mode)
            val error = assertThrows(FlutterException::class.java) { channel.operation("writeBackup", "new.bsexport") }
            assertEquals("backup_storage_failed", error.code)
            assertEquals("verify_backup_document", (error.details as Map<*, *>)["stage"])
            assertEquals(listOf("older.bsexport"), channel.operation("list"))
            assertEquals(3L, channel.operation("size", "older.bsexport"))
            val older = DocumentsContract.buildDocumentUriUsingTree(tree, "old")
            assertArrayEquals(byteArrayOf(9, 8, 7), resolver.openInputStream(older)!!.use { it.readBytes() })
            assertEquals("{\"backups\":[\"older.bsexport\"]}", channel.operation("readManifest"))
            provider("behavior", "null")
            assertEquals(true, channel.operation("writeBackup", "retry.bsexport"))
            assertEquals(4097L, channel.operation("size", "retry.bsexport"))
        }
    }

    @Test fun partialAndRevokedPersistedGrantsFailBeforeWritingAndCanRecover() = withChannel { channel, _ ->
        fixture("null")
        resolver.releasePersistableUriPermission(tree, Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        var error = assertThrows(FlutterException::class.java) { channel.operation("writeBackup", "partial.bsexport") }
        assertEquals("backup_folder_access_required", error.code)
        assertEquals("check_persisted_permission", (error.details as Map<*, *>)["stage"])
        resolver.releasePersistableUriPermission(tree, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        error = assertThrows(FlutterException::class.java) { channel.operation("writeBackup", "revoked.bsexport") }
        assertEquals("backup_folder_access_required", error.code)
        provider("grant", extras = Bundle().apply { putString("package", context.packageName) })
        resolver.takePersistableUriPermission(tree, rw)
        assertEquals(listOf("older.bsexport"), channel.operation("list"))
        assertEquals(true, channel.operation("writeBackup", "recovered.bsexport"))
    }

    @Test fun partialPickerResultReturnsAccessRequiredWithoutPersistingIt() = withChannel { messenger, native ->
        fixture("null")
        resolver.releasePersistableUriPermission(tree, rw)
        lateinit var reply: CompletableFuture<ByteBuffer>
        instrumentation.runOnMainSync {
            reply = messenger.begin("pickDirectory", emptyMap())
            assertTrue(native.onActivityResult(17017, Activity.RESULT_OK, Intent().apply {
                data = tree
                flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            }))
        }
        val error = assertThrows(FlutterException::class.java) { messenger.decode(reply) }
        assertEquals("backup_folder_access_required", error.code)
        assertEquals("persist_folder_permission", (error.details as Map<*, *>)["stage"])
        assertFalse(resolver.persistedUriPermissions.any { it.uri == tree })
    }

    private class TestMessenger : BinaryMessenger {
        private var handler: BinaryMessenger.BinaryMessageHandler? = null
        override fun send(channel: String, message: ByteBuffer?) = Unit
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) = Unit
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) { this.handler = handler }
        fun invoke(method: String, arguments: Map<String, Any?>): Any? = decode(begin(method, arguments))
        fun decode(result: CompletableFuture<ByteBuffer>): Any? =
            StandardMethodCodec.INSTANCE.decodeEnvelope(result.get(30, TimeUnit.SECONDS))
        fun begin(method: String, arguments: Map<String, Any?>): CompletableFuture<ByteBuffer> {
            val codec = StandardMethodCodec.INSTANCE
            val result = CompletableFuture<ByteBuffer>()
            val call = codec.encodeMethodCall(MethodCall(method, arguments)).apply { flip() }
            handler!!.onMessage(call) { reply -> result.complete(reply!!.apply { flip() }) }
            return result
        }
    }
}
