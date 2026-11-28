import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/backups/export_import/package/bookmark_transfer_format.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_limits.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_exception.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/core/backups/sources/bookmark_transfer_database.dart';
import 'package:boorusama/core/backups/sources/bookmark_transfer_export.dart';
import 'package:boorusama/core/backups/sources/bookmark_transfer_rows.dart';
import 'package:boorusama/core/bookmarks/src/data/stored_bookmark_codec.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';

const _group = '11111111-1111-4111-8111-111111111111';
const _fs = IoFileSystem();

void main() {
  test('streamed Bookmark parts use a separate archive budget', () async {
    final directory = await Directory.systemTemp.createTemp('bookmark-layout-');
    addTearDown(() => directory.delete(recursive: true));
    final path = await _write(directory);
    // A legacy package with these four files would exceed this file-count limit.
    final staged = await const ExportPackageReader(
      fs: _fs,
      limits: ExportPackageLimits(
        maxFileCount: 1,
        separateBookmarkBudget: true,
      ),
    ).stage(path);
    try {
      final source = staged.manifest.sources.single;
      expect(
        bookmarkTransferParts(source)!.values.expand((parts) => parts),
        hasLength(3),
      );
    } finally {
      await staged.dispose();
    }
  });

  test('explicit archive limits apply across all Bookmark parts', () async {
    final directory = await Directory.systemTemp.createTemp('bookmark-limits-');
    addTearDown(() => directory.delete(recursive: true));
    final path = await _write(directory);
    for (final limits in [
      const ExportPackageLimits(maxFileCount: 2),
      const ExportPackageLimits(maxPartBytes: 1),
    ]) {
      await expectLater(
        ExportPackageReader(fs: _fs, limits: limits).stage(path),
        throwsA(isA<ExportPackageLimitException>()),
      );
    }
  });

  for (final (description, duplicate, members) in [
    ('duplicate group', true, ''),
    (
      'absent bookmark',
      false,
      '{"groupId":"$_group","bookmarkId":42,"addedAt":"2024-04-21T00:00:00Z"}\n',
    ),
    ('incomplete row', false, '{"groupId":"$_group"}'),
  ]) {
    test('rejects $description after ZIP integrity verification', () async {
      final directory = await Directory.systemTemp.createTemp(
        'bookmark-invalid-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = await _write(
        directory,
        duplicate: duplicate,
        members: members,
      );
      final staged = await const ExportPackageReader(fs: _fs).stage(path);
      try {
        final source = staged.manifest.sources.single;
        await expectLater(
          BookmarkTransferDatabase('${staged.directoryPath}/test.sqlite').stage(
            package: staged,
            parts: bookmarkTransferParts(source)!,
            codec: const StoredBookmarkCodec(),
            cancelled: () => false,
          ),
          throwsFormatException,
        );
      } finally {
        await staged.dispose();
      }
    });
  }

  test(
    'NDJSON framing carries multibyte characters across byte chunks',
    () async {
      final row = utf8.encode('{"name":"一"}\n');
      final split = row.indexOf(0xe4) + 1;
      final decoded = await readBookmarkTransferRows(
        Stream.fromIterable([row.sublist(0, split), row.sublist(split)]),
      ).single;
      expect(decoded, {'name': '一'});
    },
  );
}

Future<String> _write(
  Directory directory, {
  bool duplicate = false,
  String members = '',
}) {
  final group = jsonEncode(
    bookmarkTransferGroupRow(id: _group, name: 'Group', position: 0),
  );
  final rows = {
    BookmarkTransferTable.groups: '$group\n${duplicate ? '$group\n' : ''}',
    BookmarkTransferTable.bookmarks: '',
    BookmarkTransferTable.memberships: members,
  };
  return const ExportPackageWriter(fs: _fs).write(
    ExportPackageBuild(
      appVersion: '1.0.0',
      createdAt: DateTime.utc(2026),
      sources: [
        ExportPackageSourceBuild(
          id: 'bookmarks',
          schemaVersion: 7,
          parts: [
            for (final entry in rows.entries)
              ExportPackagePartBuild(
                path: bookmarkTransferPartPath(entry.key, 0),
                write: (path) => File(path).writeAsString(entry.value),
              ),
          ],
        ),
      ],
    ),
    '${directory.path}/transfer',
  );
}
