package com.timberpile.boorusama;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import java.io.File;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import static org.junit.Assert.*;

public final class OwnedImageTransferTest {
    private File root;
    private OwnedImageTransfer transfer;
    private final byte[] bytes = new byte[] {1, 2, 3, 4};
    @Before public void setup() throws Exception {
        root = Files.createTempDirectory("owned-image-").toFile();
        transfer = new OwnedImageTransfer(root);
    }
    @After public void cleanup() { delete(root); }
    private static void delete(File file) {
        File[] children = file.listFiles();
        if (children != null) for (File child : children) delete(child);
        file.delete();
    }
    private File source(String directory, String name) throws Exception {
        File file = new File(root, directory + "/" + name);
        file.getParentFile().mkdirs();
        Files.write(file.toPath(), bytes);
        return file;
    }
    @Test public void retainedAndTransientSourcesBecomeIndependentOwnedCompletedFiles() throws Exception {
        for (String directory : new String[] {"cacheimage", "cacheimage-transfers"}) {
            File source = source(directory, "source-with-sensitive-url-hash");
            File owned = transfer.copy(source, "image/png");
            assertEquals(new File(root, "boorusama-clipboard").getCanonicalFile(), owned.getParentFile());
            assertTrue(owned.getName().startsWith("boorusama_share_"));
            assertTrue(owned.getName().endsWith(".png"));
            assertFalse(owned.getName().contains("sensitive"));
            assertTrue(source.delete());
            assertArrayEquals(bytes, Files.readAllBytes(owned.toPath()));
        }
    }
    @Test public void generatedGifSurvivesSourceCleanupAfterHandoff() throws Exception {
        File source = source("boorusama-share", "boorusama_share_conversion.gif");
        File owned = transfer.copy(source, "image/gif");
        assertTrue(owned.getName().endsWith(".gif"));
        assertTrue(source.delete());
        assertArrayEquals(bytes, Files.readAllBytes(owned.toPath()));
    }
    @Test public void gifHandoffDoesNotAcceptUnrelatedShareFilesOrOtherMedia() throws Exception {
        for (String name : new String[] {"unrelated.gif", "boorusama_share_video.mp4", "boorusama_share_conversion.gif.partial"}) {
            File source = source("boorusama-share", name);
            assertThrows(IllegalArgumentException.class, () -> transfer.copy(source, "image/gif"));
        }
        File source = source("boorusama-share", "boorusama_share_conversion.gif");
        assertThrows(IllegalArgumentException.class, () -> transfer.copy(source, "image/png"));
    }
    @Test public void concurrentCopiesPublishUniqueFilesWithoutExposingPartialBytes() throws Exception {
        File source = source("cacheimage", "complete");
        byte[] large = new byte[4 * 1024 * 1024];
        java.util.Arrays.fill(large, (byte) 7);
        Files.write(source.toPath(), large);
        var pool = Executors.newFixedThreadPool(4);
        try {
            List<Future<File>> copies = new ArrayList<>();
            for (int i = 0; i < 12; i++) copies.add(pool.submit(() -> transfer.copy(source, "image/avif")));
            while (copies.stream().anyMatch(copy -> !copy.isDone())) {
                File[] visible = new File(root, "boorusama-clipboard").listFiles();
                if (visible != null) for (File file : visible) {
                    if (file.getName().startsWith("boorusama_share_")) assertEquals(large.length, file.length());
                }
                Thread.yield();
            }
            var paths = new HashSet<String>();
            for (Future<File> copy : copies) {
                File owned = copy.get();
                assertTrue(paths.add(owned.getPath()));
                assertArrayEquals(large, Files.readAllBytes(owned.toPath()));
                assertTrue(owned.getName().endsWith(".avif"));
            }
            assertEquals(12, paths.size());
            for (File file : new File(root, "boorusama-clipboard").listFiles()) assertFalse(file.getName().endsWith(".partial"));
        } finally { pool.shutdownNow(); }
    }
    @Test public void expiredCleanupKeepsRecentOwnedFilesStagingAndUnrelatedFiles() throws Exception {
        long now = System.currentTimeMillis();
        File source = source("cacheimage", "complete");
        File old = transfer.copy(source, "image/jpeg");
        File recent = transfer.copy(source, "image/webp");
        File unrelated = source("boorusama-clipboard", "unrelated");
        File staging = source("boorusama-clipboard", ".boorusama_staging.partial");
        assertTrue(old.setLastModified(now - 25 * 60 * 60 * 1000L));
        assertTrue(unrelated.setLastModified(now - 25 * 60 * 60 * 1000L));
        assertTrue(staging.setLastModified(now - 25 * 60 * 60 * 1000L));
        transfer.pruneExpired(now);
        assertFalse(old.exists());
        assertTrue(recent.exists());
        assertTrue(unrelated.exists());
        assertTrue(staging.exists());
        assertTrue(source.exists());
    }
    @Test public void expiredOwnedOrphanPartialIsRecoveredWithoutDeletingRecentOrUnrelatedFiles() throws Exception {
        long now = System.currentTimeMillis();
        File orphan = source("boorusama-clipboard", ".boorusama_staging_orphan.partial");
        File recent = source("boorusama-clipboard", ".boorusama_staging_recent.partial");
        File unrelated = source("boorusama-clipboard", ".unrelated.partial");
        assertTrue(orphan.setLastModified(now - 25 * 60 * 60 * 1000L));
        assertTrue(unrelated.setLastModified(now - 25 * 60 * 60 * 1000L));
        transfer.pruneExpired(now);
        assertFalse(orphan.exists());
        assertTrue(recent.exists());
        assertTrue(unrelated.exists());
    }
    @Test public void anotherProducerPruneCannotDeleteAnActiveOldPartial() throws Exception {
        long now = System.currentTimeMillis();
        var created = new java.util.concurrent.CountDownLatch(1);
        var proceed = new java.util.concurrent.CountDownLatch(1);
        var active = new java.util.concurrent.atomic.AtomicReference<File>();
        OwnedImageTransfer producer = new OwnedImageTransfer(root, staged -> {
            assertEquals(bytes.length, staged.length());
            assertTrue(staged.setLastModified(now - 25 * 60 * 60 * 1000L));
            active.set(staged);
            created.countDown();
            try {
                if (!proceed.await(5, java.util.concurrent.TimeUnit.SECONDS)) throw new java.io.IOException("Copy barrier timed out");
            } catch (InterruptedException error) {
                Thread.currentThread().interrupt();
                throw new java.io.IOException(error);
            }
        });
        var pool = Executors.newSingleThreadExecutor();
        try {
            File source = source("cacheimage", "active-source");
            Future<File> copying = pool.submit(() -> producer.copy(source, "image/png"));
            assertTrue(created.await(5, java.util.concurrent.TimeUnit.SECONDS));
            transfer.pruneExpired(now);
            assertTrue(active.get().exists());
            proceed.countDown();
            File completed = copying.get(5, java.util.concurrent.TimeUnit.SECONDS);
            assertArrayEquals(bytes, Files.readAllBytes(completed.toPath()));
            assertFalse(active.get().exists());
            transfer.pruneExpired(now);
            assertTrue(completed.exists());
        } finally {
            proceed.countDown();
            pool.shutdownNow();
            assertTrue(pool.awaitTermination(5, java.util.concurrent.TimeUnit.SECONDS));
        }
    }
    @Test public void invalidRootsPartialEmptyAndUnsupportedMimeNeverPublish() throws Exception {
        File outside = source("ordinary", "image");
        File partial = source("cacheimage-transfers", "download.partial");
        File empty = source("cacheimage", "empty");
        Files.write(empty.toPath(), new byte[0]);
        File valid = source("cacheimage", "complete");
        for (File invalid : new File[] {outside, partial, empty, new File(root, "cacheimage/missing")}) {
            assertThrows(IllegalArgumentException.class, () -> transfer.copy(invalid, "image/png"));
        }
        assertThrows(IllegalArgumentException.class, () -> transfer.copy(valid, "text/plain"));
        File[] files = new File(root, "boorusama-clipboard").listFiles();
        assertTrue(files == null || files.length == 0);
    }
    @Test public void failedStorageDoesNotPublishOrDeleteSource() throws Exception {
        File source = source("cacheimage", "complete");
        Files.write(new File(root, "boorusama-clipboard").toPath(), bytes);
        assertThrows(java.io.IOException.class, () -> transfer.copy(source, "image/png"));
        assertArrayEquals(bytes, Files.readAllBytes(source.toPath()));
    }
}
