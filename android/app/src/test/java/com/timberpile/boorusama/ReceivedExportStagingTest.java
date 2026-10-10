package com.timberpile.boorusama;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import java.io.*;
import java.nio.file.Files;
import static org.junit.Assert.*;

public final class ReceivedExportStagingTest {
    private File directory;

    @Before public void setup() throws Exception {
        directory = Files.createTempDirectory("received-export-").toFile();
    }

    @After public void cleanup() throws Exception {
        for (File file : directory.listFiles()) Files.delete(file.toPath());
        Files.delete(directory.toPath());
    }

    @Test public void identicalOpensHaveIndependentIdentitiesAndFiles() throws Exception {
        byte[] bytes = new byte[] {1, 2, 3};
        ReceivedExportStaging.Delivery first = stage(bytes);
        ReceivedExportStaging.Delivery second = stage(bytes);
        assertNotEquals(first.id, second.id);
        assertNotEquals(first.file, second.file);
        assertArrayEquals(bytes, Files.readAllBytes(first.file.toPath()));
        assertTrue(first.file.delete());
        assertArrayEquals(bytes, Files.readAllBytes(second.file.toPath()));
        assertArrayEquals(new byte[] {4}, Files.readAllBytes(stage(new byte[] {4}).file.toPath()));
    }

    @Test public void oversizedOpenRemovesOnlyItsPartialCopyAndClosesInput() throws Exception {
        ReceivedExportStaging.Delivery first = stage(new byte[] {1});
        boolean[] closed = {false};
        InputStream input = new ByteArrayInputStream(new byte[] {2, 3}) {
            @Override public void close() { closed[0] = true; }
        };
        assertThrows(IOException.class, () -> ReceivedExportStaging.stage(input, directory, 1));
        assertTrue(closed[0]);
        assertArrayEquals(new String[] {first.file.getName()}, directory.list());
        assertArrayEquals(new byte[] {1}, Files.readAllBytes(first.file.toPath()));
    }

    @Test public void providerReadFailureLeavesNoPartialFileAndLaterOpenSucceeds() throws Exception {
        InputStream input = new InputStream() {
            private boolean first = true;
            @Override public int read() throws IOException {
                if (first) { first = false; return 1; }
                throw new IOException("Provider revoked access");
            }
        };
        assertThrows(IOException.class, () -> ReceivedExportStaging.stage(input, directory, 10));
        assertEquals(0, directory.list().length);
        assertArrayEquals(new byte[] {2}, Files.readAllBytes(stage(new byte[] {2}).file.toPath()));
    }

    private ReceivedExportStaging.Delivery stage(byte[] bytes) throws IOException {
        return ReceivedExportStaging.stage(new ByteArrayInputStream(bytes), directory, 10);
    }
}
