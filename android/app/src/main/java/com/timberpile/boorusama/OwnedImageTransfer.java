package com.timberpile.boorusama;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.UUID;
import java.util.HashSet;
import java.util.Set;

/** Owns a completed platform handoff independently from evictable image files. */
public final class OwnedImageTransfer {
    private final File retainedRoot;
    private final File transientRoot;
    private final File ownedRoot;
    private final CopyObserver observer;
    private static final long MAX_AGE_MILLIS = 24 * 60 * 60 * 1000L;
    private static final Object OWNERSHIP_LOCK = new Object();
    private static final Set<String> ACTIVE_STAGING = new HashSet<>();

    public OwnedImageTransfer(File cacheRoot) throws IOException {
        this(cacheRoot, null);
    }

    OwnedImageTransfer(File cacheRoot, CopyObserver observer) throws IOException {
        retainedRoot = new File(cacheRoot, "cacheimage").getCanonicalFile();
        transientRoot = new File(cacheRoot, "cacheimage-transfers").getCanonicalFile();
        ownedRoot = new File(cacheRoot, "boorusama-clipboard").getCanonicalFile();
        this.observer = observer;
    }

    interface CopyObserver {
        void afterFirstChunk(File staged) throws IOException;
    }

    public File copy(File source, String mimeType) throws IOException {
        String extension = extensionFor(mimeType);
        File canonical = source.getCanonicalFile();
        if ((!retainedRoot.equals(canonical.getParentFile()) && !transientRoot.equals(canonical.getParentFile()))
                || !canonical.isFile() || canonical.length() == 0 || canonical.getName().endsWith(".partial")) {
            throw new IllegalArgumentException("Image source is unavailable");
        }
        if (!ownedRoot.isDirectory() && !ownedRoot.mkdirs() && !ownedRoot.isDirectory()) throw new IOException("Image handoff storage unavailable");
        File staged;
        synchronized (OWNERSHIP_LOCK) {
            staged = File.createTempFile(".boorusama_staging_", ".partial", ownedRoot);
            ACTIVE_STAGING.add(staged.getPath());
        }
        File completed = new File(ownedRoot, "boorusama_share_" + UUID.randomUUID() + "." + extension);
        try {
            long copied = 0;
            try (FileInputStream input = new FileInputStream(canonical);
                 FileOutputStream output = new FileOutputStream(staged)) {
                byte[] buffer = new byte[64 * 1024];
                int length;
                while ((length = input.read(buffer)) != -1) {
                    output.write(buffer, 0, length);
                    if (copied == 0 && observer != null) observer.afterFirstChunk(staged);
                    copied += length;
                }
                output.getFD().sync();
            }
            synchronized (OWNERSHIP_LOCK) {
                if (copied == 0 || completed.exists() || !staged.renameTo(completed)) {
                    throw new IOException("Image handoff could not be completed");
                }
                // Retention starts at completion, including a long-stalled copy.
                if (!completed.setLastModified(System.currentTimeMillis())) {
                    completed.delete();
                    throw new IOException("Image handoff timestamp unavailable");
                }
            }
            return completed;
        } finally {
            synchronized (OWNERSHIP_LOCK) {
                if (staged.exists()) staged.delete();
                ACTIVE_STAGING.remove(staged.getPath());
            }
        }
    }

    public void pruneExpired(long nowMillis) {
        synchronized (OWNERSHIP_LOCK) {
            File[] files = ownedRoot.listFiles();
            if (files == null) return;
            long cutoff = nowMillis - MAX_AGE_MILLIS;
            for (File file : files) {
                boolean owned = file.getName().startsWith("boorusama_share_")
                        || (file.getName().startsWith(".boorusama_staging_") && file.getName().endsWith(".partial"));
                if (file.isFile() && owned && !ACTIVE_STAGING.contains(file.getPath())
                        && file.lastModified() < cutoff) file.delete();
            }
        }
    }

    private static String extensionFor(String mimeType) {
        if (mimeType == null) throw new IllegalArgumentException("Image MIME is unavailable");
        switch (mimeType) {
            case "image/jpeg": return "jpg";
            case "image/png": return "png";
            case "image/gif": return "gif";
            case "image/webp": return "webp";
            case "image/avif": return "avif";
            case "image/bmp": return "bmp";
            default: throw new IllegalArgumentException("Image MIME is unsupported");
        }
    }
}
