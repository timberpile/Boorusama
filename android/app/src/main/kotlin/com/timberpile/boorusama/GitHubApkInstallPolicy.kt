package com.timberpile.boorusama

import java.io.File

/** Platform-independent preflight rules; Android still makes the final install decision. */
internal object GitHubApkInstallPolicy {
    fun privateApk(path: String, cacheDirectory: File): File {
        val updateDirectory = File(cacheDirectory, "github-updates").canonicalFile
        val apk = File(path).canonicalFile
        require(
            apk.path.startsWith(updateDirectory.path + File.separator) &&
                apk.isFile && apk.extension.equals("apk", ignoreCase = true)
        ) { "APK must be in private update cache" }
        return apk
    }

    fun validateIdentity(
        installedPackage: String,
        archivePackage: String?,
        installedCode: Long,
        archiveCode: Long,
        archiveVersion: String?,
        expectedBuild: Int,
        expectedVersion: String,
        installedSigners: Set<String>,
        archiveSigners: Set<String>,
    ) {
        require(archivePackage == installedPackage) { "APK package mismatch" }
        require(archiveCode > installedCode) { "APK must be a newer build" }
        require(archiveCode == expectedBuild.toLong()) { "APK build number mismatch" }
        require(archiveVersion == expectedVersion) { "APK version mismatch" }
        require(
            installedSigners.isNotEmpty() && archiveSigners.isNotEmpty() &&
                installedSigners == archiveSigners
        ) { "APK signing certificate mismatch" }
    }
}
