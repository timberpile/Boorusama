import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_cover.dart';
import 'package:boorusama/boorus/danbooru/posts/listing/src/grid_thumbnail_url.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/images/types.dart';

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
  test('cover variants survive persistence and follow listing quality without member snapshots', () {
    final cover = PoolBookmarkCover(
      thumbnail: 'https://a.example/low.jpg',
      sample: 'https://a.example/sample.jpg',
      original: 'https://a.example/original.png',
      variants: {
        '720x720': 'https://a.example/high.jpg',
        '360x360': 'https://a.example/medium.jpg',
      },
    );
    final saved = testPool().copyWith(cover: cover);
    final restored = PoolBookmark.fromJson(
      jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
    );
    expect(restored.cover, cover);
    expect(restored.withGroups({poolGroupB}).cover, cover);
    final post = restored.cover!.asPost(restored.origin);
    const resolver = DanbooruGridThumbnailUrlGenerator();
    String url(ImageQuality quality) => resolver
        .resolve(
          post,
          settings: GridThumbnailSettings(
            imageQuality: quality,
            animatedPostsDefaultState: AnimatedPostsDefaultState.static,
            gridSize: GridSize.normal,
          ),
        )
        .url;
    expect(url(ImageQuality.high), 'https://a.example/high.jpg');
    expect(url(ImageQuality.low), 'https://a.example/medium.jpg');
    expect(url(ImageQuality.original), 'https://a.example/original.png');
    final legacy = saved.toJson()..remove('cover');
    expect(PoolBookmark.fromJson(legacy).cover, isNull);
    expect(PoolBookmark.fromJson(legacy).groupIds, saved.groupIds);
    expect(restored.toJson().keys, isNot(contains('posts')));
  });

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
}
