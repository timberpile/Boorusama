package com.timberpile.boorusama;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.Set;
import java.util.Locale;

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
        return copy(source, destination, null);
    }

    public synchronized String copy(File source, Destination destination, String requestedName) throws Exception {
        File owned = source.getCanonicalFile();
        boolean inCache = false;
        for (File cache : caches) {
            if (owned.getPath().startsWith(cache.getPath() + File.separator)) inCache = true;
        }
        if (!inCache || !owned.isFile()
                || !owned.getName().endsWith(".bsexport")) {
            throw new IOException("Export source is unavailable");
        }
        String name = requestedName == null ? owned.getName() : requestedName;
        if (!isValidExportName(name)) throw new IOException("Invalid export file name");
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

    private static boolean isValidExportName(String name) {
        final String extension = ".bsexport";
        if (name.length() <= extension.length() || !name.endsWith(extension)) return false;
        String stem = name.substring(0, name.length() - extension.length());
        if (stem.equals(".") || stem.equals("..") || stem.endsWith(".") || !stem.equals(stem.trim())) return false;
        for (int i = 0; i < stem.length(); i++) {
            char c = stem.charAt(i);
            if (c < 32 || c == 127 || "<>:\"/\\|?*".indexOf(c) >= 0) return false;
        }
        String reserved = stem.split("\\.", 2)[0].toUpperCase(Locale.ROOT);
        if (reserved.equals("CON") || reserved.equals("PRN") ||
                reserved.equals("AUX") || reserved.equals("NUL")) return false;
        return !(reserved.length() == 4 &&
                (reserved.startsWith("COM") || reserved.startsWith("LPT")) &&
                reserved.charAt(3) >= '1' && reserved.charAt(3) <= '9');
    }
}
