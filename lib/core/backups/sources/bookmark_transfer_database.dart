import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../../../foundation/cooperative_work.dart';
import '../../bookmarks/src/data/hive/repository.dart';
import '../../bookmarks/src/data/stored_bookmark_codec.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../bookmarks/types.dart';
import '../../content/content_map.dart';
import '../export_import/import/bookmark_profile_dependency.dart';
import '../export_import/import/import_progress.dart';
import '../export_import/models/package_manifest.dart';
import '../export_import/package/bookmark_transfer_format.dart';
import '../export_import/package/staged_export_package.dart';
import 'bookmark_backup_data.dart';
import 'bookmark_transfer_export.dart';
import 'bookmark_transfer_rows.dart';
import 'detached_bookmark_codec.dart';

const _applicationId = 0x42534d42;

String? bookmarkTransferIdentity(Bookmark record) {
  final identity = bookmarkContentIdentity(record);
  return identity == null
      ? null
      : jsonEncode([
          identity.siteNamespace,
          identity.kind.name,
          identity.sourceKey,
        ]);
}

/// File-local IDs and relationships have a single disk-backed authority from
/// package validation through review and apply. The same table layout stores
/// the private rollback preimage, with a distinct purpose and local IDs.
final class BookmarkTransferDatabase {
  const BookmarkTransferDatabase(this.path);

  final String path;
  static const batchSize = 1024;

  Database open({required bool preimage, bool writable = false}) {
    final db = sqlite3.open(
      path,
      mode: writable ? OpenMode.readWrite : OpenMode.readOnly,
    );
    try {
      if (db.select('PRAGMA application_id').single.values.single !=
              _applicationId ||
          db.select('PRAGMA user_version').single.values.single != 1 ||
          db.select('SELECT preimage FROM transfer').single['preimage'] !=
              (preimage ? 1 : 0)) {
        throw const FormatException('Invalid Bookmark transfer database');
      }
      return db;
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  Database _create({required bool preimage}) {
    final db = sqlite3.open(path);
    try {
      db.execute('''
        PRAGMA foreign_keys = ON;
        PRAGMA application_id = $_applicationId;
        PRAGMA user_version = 1;
        PRAGMA cache_size = -8192;
        BEGIN;
        CREATE TABLE transfer(preimage INTEGER NOT NULL);
        INSERT INTO transfer VALUES (${preimage ? 1 : 0});
        CREATE TABLE groups(
          id TEXT PRIMARY KEY, name TEXT NOT NULL, parent TEXT, position INTEGER NOT NULL
        ) WITHOUT ROWID;
        CREATE TABLE records(
          id INTEGER PRIMARY KEY, identity TEXT UNIQUE, wire TEXT NOT NULL,
          profile_id TEXT NOT NULL, engine TEXT NOT NULL, site TEXT NOT NULL,
          created TEXT NOT NULL
        );
        CREATE TABLE members(
          group_id TEXT NOT NULL REFERENCES groups(id),
          bookmark_id INTEGER NOT NULL REFERENCES records(id),
          added_at TEXT NOT NULL,
          PRIMARY KEY(group_id, bookmark_id)
        ) WITHOUT ROWID;
        CREATE INDEX memberships_by_record ON members(bookmark_id, group_id);
      ''');
      return db;
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  Future<void> stage({
    required StagedExportPackage package,
    required Map<BookmarkTransferTable, List<ExportPartManifest>> parts,
    required StoredBookmarkCodec codec,
    required bool Function() cancelled,
  }) async {
    if (cancelled()) throw const BookmarkTransferCancelled();
    final task = _StageBookmarkTransfer(
      this,
      [
        for (final table in BookmarkTransferTable.values)
          for (final part in parts[table]!)
            (table, package.pathFor(part.path), part.byteLength),
      ],
      detachBookmarkRecordCodec(codec),
    );
    final progress =
        ImportProgress.current ?? ImportProgress((_) {}, cancelled: cancelled);
    await package.read(() => progress.run(() => runImportWorker(task.run)));
    if (cancelled()) throw const BookmarkTransferCancelled();
  }

  Future<void> _stage(
    List<(BookmarkTransferTable, String, int)> files,
    StoredBookmarkCodec codec,
  ) async {
    final db = _create(preimage: false);
    final progress = ImportProgress.current;
    final total = files.fold(0, (sum, file) => sum + file.$3);
    var processed = 0;
    progress?.show(ImportProgressPhase.reading, total: total);
    try {
      final insert = _TransferInserts(db);
      try {
        for (final (table, path, _) in files) {
          await for (final row in readBookmarkTransferRows(
            File(path).openRead(),
            onRowProcessed: (bytes) => progress?.show(
              ImportProgressPhase.reading,
              completed: processed += bytes,
              total: total,
            ),
          )) {
            if (progress?.cancelled ?? false) {
              throw const BookmarkTransferCancelled();
            }
            switch (table) {
              case BookmarkTransferTable.groups:
                insert.group(row);
              case BookmarkTransferTable.bookmarks:
                insert.record(codec.decode(row), row);
              case BookmarkTransferTable.memberships:
                insert.memberRow(row);
            }
          }
        }
      } finally {
        insert.close();
      }
      // Parent rows can follow children in the archive.
      progress?.show(ImportProgressPhase.preparing);
      BookmarkGroupTree(groupDefinitions(db));
      db.execute('COMMIT');
    } on SqliteException catch (error) {
      if (error.extendedResultCode & 0xff == 19) {
        throw const FormatException('Duplicate or missing Bookmark reference');
      }
      rethrow;
    } finally {
      db.close();
    }
  }

  Future<void> capture(
    BookmarkHiveRepository store,
    StoredBookmarkCodec codec, {
    required bool Function() cancelled,
  }) => store.runReadWriteScope(() async {
    final budget = CooperativeWork();
    final progress = ImportProgress.current;
    final total = progress == null ? null : await store.countTransferRows();
    var written = 0;
    void rowWritten() => progress?.show(
      ImportProgressPhase.preparing,
      completed: ++written,
      total: total,
    );
    progress?.show(ImportProgressPhase.preparing, total: total);
    final db = _create(preimage: true);
    try {
      final insert = _TransferInserts(db);
      try {
        await store.visitTransferRecords((record) async {
          if (cancelled()) throw const BookmarkTransferCancelled();
          insert.record(record, codec.encode(record));
          rowWritten();
          if (budget.checkpoint() case final pause?) await pause;
        });
        await store.visitTransferGroups((group) async {
          insert.group(
            bookmarkTransferGroupRow(
              id: group.id,
              name: group.name,
              parentGroupId: group.parentGroupId,
              position: group.position,
            ),
          );
          rowWritten();
          for (final id in group.bookmarkIds) {
            if (cancelled()) throw const BookmarkTransferCancelled();
            final date =
                group.addedAt?[id] as String? ??
                bookmarkCreatedAt((await store.read(id))!)
                    .toUtc()
                    .toIso8601String();
            insert.member(group.id, id, date);
            rowWritten();
            if (budget.checkpoint() case final pause?) await pause;
          }
        });
      } finally {
        insert.close();
      }
      db.execute('COMMIT');
    } finally {
      db.close();
    }
  });

  Future<
    ({BookmarkBackupData groups, bool hasUngrouped, Map<String, int> counts})
  >
  readReviewMetadata() async {
    final db = open(preimage: false);
    try {
      final groups = BookmarkBackupData.unified(
        records: const [],
        groups: [
          for (final group in groupDefinitions(db))
            BookmarkGroupBackup(
              id: group.id,
              name: group.name,
              parentGroupId: group.parentGroupId,
              bookmarkIds: const [],
              position: group.position,
            ),
        ],
      );
      return (
        groups: groups,
        hasUngrouped: hasUngrouped(db),
        counts: {
          for (final row in db.select(
            'SELECT group_id, COUNT(*) AS n FROM members GROUP BY group_id',
          ))
            row['group_id'] as String: row['n'] as int,
        },
      );
    } finally {
      db.close();
    }
  }

  static List<BookmarkGroup> groupDefinitions(
    Database db, {
    String schema = 'main',
  }) => [
    for (final row in db.select(
      'SELECT * FROM $schema.groups ORDER BY position, id',
    ))
      BookmarkGroup(
        id: row['id'] as String,
        name: row['name'] as String,
        parentGroupId: row['parent'] as String?,
        position: row['position'] as int,
        bookmarkIds: const {},
      ),
  ];

  static bool hasUngrouped(Database db) => db.select('''
    SELECT 1 FROM records AS r
    WHERE NOT EXISTS (SELECT 1 FROM members AS m WHERE m.bookmark_id = r.id)
    LIMIT 1
  ''').isNotEmpty;
}

final class _StageBookmarkTransfer {
  const _StageBookmarkTransfer(this.database, this.parts, this.codec);

  final BookmarkTransferDatabase database;
  final List<(BookmarkTransferTable, String, int)> parts;
  final StoredBookmarkCodec codec;

  Future<void> run() => database._stage(parts, codec);
}

final class _TransferInserts {
  _TransferInserts(Database db)
    : _groups = db.prepare('INSERT INTO groups VALUES (?, ?, ?, ?)'),
      _records = db.prepare('INSERT INTO records VALUES (?, ?, ?, ?, ?, ?, ?)'),
      _members = db.prepare('INSERT INTO members VALUES (?, ?, ?)');

  final PreparedStatement _groups;
  final PreparedStatement _records;
  final PreparedStatement _members;

  void group(Map<String, Object?> row) {
    final id = row['id'];
    final name = row['name'];
    final parent = row['parentGroupId'];
    final position = row['position'];
    final isDefault = id == defaultBookmarkGroupId;
    if (id is! String ||
        !Uuid.isValidUUID(fromString: id) ||
        id != id.toLowerCase() ||
        name is! String ||
        name.isEmpty ||
        name != name.trim() ||
        position is! int ||
        position < 0 ||
        (parent != null && parent is! String) ||
        (isDefault
            ? (row['systemRole'] != 'default' || parent != null)
            : row['systemRole'] != null) ||
        row.keys.any(
          (key) => !const {
            'id',
            'name',
            'parentGroupId',
            'position',
            'systemRole',
          }.contains(key),
        )) {
      throw const FormatException('Invalid Bookmark group definition');
    }
    _groups.execute([id, isDefault ? 'Default' : name, parent, position]);
  }

  void record(Bookmark record, Map<String, Object?> wire) {
    final profile = bookmarkRecordProfileReference(record);
    _records.execute([
      record.id,
      bookmarkTransferIdentity(record),
      jsonEncode(wire),
      profile.id,
      profile.booruType,
      profile.url,
      bookmarkCreatedAt(record).toUtc().toIso8601String(),
    ]);
  }

  void memberRow(Map<String, Object?> row) {
    final group = contentString(row['groupId']);
    final id = row['bookmarkId'];
    final date = DateTime.tryParse(contentString(row['addedAt']));
    if (row.length != 3 || id is! int || date == null || !date.isUtc) {
      throw const FormatException('Invalid Bookmark membership');
    }
    member(group, id, date.toUtc().toIso8601String());
  }

  void member(String group, int id, String date) =>
      _members.execute([group, id, date]);

  void close() {
    _groups.close();
    _records.close();
    _members.close();
  }
}

final class BookmarkTransferCancelled implements Exception {
  const BookmarkTransferCancelled();
}
