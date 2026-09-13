// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/backups/types.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/posts/post/types.dart';

void main() {
  const groupId = '550e8400-e29b-41d4-a716-446655440000';
  final bookmark = Bookmark.empty.copyWith(
    id: 12,
    originalUrl: 'https://example.com/12.jpg',
  );
  final codec = BookmarkBackupCodec(
    bookmarkParser: (json) => Bookmark.fromJson(
      json,
      imageUrlResolver: const DefaultImageUrlResolver(),
    ),
  );

  test('imports the legacy group shape without an ID', () {
    final payload = decodeData(
      data: jsonEncode({
        'version': 1,
        'data': [bookmark.toJson()],
        'groups': [
          {
            'name': 'Shared',
            'bookmarkIds': [12],
          },
        ],
      }),
    );

    final data = codec.parse(payload);

    expect(data.groups.single.id, isNull);
    expect(data.groups.single.name, 'Shared');
    expect(data.groups.single.bookmarkIds, [12]);
  });

  test('preserves and emits a canonical group ID', () {
    final payload = decodeData(
      data: jsonEncode({
        'version': 1,
        'data': [bookmark.toJson()],
        'groups': [
          {
            'id': groupId.toUpperCase(),
            'name': 'Shared',
            'bookmarkIds': [12, 12],
          },
        ],
      }),
    );

    final data = codec.parse(payload);

    expect(data.groups.single.id, groupId);
    expect(data.groups.single.bookmarkIds, [12]);
    expect(data.extraFields['groups'], [
      {
        'id': groupId,
        'name': 'Shared',
        'bookmarkIds': [12],
      },
    ]);
  });

  for (final groups in [
    [
      {'id': 'bad', 'name': 'Shared', 'bookmarkIds': <int>[]},
    ],
    [
      {'id': groupId, 'name': 'One', 'bookmarkIds': <int>[]},
      {'id': groupId, 'name': 'Two', 'bookmarkIds': <int>[]},
    ],
  ]) {
    test('rejects malformed or repeated supplied group IDs', () {
      final payload = decodeData(
        data: jsonEncode({'version': 1, 'data': [], 'groups': groups}),
      );
      expect(
        () => codec.parse(payload),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });
  }
}
