import 'dart:async';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/data/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/chronological_search_scanner.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/search_refresh_query_adapter.dart';
import 'package:boorusama/core/search/subscriptions/src/services/search_refresh_service.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'subscription_test_utils.dart';

void main() {
  const config = BooruConfig.empty;
  final checkpoint = DateTime.utc(2026, 9, 14, 8);
  final startedAt = DateTime.utc(2026, 9, 14, 9);
  late SearchSubscriptionRepository repository;
  late ProviderContainer container;
  late TestSearchPostRepository posts;

  SearchSubscriptionsNotifier notifier() =>
      container.read(searchSubscriptionsProvider.notifier);
  SearchSubscriptionsState snapshot() =>
      container.read(searchSubscriptionsProvider).requireValue;

  Future<SearchSubscription> seed(
    String id, {
    int? profileId,
    DateTime? checkedAt,
    int unread = 0,
  }) async {
    final item = SearchSubscription(
      id: id,
      profileId: profileId ?? config.id,
      query: id,
      position: (await repository.getAll())
          .where((item) => item.profileId == (profileId ?? config.id))
          .length,
      createdAt: checkpoint,
      previews: const [],
      recentPostIdentities: const [],
      unreadCount: unread,
      lastSuccessfulCheckAt: checkedAt,
    );
    final existing = (await repository.getAll())
        .where((other) => other.profileId == item.profileId)
        .toList();
    await repository.restoreForProfile(item.profileId, [...existing, item]);
    return item;
  }

  setUp(() {
    repository = memorySubscriptionRepository();
    posts = TestSearchPostRepository(
      (_, _, _) async => Either.of(
        PostResult(
          posts: [
            TestSearchPost(1, checkpoint.add(const Duration(minutes: 1))),
          ],
          total: 1,
        ),
      ),
    );
    container = ProviderContainer(
      overrides: [
        searchSubscriptionRepositoryProvider.overrideWith(
          () => _RepositoryNotifier(repository),
        ),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: [config]),
        ),
        searchSubscriptionsProvider.overrideWith(
          () => SearchSubscriptionsNotifier(
            refreshService: SearchRefreshService(
              repository: repository,
              resolvePostRepository: (_) => posts,
              resolveQueryAdapter: (_) =>
                  const DefaultSearchRefreshQueryAdapter(),
              scanner: ChronologicalSearchScanner(),
              clock: Clock.fixed(startedAt),
            ),
          ),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'publishes the saved pin before its initial snapshot completes',
    () async {
      final fetched = Completer<void>();
      final release = Completer<void>();
      posts = TestSearchPostRepository((_, _, _) async {
        fetched.complete();
        await release.future;
        return Either.of(
          PostResult(posts: [TestSearchPost(1, checkpoint)], total: 1),
        );
      });
      final pinning = notifier().pin(
        profileId: config.id,
        query: 'cat',
        name: null,
      );
      await fetched.future;
      expect(snapshot().subscriptions.single.query, 'cat');
      expect(snapshot().subscriptions.single.lastSuccessfulCheckAt, isNull);
      expect(snapshot().refreshingIds, {snapshot().subscriptions.single.id});
      release.complete();
      final result = await pinning;
      expect(result.subscription.query, 'cat');
      expect(result.refresh, isA<SearchRefreshSucceeded>());
      expect(snapshot().subscriptions.single.lastSuccessfulCheckAt, startedAt);
      expect(snapshot().subscriptions.single.unreadCount, 0);
      expect(snapshot().refreshingIds, isEmpty);
    },
  );

  test(
    'keeps a pin saved when the initial snapshot fails and retries as a baseline',
    () async {
      posts = TestSearchPostRepository(
        (_, _, _) async =>
            Either.left(ServerError(httpStatusCode: 503, message: 'private')),
      );
      final result = await notifier().pin(
        profileId: config.id,
        query: 'cat',
        name: 'Cats',
      );
      expect(
        result.refresh,
        const SearchRefreshFailed(SearchRefreshErrorKind.network),
      );
      expect(snapshot().subscriptions.single.name, 'Cats');
      expect(snapshot().subscriptions.single.lastSuccessfulCheckAt, isNull);
      posts = TestSearchPostRepository(
        (_, _, _) async => Either.of(
          PostResult(posts: [TestSearchPost(1, checkpoint)], total: 1),
        ),
      );
      final retried = await notifier().refresh(result.subscription.id);
      expect((retried as SearchRefreshSucceeded).baseline, isTrue);
      expect(snapshot().subscriptions.single.unreadCount, 0);
    },
  );

  test(
    'reuses duplicate queries and applies an optional replacement name',
    () async {
      await Future.wait([
        notifier().pin(profileId: config.id, query: ' cat   dog ', name: null),
        notifier().pin(profileId: config.id, query: 'cat dog', name: 'Pets'),
      ]);
      expect(snapshot().subscriptions, hasLength(1));
      expect(snapshot().subscriptions.single.query, 'cat   dog');
      expect(snapshot().subscriptions.single.name, 'Pets');
      await notifier().pin(profileId: config.id, query: 'cat dog', name: null);
      expect(snapshot().subscriptions.single.name, 'Pets');
      await notifier().rename(snapshot().subscriptions.single.id, ' ');
      expect(snapshot().subscriptions.single.name, isNull);
    },
  );

  test(
    'serializes mutations and publishes profile lists and NEW state',
    () async {
      await seed('first', checkedAt: checkpoint, unread: 3);
      await seed('second', checkedAt: checkpoint, unread: 2);
      await seed('other', profileId: config.id + 1, unread: 9);
      await container.read(searchSubscriptionsProvider.future);
      expect(
        container.read(profilePinnedSearchHasNewPostsProvider(config.id)),
        isTrue,
      );
      final publications = <List<String>>[];
      container.listen(searchSubscriptionsProvider, (_, next) {
        if (next.valueOrNull case final value?) {
          publications.add(
            value.subscriptions
                .map((item) => '${item.id}:${item.name}:${item.unreadCount}')
                .toList(),
          );
        }
      });
      await Future.wait([
        notifier().rename('first', 'Renamed'),
        notifier().markRead('first'),
        notifier().reorder(config.id, 1, 0),
        notifier().delete('second'),
      ]);
      expect(publications, contains(contains('first:Renamed:1')));
      expect(publications, contains(contains('first:Renamed:0')));
      expect(
        container
            .read(profilePinnedSearchesProvider(config.id))
            .requireValue
            .map((item) => item.id),
        ['first'],
      );
      expect(
        container.read(profilePinnedSearchHasNewPostsProvider(config.id)),
        isFalse,
      );
      expect(
        container.read(profilePinnedSearchHasNewPostsProvider(config.id + 1)),
        isTrue,
      );
    },
  );

  test('reorders only the requested profile in published state', () async {
    await seed('first');
    await seed('second');
    await seed('other', profileId: config.id + 1);
    await notifier().reorder(config.id, 1, 0);
    expect(
      container
          .read(profilePinnedSearchesProvider(config.id))
          .requireValue
          .map((item) => item.id),
      ['second', 'first'],
    );
    expect(
      container
          .read(profilePinnedSearchesProvider(config.id + 1))
          .requireValue
          .single
          .id,
      'other',
    );
  });

  test(
    'coalesces refreshes and lets mark-read finish during network work',
    () async {
      await seed('cat', checkedAt: checkpoint, unread: 4);
      final fetched = Completer<void>();
      final release = Completer<void>();
      var fetchCount = 0;
      posts = TestSearchPostRepository((_, _, _) async {
        fetchCount++;
        fetched.complete();
        await release.future;
        return Either.of(
          PostResult(
            posts: [
              TestSearchPost(1, checkpoint.add(const Duration(minutes: 1))),
            ],
            total: 1,
          ),
        );
      });
      final first = notifier().refresh('cat');
      final second = notifier().refresh('cat');
      expect(identical(first, second), isTrue);
      await fetched.future;
      await notifier().markRead('cat');
      expect(snapshot().subscriptions.single.unreadCount, 0);
      expect(snapshot().refreshingIds, {'cat'});
      release.complete();
      await Future.wait([first, second]);
      expect(fetchCount, 1);
      expect(snapshot().subscriptions.single.unreadCount, 1);
      expect(snapshot().refreshingIds, isEmpty);
    },
  );

  test(
    'refreshes never-checked then oldest searches with three workers and continues after failure',
    () async {
      await seed(
        'newest',
        checkedAt: checkpoint.add(const Duration(minutes: 3)),
      );
      await seed('next', checkedAt: checkpoint.add(const Duration(minutes: 1)));
      await seed('oldest', checkedAt: checkpoint);
      await seed('never');
      await seed(
        'later',
        checkedAt: checkpoint.add(const Duration(minutes: 2)),
      );
      await seed('other', profileId: config.id + 1);
      final starts = <String>[];
      final releases = <String, Completer<void>>{};
      final initialWorkers = Completer<void>();
      var active = 0;
      var maxActive = 0;
      posts = TestSearchPostRepository((query, _, _) async {
        starts.add(query);
        active++;
        if (active > maxActive) maxActive = active;
        final release = releases[query] = Completer<void>();
        if (starts.length == 3) initialWorkers.complete();
        await release.future;
        active--;
        return query == 'never'
            ? Either.left(ServerError(httpStatusCode: 503, message: 'private'))
            : Either.of(PostResult.empty());
      });
      final batch = notifier().refreshAll(config.id);
      await initialWorkers.future;
      expect(starts, ['never', 'oldest', 'next']);
      expect(snapshot().batchTotal, 5);
      releases['never']!.complete();
      await pumpEventQueue();
      expect(starts, ['never', 'oldest', 'next', 'later']);
      expect(snapshot().batchCompleted, 1);
      releases['oldest']!.complete();
      await pumpEventQueue();
      expect(starts.last, 'newest');
      for (final release in releases.values) {
        if (!release.isCompleted) release.complete();
      }
      final outcomes = await batch;
      expect(outcomes, hasLength(5));
      expect(
        outcomes.first,
        const SearchRefreshFailed(SearchRefreshErrorKind.network),
      );
      expect(maxActive, lessThanOrEqualTo(3));
      expect(snapshot().batchCompleted, 5);
      expect(snapshot().refreshingIds, isEmpty);
      expect(
        (await repository.getById('other'))?.lastSuccessfulCheckAt,
        isNull,
      );
    },
  );

  test('discards a missing subscription without fetching posts', () async {
    posts = TestSearchPostRepository(
      (_, _, _) async => throw StateError('Must not fetch'),
    );
    expect(await notifier().refresh('missing'), const SearchRefreshDiscarded());
    expect(snapshot().refreshingIds, isEmpty);
  });

  test(
    'creates a shared folder and keeps its member when creation succeeds',
    () async {
      final cat = await seed('cat', unread: 2);
      await container.read(searchSubscriptionsProvider.future);

      final folder = await notifier().createSharedFolderAndMovePin(
        cat.id,
        'Animals',
      );

      expect(folder.searchIds, [cat.id]);
      expect(snapshot().organization.folders, [folder]);
    },
  );

  test('a failed shared create-and-move keeps the pin in Home', () async {
    final cat = await seed('cat', unread: 2);
    await container.read(searchSubscriptionsProvider.future);

    await expectLater(
      notifier().createSharedFolderAndMovePin(cat.id, ' '),
      throwsFormatException,
    );

    expect(snapshot().organization.homeSearchIds, [cat.id]);
  });
}

class _RepositoryNotifier extends SearchSubscriptionRepositoryNotifier {
  _RepositoryNotifier(this.repository);
  final SearchSubscriptionRepository repository;
  @override
  Future<SearchSubscriptionRepository> build() async => repository;
}
