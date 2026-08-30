import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';

void main() {
  final bookmarks = [
    _bookmark(1),
    _bookmark(2),
    _bookmark(3),
    _bookmark(4),
  ];
  final groups = [
    const BookmarkGroup(id: 10, name: 'Favorites'),
    const BookmarkGroup(id: 20, name: 'Other'),
    const BookmarkGroup(id: 30, name: 'Empty'),
  ];
  final memberships = <int, Set<int>>{
    1: {10, 20},
    2: {10},
    3: {},
    4: {20},
  };

  test('exports every bookmark and group for the all scope', () {
    final result = buildBookmarkBackupData(
      bookmarks: bookmarks,
      groups: groups,
      membershipsByBookmark: memberships,
      scope: const BookmarkExportScope.all(),
    );

    expect(result.bookmarks.map((bookmark) => bookmark.id), [1, 2, 3, 4]);
    expect(
      result.groups.map((group) => group.toJson()).toList(),
      [
        {
          'name': 'Favorites',
          'bookmarkIds': [1, 2],
        },
        {
          'name': 'Other',
          'bookmarkIds': [1, 4],
        },
        {'name': 'Empty', 'bookmarkIds': <int>[]},
      ],
    );
  });

  test('exports the union of selected groups and ungrouped bookmarks', () {
    final result = buildBookmarkBackupData(
      bookmarks: bookmarks,
      groups: groups,
      membershipsByBookmark: memberships,
      scope: BookmarkExportScope.selected(
        groupIds: {10},
        includeUngrouped: true,
      ),
    );

    expect(result.bookmarks.map((bookmark) => bookmark.id), [1, 2, 3]);
    expect(
      result.groups.map((group) => group.toJson()).toList(),
      [
        {
          'name': 'Favorites',
          'bookmarkIds': [1, 2],
        },
      ],
    );
  });

  test(
    'preserves selected empty groups without exporting unselected groups',
    () {
      final result = buildBookmarkBackupData(
        bookmarks: bookmarks,
        groups: groups,
        membershipsByBookmark: memberships,
        scope: BookmarkExportScope.selected(groupIds: {30}),
      );

      expect(result.bookmarks, isEmpty);
      expect(
        result.groups.map((group) => group.toJson()).toList(),
        [
          {'name': 'Empty', 'bookmarkIds': <int>[]},
        ],
      );
    },
  );

  test('keeps group references compatible with the existing JSON shape', () {
    final result = buildBookmarkBackupData(
      bookmarks: bookmarks,
      groups: groups,
      membershipsByBookmark: memberships,
      scope: BookmarkExportScope.selected(groupIds: {10}),
    );

    expect(
      result.extraFields,
      {
        'groups': [
          {
            'name': 'Favorites',
            'bookmarkIds': [1, 2],
          },
        ],
      },
    );
  });

  test('reports the number of bookmarks in the selected export payload', () {
    final result = buildBookmarkBackupData(
      bookmarks: bookmarks,
      groups: groups,
      membershipsByBookmark: memberships,
      scope: BookmarkExportScope.selected(groupIds: {10}),
    );

    final operationResult = buildBookmarkExportResult(result);

    expect(operationResult, isA<BackupOperationResult>());
    expect(operationResult.totalCount, 2);
    expect(operationResult.alreadyExistedCount, 0);
  });
}

Bookmark _bookmark(int id) => Bookmark.empty.copyWith(
  id: id,
  originalUrl: 'https://example.com/$id.jpg',
);
