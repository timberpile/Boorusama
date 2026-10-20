package com.timberpile.boorusama

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class GitHubApkInstallPolicyTest {
    private fun validate(
        archivePackage: String? = "app",
        archiveCode: Long = 101,
        archiveVersion: String? = "1.1.0",
        expectedBuild: Int = 101,
        installedSigners: Set<String> = setOf("current"),
        archiveSigners: Set<String> = setOf("current"),
    ) = GitHubApkInstallPolicy.validateIdentity(
        "app", archivePackage, 100, archiveCode, archiveVersion,
        expectedBuild, "1.1.0", installedSigners, archiveSigners,
    )

    @Test fun `accepts only a newer matching package build version and signer`() {
        validate()
        assertThrows(IllegalArgumentException::class.java) { validate(archivePackage = "other") }
        assertThrows(IllegalArgumentException::class.java) { validate(archivePackage = null) }
        assertThrows(IllegalArgumentException::class.java) { validate(archiveCode = 100) }
        assertThrows(IllegalArgumentException::class.java) { validate(archiveCode = 99) }
        assertThrows(IllegalArgumentException::class.java) { validate(expectedBuild = 102) }
        assertThrows(IllegalArgumentException::class.java) { validate(archiveVersion = "other") }
        assertThrows(IllegalArgumentException::class.java) { validate(archiveVersion = null) }
    }

    @Test fun `rejects missing changed and additional signers`() {
        assertThrows(IllegalArgumentException::class.java) { validate(installedSigners = emptySet()) }
        assertThrows(IllegalArgumentException::class.java) { validate(archiveSigners = emptySet()) }
        assertThrows(IllegalArgumentException::class.java) { validate(archiveSigners = setOf("different")) }
        assertThrows(IllegalArgumentException::class.java) { validate(archiveSigners = setOf("current", "other")) }
    }

    @Test fun `requires a real APK inside the canonical private update cache`() {
        val cache = Files.createTempDirectory("update-policy-").toFile()
        try {
            val apk = File(cache, "github-updates/download-1/update.apk")
            apk.parentFile.mkdirs()
            apk.writeText("fixture")
            assertEquals(apk.canonicalFile, GitHubApkInstallPolicy.privateApk(apk.path, cache))
            for (path in listOf("other.apk", "github-updates/../other.apk", "github-updates-other/update.apk", "github-updates/missing.apk", "github-updates/update.txt")) {
                val file = File(cache, path)
                file.parentFile.mkdirs()
                if (!path.endsWith("missing.apk")) file.writeText("fixture")
                assertThrows(IllegalArgumentException::class.java) {
                    GitHubApkInstallPolicy.privateApk(file.path, cache)
                }
            }
            val link = File(apk.parentFile, "outside.apk")
            Files.createSymbolicLink(link.toPath(), File(cache, "other.apk").toPath())
            assertThrows(IllegalArgumentException::class.java) { GitHubApkInstallPolicy.privateApk(link.path, cache) }
        } finally {
            cache.deleteRecursively()
        }
    }
}
