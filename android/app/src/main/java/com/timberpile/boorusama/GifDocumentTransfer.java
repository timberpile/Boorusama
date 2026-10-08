package com.timberpile.boorusama;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;

/** Streams a generated GIF into a configured download destination without loading it into memory. */
public final class GifDocumentTransfer {
    public interface Destination {
        OutputStream open() throws Exception;
        void delete() throws Exception;
    }
    private final File[] caches;
    private static final long MAX_BYTES = 100_000_000L;

    public GifDocumentTransfer(File... caches) throws IOException {
        this.caches = new File[caches.length];
        for (int i = 0; i < caches.length; i++) this.caches[i] = caches[i].getCanonicalFile();
    }

    public void copy(File source, Destination destination) throws Exception {
        try {
            File owned = source.getCanonicalFile();
            boolean inCache = false;
            for (File cache : caches) {
                File generated = new File(cache, "boorusama-share").getCanonicalFile();
                if (generated.equals(owned.getParentFile())) inCache = true;
            }
            if (!inCache || !owned.isFile() || !owned.getName().startsWith("boorusama_share_")
                    || !owned.getName().endsWith(".gif") || owned.length() < 14 || owned.length() > MAX_BYTES) {
                throw new IOException("GIF source is unavailable");
            }
            try (FileInputStream input = new FileInputStream(owned)) {
                byte[] header = new byte[6];
                if (input.read(header) != 6) throw new IOException("GIF source is invalid");
                String signature = new String(header, StandardCharsets.US_ASCII);
                if (!signature.equals("GIF87a") && !signature.equals("GIF89a")) throw new IOException("GIF source is invalid");
                try (OutputStream output = destination.open()) {
                    if (output == null) throw new IOException("GIF destination is unavailable");
                    output.write(header);
                    byte[] buffer = new byte[64 * 1024];
                    long copied = 6;
                    int count;
                    while ((count = input.read(buffer)) != -1) {
                        copied += count;
                        if (copied > MAX_BYTES) throw new IOException("GIF source is too large");
                        output.write(buffer, 0, count);
                    }
                    output.flush();
                }
            }
        } catch (Exception error) {
            try { destination.delete(); } catch (Exception cleanup) { error.addSuppressed(cleanup); }
            throw error;
        }
    }
}
