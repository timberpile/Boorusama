import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../../foundation/cooperative_work.dart';
import '../../../foundation/filesystem.dart';
import '../../bookmarks/src/types/bookmark.dart';
import '../../bookmarks/src/types/bookmark_group.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../export_import/models/export_selection.dart';
import '../export_import/package/bookmark_transfer_format.dart';
import '../export_import/package/export_package_exception.dart';
import '../export_import/package/export_package_writer.dart';
import '../sources/bookmark_backup_codec.dart';
import '../sources/bookmark_backup_schema.dart';
import '../sources/bookmark_transfer_export.dart' show bookmarkTransferGroupRow;
import '../sources/bookmark_transfer_rows.dart';
import 'bookmark_package.dart';
import 'protocol.dart';

/// A locally prepared, private publication snapshot. Only its final archive
/// leaves app storage, after the publisher rechecks its captured local revision.
final class StagedSyncBookmarkPublication {
  const StagedSyncBookmarkPublication._({
    required this.collection,
    required this.semanticHash,
    required this.fs,
    required String directory,
    required List<String> parts,
  }) : _directory = directory,
       _parts = parts;

  final SyncCollectionId collection;
  final String semanticHash;
  final AppFileSystem fs;
  final String _directory;
  final List<String> _parts;

  Future<({String path, int length, String sha256})> buildArchive({
    required String appVersion,
    required DateTime createdAt,
  }) {
    final task = _WriteArchive(
      fs: fs,
      directory: _directory,
      parts: _parts,
      source: collection.source,
      appVersion: appVersion,
      createdAt: createdAt,
    );
    return fs.runtimeType == IoFileSystem ? Isolate.run(task.run) : task.run();
  }

  Future<void> dispose() => fs.deleteDirectory(_directory, recursive: true);
}

final class SyncBookmarkStreamedPackageBuilder {
  const SyncBookmarkStreamedPackageBuilder({
    required this.fs,
    required this.codec,
  });

  final AppFileSystem fs;
  final BookmarkBackupCodec codec;

  Future<StagedSyncBookmarkPublication> stage({
    required SyncCollectionId collection,
    required BookmarkGroup group,
    required Stream<Bookmark> records,
  }) async {
    if (collection.kind != 'bookmarks' ||
        collection.source != group.id ||
        group.name != group.name.trim() ||
        group.name.isEmpty) {
      throw const FormatException('Invalid Bookmark publication scope');
    }

    final directory = await fs.createTempDirectory('boorusama_sync_publish_');
    try {
      var expanded = 0;
      void charge(int bytes) {
        expanded += bytes;
        if (expanded > bookmarkTransferExpandedBytes) {
          throw const ExportPackageLimitException(
            'Expanded Bookmark publication is too large',
          );
        }
      }

      final groups = BookmarkTransferRowsWriter(
        directory,
        BookmarkTransferTable.groups,
        charge,
      );
      final bookmarks = BookmarkTransferRowsWriter(
        directory,
        BookmarkTransferTable.bookmarks,
        charge,
      );
      final memberships = BookmarkTransferRowsWriter(
        directory,
        BookmarkTransferTable.memberships,
        charge,
      );
      final hashPath = p.join(directory, 'semantic.sqlite');
      var completed = false;
      try {
        final index = sqlite3.open(hashPath);
        try {
          index.execute('''
            CREATE TABLE members(
              sort_key BLOB PRIMARY KEY,
              id INTEGER NOT NULL UNIQUE,
              fragment TEXT NOT NULL
            ) WITHOUT ROWID;
            BEGIN;
          ''');
          final insert = index.prepare('INSERT INTO members VALUES (?, ?, ?)');
          try {
            await groups.add(
              bookmarkTransferGroupRow(
                id: group.id,
                name: group.name,
                position: 0,
              ),
            );
            final work = CooperativeWork();
            var count = 0;
            await for (final record in records) {
              if (!group.bookmarkIds.contains(record.id)) {
                throw const FormatException(
                  'Bookmark is outside the published Group',
                );
              }
              // Hash decoded portable rows for parity with receive. This also
              // validates the sanitized row before creating any shared files.
              final encoded = syncBookmarkPublicationRecord(
                codec.records.encodeForTransfer(record),
              );
              final (memberKey, fragment) = syncBookmarkSemanticEntry(
                codec.records.decode(encoded),
                codec,
              );
              insert.execute([
                syncBookmarkSemanticSortKey(memberKey),
                record.id,
                fragment,
              ]);
              await bookmarks.add(encoded);
              await memberships.add({
                'groupId': group.id,
                'bookmarkId': record.id,
                'addedAt':
                    (group.addedAt[record.id] ?? bookmarkCreatedAt(record))
                        .toUtc()
                        .toIso8601String(),
              });
              count++;
              if (work.checkpoint() case final pause?) await pause;
            }
            if (count != group.bookmarkIds.length) {
              throw const FormatException(
                'Published Group is missing a Bookmark',
              );
            }
          } finally {
            insert.close();
          }
          index.execute('COMMIT');
        } on SqliteException catch (error) {
          if (error.extendedResultCode & 0xff == 19) {
            throw const FormatException('Duplicate sync member');
          }
          rethrow;
        } finally {
          index.close();
        }
        completed = true;
      } finally {
        await Future.wait([
          groups.close(completed: completed),
          bookmarks.close(completed: completed),
          memberships.close(completed: completed),
        ]);
      }
      final parts = [...groups.paths, ...bookmarks.paths, ...memberships.paths];
      if (parts.length > bookmarkTransferPartCount) {
        throw const ExportPackageLimitException(
          'Expanded Bookmark publication is too large',
        );
      }
      final hash = await Isolate.run(_HashMembers(hashPath).run);
      await fs.deleteFile(hashPath);
      return StagedSyncBookmarkPublication._(
        collection: collection,
        semanticHash: hash,
        fs: fs,
        directory: directory,
        parts: parts,
      );
    } catch (_) {
      await fs.deleteDirectory(directory, recursive: true);
      rethrow;
    }
  }
}

final class _HashMembers {
  const _HashMembers(this.path);
  final String path;

  Future<String> run() async {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      final statement = db.prepare(
        'SELECT fragment FROM members ORDER BY sort_key',
      );
      try {
        Iterable<String> fragments() sync* {
          final cursor = statement.selectCursor();
          while (cursor.moveNext()) {
            yield cursor.current['fragment'] as String;
          }
        }

        return await hashSyncBookmarkSemanticEntries(fragments());
      } finally {
        statement.close();
      }
    } finally {
      db.close();
    }
  }
}

final class _WriteArchive {
  const _WriteArchive({
    required this.fs,
    required this.directory,
    required this.parts,
    required this.source,
    required this.appVersion,
    required this.createdAt,
  });

  final AppFileSystem fs;
  final String directory;
  final List<String> parts;
  final String source;
  final String appVersion;
  final DateTime createdAt;

  Future<({String path, int length, String sha256})> run() async {
    final path = await ExportPackageWriter(fs: fs).write(
      ExportPackageBuild(
        createdAt: createdAt,
        appVersion: appVersion,
        sources: [
          ExportPackageSourceBuild(
            id: 'bookmarks',
            schemaVersion: kBookmarksBackupVersion,
            selection: ExportNodeSelection.explicit('bookmarks', {source}),
            parts: const [],
            prepareParts: (target) async {
              for (final part in parts) {
                final destination = p.join(target, part);
                await fs.createDirectory(
                  p.dirname(destination),
                  recursive: true,
                );
                await fs.renameFile(p.join(directory, part), destination);
              }
              return parts;
            },
          ),
        ],
      ),
      p.join(directory, 'revision.bsexport'),
    );
    final length = await fs.fileSize(path);
    final digest = await sha256.bind(fs.openRead(path)).first;
    return (path: path, length: length, sha256: digest.toString());
  }
}
