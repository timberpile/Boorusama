import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../bookmarks/src/data/hive/repository.dart';
import '../../bookmarks/src/data/stored_bookmark_codec.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../bookmarks/types.dart';
import '../export_import/package/bookmark_transfer_format.dart';
import '../export_import/package/export_package_exception.dart';
import 'bookmark_backup_data.dart';
import 'bookmark_transfer_rows.dart';

Future<List<String>> writeBookmarkTransfer({
  required BookmarkHiveRepository store,
  required String directory,
  required BookmarkExportScope scope,
  required StoredBookmarkCodec codec,
}) => store.runReadWriteScope(() async {
  var expandedBytes = 0;
  void chargeBytes(int bytes) {
    expandedBytes += bytes;
    if (expandedBytes > bookmarkTransferExpandedBytes) {
      throw const ExportPackageLimitException(
        'Expanded Bookmark transfer is too large',
      );
    }
  }

  final groups = BookmarkTransferRowsWriter(
    directory,
    BookmarkTransferTable.groups,
    chargeBytes,
  );
  final records = BookmarkTransferRowsWriter(
    directory,
    BookmarkTransferTable.bookmarks,
    chargeBytes,
  );
  final members = BookmarkTransferRowsWriter(
    directory,
    BookmarkTransferTable.memberships,
    chargeBytes,
  );
  final indexPath = p.join(directory, 'bookmark_selection.sqlite');
  final index = sqlite3.open(indexPath);
  var completed = false;
  try {
    index.execute('''
      CREATE TABLE selected(id INTEGER PRIMARY KEY, written INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE assigned(id INTEGER PRIMARY KEY);
    ''');
    final definitions = <BookmarkGroup>[];
    await store.visitTransferGroups((row) async {
      definitions.add(
        BookmarkGroup(
          id: row.id,
          name: row.name,
          position: row.position,
          parentGroupId: row.parentGroupId,
          bookmarkIds: const {},
        ),
      );
    });
    final tree = BookmarkGroupTree(definitions);
    final selected = scope.isAll
        ? tree.groupsById.keys.toSet()
        : {
            for (final id in scope.groupIds!) ...tree.subtreeIds(id),
            ...scope.directGroupIds.where(tree.groupsById.containsKey),
            if (scope.includeUngrouped) defaultBookmarkGroupId,
          };
    final included = {
      ...selected,
      for (final id in selected) ...tree.ancestors(id).map((group) => group.id),
    };
    var defaultWritten =
        included.contains(defaultBookmarkGroupId) &&
        tree.groupsById.containsKey(defaultBookmarkGroupId);
    index.execute('BEGIN');
    final select = index.prepare(
      'INSERT OR IGNORE INTO selected(id) VALUES (?)',
    );
    final assign = index.prepare(
      'INSERT OR IGNORE INTO assigned(id) VALUES (?)',
    );
    final mark = index.prepare('UPDATE selected SET written = 1 WHERE id = ?');
    final isSelected = index.prepare('SELECT 1 FROM selected WHERE id = ?');
    final isAssigned = index.prepare('SELECT 1 FROM assigned WHERE id = ?');
    try {
      await store.visitTransferGroups((row) async {
        if (included.contains(row.id)) {
          await groups.add(
            bookmarkTransferGroupRow(
              id: row.id,
              name: row.name,
              parentGroupId: row.parentGroupId,
              position: row.position,
            ),
          );
        }
        final include = selected.contains(row.id);
        if (!include && !scope.includeUngrouped) return;
        for (final id in row.bookmarkIds) {
          if (scope.includeUngrouped) assign.execute([id]);
          if (!include) continue;
          select.execute([id]);
          final date = row.addedAt?[id] as String?;
          await members.add({
            'groupId': row.id,
            'bookmarkId': id,
            'addedAt':
                date ??
                bookmarkCreatedAt(
                  await store.read(id) ??
                      (throw const FormatException(
                        'Missing Bookmark group member',
                      )),
                ).toUtc().toIso8601String(),
          });
        }
      });
      await store.visitTransferRecords((record) async {
        final id = record.id;
        final selected = isSelected.select([id]).isNotEmpty;
        final keepUngrouped =
            (scope.isAll || scope.includeUngrouped) &&
            !selected &&
            isAssigned.select([id]).isEmpty;
        if (!selected && !keepUngrouped) return;
        if (keepUngrouped) {
          if (!defaultWritten) {
            await groups.add(
              bookmarkTransferGroupRow(
                id: defaultBookmarkGroupId,
                name: 'Default',
                position: 0,
              ),
            );
            defaultWritten = true;
          }
          await members.add({
            'groupId': defaultBookmarkGroupId,
            'bookmarkId': id,
            'addedAt': bookmarkCreatedAt(record).toUtc().toIso8601String(),
          });
        }
        await records.add(codec.encodeForTransfer(record));
        if (selected) mark.execute([id]);
      });
      if (index
          .select('SELECT 1 FROM selected WHERE written = 0 LIMIT 1')
          .isNotEmpty) {
        throw const FormatException('Missing Bookmark group member');
      }
      index.execute('COMMIT');
      completed = true;
    } finally {
      select.close();
      assign.close();
      mark.close();
      isSelected.close();
      isAssigned.close();
    }
  } finally {
    index.close();
    await Future.wait([
      groups.close(completed: completed),
      records.close(completed: completed),
      members.close(completed: completed),
    ]);
    await File(indexPath).delete();
  }
  final paths = [...groups.paths, ...records.paths, ...members.paths];
  if (paths.length > bookmarkTransferPartCount) {
    throw const ExportPackageLimitException(
      'Expanded Bookmark transfer is too large',
    );
  }
  return paths;
});

Map<String, Object?> bookmarkTransferGroupRow({
  required String id,
  required String name,
  String? parentGroupId,
  required int position,
}) => {
  'id': id,
  'name': name,
  'parentGroupId': parentGroupId,
  'position': position,
  if (id == defaultBookmarkGroupId) 'systemRole': 'default',
};
