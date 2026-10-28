import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/scalability/fixtures.dart';

BookmarkLibraryState apply(
  BookmarkLibraryState state, {
  List<Bookmark> upserts = const [],
  Set<int> removed = const {},
}) => state.applyCommittedChanges(
  upserts: upserts,
  removedIds: removed,
  groups: state.groups,
  folders: state.folders,
);

void main() {
  for (final additionPath in [false, true]) {
    test(
      'published lookup maps remain immutable and isolated through ${additionPath ? "addition" : "delta"}',
      () {
        final first = scalabilityBookmark(1);
        final second = scalabilityBookmark(2);
        final base = scalabilityLibrary([first]);
        final input = <Bookmark>[second];
        final updated = additionPath
            ? base.withAddedGroupMembers(
                createdBookmarks: input,
                group: base.groupsById[scalabilityGroupId]!.copyWith(
                  bookmarkIds: {1, 2},
                ),
              )
            : apply(base, upserts: input);
        input.clear();
        expect(base.bookmarksById.keys, [1]);
        expect(updated.bookmarksById.keys, containsAll([1, 2]));
        expect(updated.bookmarksByUniqueId[second.uniqueId], same(second));
        expect(() => updated.bookmarksById.clear(), throwsUnsupportedError);
        expect(
          () => updated.bookmarksByUniqueId[first.uniqueId] = second,
          throwsUnsupportedError,
        );
        final later = apply(updated, removed: {2});
        expect(later.bookmarksById.containsKey(2), isFalse);
        expect(updated.bookmarksById[2], same(second));
        expect(updated.bookmarksByUniqueId[second.uniqueId], same(second));
      },
    );
  }

  test('replacing a row cannot mutate a prior published snapshot', () {
    final original = scalabilityBookmark(1);
    final base = scalabilityLibrary([original, scalabilityBookmark(2)]);
    final changed = scalabilityBookmark(1, savedAt: scalabilityEpoch);
    final next = apply(base, upserts: [changed]);
    expect(base.bookmarksById[1], same(original));
    expect(next.bookmarksById[1], same(changed));
    expect(next.bookmarksByUniqueId[changed.uniqueId], same(changed));
    expect(next.items.first, same(changed));
    expect(base.items.first, same(original));
  });

  test(
    'identity exchange and Undo under a new local ID leave no stale lookup',
    () {
      final first = scalabilityBookmark(1, upstreamId: 10);
      final second = scalabilityBookmark(2, upstreamId: 20);
      final base = scalabilityLibrary([first, second]);
      final exchanged = apply(
        base,
        upserts: [
          scalabilityBookmark(1, upstreamId: 20),
          scalabilityBookmark(2, upstreamId: 10),
        ],
      );
      expect(exchanged.bookmarksByUniqueId[first.uniqueId]!.id, 2);
      expect(exchanged.bookmarksByUniqueId[second.uniqueId]!.id, 1);
      final restored = apply(
        exchanged,
        removed: {2},
        upserts: [scalabilityBookmark(3, upstreamId: 10)],
      );
      expect(restored.bookmarksById.containsKey(2), isFalse);
      expect(restored.bookmarksByUniqueId[first.uniqueId]!.id, 3);
      expect(exchanged.bookmarksByUniqueId[first.uniqueId]!.id, 2);
      expect(base.bookmarksByUniqueId[first.uniqueId]!.id, 1);
    },
  );

  test('no-op and group-only publication reuse unchanged row indexes', () {
    final base = scalabilityLibrary([scalabilityBookmark(1)]);
    expect(apply(base), same(base));
    final groups = [
      for (final group in base.groups)
        group.id == scalabilityGroupId
            ? group.copyWith(name: 'Renamed')
            : group,
    ];
    final next = base.applyCommittedChanges(
      groups: groups,
      folders: base.folders,
    );
    expect(next.bookmarksById, same(base.bookmarksById));
    expect(next.bookmarksByUniqueId, same(base.bookmarksByUniqueId));
    expect(next.items, same(base.items));
  });
}
