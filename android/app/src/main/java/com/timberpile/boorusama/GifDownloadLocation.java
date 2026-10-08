package com.timberpile.boorusama;

import java.io.File;
import java.io.IOException;

/** Maps configured public paths to MediaStore and reserves non-overwriting file destinations. */
public final class GifDownloadLocation {
    public record Shared(String primaryDirectory, String relativePath) {}

    public static Shared shared(File directory, File volumeRoot) throws IOException {
        String root = volumeRoot.getCanonicalPath() + File.separator;
        String target = directory.getCanonicalPath();
        if (!target.startsWith(root)) throw new IOException("Download folder is outside this volume");
        String relative = target.substring(root.length());
        String primary = relative.split("/", 2)[0];
        if (!primary.equals("Download") && !primary.equals("Documents") && !primary.equals("Pictures")) {
            throw new IOException("Unsupported public download folder");
        }
        return new Shared(primary, relative + "/");
    }

    public static File reserve(File directory, String name) throws IOException {
        if (!directory.isDirectory() && !directory.mkdirs() && !directory.isDirectory()) {
            throw new IOException("Download folder is unavailable");
        }
        String stem = name.substring(0, name.length() - 4);
        for (int attempt = 1; attempt <= 10000; attempt++) {
            File target = new File(directory, attempt == 1 ? name : stem + "_" + attempt + ".gif");
            if (target.createNewFile()) return target;
        }
        throw new IOException("No available GIF filename");
    }
}
