import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Bookmark bookmark(int storageId, int postId) => Bookmark.empty.copyWith(
    id: storageId,
    sourceUrl: 'https://example.com',
    postId: () => postId,
  );

  BookmarkGroup group(String id, Set<int> members) => BookmarkGroup(
    id: id,
    name: id == defaultBookmarkGroupId ? 'Default' : 'Other',
    bookmarkIds: members,
  );

  BookmarkLibraryState library(
    List<Bookmark> rows,
    List<BookmarkGroup> groups,
  ) => BookmarkLibraryState(
    bookmarks: rows,
    groups: groups,
  );

  void expectIndexesMatch(
    BookmarkLibraryState actual,
    BookmarkLibraryState expected,
  ) {
    expect(actual, expected);
    expect(actual.bookmarks, expected.bookmarks);
    expect(actual.bookmarksById, expected.bookmarksById);
    expect(actual.bookmarksByUniqueId, expected.bookmarksByUniqueId);
    expect(actual.groupsById, expected.groupsById);
    expect(actual.membershipsByBookmark, expected.membershipsByBookmark);
  }

  test('a logical bookmark keeps memberships when its storage ID changes', () {
    final original = bookmark(1, 101);
    final restored = original.copyWith(id: 2);
    final before = library(
      [original],
      [
        group(defaultBookmarkGroupId, {1}),
      ],
    );
    final groups = [
      group(defaultBookmarkGroupId, {2}),
    ];
    final after = before.applyCommittedChanges(
      removedIds: {1},
      upserts: [restored],
      groups: groups,
      folders: const [],
    );
    expectIndexesMatch(after, library([restored], groups));
    expect(before.membershipsFor(original.uniqueId), {defaultBookmarkGroupId});
    expect(before.bookmarksById.keys, [1]);
    expect(after.bookmarksById.keys, [2]);
  });

  test('identity changes are independent of delta iteration order', () {
    final first = bookmark(1, 101);
    final second = bookmark(2, 102);
    final groups = [
      group(defaultBookmarkGroupId, {1}),
      group('other', {2}),
    ];
    final before = library([first, second], groups);
    final swapped = [second.copyWith(id: 1), first.copyWith(id: 2)];
    for (final updates in [swapped, swapped.reversed.toList()]) {
      final after = before.applyCommittedChanges(
        upserts: updates,
        groups: groups,
        folders: const [],
      );
      expectIndexesMatch(after, library(swapped, groups));
    }
    expect(before.membershipsFor(first.uniqueId), {defaultBookmarkGroupId});
    expect(before.membershipsFor(second.uniqueId), {'other'});
  });

  test('membership-only changes reuse post indexes and unaffected sets', () {
    final first = bookmark(1, 101);
    final second = bookmark(2, 102);
    final before = library(
      [first, second],
      [
        group(defaultBookmarkGroupId, {1, 2}),
      ],
    );
    final groups = [
      group(defaultBookmarkGroupId, {1, 2}),
      group('other', {1}),
    ];
    final after = before.applyCommittedChanges(
      groups: groups,
      folders: const [],
    );
    expectIndexesMatch(after, library([first, second], groups));
    expect(identical(before.items, after.items), isTrue);
    expect(identical(before.bookmarksById, after.bookmarksById), isTrue);
    expect(
      identical(before.bookmarksByUniqueId, after.bookmarksByUniqueId),
      isTrue,
    );
    expect(identical(before.bookmarks, after.bookmarks), isTrue);
    expect(
      identical(
        before.membershipsFor(second.uniqueId),
        after.membershipsFor(second.uniqueId),
      ),
      isTrue,
    );
    expect(
      () => after.membershipsFor(first.uniqueId).clear(),
      throwsUnsupportedError,
    );
    expect(() => after.membershipsByBookmark.clear(), throwsUnsupportedError);
    expect(before.membershipsFor(first.uniqueId), {defaultBookmarkGroupId});
  });

  test('delete, add and snapshot replacement match a cold reconstruction', () {
    final first = bookmark(1, 101);
    final second = bookmark(2, 102);
    final third = bookmark(3, 103);
    final updated = second.copyWith(updatedAt: DateTime.utc(2026));
    final before = library(
      [first, second],
      [
        group(defaultBookmarkGroupId, {1, 2}),
      ],
    );
    final groups = [
      group(defaultBookmarkGroupId, {2, 3}),
    ];
    final after = before.applyCommittedChanges(
      removedIds: {1},
      upserts: [updated, third],
      groups: groups,
      folders: const [],
    );
    expectIndexesMatch(after, library([updated, third], groups));
    expect(before.items, [first, second]);
    expect(before.groups.single.bookmarkIds, {1, 2});
  });

  test('a no-op preserves the complete state identity', () {
    final row = bookmark(1, 101);
    final before = library(
      [row],
      [
        group(defaultBookmarkGroupId, {1}),
      ],
    );
    expect(
      identical(
        before,
        before.applyCommittedChanges(
          groups: [
            group(defaultBookmarkGroupId, {1}),
          ],
          folders: const [],
        ),
      ),
      isTrue,
    );
  });

  test(
    'snapshot-only updates retain the identity set and membership indexes',
    () {
      final row = bookmark(1, 101);
      final before = library(
        [row],
        [
          group(defaultBookmarkGroupId, {1}),
        ],
      );
      final updated = row.copyWith(updatedAt: DateTime.utc(2026));
      final after = before.applyCommittedChanges(
        upserts: [updated],
        groups: before.groups,
        folders: before.folders,
      );
      expectIndexesMatch(after, library([updated], before.groups));
      expect(identical(before.bookmarks, after.bookmarks), isTrue);
      expect(
        identical(before.membershipsByBookmark, after.membershipsByBookmark),
        isTrue,
      );
    },
  );
}
