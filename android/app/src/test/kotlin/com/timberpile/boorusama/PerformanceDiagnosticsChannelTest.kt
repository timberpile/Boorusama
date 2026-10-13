package com.timberpile.boorusama

import android.os.Environment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PerformanceDiagnosticsChannelTest {
    @Test
    fun `export path belongs to the MediaStore downloads collection`() {
        assertEquals(
            "${Environment.DIRECTORY_DOWNLOADS}/Dev/diagnostics/",
            PerformanceDiagnosticsChannel.RELATIVE_PATH,
        )
    }

    @Test
    fun `export file names sort by timestamp before revision`() {
        assertTrue(
            PerformanceDiagnosticsChannel.SAFE_FILE_NAME.matches(
                "boorusama-performance-release-20261013T111745249Z-c315ce56.json",
            ),
        )
        assertFalse(
            PerformanceDiagnosticsChannel.SAFE_FILE_NAME.matches(
                "boorusama-performance-release-c315ce56-20261013T111745249Z.json",
            ),
        )
    }
}
