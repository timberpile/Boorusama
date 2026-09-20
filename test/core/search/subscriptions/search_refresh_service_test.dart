import 'dart:async';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/chronological_search_scanner.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/search_refresh_query_adapter.dart';
import 'package:boorusama/core/search/subscriptions/src/services/search_refresh_service.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'subscription_test_utils.dart';

void main() {
  final checkpoint = DateTime.utc(2026, 9, 14, 8);
  final startedAt = DateTime.utc(2026, 9, 14, 9);
  late SearchSubscriptionRepository repository;
  late SearchSubscription subscription;
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
    subscription = (await repository.commitRefresh(
      SearchRefreshCommit(
        subscriptionId: subscription.id,
        expectedCreatedAt: subscription.createdAt,
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
    subscription = await repository.create(
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
            TestSearchPost(2, checkpoint.add(const Duration(minutes: 2))),
            TestSearchPost(1, checkpoint.add(const Duration(minutes: 1))),
          ],
          total: 2,
        ),
      ),
    );
  });

  test('first successful refresh establishes a read baseline', () async {
    final result = await service().refresh(subscription, BooruConfig.empty);
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
            TestSearchPost(2, checkpoint.add(const Duration(minutes: 2))),
            TestSearchPost(1, checkpoint.add(const Duration(minutes: 1))),
            TestSearchPost(0, checkpoint),
          ],
          total: 3,
        ),
      ),
    );
    final result = await service().refresh(subscription, BooruConfig.empty);
    expect((result as SearchRefreshSucceeded).detectedNewPosts, isTrue);
    expect(result.baseline, isFalse);
    expect((await repository.getById('cat'))?.unreadCount, 1);
  });

  test('a higher post ID sets NEW even with an older upload time', () async {
    posts = TestSearchPostRepository(
      (_, _, _) async => Either.right(
        [TestSearchPost(100, checkpoint)].toResult(),
      ),
    );
    now = checkpoint;
    await service().refresh(subscription, BooruConfig.empty);
    subscription = (await repository.getById('cat'))!;
    posts = TestSearchPostRepository(
      (_, _, _) async => Either.right(
        [
          TestSearchPost(101, checkpoint.subtract(const Duration(days: 1))),
          TestSearchPost(100, checkpoint),
        ].toResult(),
      ),
    );
    now = startedAt;

    final result = await service().refresh(subscription, BooruConfig.empty);

    expect((result as SearchRefreshSucceeded).detectedNewPosts, isTrue);
    expect((await repository.getById('cat'))?.hasNewPosts, isTrue);
  });

  test('a lower post ID does not set NEW with a newer upload time', () async {
    posts = TestSearchPostRepository(
      (_, _, _) async => Either.right(
        [TestSearchPost(100, checkpoint)].toResult(),
      ),
    );
    now = checkpoint;
    await service().refresh(subscription, BooruConfig.empty);
    subscription = (await repository.getById('cat'))!;
    posts = TestSearchPostRepository(
      (_, _, _) async => Either.right(
        [
          TestSearchPost(100, checkpoint),
          TestSearchPost(99, startedAt.add(const Duration(days: 1))),
        ].toResult(),
      ),
    );
    now = startedAt;

    final result = await service().refresh(subscription, BooruConfig.empty);

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
    await service().refresh(subscription, BooruConfig.empty);
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
                  TestSearchPost(id, checkpoint.add(Duration(seconds: id))),
              ],
              total: total,
              hasMore: total > 50,
            ),
          );
        });
        final result = await service().refresh(subscription, BooruConfig.empty);
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
          [TestSearchPost(10, checkpoint)].toResult(),
        ),
      );
      now = checkpoint;
      await service().refresh(subscription, BooruConfig.empty);
      subscription = (await repository.getById('cat'))!;
      now = startedAt;
      posts = TestSearchPostRepository(
        (_, _, _) async => Either.right(
          [
            TestSearchPost(9, checkpoint),
            TestSearchPost(8, checkpoint.subtract(const Duration(days: 1))),
          ].toResult(),
        ),
      );
      final result = await service().refresh(subscription, BooruConfig.empty);
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
      await service().refresh(subscription, BooruConfig.empty);
      subscription = (await repository.getById('cat'))!;
      posts = TestSearchPostRepository(
        (_, _, _) async => Either.right(PostResult.empty()),
      );
      now = startedAt.add(const Duration(hours: 1));
      await service().refresh(subscription, BooruConfig.empty);
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
      await service().refresh(subscription, BooruConfig.empty);
      subscription = (await repository.getById('cat'))!;
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
              PostResult(posts: [TestSearchPost(3, null)], total: 1),
            ),
          },
        );
      }
      final outcome = await service().refresh(subscription, BooruConfig.empty);
      expect(outcome, SearchRefreshFailed(c.expected));
      final saved = (await repository.getById('cat'))!;
      expect(saved.lastAttemptAt, now);
      expect(saved.lastErrorKind, c.expected);
      expect(saved.lastSuccessfulCheckAt, startedAt);
      expect(saved.highestSeenPostId, subscription.highestSeenPostId);
      expect(saved.previews, subscription.previews);
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
        final refreshing = service().refresh(subscription, BooruConfig.empty);
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
