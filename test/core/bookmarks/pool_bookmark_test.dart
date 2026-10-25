import 'dart:convert';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_series_projection.dart';
import 'package:boorusama/core/bookmarks/src/services/pool_summary_indexer.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_grid_entry.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes/test_post.dart';
import '../search/following_topics/topic_test_utils.dart';
import 'pool_bookmark_test_utils.dart';

void main() {
  test(
    'future source engine identity survives a stored reference round trip',
    () {
      final raw = testPool().toJson();
      raw['origin'] = {
        ...testPool().origin.toSnapshot().toJson(),
        'booruTypeId': 99999,
      };
      final parsed = PoolBookmark.fromJson(raw);
      expect(parsed.identity.$1, 99999);
      expect((parsed.toJson()['origin'] as Map)['booruTypeId'], 99999);
      expect(parsed.withGroups({poolGroupB}).identity, parsed.identity);
    },
  );

  test('controller visibility filters keep reference order and raw Post addressing', () {
    final a = BookmarkPostEntry(testPoolPost(1));
    final b = BookmarkPostEntry(testPoolPost(2));
    final pool = BookmarkPoolEntry(testPool());
    final visible = visibleBookmarkGridEntries([a, pool, b], [b.bookmark.post]);
    expect(visible.entries, [pool, b]);
    expect(visible.postIndices, {b.key: 0});
  });

  test(
    'collection metadata and different profile scopes cannot project a Series',
    () {
      final entries = [
        BookmarkPostEntry(testPoolPost(1)),
        BookmarkPostEntry(testPoolPost(2)),
      ];
      final collection = testPool(category: BookmarkedPoolCategory.collection);
      expect(
        projectBookmarkSeries(entries, {
          for (final e in entries)
            e.key: BookmarkSeriesMembership(
              scope: 'same',
              pools: {10: collection},
            ),
        }),
        hasLength(2),
      );
      expect(
        projectBookmarkSeries(entries, {
          entries[0].key: BookmarkSeriesMembership(
            scope: 'a',
            pools: {10: testPool()},
          ),
          entries[1].key: BookmarkSeriesMembership(
            scope: 'b',
            pools: {10: testPool()},
          ),
        }),
        hasLength(2),
      );
    },
  );

  BookmarkLibraryState library(
    List<PoolBookmark> pools, {
    List<Bookmark> posts = const [],
  }) => BookmarkLibraryState(
    bookmarks: posts,
    pools: pools,
    groups: [
      BookmarkGroup(
        id: poolGroupA,
        name: 'A',
        bookmarkIds: posts.map((p) => p.id).toSet(),
      ),
    ],
  );

  test(
    'typed reference round trips without member snapshots or credentials',
    () {
      final pool = testPool(
        newest: DateTime.utc(2025),
        oldest: DateTime.utc(2020),
      );
      final encoded =
          jsonDecode(jsonEncode(pool.toJson())) as Map<String, dynamic>;
      expect(PoolBookmark.fromJson(encoded), pool);
      expect(
        encoded.keys,
        isNot(
          contains(anyOf('posts', 'postIds', 'snapshots', 'apiKey', 'login')),
        ),
      );
      expect(testPool(host: 'other.example').identity, isNot(pool.identity));
      expect(
        () => PoolBookmark.fromJson({...encoded, 'kind': 'future-entry'}),
        throwsFormatException,
      );
    },
  );

  test(
    'small complete index uses one metadata request and true upload extrema',
    () async {
      final calls = <(String, int)>[];
      final result = await PoolSummaryIndexer(
        fetch: (query, limit) async {
          calls.add((query, limit));
          return [
            testSearchPost(1, DateTime.utc(2020)),
            testSearchPost(2, DateTime.utc(2025)),
          ];
        },
      ).index(poolId: 10, total: 2, supportsUploadOrder: true);
      expect(calls, [('pool:10', 40)]);
      expect(result.coverage, PoolTagCoverage.complete);
      expect(result.oldestUpload, DateTime.utc(2020));
      expect(result.newestUpload, DateTime.utc(2025));
    },
  );

  test('large index stops at the member and request budget', () async {
    final calls = <(String, int)>[];
    final result = await PoolSummaryIndexer(
      fetch: (query, limit) async {
        calls.add((query, limit));
        if (query.endsWith('created_at_asc'))
          return [testSearchPost(900, DateTime.utc(2000))];
        if (query.endsWith('created_at'))
          return [testSearchPost(100, DateTime.utc(2026))];
        return [
          for (var i = 1; i <= 50; i++) TestPost(id: i, tags: {'tag_$i'}),
        ];
      },
    ).index(poolId: 10, total: 10000, supportsUploadOrder: true);
    expect(calls.map((c) => c.$2), [40, 1, 1]);
    expect(result.members, hasLength(40));
    expect(result.tags, hasLength(40));
    expect(result.tags, isNot(contains('tag_41')));
    expect(result.coverage, PoolTagCoverage.partial);
    expect(result.oldestUpload, DateTime.utc(2000));
    expect(result.newestUpload, DateTime.utc(2026));
  });

  test(
    'inaccessible or interrupted members never prove completeness or dates',
    () async {
      final partial = await PoolSummaryIndexer(
        fetch: (_, _) async => [testSearchPost(1, DateTime.utc(2025))],
      ).index(poolId: 10, total: 2, supportsUploadOrder: false);
      expect(partial.coverage, PoolTagCoverage.partial);
      expect(partial.oldestUpload, isNull);
      expect(partial.newestUpload, isNull);
      final failed = await PoolSummaryIndexer(
        fetch: (_, _) async => throw StateError('offline'),
      ).index(poolId: 10, total: null, supportsUploadOrder: true);
      expect(failed.coverage, PoolTagCoverage.unknown);
      expect(failed.members, isEmpty);
      expect(failed.newestUpload, isNull);
    },
  );

  test('partial union filtering is strict for positive and negative tags', () {
    final state = library([
      testPool(),
      testPool(id: 11, tags: {}, coverage: PoolTagCoverage.unknown),
    ]);
    List<int> selected(List<String> tags) => selectPoolBookmarks(
      state: state,
      view: const BookmarkView.all(),
      selectedTags: tags,
    ).map((p) => p.poolId).toList();
    expect(selected([]), [10, 11]);
    expect(selected(['alpha', 'beta']), [10]);
    expect(selected(['missing']), isEmpty);
    expect(selected(['-alpha']), [11]);
    expect(selected(['alpha', '-missing']), [10]);
    expect(selected(['alpha', '-beta']), isEmpty);
  });

  test('mixed upload sorts use extrema, newest fallback, then unknown', () {
    final state = library([
      testPool(id: 10, newest: DateTime.utc(2025), oldest: DateTime.utc(2000)),
      testPool(id: 11, newest: DateTime.utc(2020)),
      testPool(id: 12),
    ]);
    List<int> order(BookmarkSortType sort) => selectBookmarkGridEntries(
      state: state,
      view: const BookmarkView.all(),
      selectedTags: [],
      sortType: sort,
    ).whereType<BookmarkPoolEntry>().map((e) => e.pool.poolId).toList();
    expect(order(BookmarkSortType.newestUpload), [10, 11, 12]);
    expect(order(BookmarkSortType.oldestUpload), [10, 11, 12]);
  });

  test(
    'projection keeps whole Series count and selection restores Post entries',
    () {
      final entries = [
        for (var i = 1; i <= 3; i++) BookmarkPostEntry(testPoolPost(i)),
        BookmarkPoolEntry(testPool()),
      ];
      final memberships = {
        for (final entry in entries.whereType<BookmarkPostEntry>())
          entry.key: BookmarkSeriesMembership(
            scope: 'profile-a',
            pools: {10: testPool()},
          ),
      };
      final projected = projectBookmarkSeries(entries, memberships);
      expect(projected, hasLength(2));
      expect(projected.first.series?.total, 20);
      expect(projected.first.endIndex, 3);
      expect(projected.last.entry, isA<BookmarkPoolEntry>());
      final selecting = projectBookmarkSeries(
        entries,
        memberships,
        enabled: false,
      );
      expect(selecting, hasLength(4));
      expect(selecting.map((e) => e.firstIndex), [0, 1, 2, 3]);
      expect(selecting.every((e) => e.series == null), isTrue);
    },
  );

  test(
    'deferred metadata freezes built entries and groups only unseen suffix',
    () {
      final entries = [
        for (var i = 1; i <= 4; i++) BookmarkPostEntry(testPoolPost(i)),
      ];
      final initial = projectBookmarkSeries(entries, {});
      final memberships = {
        for (final entry in entries)
          entry.key: BookmarkSeriesMembership(
            scope: 'profile-a',
            pools: {10: testPool()},
          ),
      };
      final updated = updateUnseenBookmarkSeries(
        entries: entries,
        displayed: initial,
        memberships: memberships,
        frozenUntil: 2,
      );
      expect(updated, hasLength(3));
      expect(identical(updated[0], initial[0]), isTrue);
      expect(identical(updated[1], initial[1]), isTrue);
      expect(updated.last.firstIndex, 2);
      expect(updated.last.endIndex, 4);
      expect(updated.last.series?.total, 20);
      expect(projectBookmarkSeries(entries, memberships), hasLength(1));
    },
  );
}
