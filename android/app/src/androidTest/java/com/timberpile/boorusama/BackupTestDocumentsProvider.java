package com.timberpile.boorusama;

import android.app.ActivityOptions;
import android.app.PendingIntent;
import android.os.Build;
import android.content.ComponentName;
import android.content.Intent;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.Binder;
import android.os.Bundle;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;
import android.provider.DocumentsContract;
import android.provider.DocumentsContract.Document;
import android.provider.DocumentsProvider;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.LinkedHashMap;
import java.util.Map;

/** Standalone test-APK provider: only Android/Java classes, no target-app runtime dependencies. */
public class BackupTestDocumentsProvider extends DocumentsProvider {
    public static final String AUTHORITY = "com.timberpile.boorusama.backup.test.documents";
    public static Uri tree() { return DocumentsContract.buildTreeDocumentUri(AUTHORITY, "root"); }
    private final Map<String, File> files = new LinkedHashMap<>();
    private final Map<String, String> names = new LinkedHashMap<>();
    private final Map<String, String> types = new LinkedHashMap<>();
    private String behavior = "known";
    private int nextId;
    private boolean syncMode;
    private int faultFrom;
    private final Map<String, String> parents = new LinkedHashMap<>();
    private File directory() { return new File(getContext().getCacheDir(), "backup-provider-fixture"); }
    @Override public boolean onCreate() { return true; }

    @Override public synchronized Bundle call(String method, String arg, Bundle extras) {
        if ("fixture".equals(method)) {
            for (File file : files.values()) file.delete();
            directory().mkdirs();
            files.clear(); names.clear(); types.clear(); parents.clear(); nextId = 0;
            syncMode = extras.getBoolean("sync", false);
            faultFrom = 1;
            behavior = extras.getString("behavior");
            try {
                add("root", "QA root", Document.MIME_TYPE_DIR);
                if (!syncMode) {
                    add("folder", "boorusama_auto_backups", Document.MIME_TYPE_DIR);
                    Files.write(add("old", "older.bsexport", "application/octet-stream").toPath(), new byte[]{9, 8, 7});
                    Files.write(add("manifest", "auto_backup_manifest.json", "application/json").toPath(),
                        "{\"backups\":[\"older.bsexport\"]}".getBytes(StandardCharsets.UTF_8));
                }
            } catch (IOException error) { throw new IllegalStateException(error); }
            return grant(extras);
        }
        if ("grant".equals(method)) return grant(extras);
        if ("behavior".equals(method)) { behavior = arg; faultFrom = nextId + 1; return Bundle.EMPTY; }
        return super.call(method, arg, extras);
    }

    private Bundle grant(Bundle extras) {
        long identity = Binder.clearCallingIdentity();
        try {
            // Persistable grants require an Intent, not Context.grantUriPermission.
            Intent grant = new Intent().setComponent(new ComponentName(extras.getString("package"),
                "com.timberpile.boorusama.BackupGrantActivity")).setData(tree());
            grant.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_GRANT_READ_URI_PERMISSION |
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION |
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION);
            ActivityOptions options = ActivityOptions.makeBasic();
            if (Build.VERSION.SDK_INT >= 35) options.setPendingIntentCreatorBackgroundActivityStartMode(
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED);
            PendingIntent pending = PendingIntent.getActivity(getContext(), 0, grant,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE, options.toBundle());
            Bundle result = new Bundle(); result.putParcelable("grant", pending); return result;
        } finally { Binder.restoreCallingIdentity(identity); }
    }

    private File add(String id, String name, String mime) throws IOException {
        names.put(id, name); types.put(id, mime);
        File file = new File(directory(), id); files.put(id, file);
        if (!Document.MIME_TYPE_DIR.equals(mime)) Files.write(file.toPath(), new byte[0]);
        return file;
    }

    private static final String[] COLUMNS = {Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME,
        Document.COLUMN_MIME_TYPE, Document.COLUMN_SIZE, Document.COLUMN_FLAGS};
    @Override public Cursor queryRoots(String[] projection) {
        return new MatrixCursor(projection == null ? new String[]{DocumentsContract.Root.COLUMN_ROOT_ID} : projection);
    }
    private void row(MatrixCursor cursor, String id) throws FileNotFoundException {
        File file = files.get(id);
        if (file == null) throw new FileNotFoundException();
        boolean fresh = id.startsWith("new") && (!syncMode || Integer.parseInt(id.substring(3)) >= faultFrom);
        if (fresh && "truncated".equals(behavior)) {
            try { Files.write(file.toPath(), new byte[]{1}); }
            catch (IOException error) { throw new IllegalStateException(error); }
        }
        Object[] values = new Object[cursor.getColumnCount()];
        String[] columns = cursor.getColumnNames();
        for (int i = 0; i < columns.length; i++) {
            switch (columns[i]) {
                case Document.COLUMN_DOCUMENT_ID: values[i] = id; break;
                case Document.COLUMN_DISPLAY_NAME: values[i] = names.get(id); break;
                case Document.COLUMN_MIME_TYPE: values[i] = types.get(id); break;
                case Document.COLUMN_FLAGS: values[i] = Document.FLAG_SUPPORTS_WRITE | Document.FLAG_SUPPORTS_DELETE | Document.FLAG_DIR_SUPPORTS_CREATE; break;
                case Document.COLUMN_SIZE:
                    if (!fresh) values[i] = file.length();
                    else if ("null".equals(behavior) || "truncated".equals(behavior) || "read-failure".equals(behavior)) values[i] = null;
                    else if ("negative".equals(behavior)) values[i] = -1L;
                    else if ("zero".equals(behavior)) values[i] = 0L;
                    else values[i] = file.length();
                    break;
            }
        }
        cursor.addRow(values);
    }
    @Override public synchronized Cursor queryDocument(String id, String[] projection) throws FileNotFoundException {
        MatrixCursor cursor = new MatrixCursor(projection == null ? COLUMNS : projection); row(cursor, id); return cursor;
    }
    @Override public synchronized Cursor queryChildDocuments(String parent, String[] projection, String sortOrder) throws FileNotFoundException {
        MatrixCursor cursor = new MatrixCursor(projection == null ? COLUMNS : projection);
        if (syncMode) {
            for (String id : names.keySet()) if (parent.equals(parents.get(id))) {
                row(cursor, id);
                if ("duplicate".equals(behavior)) row(cursor, id);
            }
        } else if ("root".equals(parent)) row(cursor, "folder");
        else for (String id : names.keySet()) if (!"root".equals(id) && !"folder".equals(id)) row(cursor, id);
        return cursor;
    }
    @Override public synchronized String createDocument(String parent, String mime, String name) throws FileNotFoundException {
        if (syncMode && !Document.MIME_TYPE_DIR.equals(types.get(parent))) throw new FileNotFoundException("Missing directory");
        String id = "new" + ++nextId;
        if (syncMode) parents.put(id, parent);
        try { add(id, "renamed".equals(behavior) ? "renamed-" + name : name, mime); }
        catch (IOException error) { throw new IllegalStateException(error); }
        return id;
    }
    @Override public synchronized void deleteDocument(String id) {
        File file = files.remove(id); if (file != null) file.delete(); names.remove(id); types.remove(id); parents.remove(id);
    }
    @Override public boolean isChildDocument(String parent, String id) {
        if (syncMode) {
            String current = id;
            for (int depth = 0; current != null && depth <= parents.size(); depth++) {
                if (parent.equals(current)) return true;
                current = parents.get(current);
            }
            return false;
        }
        return "root".equals(parent) || ("folder".equals(parent) && !"root".equals(id));
    }
    @Override public synchronized ParcelFileDescriptor openDocument(String id, String mode, CancellationSignal signal) throws FileNotFoundException {
        if (id.startsWith("new") && (!syncMode || Integer.parseInt(id.substring(3)) >= faultFrom) && "r".equals(mode) && "read-failure".equals(behavior)) throw new FileNotFoundException("Controlled read failure");
        File file = files.get(id); if (file == null) throw new FileNotFoundException();
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.parseMode(mode));
    }
}
