package com.timberpile.boorusama;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import java.io.*;
import java.nio.file.Files;
import java.util.Random;
import static org.junit.Assert.*;

public final class GifDocumentTransferTest {
    private File cache, codeCache, source;
    private byte[] bytes;
    private GifDocumentTransfer transfer;
    private Target target;

    @Before public void setup() throws Exception {
        cache = Files.createTempDirectory("gif-save-cache-").toFile();
        codeCache = Files.createTempDirectory("gif-save-code-").toFile();
        new File(cache, "boorusama-share").mkdir();
        new File(codeCache, "boorusama-share").mkdir();
        source = new File(cache, "boorusama-share/boorusama_share_test.gif");
        bytes = new byte[180000];
        new Random(42).nextBytes(bytes);
        System.arraycopy("GIF89a".getBytes("US-ASCII"), 0, bytes, 0, 6);
        Files.write(source.toPath(), bytes);
        transfer = new GifDocumentTransfer(cache, codeCache);
        target = new Target();
    }

    @After public void cleanup() throws Exception {
        for (File root : new File[]{cache, codeCache}) {
            try (var paths = Files.walk(root.toPath())) {
                for (var path : paths.sorted(java.util.Comparator.reverseOrder()).toList()) Files.deleteIfExists(path);
            }
        }
    }
    @Test public void streamsCompleteGifAndClosesBeforeSuccess() throws Exception {
        transfer.copy(source, target);
        assertArrayEquals(bytes, target.bytes.toByteArray());
        assertTrue(target.closed);
        assertFalse(target.deleted);
        assertTrue(target.largestWrite <= 65536);
        assertArrayEquals(bytes, Files.readAllBytes(source.toPath()));
    }
    @Test public void acceptsRuntimeCodeCache() throws Exception {
        File runtime = new File(codeCache, "boorusama-share/boorusama_share_runtime.gif");
        Files.write(runtime.toPath(), bytes);
        transfer.copy(runtime, target);
        assertArrayEquals(bytes, target.bytes.toByteArray());
    }
    @Test public void invalidSignatureNeverOpensDestination() throws Exception {
        bytes[0] = 0;
        Files.write(source.toPath(), bytes);
        assertThrows(IOException.class, () -> transfer.copy(source, target));
        assertFalse(target.opened);
        assertTrue(target.deleted);
    }
    @Test public void refusesOutsideCacheAndSymlinkEscape() throws Exception {
        File outside = new File(cache, "outside.gif");
        Files.write(outside.toPath(), bytes);
        assertThrows(IOException.class, () -> transfer.copy(outside, target));
        File link = new File(cache, "boorusama-share/boorusama_share_link.gif");
        Files.createSymbolicLink(link.toPath(), outside.toPath());
        assertThrows(IOException.class, () -> transfer.copy(link, target));
        assertFalse(target.opened);
    }
    @Test public void acceptsExactlyHundredMbWithBoundedStreaming() throws Exception {
        try (RandomAccessFile file = new RandomAccessFile(source, "rw")) { file.setLength(100000000); }
        final long[] copied = {0};
        final boolean[] closed = {false};
        transfer.copy(source, new GifDocumentTransfer.Destination() {
            public OutputStream open() {
                return new OutputStream() {
                    public void write(int value) { fail("Unexpected byte write"); }
                    public void write(byte[] value, int start, int count) { assertTrue(count <= 65536); copied[0] += count; }
                    public void close() { closed[0] = true; }
                };
            }
            public void delete() { fail("Valid GIF should be kept"); }
        });
        assertEquals(100000000, copied[0]);
        assertTrue(closed[0]);
    }
    @Test public void rejectsOutputAboveActualHundredMbLimit() throws Exception {
        try (RandomAccessFile file = new RandomAccessFile(source, "rw")) { file.setLength(100000001); }
        assertThrows(IOException.class, () -> transfer.copy(source, target));
        assertFalse(target.opened);
    }
    @Test public void failedWriteClosesAndDeletesPartialDestination() throws Exception {
        target.failWrite = true;
        assertThrows(IOException.class, () -> transfer.copy(source, target));
        assertTrue(target.closed);
        assertTrue(target.deleted);
        assertArrayEquals(bytes, Files.readAllBytes(source.toPath()));
    }
    @Test public void failedCloseDeletesDestination() throws Exception {
        target.failClose = true;
        assertThrows(IOException.class, () -> transfer.copy(source, target));
        assertTrue(target.deleted);
    }
    private static final class Target implements GifDocumentTransfer.Destination {
        final ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        boolean opened, closed, deleted, failWrite, failClose;
        int largestWrite;
        public OutputStream open() {
            opened = true;
            return new OutputStream() {
                public void write(int value) throws IOException { throw new IOException("Unexpected byte write"); }
                public void write(byte[] value, int start, int count) throws IOException {
                    largestWrite = Math.max(largestWrite, count);
                    if (failWrite && bytes.size() > 6) throw new IOException("Full destination");
                    bytes.write(value, start, count);
                }
                public void close() throws IOException { closed = true; if (failClose) throw new IOException("Close failed"); }
            };
        }
        public void delete() { deleted = true; }
    }
}
