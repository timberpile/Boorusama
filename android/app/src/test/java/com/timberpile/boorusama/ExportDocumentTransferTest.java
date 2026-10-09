package com.timberpile.boorusama;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import java.io.*;
import java.nio.file.Files;
import java.util.*;
import static org.junit.Assert.*;

public final class ExportDocumentTransferTest {
    private File cache;
    private File codeCache;
    private File source;
    private ExportDocumentTransfer transfer;
    private Destination destination;
    private byte[] bytes;

    @Before public void setup() throws Exception {
        cache = Files.createTempDirectory("export-document-").toFile();
        codeCache = Files.createTempDirectory("export-code-cache-").toFile();
        source = new File(cache, "boorusama-2026-10-06_12-00-00Z.bsexport");
        bytes = new byte[180000];
        new Random(42).nextBytes(bytes);
        Files.write(source.toPath(), bytes);
        transfer = new ExportDocumentTransfer(cache, codeCache);
        destination = new Destination();
    }

    @After public void cleanup() throws Exception {
        Files.deleteIfExists(source.toPath());
        Files.delete(cache.toPath());
        Files.delete(codeCache.toPath());
    }

    @Test public void streamsCompleteBytesAndClosesDestinationBeforeSuccess() throws Exception {
        String saved = transfer.copy(source, destination);
        assertArrayEquals(bytes, destination.output.toByteArray());
        assertTrue(destination.closed);
        assertTrue(destination.largestWrite <= 64 * 1024);
        assertEquals("content://exports/boorusama-2026-10-06_12-00-00Z.bsexport", saved);
        assertArrayEquals(bytes, Files.readAllBytes(source.toPath()));
    }

    @Test public void exportsInRuntimeCodeCacheCanBeSaved() throws Exception {
        File codeExport = new File(codeCache, "boorusama-code-cache.bsexport");
        Files.write(codeExport.toPath(), bytes);
        try {
            assertEquals("content://exports/boorusama-code-cache.bsexport", transfer.copy(codeExport, destination));
            assertArrayEquals(bytes, destination.output.toByteArray());
        } finally {
            Files.delete(codeExport.toPath());
        }
    }

    @Test public void preservesExistingDocumentsAndUsesNextNumberedName() throws Exception {
        destination.existing.add(source.getName());
        destination.existing.add("boorusama-2026-10-06_12-00-00Z-2.bsexport");
        assertEquals("content://exports/boorusama-2026-10-06_12-00-00Z-3.bsexport", transfer.copy(source, destination));
        assertEquals(2, destination.existing.size());
    }

    @Test public void customNameUsesNextAvailableNameWithoutChangingCachedExport() throws Exception {
        destination.existing.add("My favorites.bsexport");
        assertEquals("content://exports/My favorites-2.bsexport",
                transfer.copy(source, destination, "My favorites.bsexport"));
        assertArrayEquals(bytes, Files.readAllBytes(source.toPath()));
    }

    @Test public void rejectsUnsafeCustomFileNameBeforeWriting() throws Exception {
        for (String invalid : new String[] {"../unsafe.bsexport", "a\\b.bsexport", "CON.bsexport", ".bsexport"}) {
            assertThrows(IOException.class, () -> transfer.copy(source, destination, invalid));
            assertNull(destination.created);
        }
    }

    @Test public void nullOutputIsFailureAndDeletesOnlyNewDocument() throws Exception {
        destination.nullOutput = true;
        assertThrows(IOException.class, () -> transfer.copy(source, destination));
        assertEquals(destination.created, destination.deleted);
    }

    @Test public void closeFailureIsFailureAndRemovesIncompleteExport() throws Exception {
        destination.failClose = true;
        assertThrows(IOException.class, () -> transfer.copy(source, destination));
        assertEquals(destination.created, destination.deleted);
        assertArrayEquals(bytes, Files.readAllBytes(source.toPath()));
    }

    @Test public void interruptedWriteRemovesPartialDocument() throws Exception {
        destination.failWrite = true;
        assertThrows(IOException.class, () -> transfer.copy(source, destination));
        assertEquals(destination.created, destination.deleted);
        assertTrue(destination.closed);
    }

    @Test public void unavailableFolderCannotPublishSuccess() throws Exception {
        destination.failCreate = true;
        assertThrows(IOException.class, () -> transfer.copy(source, destination));
        assertNull(destination.deleted);
    }

    @Test public void rejectsFilesOutsideOwnedCacheBeforeCreatingDocument() throws Exception {
        File outside = File.createTempFile("outside-export-", ".bsexport");
        try {
            assertThrows(IOException.class, () -> transfer.copy(outside, destination));
            assertNull(destination.created);
        } finally { outside.delete(); }
    }

    private static final class Destination implements ExportDocumentTransfer.Destination {
        final Set<String> existing = new HashSet<>();
        final ByteArrayOutputStream output = new ByteArrayOutputStream();
        boolean nullOutput, failClose, failCreate, failWrite, closed;
        int largestWrite;
        String created, deleted;
        public Set<String> names() { return existing; }
        public String create(String name) throws IOException {
            if (failCreate) throw new IOException("Unavailable");
            return created = "content://exports/" + name;
        }
        public OutputStream open(String document) {
            if (nullOutput) return null;
            return new FilterOutputStream(output) {
                @Override public void write(byte[] data, int offset, int count) throws IOException {
                    largestWrite = Math.max(largestWrite, count);
                    if (failWrite) throw new IOException("Write failed");
                    out.write(data, offset, count);
                }
                @Override public void close() throws IOException {
                    closed = true;
                    if (failClose) throw new IOException("Close failed");
                    super.close();
                }
            };
        }
        public void delete(String document) { deleted = document; }
    }
}
