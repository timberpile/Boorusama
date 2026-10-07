package com.timberpile.boorusama;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.Set;

/** Streams an owned export into a newly created document, never overwriting a document. */
public final class ExportDocumentTransfer {
    public interface Destination {
        Set<String> names() throws Exception;
        String create(String name) throws Exception;
        OutputStream open(String document) throws Exception;
        void delete(String document) throws Exception;
    }

    private final File[] caches;

    public ExportDocumentTransfer(File... caches) throws IOException {
        this.caches = new File[caches.length];
        for (int i = 0; i < caches.length; i++) this.caches[i] = caches[i].getCanonicalFile();
    }

    public synchronized String copy(File source, Destination destination) throws Exception {
        File owned = source.getCanonicalFile();
        boolean inCache = false;
        for (File cache : caches) {
            if (owned.getPath().startsWith(cache.getPath() + File.separator)) inCache = true;
        }
        if (!inCache || !owned.isFile()
                || !owned.getName().endsWith(".bsexport")) {
            throw new IOException("Export source is unavailable");
        }
        String name = owned.getName();
        String stem = name.substring(0, name.length() - ".bsexport".length());
        Set<String> names = destination.names();
        for (int suffix = 2; names.contains(name); suffix++) {
            name = stem + "-" + suffix + ".bsexport";
        }
        String document = destination.create(name);
        if (document == null) throw new IOException("Could not create export document");
        try {
            try (FileInputStream input = new FileInputStream(owned);
                    OutputStream output = destination.open(document)) {
                if (output == null) throw new IOException("Could not open export document");
                byte[] buffer = new byte[64 * 1024];
                int count;
                while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
                output.flush();
            }
            return document;
        } catch (Exception error) {
            try {
                destination.delete(document);
            } catch (Exception cleanup) {
                error.addSuppressed(cleanup);
            }
            throw error;
        }
    }
}
