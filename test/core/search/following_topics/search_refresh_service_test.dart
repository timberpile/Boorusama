import 'dart:async';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:dio/dio.dart';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/src/refresh/chronological_search_scanner.dart';
import 'package:boorusama/core/search/following_topics/src/refresh/search_refresh_query_adapter.dart';
import 'package:boorusama/core/search/following_topics/src/services/search_refresh_service.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'topic_test_utils.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_hive_object.dart';

void main() {
  final checkpoint = DateTime.utc(2026, 9, 14, 8);
  final startedAt = DateTime.utc(2026, 9, 14, 9);
  late FollowingTopicRepository repository;
  late FollowingTopic topic;
  late TestSearchPostRepository posts;
  late SearchRefreshQueryAdapter adapter;
  var now = startedAt;

  SearchRefreshService service() => SearchRefreshService(
    repository: repository,
    resolvePostRepository: (_) => posts,
    resolveQueryAdapter: (_) => adapter,
    scanner: ChronologicalSearchScanner(),
    clock: Clock(() => now),
  );

  Future<void> seedCheckpoint() async {
    topic = (await repository.commitRefresh(
      SearchRefreshCommit(
        topicId: topic.id,
        expectedCreatedAt: topic.createdAt,
        expectedCheckpoint: null,
        startedAt: checkpoint,
        identityRetentionBoundary: checkpoint.subtract(
          const Duration(minutes: 5),
        ),
        baseline: true,
        discoveredPosts: const [],
      ),
    ))!;
  }

  setUp(() async {
    repository = memorySubscriptionRepository();
    topic = await repository.create(
      profileId: BooruConfig.empty.id,
      query: 'cat',
      name: null,
      id: 'cat',
    );
    adapter = const DefaultSearchRefreshQueryAdapter();
    now = startedAt;
    posts = TestSearchPostRepository(
      (query, page, limit) async => Either.of(
        PostResult(
          posts: [
            testSearchPost(2, checkpoint.add(const Duration(minutes: 2))),
            testSearchPost(1, checkpoint.add(const Duration(minutes: 1))),
          ],
          total: 2,
        ),
      ),
    );
  });

  test(
    'cooldown exposes retryAt without writing an attempt or checkpoint',
    () async {
      final retryAt = startedAt.add(const Duration(minutes: 2));
      posts = TestSearchPostRepository(
        (_, _, _) async => Either.left(RateLimitedError(retryAt)),
      );
      final result = await service().refresh(topic, BooruConfig.empty);
      expect(
        result,
        isA<SearchRefreshDeferred>().having(
          (r) => r.retryAt,
          'retryAt',
          retryAt,
        ),
      );
      final saved = (await repository.getById(topic.id))!;
      expect(saved.lastAttemptAt, isNull);
      expect(saved.lastSuccessfulCheckAt, isNull);
      expect(saved.lastErrorKind, isNull);
    },
  );

  test(
    'cancelled source refresh cannot commit after a fetch completes',
    () async {
      final fetched = Completer<void>();
      final release = Completer<void>();
      posts = TestSearchPostRepository((_, _, _) async {
        fetched.complete();
        await release.future;
        return Either.of(
          PostResult(posts: [testSearchPost(3, startedAt)], total: 1),
        );
      });
      final token = CancelToken();
      final operation = runWithApiRequestContext(
        ApiRequestContext(cancelToken: token),
        () => service().refresh(topic, BooruConfig.empty),
      );
      await fetched.future;
      token.cancel();
      release.complete();
      expect(await operation, const SearchRefreshDiscarded());
      final saved = (await repository.getById(topic.id))!;
      expect(saved.lastAttemptAt, isNull);
      expect(saved.lastSuccessfulCheckAt, isNull);
      expect(saved.previews, isEmpty);
      expect(saved.hasNewPosts, false);
    },
  );

  for (final failure in [false, true]) {
    test(
      'cancellation while ${failure ? 'failure' : 'success'} commit waits for serialization preserves runtime state',
      () async {
        final box = _QueuedWriteBox();
        repository = HiveFollowingTopicRepository(
          box: box,
          organizationBox: MemoryBox<dynamic>(),
        );
        topic = await repository.create(
          profileId: BooruConfig.empty.id,
          query: 'cat',
          name: null,
          id: 'cat',
        );
        box.block = true;
        final renaming = repository.rename('cat', 'Renamed');
        await box.entered.future;
        final fetched = Completer<void>();
        posts = TestSearchPostRepository((_, _, _) async {
          fetched.complete();
          return failure
              ? Either.left(
                  AppError(
                    type: AppErrorType.cannotReachServer,
                    message: 'offline',
                  ),
                )
              : Either.of(
                  PostResult(posts: [testSearchPost(3, startedAt)], total: 1),
                );
        });
        final token = CancelToken();
        final operation = runWithApiRequestContext(
          ApiRequestContext(cancelToken: token),
          () => service().refresh(topic, BooruConfig.empty),
        );
        await fetched.future;
        await Future<void>.delayed(Duration.zero);
        token.cancel();
        box.release.complete();
        await renaming;
        expect(await operation, const SearchRefreshDiscarded());
        final saved = (await repository.getById('cat'))!;
        expect(saved.name, 'Renamed');
        expect(saved.lastAttemptAt, isNull);
        expect(saved.lastSuccessfulCheckAt, isNull);
        expect(saved.lastErrorKind, isNull);
        expect(saved.previews, isEmpty);
        expect(saved.hasNewPosts, false);
      },
    );
  }

  test(
    'two-tag Donmai topics refresh without exceeding the basic term limit',
    () async {
      final config = BooruConfig.empty.copyWith(
        booruIdHint: BooruType.danbooru.id,
        url: 'https://danbooru.donmai.us',
      );
      topic = await repository.edit(
        topic.id,
        profileId: config.id,
        query: 'zenless_zone_zero 1girl',
        name: null,
      );
      adapter = const OrderedSearchRefreshQueryAdapter(orderingToken: null);
      var newestId = 2;
      posts = TestSearchPostRepository((query, page, limit) async {
        // Donmai exempts id/rating, but counts order against the two-term limit.
        final countedTerms = query
            .split(RegExp(r'\s+'))
            .where(
              (term) => !term.startsWith('id:') && !term.startsWith('rating:'),
            );
        expect(countedTerms.length, lessThanOrEqualTo(2));
        expect(query, 'zenless_zone_zero 1girl');
        return Either.right(
          PostResult(
            posts: [testSearchPost(newestId, startedAt)],
            total: 1,
          ),
        );
      });
      expect(
        await service().refresh(topic, config),
        isA<SearchRefreshSucceeded>(),
      );
      topic = (await repository.getById(topic.id))!;
      expect(topic.hasNewPosts, isFalse);
      newestId = 3;
      expect(
        await service().refresh(topic, config),
        isA<SearchRefreshSucceeded>(),
      );
      topic = (await repository.getById(topic.id))!;
      expect(topic.highestSeenPostId, 3);
      expect(topic.newPostCountEstimate, 1);
    },
  );

  test(
    'truncated ascending deltas resume across restart without skipping IDs',
    () async {
      final config = BooruConfig.empty.copyWith(
        booruIdHint: BooruType.danbooru.id,
        url: 'https://danbooru.donmai.us',
      );
      await service().refresh(topic, config); // baseline ID 2
      topic = (await repository.getById('cat'))!;
      final seen = <int>[];
      posts = TestSearchPostRepository((query, page, limit) async {
        expect(page, 1);
        expect(query, contains('order:id_asc'));
        final cursor = int.parse(
          RegExp(r'id:>(\d+)').firstMatch(query)!.group(1)!,
        );
        final chunk = [
          for (var id = cursor + 1; id <= 1502 && id <= cursor + limit!; id++)
            testSearchPost(id, startedAt),
        ];
        seen.addAll(chunk.map((post) => post.id));
        return Either.right(PostResult(posts: chunk, total: null));
      });
      await service().refresh(topic, config);
      topic = (await repository.getById('cat'))!;
      expect(topic.highestSeenPostId, 1002);
      expect(topic.newPostCountEstimate, 1000);
      expect(topic.newPostCountIsLowerBound, isTrue);
      // A fresh service consumes the durable checkpoint and fetches the remainder.
      await service().refresh(topic, config);
      topic = (await repository.getById('cat'))!;
      expect(topic.highestSeenPostId, 1502);
      expect(topic.newPostCountEstimate, 1500);
      expect(seen, [for (var id = 3; id <= 1502; id++) id]);
      await service().refresh(topic, config);
      expect((await repository.getById('cat'))!.newPostCountEstimate, 1500);
    },
  );

  test(
    'an endpoint ignoring ascending delta order cannot advance a checkpoint',
    () async {
      final config = BooruConfig.empty.copyWith(
        booruIdHint: BooruType.danbooru.id,
        url: 'https://danbooru.donmai.us',
      );
      await service().refresh(topic, config);
      topic = (await repository.getById('cat'))!;
      posts = TestSearchPostRepository(
        (_, _, _) async => Either.right(
          PostResult(
            posts: [testSearchPost(5, startedAt), testSearchPost(4, startedAt)],
            total: null,
          ),
        ),
      );
      expect(
        await service().refresh(topic, config),
        const SearchRefreshFailed(SearchRefreshErrorKind.unsupported),
      );
      expect((await repository.getById('cat'))!.highestSeenPostId, 2);
    },
  );

  test(
    'initializing a new feed cannot jump over a pending delta backlog',
    () async {
      final config = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': '00000000-0000-4000-8000-000000000001',
        'booruIdHint': BooruType.danbooru.id,
        'url': 'https://danbooru.donmai.us',
      });
      topic = await repository.edit(
        'cat',
        profileId: config.id,
        query: 'cat',
        name: null,
      );
      await service().refresh(topic, config);
      topic = (await repository.getById('cat'))!;
      await repository.restoreFeeds(config.id, [
        TopicFeed(
          id: 'new-feed',
          profileId: config.id,
          name: 'New feed',
          sourceIds: ['cat'],
        ),
      ]);
      posts = TestSearchPostRepository((query, page, limit) async {
        final cursorMatch = RegExp(r'id:>(\d+)').firstMatch(query);
        final chunk = cursorMatch == null
            ? [
                for (
                  var id = 1502 - (page - 1) * limit!;
                  id > 2 && id > 1502 - page * limit;
                  id--
                )
                  testSearchPost(id, startedAt),
              ]
            : [
                for (
                  var id = int.parse(cursorMatch.group(1)!) + 1;
                  id <= 1502 && id <= int.parse(cursorMatch.group(1)!) + limit!;
                  id++
                )
                  testSearchPost(id, startedAt),
              ];
        return Either.right(PostResult(posts: chunk, total: null));
      });
      await service().refresh(topic, config, requireFullSnapshot: true);
      topic = (await repository.getById('cat'))!;
      expect(topic.highestSeenPostId, 1002);
      final cache = (await repository.getFeeds()).single;
      expect(cache.posts, hasLength(1000));
      expect(feedPostId(cache.posts.first), 1502);
      expect(cache.initializedSourceIds, ['cat']);
      await service().refresh(topic, config);
      expect((await repository.getById('cat'))!.highestSeenPostId, 1502);
      expect((await repository.getById('cat'))!.newPostCountEstimate, 1500);
    },
  );

  test(
    'failure on a later delta page leaves the durable checkpoint untouched',
    () async {
      final config = BooruConfig.empty.copyWith(
        booruIdHint: BooruType.danbooru.id,
        url: 'https://danbooru.donmai.us',
      );
      await service().refresh(topic, config);
      topic = (await repository.getById('cat'))!;
      var calls = 0;
      posts = TestSearchPostRepository((_, _, limit) async {
        calls++;
        return calls == 1
            ? Either.right(
                PostResult(
                  total: null,
                  posts: [
                    for (var id = 3; id < 3 + limit!; id++)
                      testSearchPost(id, startedAt),
                  ],
                ),
              )
            : Either.left(
                ServerError(httpStatusCode: 500, message: 'unavailable'),
              );
      });
      expect(
        await service().refresh(topic, config),
        const SearchRefreshFailed(SearchRefreshErrorKind.network),
      );
      expect(calls, 2);
      expect((await repository.getById('cat'))!.highestSeenPostId, 2);
      expect((await repository.getById('cat'))!.newPostCountEstimate, isNull);
    },
  );

  test('first successful refresh establishes a read baseline', () async {
    final result = await service().refresh(topic, BooruConfig.empty);
    expect(result, isA<SearchRefreshSucceeded>());
    final saved = (await repository.getById('cat'))!;
    expect(saved.unreadCount, 0);
    expect(saved.lastSuccessfulCheckAt, startedAt);
    expect(saved.previews.map((post) => post.postId), [2, 1]);
    expect(
      saved.previews.first.thumbnailUrl,
      'https://example.com/2-thumb.jpg',
    );
  });

  test('later refresh sets NEW and keeps newest matching previews', () async {
    await seedCheckpoint();
    posts = TestSearchPostRepository(
      (_, _, _) async => Either.of(
        PostResult(
          posts: [
            testSearchPost(2, checkpoint.add(const Duration(minutes: 2))),
            testSearchPost(1, checkpoint.add(const Duration(minutes: 1))),
            testSearchPost(0, checkpoint),
          ],
          total: 3,
        ),
      ),
    );
    final result = await service().refresh(topic, BooruConfig.empty);
    expect((result as SearchRefreshSucceeded).detectedNewPosts, isTrue);
    expect(result.baseline, isFalse);
    expect((await repository.getById('cat'))?.unreadCount, 1);
  });

  test('a higher post ID sets NEW even with an older upload time', () async {
    posts = TestSearchPostRepository(
      (_, _, _) async => Either.right(
        [testSearchPost(100, checkpoint)].toResult(),
      ),
    );
    now = checkpoint;
    await service().refresh(topic, BooruConfig.empty);
    topic = (await repository.getById('cat'))!;
    posts = TestSearchPostRepository(
      (_, _, _) async => Either.right(
        [
          testSearchPost(101, checkpoint.subtract(const Duration(days: 1))),
          testSearchPost(100, checkpoint),
        ].toResult(),
      ),
    );
    now = startedAt;

    final result = await service().refresh(topic, BooruConfig.empty);

    expect((result as SearchRefreshSucceeded).detectedNewPosts, isTrue);
    expect((await repository.getById('cat'))?.hasNewPosts, isTrue);
  });

  test('a lower post ID does not set NEW with a newer upload time', () async {
    posts = TestSearchPostRepository(
      (_, _, _) async => Either.right(
        [testSearchPost(100, checkpoint)].toResult(),
      ),
    );
    now = checkpoint;
    await service().refresh(topic, BooruConfig.empty);
    topic = (await repository.getById('cat'))!;
    posts = TestSearchPostRepository(
      (_, _, _) async => Either.right(
        [
          testSearchPost(100, checkpoint),
          testSearchPost(99, startedAt.add(const Duration(days: 1))),
        ].toResult(),
      ),
    );
    now = startedAt;

    final result = await service().refresh(topic, BooruConfig.empty);

    expect((result as SearchRefreshSucceeded).detectedNewPosts, isFalse);
    expect((await repository.getById('cat'))?.hasNewPosts, isFalse);
  });

  test('captures the UTC start before query planning and fetch', () async {
    await seedCheckpoint();
    adapter = _TestAdapter((query, after) {
      expect(query, 'cat');
      expect(after, isNull);
      now = startedAt.add(const Duration(hours: 1));
      return const SupportedSearchRefreshQueryPlan(query: 'cat date:planned');
    });
    posts = TestSearchPostRepository((query, page, limit) async {
      expect(query, 'cat date:planned');
      expect((page, limit), (1, 50));
      return Either.of(PostResult.empty());
    });
    await service().refresh(topic, BooruConfig.empty);
    expect((await repository.getById('cat'))?.lastSuccessfulCheckAt, startedAt);
    expect(
      (await repository.getById('cat'))?.lastSuccessfulCheckAt?.isUtc,
      isTrue,
    );
  });

  for (final total in [1, 50000]) {
    test(
      'refreshing $total matching uploads uses one page and sets NEW',
      () async {
        await seedCheckpoint();
        final requests = <(int, int?)>[];
        posts = TestSearchPostRepository((_, page, limit) async {
          requests.add((page, limit));
          return Either.right(
            PostResult(
              posts: [
                for (
                  var id = total;
                  id > total - (total < 50 ? total : 50);
                  id--
                )
                  testSearchPost(id, checkpoint.add(Duration(seconds: id))),
              ],
              total: total,
              hasMore: total > 50,
            ),
          );
        });
        final result = await service().refresh(topic, BooruConfig.empty);
        expect(requests, [(1, 50)]);
        expect(result, isA<SearchRefreshSucceeded>());
        final saved = (await repository.getById('cat'))!;
        expect(saved.hasNewPosts, isTrue);
        expect(saved.lastSuccessfulCheckAt, startedAt);
        expect(saved.previews.length, total < 4 ? total : 4);
        expect(saved.recentPostIdentities.length, lessThanOrEqualTo(50));
      },
    );
  }

  test(
    'old matching posts update previews without setting NEW after metadata edits',
    () async {
      posts = TestSearchPostRepository(
        (_, _, _) async => Either.right(
          [testSearchPost(10, checkpoint)].toResult(),
        ),
      );
      now = checkpoint;
      await service().refresh(topic, BooruConfig.empty);
      topic = (await repository.getById('cat'))!;
      now = startedAt;
      posts = TestSearchPostRepository(
        (_, _, _) async => Either.right(
          [
            testSearchPost(9, checkpoint),
            testSearchPost(8, checkpoint.subtract(const Duration(days: 1))),
          ].toResult(),
        ),
      );
      final result = await service().refresh(topic, BooruConfig.empty);
      expect((result as SearchRefreshSucceeded).detectedNewPosts, isFalse);
      final saved = (await repository.getById('cat'))!;
      expect(saved.hasNewPosts, isFalse);
      expect(saved.previews.map((post) => post.postId), [9, 8]);
    },
  );

  test(
    'a successful empty snapshot clears old previews and retains pending NEW',
    () async {
      await seedCheckpoint();
      await service().refresh(topic, BooruConfig.empty);
      topic = (await repository.getById('cat'))!;
      posts = TestSearchPostRepository(
        (_, _, _) async => Either.right(PostResult.empty()),
      );
      now = startedAt.add(const Duration(hours: 1));
      await service().refresh(topic, BooruConfig.empty);
      final saved = (await repository.getById('cat'))!;
      expect(saved.hasNewPosts, isTrue);
      expect(saved.previews, isEmpty);
      expect(saved.lastSuccessfulCheckAt, now);
      expect(saved.highestSeenPostId, 2);
    },
  );

  final failures = [
    (
      name: 'unsupported query plan',
      error: null,
      expected: SearchRefreshErrorKind.unsupported,
    ),
    (
      name: 'missing upload timestamp',
      error: null,
      expected: SearchRefreshErrorKind.unsupported,
    ),
    (
      name: 'network failure',
      error: AppError(type: AppErrorType.cannotReachServer, message: 'private'),
      expected: SearchRefreshErrorKind.network,
    ),
    (
      name: 'authentication failure',
      error: ServerError(httpStatusCode: 401, message: 'private'),
      expected: SearchRefreshErrorKind.authentication,
    ),
    (
      name: 'query rejection',
      error: ServerError(httpStatusCode: 422, message: 'private'),
      expected: SearchRefreshErrorKind.tagLimit,
    ),
    (
      name: 'rate limit',
      error: ServerError(httpStatusCode: 429, message: 'private'),
      expected: SearchRefreshErrorKind.rateLimited,
    ),
    (
      name: 'pagination limit',
      error: ServerError(httpStatusCode: 410, message: 'private'),
      expected: SearchRefreshErrorKind.pagination,
    ),
    (
      name: 'parse failure',
      error: UnknownError(
        error: const FormatException('private'),
        message: 'private',
      ),
      expected: SearchRefreshErrorKind.parsing,
    ),
  ];
  for (final c in failures) {
    test('preserves successful data after ${c.name}', () async {
      await seedCheckpoint();
      await service().refresh(topic, BooruConfig.empty);
      topic = (await repository.getById('cat'))!;
      now = startedAt.add(const Duration(hours: 1));
      if (c.name == 'unsupported query plan') {
        adapter = _TestAdapter(
          (_, _) => const UnsupportedSearchRefreshQueryPlan(),
        );
      } else {
        posts = TestSearchPostRepository(
          (_, _, _) async => switch (c.error) {
            final error? => Either.left(error),
            null => Either.of(
              PostResult(posts: [testSearchPost(3, null)], total: 1),
            ),
          },
        );
      }
      final outcome = await service().refresh(topic, BooruConfig.empty);
      expect(outcome, SearchRefreshFailed(c.expected));
      final saved = (await repository.getById('cat'))!;
      expect(saved.lastAttemptAt, now);
      expect(saved.lastErrorKind, c.expected);
      expect(saved.lastSuccessfulCheckAt, startedAt);
      expect(saved.highestSeenPostId, topic.highestSeenPostId);
      expect(saved.previews, topic.previews);
      expect(saved.hasNewPosts, isTrue);
    });
  }

  for (final delete in [false, true]) {
    test(
      'discards a refresh after ${delete ? 'deletion' : 'a newer commit'} during fetch',
      () async {
        final fetched = Completer<void>();
        final release = Completer<void>();
        posts = TestSearchPostRepository((_, _, _) async {
          fetched.complete();
          await release.future;
          return Either.of(PostResult.empty());
        });
        final refreshing = service().refresh(topic, BooruConfig.empty);
        await fetched.future;
        if (delete) {
          await repository.delete('cat');
        } else {
          await seedCheckpoint();
        }
        release.complete();
        expect(await refreshing, const SearchRefreshDiscarded());
        expect(
          (await repository.getById('cat'))?.lastSuccessfulCheckAt,
          delete ? null : checkpoint,
        );
      },
    );
  }
}

class _TestAdapter implements SearchRefreshQueryAdapter {
  _TestAdapter(this.resolve);
  @override
  bool get isSupported => true;
  final SearchRefreshQueryPlan Function(String query, DateTime? after) resolve;
  @override
  SearchRefreshQueryPlan plan(String query, {required DateTime? after}) =>
      resolve(query, after);
}

class _QueuedWriteBox extends MemorySubscriptionBox {
  var block = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> put(dynamic key, FollowingTopicHiveObject value) async {
    if (block) {
      block = false;
      entered.complete();
      await release.future;
    }
    await super.put(key, value);
  }
}
