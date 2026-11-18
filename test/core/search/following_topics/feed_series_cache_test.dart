import 'dart:async';

import 'package:boorusama/boorus/danbooru/posts/post/src/danbooru_post_codec.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_capability.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/src/refresh/chronological_search_scanner.dart';
import 'package:boorusama/core/search/following_topics/src/refresh/search_refresh_query_adapter.dart';
import 'package:boorusama/core/search/following_topics/src/services/search_refresh_service.dart';
import 'package:boorusama/core/search/following_topics/src/services/feed_series_enrichment.dart';
import 'package:boorusama/core/search/following_topics/src/types/feed_series_membership.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'feed_grouping_test_utils.dart';
import 'following_topic_test_utils.dart';
import 'topic_test_utils.dart';

void main() {
  final config = feedGroupingConfig;
  final source = topicFixture(id: 'source', profileId: config.id);
  StoredPostSnapshot snapshot(Post post) =>
      feedPostSnapshotFromPost(post, dataCodec: const DanbooruPostCodec());

  test('optional cache roundtrips, stays actor-scoped and is excluded from definitions', () {
    final post = feedGroupingPost(10);
    final membership = feedMembership(source, post, [9]);
    final feed = TopicFeed(
      id: 'f',
      profileId: config.id,
      name: 'Feed',
      sourceIds: [source.id],
      posts: [snapshot(post)],
      seriesMemberships: {membership.key: membership},
    );
    expect(TopicFeed.fromJson(feed.toJson()), feed);
    expect(
      feed
          .copyWith(
            posts: [
              snapshot(feedGroupingPost(10, config: otherGroupingConfig)),
            ],
          )
          .seriesMemberships,
      isEmpty,
    );
    expect(
      feed.toJson(includeCache: false).containsKey('seriesMemberships'),
      isFalse,
    );
    expect(
      membership.key,
      isNot(
        feedSeriesPostKey(
          feedGroupingPost(10, config: otherGroupingConfig).origin,
          10,
        ),
      ),
    );
    final old = {...feed.toJson()}..remove('seriesMemberships');
    expect(TopicFeed.fromJson(old).posts, feed.posts);
    expect(TopicFeed.fromJson(old).seriesMemberships, isEmpty);
    final malformed = {
      ...feed.toJson(),
      'seriesMemberships': {
        'bad': {'series': 'bad'},
        membership.key: membership.toJson(),
      },
    };
    expect(TopicFeed.fromJson(malformed), feed);
    expect(
      TopicFeed.fromJson({...feed.toJson(), 'seriesMemberships': 'bad'}).posts,
      feed.posts,
    );
  });

  test('cache merge distinguishes unknown, confirmed empty and known; trims with retention and sources', () {
    final posts = [feedGroupingPost(10), feedGroupingPost(11)];
    final known = feedMembership(source, posts.first, [9]);
    var feed = TopicFeed(
      id: 'f',
      profileId: config.id,
      name: 'Feed',
      sourceIds: [source.id],
      posts: posts.map(snapshot).toList(),
      seriesMemberships: {known.key: known},
    );
    expect(
      feed.seriesMemberships[feedSeriesPostKey(posts.last.origin, 11)],
      isNull,
    );
    expect(
      feed.merge([], seriesMemberships: {}).seriesMemberships[known.key],
      known,
    );
    expect(feed.reconcileSources([]).seriesMemberships, isEmpty);
    final empty = feedMembership(source, posts.first, []);
    feed = feed.merge([], seriesMemberships: {empty.key: empty});
    expect(feed.seriesMemberships[known.key]!.series, isEmpty);
    expect(feed.copyWith(maxPosts: 1).seriesMemberships, isEmpty);
    feed = feed.merge([snapshot(feedGroupingPost(12))]).copyWith(maxPosts: 1);
    expect(feed.seriesMemberships, isEmpty);
    expect(feed.reconcileSources([]).seriesMemberships, isEmpty);
  });

  test('bulk enrichment deduplicates Posts, isolates actors and preserves missing IDs as unknown', () async {
    final capability = FeedSeriesCapability()
      ..respond = (_) => {
        10: [feedPool(7)],
        11: [],
      };
    final result = await enrichFeedSeries(
      config: config,
      source: source,
      posts: [
        feedGroupingPost(10),
        feedGroupingPost(10),
        feedGroupingPost(11),
        feedGroupingPost(12),
        feedGroupingPost(99, config: otherGroupingConfig),
      ],
      capability: capability,
      isCurrent: () => true,
    );
    expect(capability.calls.single.$1, config.id);
    expect(capability.calls.single.$2, [10, 11, 12]);
    expect(
      result[feedSeriesPostKey(feedGroupingPost(10).origin, 10)]!
          .series
          .single
          .id,
      7,
    );
    expect(
      result[feedSeriesPostKey(feedGroupingPost(11).origin, 11)]!.series,
      isEmpty,
    );
    expect(
      result.containsKey(feedSeriesPostKey(feedGroupingPost(12).origin, 12)),
      isFalse,
    );
  });

  test(
    'failed batches keep successful batches and never create empty results',
    () async {
      final capability = FeedSeriesCapability()
        ..respond = (posts) {
          if (posts.first.id > 200) throw StateError('offline');
          return {for (final p in posts) p.id: []};
        };
      final result = await enrichFeedSeries(
        config: config,
        source: source,
        posts: [for (var i = 1; i <= 205; i++) feedGroupingPost(i)],
        capability: capability,
        isCurrent: () => true,
      );
      expect(capability.calls.map((call) => call.$2.length), [200, 5]);
      expect(result.length, 200);
    },
  );

  testWidgets('timeout and revoked ownership leave membership unknown', (
    tester,
  ) async {
    final pending = Completer<Map<int, List<RemoteBookmarkPool>>>();
    final capability = FeedSeriesCapability()..respond = (_) => pending.future;
    final timed = enrichFeedSeries(
      config: config,
      source: source,
      posts: [feedGroupingPost(10)],
      capability: capability,
      isCurrent: () => true,
    );
    await tester.pump(const Duration(seconds: 11));
    expect(await timed, isEmpty);
    var current = true;
    final stale = enrichFeedSeries(
      config: config,
      source: source,
      posts: [feedGroupingPost(10)],
      capability: capability,
      isCurrent: () => current,
    );
    current = false;
    pending.complete({
      10: [feedPool(9)],
    });
    expect(await stale, isEmpty);
  });

  testWidgets(
    'one deadline preserves completed batches and ignores late metadata',
    (tester) async {
      final pending = Completer<Map<int, List<RemoteBookmarkPool>>>();
      final capability = FeedSeriesCapability()
        ..respond = (posts) => posts.first.id <= 200
            ? {for (final post in posts) post.id: []}
            : pending.future;
      final loading = enrichFeedSeries(
        config: config,
        source: source,
        posts: [for (var i = 1; i <= 205; i++) feedGroupingPost(i)],
        capability: capability,
        isCurrent: () => true,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 11));
      final result = await loading;
      expect(result.length, 200);
      pending.complete({
        205: [feedPool(9)],
      });
      await tester.pump();
      expect(result.length, 200);
      expect(result.values.any((entry) => entry.postId == 205), isFalse);
    },
  );

  test('invalid individual Series records stay unknown', () async {
    final capability = FeedSeriesCapability()
      ..respond = (_) => {
        10: [
          const RemoteBookmarkPool(
            id: 0,
            title: 'bad',
            category: BookmarkedPoolCategory.series,
            total: null,
          ),
        ],
        11: [
          const RemoteBookmarkPool(
            id: 9,
            title: 'bad',
            category: BookmarkedPoolCategory.unknown,
            total: null,
          ),
        ],
      };
    expect(
      await enrichFeedSeries(
        config: config,
        source: source,
        posts: [feedGroupingPost(10), feedGroupingPost(11)],
        capability: capability,
        isCurrent: () => true,
      ),
      isEmpty,
    );
  });

  test('refresh backfills retained cache, preserves partial results and commits successful Posts', () async {
    final repository = memorySubscriptionRepository();
    var feed = await repository.saveFeed(
      profileId: config.id,
      name: 'Feed',
      queries: ['cat'],
    );
    var topic = (await repository.getById(feed.sourceIds.single))!;
    final old = feedGroupingPost(10);
    final known = feedMembership(topic, feedGroupingPost(20), [5]);
    await repository.commitRefresh(
      SearchRefreshCommit(
        topicId: topic.id,
        expectedCreatedAt: topic.createdAt,
        expectedCheckpoint: null,
        startedAt: checkedAt,
        identityRetentionBoundary: checkedAt,
        baseline: true,
        discoveredPosts: const [],
        feedPosts: [snapshot(old), snapshot(feedGroupingPost(20))],
        feedSeriesMemberships: {known.key: known},
      ),
    );
    topic = (await repository.getById(topic.id))!;
    final capability = FeedSeriesCapability()
      ..respond = (_) => {
        10: [feedPool(9)],
        30: [],
      };
    var incoming = 30;
    var now = checkedAt.add(const Duration(hours: 1));
    final service = SearchRefreshService(
      repository: repository,
      resolvePostRepository: (_) => TestSearchPostRepository(
        (_, _, _) async => Either.of(
          PostResult(
            posts: [
              feedGroupingPost(incoming),
              if (incoming == 30) feedGroupingPost(20),
            ],
            total: incoming == 30 ? 2 : 1,
            hasMore: false,
          ),
        ),
      ),
      resolveQueryAdapter: (_) => const DefaultSearchRefreshQueryAdapter(),
      resolvePostDataCodec: (_) => const DanbooruPostCodec(),
      resolveSeriesCapability: (_) => capability,
      scanner: ChronologicalSearchScanner(),
      clock: Clock(() => now),
    );
    expect(await service.refresh(topic, config), isA<SearchRefreshSucceeded>());
    feed = (await repository.getFeeds()).single;
    expect(capability.calls.single.$2.toSet(), {10, 20, 30});
    expect(feed.seriesMemberships.length, 3);
    expect(feed.seriesMemberships[known.key], known);
    topic = (await repository.getById(topic.id))!;
    incoming = 31;
    now = now.add(const Duration(hours: 1));
    capability.respond = (_) => throw StateError('metadata failed');
    expect(await service.refresh(topic, config), isA<SearchRefreshSucceeded>());
    feed = (await repository.getFeeds()).single;
    expect(feed.posts.map(feedPostId), contains(31));
    expect(feed.seriesMemberships.length, 3);
    await repository.invalidateFeedSeriesForProfile(config.id);
    final invalidated = (await repository.getFeeds()).single;
    expect(invalidated.seriesMemberships, isEmpty);
    expect(invalidated.posts, feed.posts);
  });

  test('cancelling refresh during enrichment prevents stale cache and Post publication', () async {
    final repository = memorySubscriptionRepository();
    final feed = await repository.saveFeed(
      profileId: config.id,
      name: 'Feed',
      queries: ['cat'],
    );
    final topic = (await repository.getById(feed.sourceIds.single))!;
    final entered = Completer<void>();
    final pending = Completer<Map<int, List<RemoteBookmarkPool>>>();
    final capability = FeedSeriesCapability()
      ..respond = (_) {
        entered.complete();
        return pending.future;
      };
    final token = CancelToken();
    final service = SearchRefreshService(
      repository: repository,
      resolvePostRepository: (_) => TestSearchPostRepository(
        (_, _, _) async => Either.of(
          PostResult(posts: [feedGroupingPost(30)], total: 1, hasMore: false),
        ),
      ),
      resolveQueryAdapter: (_) => const DefaultSearchRefreshQueryAdapter(),
      resolvePostDataCodec: (_) => const DanbooruPostCodec(),
      resolveSeriesCapability: (_) => capability,
      scanner: ChronologicalSearchScanner(),
      clock: Clock(() => checkedAt),
    );
    final refreshing = runWithApiRequestContext(
      ApiRequestContext(cancelToken: token),
      () => service.refresh(topic, config),
    );
    await entered.future;
    token.cancel();
    pending.complete({
      30: [feedPool(9)],
    });
    expect(await refreshing, isA<SearchRefreshDiscarded>());
    expect((await repository.getFeeds()).single.posts, isEmpty);
    expect((await repository.getFeeds()).single.seriesMemberships, isEmpty);
  });
}
