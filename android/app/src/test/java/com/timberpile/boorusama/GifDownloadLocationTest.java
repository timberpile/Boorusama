package com.timberpile.boorusama;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.util.Comparator;
import static org.junit.Assert.*;

public final class GifDownloadLocationTest {
    private File volume;
    @Before public void setup() throws Exception { volume = Files.createTempDirectory("gif-download-volume-").toFile(); }
    @After public void cleanup() throws Exception {
        try (var paths = Files.walk(volume.toPath())) {
            for (var path : paths.sorted(Comparator.reverseOrder()).toList()) Files.deleteIfExists(path);
        }
    }
    @Test public void mapsPublicFoldersAndSubfoldersToTheirExactRelativePath() throws Exception {
        for (String primary : new String[]{"Download", "Documents", "Pictures"}) {
            var location = GifDownloadLocation.shared(new File(volume, primary + "/Boorusama/GIFs"), volume);
            assertEquals(primary, location.primaryDirectory());
            assertEquals(primary + "/Boorusama/GIFs/", location.relativePath());
        }
    }
    @Test public void refusesParentTraversalOrAnUnavailablePublicFolder() throws Exception {
        assertThrows(IOException.class, () -> GifDownloadLocation.shared(new File(volume, "Download/../../outside"), volume));
        assertThrows(IOException.class, () -> GifDownloadLocation.shared(new File(volume, "Android/data/private"), volume));
        assertThrows(IOException.class, () -> GifDownloadLocation.shared(new File(volume, "Download-other"), volume));
    }
    @Test public void symlinkCannotChangeTheSelectedStorageVolume() throws Exception {
        File outside = Files.createTempDirectory("gif-other-volume-").toFile();
        try {
            Files.createSymbolicLink(new File(volume, "Pictures").toPath(), outside.toPath());
            assertThrows(IOException.class, () -> GifDownloadLocation.shared(new File(volume, "Pictures"), volume));
        } finally { Files.delete(outside.toPath()); }
    }
    @Test public void repeatedSavesReserveNewFilesAndPreserveExistingContents() throws Exception {
        File directory = new File(volume, "Download/GIFs");
        File first = GifDownloadLocation.reserve(directory, "boorusama_42.gif");
        Files.write(first.toPath(), new byte[]{1, 2, 3});
        File second = GifDownloadLocation.reserve(directory, "boorusama_42.gif");
        assertEquals("boorusama_42_2.gif", second.getName());
        assertTrue(second.isFile());
        assertArrayEquals(new byte[]{1, 2, 3}, Files.readAllBytes(first.toPath()));
    }
    @Test public void cannotSaveToAFilePretendingToBeADirectory() throws Exception {
        File file = new File(volume, "Download");
        Files.write(file.toPath(), new byte[]{1});
        assertThrows(IOException.class, () -> GifDownloadLocation.reserve(file, "boorusama_42.gif"));
    }
}
