// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/bookmarks/types.dart';

void main() {
  const firstId = '550e8400-e29b-41d4-a716-446655440000';
  const secondId = '5f1d7f5e-3114-4dc7-a347-18f95852fc31';
  final bookmarks = [
    Bookmark.empty.copyWith(id: 1, originalUrl: 'https://example.com/1.jpg'),
    Bookmark.empty.copyWith(id: 2, originalUrl: 'https://example.com/2.jpg'),
    Bookmark.empty.copyWith(id: 3, originalUrl: 'https://example.com/3.jpg'),
  ];
  final groups = [
    BookmarkGroup(id: firstId, name: 'Same', bookmarkIds: const {1, 2}),
    BookmarkGroup(id: secondId, name: 'Same', bookmarkIds: const {2}),
  ];

  test('selected groups export the bookmark union once', () {
    final data = buildBookmarkBackupData(
      bookmarks: bookmarks,
      groups: groups,
      scope: BookmarkExportScope.selected(
        groupIds: const [firstId, secondId],
      ),
    );

    expect(data.bookmarks.map((bookmark) => bookmark.id), [1, 2]);
    expect(data.groups, hasLength(2));
  });

  test('No Group exports only bookmarks without named memberships', () {
    final data = buildBookmarkBackupData(
      bookmarks: bookmarks,
      groups: groups,
      scope: BookmarkExportScope.selected(
        groupIds: const [],
        includeUngrouped: true,
      ),
    );

    expect(data.bookmarks.map((bookmark) => bookmark.id), [3]);
    expect(data.groups, isEmpty);
  });
}
