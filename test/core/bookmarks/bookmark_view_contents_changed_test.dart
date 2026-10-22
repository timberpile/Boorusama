import 'package:boorusama/core/bookmarks/src/data/bookmark_view_refresh_gate.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const otherId = '550e8400-e29b-41d4-a716-446655440000';
  late Bookmark first;
  late Bookmark second;
  late BookmarkLibraryState before;

  setUp(() {
    first = Bookmark.empty.copyWith(
      id: 1,
      sourceUrl: 'https://example.com',
      postId: () => 101,
    );
    second = Bookmark.empty.copyWith(
      id: 2,
      sourceUrl: 'https://example.com',
      postId: () => 102,
    );
    before = BookmarkLibraryState(
      bookmarks: [first, second],
      groups: [
        BookmarkGroup(
          id: defaultBookmarkGroupId,
          name: 'Default',
          bookmarkIds: {1},
        ),
        BookmarkGroup(id: otherId, name: 'Other', bookmarkIds: {2}),
      ],
      activeTarget: const BookmarkTarget.defaultGroup(),
    );
  });

  test('active target and group labels do not refresh post contents', () {
    final after = before.applyCommittedChanges(
      groups: [
        before.groups.first,
        before.groups.last.copyWith(name: 'Renamed'),
      ],
      folders: before.folders,
      activeTarget: BookmarkTarget.group(otherId),
    );
    for (final view in [
      const BookmarkView.all(),
      const BookmarkView.defaultGroup(),
      BookmarkView.group(otherId),
    ]) {
      expect(bookmarkViewContentsChanged(before, after, view), isFalse);
    }
  });

  test('an unrelated group membership does not refresh this group or All', () {
    final after = before.applyCommittedChanges(
      groups: [
        before.groups.first,
        before.groups.last.copyWith(bookmarkIds: {1, 2}),
      ],
      folders: before.folders,
      activeTarget: before.activeTarget,
    );
    expect(
      bookmarkViewContentsChanged(before, after, const BookmarkView.all()),
      isFalse,
    );
    expect(
      bookmarkViewContentsChanged(
        before,
        after,
        const BookmarkView.defaultGroup(),
      ),
      isFalse,
    );
    expect(
      bookmarkViewContentsChanged(before, after, BookmarkView.group(otherId)),
      isTrue,
    );
  });

  test(
    'snapshot changes refresh only views containing the changed bookmark',
    () {
      final after = before.applyCommittedChanges(
        upserts: [second.copyWith(updatedAt: DateTime.utc(2026))],
        groups: before.groups,
        folders: before.folders,
        activeTarget: before.activeTarget,
      );
      expect(
        bookmarkViewContentsChanged(before, after, const BookmarkView.all()),
        isTrue,
      );
      expect(
        bookmarkViewContentsChanged(
          before,
          after,
          const BookmarkView.defaultGroup(),
        ),
        isFalse,
      );
      expect(
        bookmarkViewContentsChanged(before, after, BookmarkView.group(otherId)),
        isTrue,
      );
    },
  );

  test('final deletion refreshes All and the source group', () {
    final after = before.applyCommittedChanges(
      removedIds: {1},
      groups: [
        before.groups.first.copyWith(bookmarkIds: {}),
        before.groups.last,
      ],
      folders: before.folders,
      activeTarget: before.activeTarget,
    );
    expect(
      bookmarkViewContentsChanged(before, after, const BookmarkView.all()),
      isTrue,
    );
    expect(
      bookmarkViewContentsChanged(
        before,
        after,
        const BookmarkView.defaultGroup(),
      ),
      isTrue,
    );
    expect(
      bookmarkViewContentsChanged(before, after, BookmarkView.group(otherId)),
      isFalse,
    );
  });

  test('missing states retain conservative refresh behavior', () {
    expect(
      bookmarkViewContentsChanged(null, before, const BookmarkView.all()),
      isTrue,
    );
    expect(
      bookmarkViewContentsChanged(before, null, const BookmarkView.all()),
      isTrue,
    );
  });
}
