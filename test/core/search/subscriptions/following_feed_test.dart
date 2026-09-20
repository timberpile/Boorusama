import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/following_feeds_page.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/pinned_searches_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pinned_search_test_utils.dart';
import 'subscription_test_utils.dart';

void main() {
  late PinnedSearchHarness harness;
  setUp(() => harness = PinnedSearchHarness());
  tearDown(() => harness.dispose());

  test(
    'manual pin order and folders exclude feed-owned subscriptions',
    () async {
      final harness = PinnedSearchHarness();
      addTearDown(harness.dispose);
      final cats = pinnedFixture(query: 'cat');
      final dogs = pinnedFixture(id: 'dogs', query: 'dog', position: 1);
      await harness.seed([cats, dogs]);
      final notifier = harness.container.read(
        searchSubscriptionsProvider.notifier,
      );
      await harness.container.read(searchSubscriptionsProvider.future);
      final feed = await notifier.saveFeed(
        profileId: 12,
        name: 'Animals',
        queries: ['cat', 'dog'],
      );
      await notifier.reorderSharedPins(null, 1, 0);
      expect(
        harness.container
            .read(organizedPinnedSearchesProvider(null))
            .requireValue
            .map((s) => s.id),
        ['dogs', 'cats'],
      );
      expect(
        (await harness.repository.getAll())
            .where((s) => s.feedId == feed.id)
            .length,
        2,
      );
      final source = (await harness.repository.getAll()).firstWhere(
        (s) => s.feedId == feed.id,
      );
      final folder = await notifier.createSharedFolder('Folder');
      await expectLater(
        notifier.movePinToSharedFolder(source.id, folder.id),
        throwsStateError,
      );
    },
  );

  test(
    'shared folders exclude feed-owned sources from the same profile',
    () async {
      await harness.seed([pinnedFixture(query: 'cat')]);
      final notifier = harness.container.read(
        searchSubscriptionsProvider.notifier,
      );
      await harness.container.read(searchSubscriptionsProvider.future);
      final feed = await notifier.saveFeed(
        profileId: 12,
        name: 'Animals',
        queries: ['dog'],
      );
      final source = (await harness.repository.getAll()).singleWhere(
        (search) => search.feedId == feed.id,
      );
      final folder = await notifier.createSharedFolder('Pins');

      await expectLater(
        notifier.movePinToSharedFolder(source.id, folder.id),
        throwsStateError,
      );
      expect(
        harness.container
            .read(organizedPinnedSearchesProvider(folder.id))
            .requireValue,
        isEmpty,
      );
    },
  );

  test(
    'feed sources are separate from identical user pins and feed reading preserves user NEW',
    () async {
      await harness.seed([pinnedFixture(query: 'cat')]);
      final notifier = harness.container.read(
        searchSubscriptionsProvider.notifier,
      );
      await harness.container.read(searchSubscriptionsProvider.future);
      final feed = await notifier.saveFeed(
        profileId: 12,
        name: 'Animals',
        queries: ['cat', 'dog', 'cat'],
      );
      final state = harness.container
          .read(searchSubscriptionsProvider)
          .requireValue;
      expect(state.subscriptions.where((s) => s.feedId == feed.id).length, 2);
      expect(
        harness.container
            .read(organizedPinnedSearchesProvider(null))
            .requireValue
            .map((s) => s.id),
        ['cats'],
      );
      expect(
        await harness.repository.findByQuery(12, 'cat'),
        pinnedFixture(query: 'cat'),
      );
      await notifier.markFeedRead(feed.id);
      expect((await harness.repository.getById('cats'))!.hasNewPosts, true);
      await notifier.deleteFeed(feed.id);
      expect(await harness.repository.getAll(), [pinnedFixture(query: 'cat')]);
      expect(await harness.repository.getFeeds(), isEmpty);
    },
  );

  test(
    'feed snapshots persist chronological deduplicated results and failures keep the cache',
    () async {
      final feed = await harness.repository.saveFeed(
        profileId: 12,
        name: 'Animals',
        queries: ['cat', 'dog'],
      );
      final sources = (await harness.repository.getAll())
          .where((s) => s.feedId == feed.id)
          .toList();
      Future<void> commit(SearchSubscription source, List<int> ids) async {
        await harness.repository.commitRefresh(
          SearchRefreshCommit(
            subscriptionId: source.id,
            expectedCreatedAt: source.createdAt,
            expectedCheckpoint: source.lastSuccessfulCheckAt,
            startedAt: checkedAt,
            identityRetentionBoundary: checkedAt,
            baseline: true,
            discoveredPosts: const [],
            feedPosts: [
              for (final id in ids)
                CachedFeedPost.fromPost(
                  TestSearchPost(id, checkedAt.add(Duration(seconds: id))),
                ),
            ],
          ),
        );
      }

      await commit(sources[0], [1, 2]);
      await commit(sources[1], [2, 3]);
      expect(
        (await harness.repository.getFeeds()).single.posts.map((p) => p.id),
        [3, 2, 1],
      );
      await harness.repository.recordRefreshFailure(
        sources[0].id,
        expectedCreatedAt: sources[0].createdAt,
        attemptedAt: checkedAt,
        kind: SearchRefreshErrorKind.network,
      );
      expect(
        (await harness.repository.getFeeds()).single.posts.map((p) => p.id),
        [3, 2, 1],
      );
      final restored = SearchFollowingFeed.fromJson(
        (await harness.repository.getFeeds()).single.toJson(),
      );
      expect(restored, (await harness.repository.getFeeds()).single);
      await harness.repository.deleteForProfile(12);
      expect(await harness.repository.getFeeds(), isEmpty);
      expect(await harness.repository.getAll(), isEmpty);
    },
  );

  test(
    'editing feed sources preserves unchanged checkpoints and removes only owned sources',
    () async {
      await harness.seed([pinnedFixture(query: 'cat')]);
      final feed = await harness.repository.saveFeed(
        profileId: 12,
        name: 'Animals',
        queries: ['cat', 'dog'],
      );
      final cat = (await harness.repository.getAll()).singleWhere(
        (s) => s.feedId == feed.id && s.query == 'cat',
      );
      await harness.repository.recordRefreshFailure(
        cat.id,
        expectedCreatedAt: cat.createdAt,
        attemptedAt: checkedAt,
        kind: SearchRefreshErrorKind.network,
      );
      await harness.repository.saveFeed(
        profileId: 12,
        name: 'Renamed',
        queries: ['cat', 'bird'],
        id: feed.id,
      );
      final owned = (await harness.repository.getAll())
          .where((s) => s.feedId == feed.id)
          .toList();
      expect(owned.map((s) => s.query).toSet(), {'cat', 'bird'});
      expect(
        owned.singleWhere((s) => s.query == 'cat').lastErrorKind,
        SearchRefreshErrorKind.network,
      );
      expect((await harness.repository.getById('cats'))!.hasNewPosts, true);
      expect((await harness.repository.getFeeds()).single.name, 'Renamed');
      await expectLater(
        harness.repository.saveFeed(
          profileId: 99,
          name: 'Wrong',
          queries: ['cat'],
          id: feed.id,
        ),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'opening feeds uses cache without fetching hidden sources and keeps them out of pins',
    (tester) async {
      await tester.runAsync(() async {
        await harness.seed([pinnedFixture(query: 'cat')]);
        await harness.repository.saveFeed(
          profileId: 12,
          name: 'Animals',
          queries: ['cat', 'dog'],
        );
        await harness.container.read(searchSubscriptionsProvider.future);
      });
      await harness.pump(tester, const PinnedSearchesPage());
      expect(find.text('Cats'), findsOneWidget);
      expect(find.text('dog'), findsNothing);
      await tester.tap(find.byTooltip('Following feeds'));
      await settle(tester);
      expect(find.text('Animals'), findsOneWidget);
      expect(find.byType(FollowingFeedsPage), findsOneWidget);
      expect(harness.requests, isEmpty);
    },
  );
}
