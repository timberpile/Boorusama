import 'dart:convert';

import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_planned_change_projector.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('populated self-Replace projection workload', () {
    final date = DateTime.utc(2024);
    final records = [
      for (var id = 0; id < 5000; id++)
        PostBookmark(
          id: id,
          booruId: BooruType.danbooru.id,
          createdAt: date,
          updatedAt: date,
          thumbnailUrl: '',
          sampleUrl: '',
          originalUrl: '',
          sourceUrl: 'https://danbooru.donmai.us',
          width: 100,
          height: 100,
          md5: 'post-$id',
          tags: const {'benchmark'},
          realSourceUrl: null,
          format: 'jpg',
          imageUrlResolver: const DefaultImageUrlResolver(),
          postId: id + 1,
          metadata: const {},
        ),
    ];
    final group = BookmarkGroup(
      id: defaultBookmarkGroupId,
      name: 'Default',
      bookmarkIds: records.map((r) => r.id).toSet(),
      addedAt: {for (final r in records) r.id: date},
    );
    final data = BookmarkBackupData.unified(
      records: records,
      groups: [
        BookmarkGroupBackup(
          id: group.id,
          name: group.name,
          bookmarkIds: group.bookmarkIds.toList(),
          addedAt: group.addedAt,
        ),
      ],
    );
    final codec = BookmarkBackupCodec();
    final encoded = encodeData(
      version: 10,
      exportDate: date,
      exportVersion: null,
      payload: codec.encode(data),
      extraFields: data.extraFields,
    );
    final incoming = codec.parse(decodeData(data: encoded));
    for (final populated in [false, true]) {
      final watch = Stopwatch()..start();
      final summary = const ImportPlannedChangeProjector().bookmarks(
        local: BookmarkImportLocalSnapshot(
          records: populated ? records : const [],
          groups: populated ? [group] : const [],
        ),
        incoming: incoming,
        resolution: ResolvedImportSource(
          id: 'bookmarks',
          action: ImportAction.replace,
          items: const [],
        ),
      )!;
      watch.stop();
      print(
        jsonEncode({
          'incoming': records.length,
          'local': populated ? records.length : 0,
          'elapsedMicroseconds': watch.elapsedMicroseconds,
          'created': summary.created,
          'updated': summary.updated,
          'deleted': summary.deleted,
        }),
      );
      if (populated) {
        expect(summary.created, 0);
        expect(summary.updated, 0);
        expect(summary.deleted, 0);
      } else {
        expect(summary.created, greaterThan(0));
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
