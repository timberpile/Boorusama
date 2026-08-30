import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';

void main() {
  final bookmark = Bookmark.empty.copyWith(
    id: 12,
    originalUrl: 'https://example.com/image.jpg',
  );

  test('preserves optional top-level fields in a decoded backup payload', () {
    final json = jsonEncode(
      ExportDataPayload(
        version: 1,
        exportDate: DateTime(2026, 8, 21),
        exportVersion: null,
        data: [bookmark.toJson()],
        extraFields: {
          'groups': [
            {
              'name': 'Favorites',
              'bookmarkIds': [12],
            },
          ],
        },
      ).toJson(),
    );

    final decoded = decodeData(data: json);

    expect(decoded.data, [bookmark.toJson()]);
    expect(decoded.extraFields['groups'], [
      {
        'name': 'Favorites',
        'bookmarkIds': [12],
      },
    ]);
  });

  test('parses and encodes bookmark groups separately from bookmark data', () {
    final handler = BookmarkBackupHandler(
      parser: (json) => Bookmark.fromJson(
        json,
        imageUrlResolver: const DefaultImageUrlResolver(),
      ),
    );
    final group = BookmarkGroupBackup(
      name: 'Favorites',
      bookmarkIds: [bookmark.id],
    );

    final parsed = handler.parse(
      ExportDataPayload(
        version: 1,
        exportDate: null,
        exportVersion: null,
        data: [bookmark.toJson()],
        extraFields: {
          'groups': [group.toJson()],
        },
      ),
    );

    expect(parsed.bookmarks.single.uniqueId, bookmark.uniqueId);
    expect(parsed.groups, hasLength(1));
    expect(parsed.groups.single.name, group.name);
    expect(parsed.groups.single.bookmarkIds, group.bookmarkIds);
    expect(handler.encode(parsed), [bookmark.toJson()]);
    expect(parsed.extraFields, {
      'groups': [group.toJson()],
    });
  });

  test('reads a legacy bookmark-only payload without groups', () {
    final handler = BookmarkBackupHandler(
      parser: (json) => Bookmark.fromJson(
        json,
        imageUrlResolver: const DefaultImageUrlResolver(),
      ),
    );

    final parsed = handler.parse(
      ExportDataPayload.legacy(data: [bookmark.toJson()]),
    );

    expect(parsed.bookmarks.single.uniqueId, bookmark.uniqueId);
    expect(parsed.groups, isEmpty);
  });

  test('reports the failing bookmark index and parser error in debug mode', () {
    final invalidBookmark = {
      ...bookmark.toJson(),
      'width': 'not a number',
    };
    final handler = BookmarkBackupHandler(
      parser: (json) => Bookmark.fromJson(
        json,
        imageUrlResolver: const DefaultImageUrlResolver(),
      ),
    );

    expect(
      () => handler.parse(
        ExportDataPayload.legacy(data: [bookmark.toJson(), invalidBookmark]),
      ),
      throwsA(
        isA<InvalidBackupFormatException>().having(
          (error) => error.details,
          'details',
          allOf(
            contains('Bookmark at index 1'),
            contains('width'),
            contains('not a number'),
          ),
        ),
      ),
    );
  });
}
