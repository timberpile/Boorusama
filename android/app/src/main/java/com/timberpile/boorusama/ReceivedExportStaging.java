package com.timberpile.boorusama;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.UUID;

/** Owns a separate cache file for each external delivery, even when bytes match. */
public final class ReceivedExportStaging {
    public static final class Delivery {
        public final String id;
        public final File file;

        private Delivery(String id, File file) {
            this.id = id;
            this.file = file;
        }
    }

    public static Delivery stage(InputStream input, File directory, long maxBytes)
            throws IOException {
        String id = UUID.randomUUID().toString();
        File pending = new File(directory, id + ".part");
        File completed = new File(directory, id + ".bsexport");
        try {
            try (InputStream source = input) {
                if (!directory.isDirectory() && !directory.mkdirs()) {
                    throw new IOException("Could not create received export cache");
                }
                try (FileOutputStream output = new FileOutputStream(pending)) {
                    byte[] buffer = new byte[8192];
                    long byteCount = 0;
                    int count;
                    while ((count = source.read(buffer)) != -1) {
                        byteCount += count;
                        if (byteCount > maxBytes) {
                            throw new IOException("Received export is too large");
                        }
                        output.write(buffer, 0, count);
                    }
                }
            }
            if (!pending.renameTo(completed)) {
                throw new IOException("Could not complete received export");
            }
            return new Delivery(id, completed);
        } finally {
            pending.delete();
        }
    }

    private ReceivedExportStaging() {}
}
