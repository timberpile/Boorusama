import 'dart:math';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_shuffle_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/scalability/fixtures.dart';

void main() {
  final views = [
    const BookmarkView.all(),
    const BookmarkView.defaultGroup(),
    BookmarkView.group(scalabilityGroupId),
    BookmarkView.group('00000000-0000-4000-8000-000000000099'),
  ];
  for (final seed in [0, 17, 989]) {
    for (final size in [0, 1, 3, 4, 5, 257]) {
      for (final sort in BookmarkSortType.values.where(
        (sort) => sort != BookmarkSortType.random,
      )) {
        test(
          'covers match full selection for $sort, size $size, seed $seed',
          () {
            final random = Random(seed);
            final rows = List<Bookmark>.generate(size, (index) {
              final id = index + 1;
              return scalabilityBookmark(
                id,
                upstreamId: id % 13 + 1,
                site: 'https://site${id % 3}.test',
                savedAt: scalabilityEpoch.add(
                  Duration(seconds: random.nextInt(7)),
                ),
                uploadedAt: id % 4 == 0
                    ? null
                    : scalabilityEpoch.add(
                        Duration(seconds: random.nextInt(9)),
                      ),
              );
            })..shuffle(random);
            final before = List<Bookmark>.of(rows);
            final state = scalabilityLibrary(
              rows,
              members: rows.where((b) => b.id.isOdd).map((b) => b.id).toSet(),
            );
            final shuffle = BookmarkShuffleState(seed: seed);
            for (final view in views) {
              final expected = selectBookmarks(
                state: state,
                view: view,
                selectedTags: const [],
                sortType: sort,
                shuffleState: shuffle,
              ).take(4);
              final actual = selectBookmarkPreviews(
                state: state,
                view: view,
                sortType: sort,
                shuffleState: shuffle,
              );
              expect(actual.map((b) => b.id), expected.map((b) => b.id));
            }
            expect(rows, orderedEquals(before));
          },
        );
      }
    }
  }

  for (final invalidRows in [false, true]) {
    test(
      'retains full-selector behavior for ${invalidRows ? "unindexed" : "duplicate ID"} rows',
      () {
        final rows = [
          for (var id = 1; id <= 8; id++) scalabilityBookmark(id),
          scalabilityBookmark(
            invalidRows ? 9 : 1,
            upstreamId: 99,
            bookmarkable: !invalidRows,
          ),
        ];
        final state = scalabilityLibrary(rows);
        for (final sort in BookmarkSortType.values) {
          for (final view in views) {
            const shuffle = BookmarkShuffleState(seed: 42);
            final expected = selectBookmarks(
              state: state,
              view: view,
              selectedTags: const [],
              sortType: sort,
              shuffleState: shuffle,
            ).take(4);
            expect(
              selectBookmarkPreviews(
                state: state,
                view: view,
                sortType: sort,
                shuffleState: shuffle,
              ),
              orderedEquals(expected),
            );
          }
        }
      },
    );
  }

  test(
    'random All covers and ordinary group navigation keep full seeded ordering',
    () {
      final rows = [for (var id = 1; id <= 50; id++) scalabilityBookmark(id)];
      final members = {for (var id = 2; id <= 50; id += 2) id};
      final state = scalabilityLibrary(rows, members: members);
      for (final seed in [0, 17, 989]) {
        final shuffle = BookmarkShuffleState(seed: seed);
        final full = selectBookmarks(
          state: state,
          view: BookmarkView.group(scalabilityGroupId),
          selectedTags: const [],
          sortType: BookmarkSortType.random,
          shuffleState: shuffle,
        );
        final expected = filterBookmarks(
          bookmarks: rows.where((b) => members.contains(b.id)).toList(),
          selectedTags: const [],
          sortType: BookmarkSortType.random,
          shuffleState: shuffle,
        );
        expect(full, orderedEquals(expected));
        expect(
          selectBookmarkPreviews(
            state: state,
            view: const BookmarkView.all(),
            sortType: BookmarkSortType.random,
            shuffleState: shuffle,
          ),
          orderedEquals(
            selectBookmarks(
              state: state,
              view: const BookmarkView.all(),
              selectedTags: const [],
              sortType: BookmarkSortType.random,
              shuffleState: shuffle,
            ).take(4),
          ),
        );
      }
    },
  );

  test('random group covers are bounded, seed-stable and independent of unrelated rows or member order', () {
    final rows = [for (var id = 1; id <= 5000; id++) scalabilityBookmark(id)];
    final members = {3, 200, 4999, 7, 600, 43, 99999};
    final base = scalabilityLibrary(rows, members: members);
    final reordered = scalabilityLibrary(
      rows.reversed.toList(),
      members: members.toList().reversed.toSet(),
    );
    final extended = scalabilityLibrary([
      ...rows,
      scalabilityBookmark(6000),
    ], members: members);
    final view = BookmarkView.group(scalabilityGroupId);
    List<int> covers(BookmarkLibraryState state, int? seed) =>
        selectBookmarkPreviews(
          state: state,
          view: view,
          sortType: BookmarkSortType.random,
          shuffleState: BookmarkShuffleState(seed: seed),
        ).map((b) => b.id).toList();
    final orders = <String>{};
    for (final seed in [null, 0, 17, 989, 999999999999999]) {
      final selected = covers(base, seed);
      expect(selected, hasLength(4));
      expect(selected.toSet(), hasLength(4));
      expect(
        selected.every((id) => members.contains(id) && id != 99999),
        isTrue,
      );
      expect(covers(base, seed), selected);
      expect(covers(reordered, seed), selected);
      expect(covers(extended, seed), selected);
      orders.add(selected.join(','));
      // Covers must not alter the full list used by ordinary group navigation.
      final full = selectBookmarks(
        state: base,
        view: view,
        selectedTags: const [],
        sortType: BookmarkSortType.random,
        shuffleState: BookmarkShuffleState(seed: seed ?? 0),
      );
      expect(full.map((b) => b.id).toSet(), members.difference({99999}));
      expect(full, hasLength(6));
    }
    expect(orders.length, greaterThan(1));
  });

  test(
    'random tiny, missing and empty groups use only valid indexed members',
    () {
      final counter = BookmarkReadCounter();
      final state = scalabilityLibrary(
        [
          for (var id = 1; id <= 5000; id++)
            scalabilityBookmark(id, counter: counter),
        ],
        members: {3, 200, 4999, 99999},
      );
      counter.reset();
      final result = selectBookmarkPreviews(
        state: state,
        view: BookmarkView.group(scalabilityGroupId),
        sortType: BookmarkSortType.random,
        shuffleState: const BookmarkShuffleState(seed: 17),
      );
      expect(counter.ids, 3);
      expect(counter.dates, 0);
      expect(counter.posts, 0);
      expect(result.map((b) => b.id).toSet(), {3, 200, 4999});
      for (final group in [
        scalabilityGroupId,
        '00000000-0000-4000-8000-000000000099',
      ]) {
        expect(
          selectBookmarkPreviews(
            state: scalabilityLibrary([], members: {99999}),
            view: BookmarkView.group(group),
            sortType: BookmarkSortType.random,
          ),
          isEmpty,
        );
      }
    },
  );

  test('a tiny group does not inspect unrelated library rows', () {
    final counter = BookmarkReadCounter();
    final state = scalabilityLibrary(
      [
        for (var id = 1; id <= 5000; id++)
          scalabilityBookmark(id, counter: counter),
      ],
      members: {3, 200, 4999},
    );
    counter.reset();
    final result = selectBookmarkPreviews(
      state: state,
      view: BookmarkView.group(scalabilityGroupId),
      sortType: BookmarkSortType.newest,
    );
    expect(result.length, 3);
    expect(counter.ids, lessThanOrEqualTo(24));
    expect(counter.dates, lessThanOrEqualTo(24));
  });

  test('large all-bookmarks covers retain at most four candidates', () {
    final counter = BookmarkReadCounter();
    final state = scalabilityLibrary([
      for (var id = 1; id <= 1000; id++)
        scalabilityBookmark(id, counter: counter),
    ]);
    counter.reset();
    final result = selectBookmarkPreviews(
      state: state,
      view: const BookmarkView.all(),
      sortType: BookmarkSortType.newest,
    );
    expect(result.length, 4);
    // At most four comparisons per record, each reading two dates.
    expect(counter.dates, lessThanOrEqualTo(8000));
  });
}
