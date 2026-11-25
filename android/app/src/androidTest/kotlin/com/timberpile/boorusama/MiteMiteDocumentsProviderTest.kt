package com.timberpile.boorusama

import android.app.Activity
import android.app.ActivityOptions
import android.app.PendingIntent
import android.app.UiAutomation
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.nio.ByteBuffer
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit

/** Actual ContentResolver/DocumentProvider I/O; fixtures never use the app's selected transport. */
@RunWith(AndroidJUnit4::class)
class MiteMiteDocumentsProviderTest {
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    private val context get() = instrumentation.targetContext
    private val resolver get() = context.contentResolver
    private val tree get() = BackupTestDocumentsProvider.tree()
    private val automation get() = instrumentation.getUiAutomation(UiAutomation.FLAG_DONT_USE_ACCESSIBILITY)
    private val rw = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val foreign = "22222222-2222-4222-8222-222222222222"
    private val source = "33333333-3333-4333-8333-333333333333"
    private val prefix get() = "devices/$owner/collections/bookmarks/$source"
    private val bytes = ByteArray(4097) { (it % 251).toByte() }

    private fun provider(method: String, arg: String? = null, extras: Bundle? = null) {
        automation.adoptShellPermissionIdentity("android.permission.MANAGE_DOCUMENTS", "android.permission.START_ACTIVITIES_FROM_BACKGROUND")
        try {
            val result = checkNotNull(resolver.call(Uri.parse("content://${BackupTestDocumentsProvider.AUTHORITY}"), method, arg, extras))
            val grant = result.getParcelable<PendingIntent>("grant")
            if (grant != null) {
                val options = ActivityOptions.makeBasic()
                if (Build.VERSION.SDK_INT >= 34) options.setPendingIntentBackgroundActivityStartMode(ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
                val monitor = instrumentation.addMonitor(BackupGrantActivity::class.java.name, null, false)
                try {
                    grant.send(context, 0, null, null, null, null, options.toBundle())
                    checkNotNull(instrumentation.waitForMonitorWithTimeout(monitor, 30_000))
                    instrumentation.waitForIdleSync()
                } finally { instrumentation.removeMonitor(monitor) }
            }
        } finally { automation.dropShellPermissionIdentity() }
    }

    private fun fixture(mode: String = "known") {
        provider("fixture", extras = Bundle().apply {
            putString("behavior", mode); putBoolean("sync", true); putString("package", context.packageName)
        })
        resolver.takePersistableUriPermission(tree, rw)
    }

    private fun withChannel(body: (TestMessenger) -> Unit) {
        val component = ComponentName(context.packageName, BackupGrantActivity::class.java.name)
        val originalComponent = context.packageManager.getComponentEnabledSetting(component)
        val originalGrant = resolver.persistedUriPermissions.firstOrNull { it.uri == tree }?.let {
            (if (it.isReadPermission) Intent.FLAG_GRANT_READ_URI_PERMISSION else 0) or
                (if (it.isWritePermission) Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0)
        } ?: 0
        var native: MiteMiteChannel? = null
        try {
            context.packageManager.setComponentEnabledSetting(component, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
            fixture()
            val messenger = TestMessenger()
            instrumentation.runOnMainSync { native = MiteMiteChannel(context, messenger) }
            body(messenger)
        } finally {
            instrumentation.runOnMainSync { native?.close() }
            runCatching { resolver.releasePersistableUriPermission(tree, rw) }
            if (originalGrant != 0) {
                provider("grant", extras = Bundle().apply { putString("package", context.packageName) })
                val extra = rw and originalGrant.inv()
                if (extra != 0) resolver.releasePersistableUriPermission(tree, extra)
            }
            context.packageManager.setComponentEnabledSetting(component, originalComponent, PackageManager.DONT_KILL_APP)
        }
    }

    private fun arguments(path: String = "", data: ByteArray? = null, limit: Int = 32 * 1024 * 1024, publisher: String = owner) = mapOf(
        "location" to tree.toString(), "path" to path, "bytes" to data, "maxBytes" to limit, "owner" to publisher,
    )
    private fun TestMessenger.write(path: String, data: ByteArray = bytes) = invoke("writeImmutable", arguments(path, data))
    private fun TestMessenger.read(path: String, limit: Int = 32 * 1024 * 1024) = invoke("read", arguments(path, limit = limit)) as ByteArray?
    private fun failure(code: String = "sync_storage_failed", body: () -> Unit) {
        val error = assertThrows(FlutterException::class.java, body)
        assertEquals(code, error.code)
        assertNull(error.details)
        assertFalse(error.message.orEmpty().contains(tree.toString()))
    }

    @Test fun unknownReportedSizesUseActualBoundedBytesAndImmutableWinners() = withChannel { channel ->
        for (mode in listOf("known", "null", "negative", "zero")) {
            fixture(mode)
            assertEquals(true, channel.write("$prefix/1.bsexport"))
            assertArrayEquals(bytes, channel.read("$prefix/1.bsexport"))
            assertEquals(true, channel.write("$prefix/1.bsexport"))
            failure { channel.write("$prefix/1.bsexport", byteArrayOf(9, 8)) }
            assertArrayEquals(bytes, channel.read("$prefix/1.bsexport"))
            failure { channel.read("$prefix/1.bsexport", 4) }
            assertNull(channel.read("$prefix/99.bsexport"))
        }
    }

    @Test fun partialPayloadDescriptorAndCatalogNamesRemainEvidenceAndRetryUsesFreshNames() = withChannel { channel ->
        for (path in listOf("$prefix/2.bsexport", "$prefix/2.json", "devices/$owner/catalog/2.json")) {
            fixture()
            channel.write("$prefix/1.bsexport")
            provider("behavior", "truncated")
            failure { channel.write(path) }
            provider("behavior", "known")
            assertArrayEquals(byteArrayOf(1), channel.read(path))
            failure { channel.write(path) }
            assertArrayEquals(byteArrayOf(1), channel.read(path))
            assertArrayEquals(bytes, channel.read("$prefix/1.bsexport"))
            assertEquals(true, channel.write(path.replace("/2.", "/3.")))
        }
    }

    @Test fun providerReadFailureOrRenamedCreateDoesNotAlterExistingPublications() = withChannel { channel ->
        for (mode in listOf("read-failure", "renamed")) {
            fixture()
            channel.write("$prefix/1.bsexport")
            provider("behavior", mode)
            failure { channel.write("$prefix/2.json") }
            provider("behavior", "known")
            assertArrayEquals(bytes, channel.read("$prefix/1.bsexport"))
            assertEquals(true, channel.write("$prefix/3.json"))
            if (mode == "renamed") assertNull(channel.read("$prefix/2.json"))
        }
    }

    @Test fun duplicateDocumentNamesFailClosedWithoutWritingOverAValidDocument() = withChannel { channel ->
        channel.write("$prefix/1.bsexport")
        provider("behavior", "duplicate")
        failure { channel.write("$prefix/2.bsexport") }
        provider("behavior", "known")
        assertArrayEquals(bytes, channel.read("$prefix/1.bsexport"))
        assertNull(channel.read("$prefix/2.bsexport"))
    }

    @Test fun partialIdentityCannotBeOverwrittenOrRemovedByRevisionRetention() = withChannel { channel ->
        channel.write("$prefix/1.bsexport")
        val path = "devices/$owner/identity.json"
        provider("behavior", "truncated")
        failure { channel.write(path) }
        provider("behavior", "known")
        failure { channel.write(path) }
        failure { channel.invoke("deleteOwnedRevision", arguments(path)) }
        assertArrayEquals(byteArrayOf(1), channel.read(path))
        assertArrayEquals(bytes, channel.read("$prefix/1.bsexport"))
    }

    @Test fun ownerBoundsPermitOnlyOwnedRevisionFilesAndRejectTraversal() = withChannel { channel ->
        val other = "devices/$foreign/collections/bookmarks/$source/1.json"
        channel.write("$prefix/1.json")
        channel.write(other)
        failure { channel.invoke("deleteOwnedRevision", arguments(other)) }
        failure { channel.write("../escape.json") }
        failure { channel.invoke("deleteOwnedRevision", arguments("devices/$owner")) }
        assertArrayEquals(bytes, channel.read(other))
        assertEquals(true, channel.invoke("deleteOwnedRevision", arguments("$prefix/1.json")))
        assertNull(channel.read("$prefix/1.json"))
    }

    @Test fun completeCleanupIsConfinedToOwnedDeviceOrCollection() = withChannel { channel ->
        val other = "devices/$foreign/collections/bookmarks/$source/1.json"
        val identity = "devices/$owner/identity.json"
        channel.write("$prefix/1.json")
        channel.write(other)
        channel.write(identity)
        failure { channel.invoke("deleteOwnedDirectory", arguments("devices/$foreign")) }
        failure { channel.invoke("deleteOwnedDirectory", arguments("devices/$owner/collections")) }
        assertEquals(true, channel.invoke("deleteOwnedDirectory", arguments(prefix)))
        assertNull(channel.read("$prefix/1.json"))
        assertArrayEquals(bytes, channel.read(identity))
        assertEquals(true, channel.invoke("deleteOwnedDirectory", arguments("devices/$owner")))
        assertEquals(true, channel.invoke("deleteOwnedDirectory", arguments("devices/$owner")))
        assertNull(channel.read(identity))
        assertArrayEquals(bytes, channel.read(other))
    }

    @Test fun concurrentChannelsKeepExistingWinnersAndIndependentNewFiles() = withChannel { channel ->
        channel.write("$prefix/1.bsexport")
        val second = TestMessenger()
        lateinit var native: MiteMiteChannel
        instrumentation.runOnMainSync { native = MiteMiteChannel(context, second) }
        try {
            val sameA = channel.begin("writeImmutable", arguments("$prefix/1.bsexport", bytes))
            val sameB = second.begin("writeImmutable", arguments("$prefix/1.bsexport", bytes))
            assertEquals(true, channel.decode(sameA)); assertEquals(true, second.decode(sameB))
            val first = channel.begin("writeImmutable", arguments("$prefix/2.json", bytes))
            val other = second.begin("writeImmutable", arguments("$prefix/3.json", byteArrayOf(4, 5, 6)))
            assertEquals(true, channel.decode(first)); assertEquals(true, second.decode(other))
            assertArrayEquals(bytes, channel.read("$prefix/2.json"))
            assertArrayEquals(byteArrayOf(4, 5, 6), channel.read("$prefix/3.json"))
            failure { second.write("$prefix/1.bsexport", byteArrayOf(0)) }
            assertArrayEquals(bytes, channel.read("$prefix/1.bsexport"))
        } finally { instrumentation.runOnMainSync { native.close() } }
    }

    @Test fun persistedPartialAndRevokedGrantsBlockOperationsAndExplicitGrantRestoresThem() = withChannel { channel ->
        channel.write("$prefix/1.bsexport")
        resolver.releasePersistableUriPermission(tree, Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        failure("sync_folder_access_required") { channel.write("$prefix/2.json") }
        failure("sync_folder_access_required") { channel.invoke("list", arguments()) }
        resolver.releasePersistableUriPermission(tree, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        failure("sync_folder_access_required") { channel.read("$prefix/1.bsexport") }
        provider("grant", extras = Bundle().apply { putString("package", context.packageName) })
        resolver.takePersistableUriPermission(tree, rw)
        assertArrayEquals(bytes, channel.read("$prefix/1.bsexport"))
        assertNull(channel.read("$prefix/2.json"))
        assertEquals(true, channel.write("$prefix/3.json"))
    }

    @Test fun privateAuthorityLocationUsesNoBackupStorageWithoutASelectedTreeGrant() = withChannel { channel ->
        resolver.releasePersistableUriPermission(tree, rw)
        assertFalse(resolver.persistedUriPermissions.any { it.uri == tree })
        val first = channel.invoke("privateDataDirectory", emptyMap()) as String
        val second = channel.invoke("privateDataDirectory", emptyMap()) as String
        assertEquals(first, second)
        assertEquals(context.noBackupFilesDir.resolve("mitemite_private").absolutePath, first)
        assertFalse(first.startsWith(context.cacheDir.absolutePath + "/"))
    }

    @Test fun opaqueProviderDisplayNameResolutionCreatesNoTransportOrBackupDirectory() = withChannel { channel ->
        assertEquals(emptyList<String>(), channel.invoke("list", arguments()))
        val names = TestMessenger()
        lateinit var native: AutoBackupChannel
        instrumentation.runOnMainSync {
            val target = context
            val activity = object : Activity() { override fun getApplicationContext(): Context = target }
            native = AutoBackupChannel(activity, names)
        }
        try {
            assertEquals("QA root", names.invoke("directoryDisplayName", mapOf("location" to tree.toString())))
            assertEquals(emptyList<String>(), channel.invoke("list", arguments()))
        } finally { instrumentation.runOnMainSync { native.close() } }
    }

    private class TestMessenger : BinaryMessenger {
        private var handler: BinaryMessenger.BinaryMessageHandler? = null
        override fun send(channel: String, message: ByteBuffer?) = Unit
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) = Unit
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
            assertEquals("boorusama/mitemite", channel)
            this.handler = handler
        }
        fun invoke(method: String, arguments: Map<String, Any?>): Any? = decode(begin(method, arguments))
        fun decode(result: CompletableFuture<ByteBuffer>): Any? = StandardMethodCodec.INSTANCE.decodeEnvelope(result.get(30, TimeUnit.SECONDS))
        fun begin(method: String, arguments: Map<String, Any?>): CompletableFuture<ByteBuffer> {
            val codec = StandardMethodCodec.INSTANCE
            val reply = CompletableFuture<ByteBuffer>()
            handler!!.onMessage(codec.encodeMethodCall(MethodCall(method, arguments)).apply { flip() }) { value -> reply.complete(value!!.apply { flip() }) }
            return reply
        }
    }
}
