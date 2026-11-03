import 'package:boorusama/core/bookmarks/src/data/bookmark_view_refresh_gate.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_grid_entry.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/posts/related/related_family.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pool_bookmark_test_utils.dart';

void main() {
  final early = DateTime.utc(2020);
  final middle = DateTime.utc(2022);
  final late = DateTime.utc(2024);
  final newest = DateTime.utc(2025);
  final a = testPoolPost(1).copyWith(createdAt: newest);
  final b = testPoolPost(2).copyWith(createdAt: early);
  BookmarkGroup group(String id, Map<int, DateTime> dates) => BookmarkGroup(
    id: id,
    name: id,
    bookmarkIds: dates.keys.toSet(),
    addedAt: dates,
  );
  BookmarkLibraryState library({
    List<BookmarkGroup>? groups,
    List<CollectionBookmark> pools = const [],
  }) => BookmarkLibraryState(
    bookmarks: [a, b],
    groups:
        groups ??
        [
          group(poolGroupA, {a.id: middle, b.id: late}),
          group(poolGroupB, {a.id: early, b.id: newest}),
        ],
    pools: pools,
  );
  List<int> select(
    BookmarkLibraryState state,
    BookmarkSortType sort, {
    BookmarkView view = const BookmarkView.all(),
  }) => selectBookmarks(
    state: state,
    view: view,
    selectedTags: [],
    sortType: sort,
  ).map((b) => b.id).toList();

  test(
    'All Newest uses latest current membership and Oldest uses earliest',
    () {
      final state = library();
      expect(select(state, BookmarkSortType.newest), [b.id, a.id]);
      expect(select(state, BookmarkSortType.oldest), [a.id, b.id]);
      expect(
        select(
          state,
          BookmarkSortType.newest,
          view: BookmarkView.group(poolGroupA),
        ),
        [b.id, a.id],
      );
    },
  );

  test(
    'removal, Undo and re-add update All using only current memberships',
    () {
      final before = library(
        groups: [
          group(poolGroupA, {a.id: middle, b.id: late}),
          group(poolGroupB, {a.id: newest, b.id: early}),
        ],
      );
      final removed = before.applyCommittedChanges(
        groups: [
          before.groups.first,
          group(poolGroupB, {b.id: early}),
        ],
        folders: [],
      );
      expect(select(removed, BookmarkSortType.newest), [b.id, a.id]);
      final readded = removed.applyCommittedChanges(
        groups: [
          removed.groups.first,
          group(poolGroupB, {a.id: DateTime.utc(2026), b.id: early}),
        ],
        folders: [],
      );
      expect(select(readded, BookmarkSortType.newest), [a.id, b.id]);
      final undone = readded.applyCommittedChanges(
        groups: before.groups,
        folders: [],
      );
      expect(select(undone, BookmarkSortType.newest), [a.id, b.id]);
      final withoutEarliest = before.applyCommittedChanges(
        groups: [
          before.groups.first,
          group(poolGroupB, {a.id: newest}),
        ],
        folders: [],
      );
      expect(select(withoutEarliest, BookmarkSortType.oldest), [a.id, b.id]);
    },
  );

  test(
    'changing global metadata dates does not change dated membership order',
    () {
      final before = library();
      final changed = before.applyCommittedChanges(
        upserts: [
          a.copyWith(createdAt: early),
          b.copyWith(createdAt: newest),
        ],
        groups: before.groups,
        folders: [],
      );
      for (final sort in [BookmarkSortType.newest, BookmarkSortType.oldest]) {
        expect(select(changed, sort), select(before, sort));
      }
    },
  );

  test('All previews agree with full membership order in both directions', () {
    final state = library();
    for (final sort in [BookmarkSortType.newest, BookmarkSortType.oldest]) {
      expect(
        selectBookmarkPreviews(
          state: state,
          view: const BookmarkView.all(),
          sortType: sort,
        ).map((b) => b.id),
        select(state, sort),
      );
    }
  });

  test(
    'mixed Post Pool and Related rows use the same directional membership rule',
    () {
      final pool = testPool(groups: {poolGroupA, poolGroupB})
          .copyWith(addedAt: {poolGroupA: middle, poolGroupB: late});
      final related = RelatedBookmark(
        family: RelatedFamilyReference(origin: poolOrigin(), anchorId: 42),
        localId: poolProfile,
        createdAt: newest,
        observedAt: newest,
        groupIds: {poolGroupA, poolGroupB},
        addedAt: {poolGroupA: early, poolGroupB: newest},
      );
      final state = library(pools: [pool, related]);
      final rows = selectBookmarkGridEntries(
        state: state,
        view: const BookmarkView.all(),
        selectedTags: [],
        sortType: BookmarkSortType.oldest,
      );
      expect(
        rows.indexWhere(
          (e) => e is BookmarkPoolEntry && e.pool.identity == related.identity,
        ),
        lessThan(
          rows.indexWhere(
            (e) => e is BookmarkPoolEntry && e.pool.identity == pool.identity,
          ),
        ),
      );
      final changed = state.applyCommittedChanges(
        groups: state.groups,
        folders: [],
        pools: [
          pool,
          related.withGroups({poolGroupA}),
        ],
      );
      final newestRows = selectBookmarkGridEntries(
        state: changed,
        view: const BookmarkView.all(),
        selectedTags: [],
        sortType: BookmarkSortType.newest,
      );
      expect(newestRows.last.key, BookmarkPoolEntry(related).key);
    },
  );

  test('date-only membership changes refresh All while renaming does not', () {
    final before = library();
    final changed = before.applyCommittedChanges(
      groups: [
        group(poolGroupA, {a.id: newest, b.id: late}),
        before.groups.last,
      ],
      folders: [],
    );
    expect(
      bookmarkViewContentsChanged(before, changed, const BookmarkView.all()),
      isTrue,
    );
    final renamed = before.applyCommittedChanges(
      groups: [
        before.groups.first.copyWith(name: 'Renamed'),
        before.groups.last,
      ],
      folders: [],
    );
    expect(
      bookmarkViewContentsChanged(before, renamed, const BookmarkView.all()),
      isFalse,
    );
  });
  test('duplicating membership dates does not change All ordering', () {
    final before = library();
    final duplicate = before.applyCommittedChanges(
      groups: [
        ...before.groups,
        group(poolProfile, before.groups.first.addedAt),
      ],
      folders: [],
    );
    for (final sort in [BookmarkSortType.newest, BookmarkSortType.oldest]) {
      expect(select(duplicate, sort), select(before, sort));
    }
  });
}
