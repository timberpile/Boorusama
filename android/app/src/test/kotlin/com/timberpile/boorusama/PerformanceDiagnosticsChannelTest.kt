package com.timberpile.boorusama

import android.os.Environment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PerformanceDiagnosticsChannelTest {
    @Test
    fun `zoom study exports use the public downloads root`() {
        assertEquals(
            "${Environment.DIRECTORY_DOWNLOADS}/",
            PerformanceDiagnosticsChannel.ZOOM_RELATIVE_PATH,
        )
    }

    @Test
    fun `zoom study names accept timestamped JSON and reject unsafe names`() {
        assertTrue(
            PerformanceDiagnosticsChannel.SAFE_ZOOM_STUDY_NAME.matches(
                "boorusama-zoom-study-20261105T180709023Z.json",
            ),
        )
        for (name in listOf(
            "../boorusama-zoom-study-20261105T180709023Z.json",
            "boorusama-zoom-study-20261105T180709023Z.json/other",
            "boorusama-zoom-study-20261105T180709023Z.txt",
            "boorusama-zoom-study-20261105T180709Z.json",
        )) {
            assertFalse(PerformanceDiagnosticsChannel.SAFE_ZOOM_STUDY_NAME.matches(name))
        }
    }

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
