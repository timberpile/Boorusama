package com.timberpile.boorusama

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Lets the OS installer handle a verified update after explicit user action. */
class GitHubApkInstallChannel(
    private val activity: FlutterFragmentActivity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "supportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
                    "canInstall" -> result.success(canInstall())
                    "openInstallSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:${activity.packageName}"),
                            )
                            activity.startActivity(intent)
                        }
                        result.success(null)
                    }
                    "install" -> {
                        val path = call.argument<String>("path")
                            ?: throw IllegalArgumentException("Missing APK path")
                        val expectedBuild = call.argument<Int>("buildNumber")
                        val expectedVersion = call.argument<String>("version")
                        if (!canInstall()) {
                            result.error("permission_required", "Allow installs from this app first", null)
                        } else {
                            install(path, expectedBuild, expectedVersion)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("install_failed", error.message ?: "Could not install APK", null)
            }
        }
    }

    fun close() = channel.setMethodCallHandler(null)

    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            activity.packageManager.canRequestPackageInstalls()

    private fun install(path: String, expectedBuild: Int?, expectedVersion: String?) {
        val updateDirectory = File(activity.cacheDir, "github-updates").canonicalFile
        val apk = File(path).canonicalFile
        require(
            apk.path.startsWith(updateDirectory.path + File.separator) &&
                apk.isFile &&
                apk.extension.equals("apk", ignoreCase = true)
        ) { "APK must be in private update cache" }

        val manager = activity.packageManager
        @Suppress("DEPRECATION")
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        val archive = archiveInfo(manager, apk.path, flags)
            ?: throw IllegalArgumentException("Invalid or unreadable APK")
        val installed = installedInfo(manager, activity.packageName, flags)

        require(archive.packageName == activity.packageName) { "APK package mismatch" }

        val archiveCode = versionCode(archive)
        require(archiveCode > versionCode(installed)) { "APK must be a newer build" }
        if (expectedBuild != null) {
            require(archiveCode == expectedBuild.toLong()) { "APK build number mismatch" }
        }
        if (expectedVersion != null) {
            require(archive.versionName == expectedVersion) { "APK version mismatch" }
        }

        val installedSigners = signers(installed)
        val archiveSigners = signers(archive)
        require(
            installedSigners.isNotEmpty() &&
                archiveSigners.isNotEmpty() &&
                installedSigners == archiveSigners
        ) { "APK signing certificate mismatch" }

        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.provider",
            apk,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(intent)
    }

    @Suppress("DEPRECATION")
    private fun archiveInfo(
        manager: PackageManager,
        path: String,
        flags: Int,
    ): PackageInfo? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            manager.getPackageArchiveInfo(path, PackageManager.PackageInfoFlags.of(flags.toLong()))
        } else {
            manager.getPackageArchiveInfo(path, flags)
        }

    @Suppress("DEPRECATION")
    private fun installedInfo(
        manager: PackageManager,
        name: String,
        flags: Int,
    ): PackageInfo =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            manager.getPackageInfo(name, PackageManager.PackageInfoFlags.of(flags.toLong()))
        } else {
            manager.getPackageInfo(name, flags)
        }

    @Suppress("DEPRECATION")
    private fun versionCode(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }

    @Suppress("DEPRECATION")
    private fun signers(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners
        } else {
            info.signatures
        }
        return signatures?.map { it.toCharsString() }?.toSet() ?: emptySet()
    }

    companion object {
        private const val CHANNEL = "com.timberpile.boorusama/github_apk_install"
    }
}
