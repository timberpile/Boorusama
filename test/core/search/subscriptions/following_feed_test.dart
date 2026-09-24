import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/defaults/widgets.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/details/routes.dart';
import 'package:boorusama/core/posts/details_parts/types.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/post/widgets.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/following_feeds_page.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/pinned_searches_page.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/feed_post_thumbnail.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/themes/colors/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';
import 'pinned_search_test_utils.dart';
import 'subscription_test_utils.dart';

void main() {
  late PinnedSearchHarness harness;
  setUp(() => harness = PinnedSearchHarness());
  tearDown(() => harness.dispose());

  test(
    'feeds store member search IDs without changing independent pins',
    () async {
      await harness.seed([pinnedFixture(query: 'cat')]);
      final feed = await harness.repository.saveFeed(
        profileId: 12,
        name: 'Animals',
        queries: ['cat', 'dog'],
      );
      final byId = {
        for (final search in await harness.repository.getAll())
          search.id: search,
      };

      expect(feed.sourceIds.length, 2);
      expect(feed.sourceIds.map((id) => byId[id]!.query), ['cat', 'dog']);
      expect(feed.sourceIds, isNot(contains('cats')));
      expect((await harness.repository.getById('cats'))!.hasNewPosts, isTrue);
    },
  );

  test(
    'one internal search can serve two feeds while the user pin stays separate',
    () async {
      await harness.seed([pinnedFixture(query: 'cat')]);
      final first = await harness.repository.saveFeed(
        profileId: 12,
        name: 'First',
        queries: ['cat'],
      );
      final second = await harness.repository.saveFeed(
        profileId: 12,
        name: 'Second',
        queries: ['cat'],
      );
      expect(first.sourceIds, second.sourceIds);
      expect(first.sourceIds, isNot(contains('cats')));

      await harness.repository.deleteFeed(first.id);
      expect(
        await harness.repository.getById(second.sourceIds.single),
        isNotNull,
      );
      await harness.repository.deleteFeed(second.id);
      expect((await harness.repository.getAll()).map((search) => search.id), [
        'cats',
      ]);
    },
  );

  test('following and unfollowing changes only the selected feed', () async {
    final notifier = harness.container.read(
      searchSubscriptionsProvider.notifier,
    );
    await harness.container.read(searchSubscriptionsProvider.future);
    final first = await notifier.saveFeed(
      profileId: 12,
      name: 'First',
      queries: ['cat'],
    );
    final second = await notifier.saveFeed(
      profileId: 12,
      name: 'Second',
      queries: ['cat'],
    );

    final expanded = await notifier.setFeedFollowing(
      feedId: first.id,
      profileId: 12,
      query: 'dog',
      following: true,
    );
    expect(expanded!.sourceIds.length, 2);
    expect(expanded.sourceIds.first, second.sourceIds.single);
    expect((await harness.repository.getFeeds()).last.sourceIds, [
      second.sourceIds.single,
    ]);

    final reduced = await notifier.setFeedFollowing(
      feedId: first.id,
      profileId: 12,
      query: 'cat',
      following: false,
    );
    expect(reduced!.sourceIds.length, 1);
    expect(
      await harness.repository.getById(second.sourceIds.single),
      isNotNull,
    );
    expect((await harness.repository.getFeeds()).length, 2);
  });

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
            .where((s) => feed.sourceIds.contains(s.id))
            .length,
        2,
      );
      final source = (await harness.repository.getAll()).firstWhere(
        (s) => feed.sourceIds.contains(s.id),
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
        (search) => feed.sourceIds.contains(search.id),
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
      expect(
        state.subscriptions.where((s) => feed.sourceIds.contains(s.id)).length,
        2,
      );
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
          .where((s) => feed.sourceIds.contains(s.id))
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
                feedPostSnapshotFromPost(
                  TestSearchPost(id, checkedAt.add(Duration(seconds: id))),
                ),
            ],
          ),
        );
      }

      await commit(sources[0], [1, 2]);
      await commit(sources[1], [2, 3]);
      expect(
        (await harness.repository.getFeeds()).single.posts.map(feedPostId),
        [3, 2, 1],
      );
      await harness.repository.recordRefreshFailure(
        sources[0].id,
        expectedCreatedAt: sources[0].createdAt,
        attemptedAt: checkedAt,
        kind: SearchRefreshErrorKind.network,
      );
      expect(
        (await harness.repository.getFeeds()).single.posts.map(feedPostId),
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

  test('cached feed posts preserve media variants through serialization', () {
    final cached = feedPostSnapshotFromPost(_variantSearchPost(42, checkedAt));

    expect(decodeFeedPost(cached).mediaVariants, _variantMediaVariants);
    expect(
      decodeFeedPost(
        feedPostSnapshotFromJson(feedPostSnapshotToJson(cached)),
      ).mediaVariants,
      _variantMediaVariants,
    );
  });

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
        (s) => feed.sourceIds.contains(s.id) && s.query == 'cat',
      );
      await harness.repository.recordRefreshFailure(
        cat.id,
        expectedCreatedAt: cat.createdAt,
        attemptedAt: checkedAt,
        kind: SearchRefreshErrorKind.network,
      );
      final updatedFeed = await harness.repository.saveFeed(
        profileId: 12,
        name: 'Renamed',
        queries: ['cat', 'bird'],
        id: feed.id,
      );
      final owned = (await harness.repository.getAll())
          .where((s) => updatedFeed.sourceIds.contains(s.id))
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

  test(
    'adding a member clears cached feed posts and retains shared source state',
    () async {
      final first = await harness.repository.saveFeed(
        profileId: 12,
        name: 'First',
        queries: ['cat'],
      );
      final second = await harness.repository.saveFeed(
        profileId: 12,
        name: 'Second',
        queries: ['cat'],
      );
      final cat = (await harness.repository.getById(first.sourceIds.single))!;
      await harness.repository.commitRefresh(
        SearchRefreshCommit(
          subscriptionId: cat.id,
          expectedCreatedAt: cat.createdAt,
          expectedCheckpoint: null,
          startedAt: checkedAt,
          identityRetentionBoundary: checkedAt,
          baseline: true,
          discoveredPosts: const [],
          feedPosts: [
            feedPostSnapshotFromPost(TestSearchPost(1, checkedAt)),
          ],
        ),
      );
      expect((await harness.repository.getFeeds()).first.posts, isNotEmpty);

      final updated = await harness.repository.saveFeed(
        profileId: 12,
        name: 'First',
        queries: ['cat', 'dog'],
        id: first.id,
      );
      expect(updated.posts, isEmpty);
      expect(updated.sourceIds.first, cat.id);
      expect(
        (await harness.repository.getById(cat.id))!.lastSuccessfulCheckAt,
        isNotNull,
      );
      await harness.repository.saveFeed(
        profileId: 12,
        name: 'First',
        queries: ['dog'],
        id: first.id,
      );
      expect(
        (await harness.repository.getFeeds()).last.sourceIds.single,
        cat.id,
      );
      expect(
        await harness.repository.getById(second.sourceIds.single),
        isNotNull,
      );
    },
  );

  test(
    'feed ordering rejects incomplete IDs without changing saved order',
    () async {
      final first = await harness.repository.saveFeed(
        profileId: 12,
        name: 'First',
        queries: ['cat'],
      );
      final second = await harness.repository.saveFeed(
        profileId: 12,
        name: 'Second',
        queries: ['dog'],
      );
      final third = await harness.repository.saveFeed(
        profileId: 12,
        name: 'Third',
        queries: ['bird'],
      );
      await harness.repository.setFeedOrder(12, [
        third.id,
        first.id,
        second.id,
      ]);
      expect((await harness.repository.getFeeds()).map((feed) => feed.id), [
        third.id,
        first.id,
        second.id,
      ]);
      expect(
        (await harness.repository.getFeeds()).map((feed) => feed.position),
        [
          0,
          1,
          2,
        ],
      );
      await expectLater(
        harness.repository.setFeedOrder(12, [first.id, second.id]),
        throwsFormatException,
      );
      expect((await harness.repository.getFeeds()).map((feed) => feed.id), [
        third.id,
        first.id,
        second.id,
      ]);
    },
  );

  testWidgets(
    'feed overview lists both profile owners without fetching hidden sources',
    (tester) async {
      await tester.runAsync(() async {
        await harness.seed([pinnedFixture(query: 'cat')]);
        await harness.repository.saveFeed(
          profileId: 12,
          name: 'Animals',
          queries: ['cat', 'dog'],
        );
        await harness.repository.saveFeed(
          profileId: 99,
          name: 'Birds',
          queries: ['bird'],
        );
        await harness.container.read(searchSubscriptionsProvider.future);
      });
      await harness.pump(tester, const PinnedSearchesPage());
      expect(find.text('Cats'), findsOneWidget);
      expect(find.text('dog'), findsNothing);
      expect(find.byTooltip('Following feeds'), findsNothing);
      await harness.pump(tester, const FollowingFeedsPage());
      expect(find.text('Animals'), findsOneWidget);
      expect(find.text('Birds'), findsOneWidget);
      expect(find.text('https://active.example'), findsOneWidget);
      expect(find.text('https://other.example'), findsOneWidget);
      expect(find.byType(FollowingFeedsPage), findsOneWidget);
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets('feed overview shows four recent thumbnails with its owner', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final feed = await harness.repository.saveFeed(
        profileId: 12,
        name: 'Animals',
        queries: ['cat'],
      );
      final source = (await harness.repository.getById(feed.sourceIds.single))!;
      await harness.repository.commitRefresh(
        SearchRefreshCommit(
          subscriptionId: source.id,
          expectedCreatedAt: source.createdAt,
          expectedCheckpoint: null,
          startedAt: checkedAt,
          identityRetentionBoundary: checkedAt,
          baseline: true,
          discoveredPosts: const [],
          feedPosts: [
            for (var i = 0; i < 6; i++)
              feedPostSnapshotFromPost(
                TestSearchPost(i, checkedAt.add(Duration(seconds: i))),
              ),
          ],
        ),
      );
      await harness.container.read(searchSubscriptionsProvider.future);
    });
    await harness.pump(tester, const FollowingFeedsPage());
    final images = tester.widgetList<BooruImage>(find.byType(BooruImage));
    expect(images.map((image) => image.imageUrl), [
      'https://example.com/5-thumb.jpg',
      'https://example.com/4-thumb.jpg',
      'https://example.com/3-thumb.jpg',
      'https://example.com/2-thumb.jpg',
    ]);
    expect(images.every((image) => image.config == testProfile.auth), isTrue);
    expect(harness.requests, isEmpty);
  });

  testWidgets('feed overview uses the configured high-quality images', (
    tester,
  ) async {
    harness.dispose();
    harness = PinnedSearchHarness(
      listingSettings: Settings.defaultSettings.listing.copyWith(
        imageQuality: ImageQuality.high,
      ),
    );
    await tester.runAsync(() async {
      final feed = await harness.repository.saveFeed(
        profileId: 12,
        name: 'Animals',
        queries: ['cat'],
      );
      final source = (await harness.repository.getById(feed.sourceIds.single))!;
      await harness.repository.commitRefresh(
        SearchRefreshCommit(
          subscriptionId: source.id,
          expectedCreatedAt: source.createdAt,
          expectedCheckpoint: null,
          startedAt: checkedAt,
          identityRetentionBoundary: checkedAt,
          baseline: true,
          discoveredPosts: const [],
          feedPosts: [
            feedPostSnapshotFromPost(TestSearchPost(1, checkedAt)),
          ],
        ),
      );
      await harness.container.read(searchSubscriptionsProvider.future);
    });

    await harness.pump(tester, const FollowingFeedsPage());

    expect(
      tester.widget<BooruImage>(find.byType(BooruImage)).imageUrl,
      'https://example.com/1.jpg',
    );
  });

  testWidgets(
    'feed uses native cards and opens mixed snapshots without changing profiles',
    (tester) async {
      harness.dispose();
      const presentation = _FeedPresentation();
      harness = PinnedSearchHarness(
        profiles: [_feedConfig],
        postCapability: const BooruPostCapability<BooruPostData>(
          booruType: BooruType.gelbooruV2,
          codec: GelbooruV2PostCodec(),
          presentation: presentation,
        ),
      );
      final feed = await harness.repository.saveFeed(
        profileId: _feedConfig.id,
        name: 'Native feed',
        queries: ['cat'],
      );
      final source = (await harness.repository.getById(feed.sourceIds.single))!;
      final native = feedPostSnapshotFromPost(
        _feedPost(42),
        dataCodec: const GelbooruV2PostCodec(),
      );
      final fallbackSource = feedPostSnapshotFromPost(
        _feedPost(41),
        dataCodec: const GelbooruV2PostCodec(),
      );
      final fallback = feedPostSnapshotFromJson({
        'snapshotSchemaVersion': 1,
        'postSnapshot': {
          ...fallbackSource.toJson(),
          'codecVersion': 99,
          'custom': const {'future': true},
        },
      });
      await harness.repository.commitRefresh(
        SearchRefreshCommit(
          subscriptionId: source.id,
          expectedCreatedAt: source.createdAt,
          expectedCheckpoint: null,
          startedAt: checkedAt,
          identityRetentionBoundary: checkedAt,
          baseline: true,
          discoveredPosts: const [],
          feedPosts: [native, fallback],
        ),
      );
      await harness.container.read(searchSubscriptionsProvider.future);

      DetailsRouteContext? opened;
      harness.router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => FollowingFeedPage(
              feedId: feed.id,
              profileId: _feedConfig.id,
            ),
          ),
          GoRoute(
            path: '/details',
            builder: (_, state) {
              opened = state.extra! as DetailsRouteContext;
              return const Scaffold(body: Text('mixed feed viewer'));
            },
          ),
        ],
      );
      addTearDown(harness.router.dispose);
      await tester.pumpWidget(
        harness.wrap(
          MaterialApp.router(
            routerConfig: harness.router,
            theme: Kurumi.themeFrom(
              KurumiThemeMode.light,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              systemDarkMode: false,
            ).withBoorusamaColors(),
            builder: themeBuilder,
          ),
        ),
      );
      await settle(tester);

      expect(find.text('native feed card'), findsOneWidget);
      final cards = tester.widgetList<PostGridItem>(find.byType(PostGridItem));
      expect(cards.length, 2);
      expect(
        cards.first.post.booruData,
        isA<GelbooruV2PostData>(),
      );
      expect(
        cards.last.post.booruData,
        isA<UnknownPostData>(),
      );
      expect(harness.requests, isEmpty);

      await tester.tap(find.byType(ImageGridItem).first);
      await tester.pumpAndSettle();

      expect(find.text('mixed feed viewer'), findsOneWidget);
      expect(opened?.useMixedViewer, isTrue);
      expect(opened?.posts.length, 2);
      expect(
        opened!.posts.last.booruData,
        isA<UnknownPostData>(),
      );
      expect(
        harness.container.read(currentBooruConfigProvider).url,
        testProfile.url,
      );
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets(
    'feed footer uses its owner profile without changing the global profile',
    (tester) async {
      final footerConfigs = <BooruConfigAuth>[];
      harness.dispose();
      harness = PinnedSearchHarness(
        profiles: [testProfile, _feedConfig, _otherFeedConfig],
        postCapability: _feedCapability,
        listingSettings: Settings.defaultSettings.listing.copyWith(
          showPostListConfigHeader: false,
        ),
        booruBuilder: (config) => _FeedMultiSelectionBuilder(
          config: config,
          onBuild: footerConfigs.add,
        ),
      );
      final feed = await harness.repository.saveFeed(
        profileId: _feedConfig.id,
        name: 'Native feed',
        queries: ['cat'],
      );
      final source = (await harness.repository.getById(feed.sourceIds.single))!;
      await harness.repository.commitRefresh(
        SearchRefreshCommit(
          subscriptionId: source.id,
          expectedCreatedAt: source.createdAt,
          expectedCheckpoint: null,
          startedAt: checkedAt,
          identityRetentionBoundary: checkedAt,
          baseline: true,
          discoveredPosts: const [],
          feedPosts: [
            feedPostSnapshotFromPost(
              _feedPost(42),
              dataCodec: const GelbooruV2PostCodec(),
            ),
          ],
        ),
      );
      await harness.container.read(searchSubscriptionsProvider.future);

      await harness.pump(
        tester,
        FollowingFeedPage(feedId: feed.id, profileId: _feedConfig.id),
      );
      final selection = tester
          .widget<SelectionMode>(find.byType(SelectionMode))
          .controller!;
      selection.enable(initialSelected: const [0]);
      await tester.pump();

      expect(footerConfigs, isNotEmpty);
      expect(footerConfigs.last, _feedConfig.auth);
      expect(find.text('native bulk mutation'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Bookmark'), findsOneWidget);
      expect(
        harness.container.read(currentBooruConfigProvider),
        testProfile,
      );
    },
  );

  testWidgets(
    'feed exposes no bulk actions for an incompatible selected origin',
    (tester) async {
      harness.dispose();
      harness = PinnedSearchHarness(
        profiles: [testProfile, _feedConfig, _otherFeedConfig],
        postCapability: _feedCapability,
        listingSettings: Settings.defaultSettings.listing.copyWith(
          showPostListConfigHeader: false,
        ),
        booruBuilder: (config) => _FeedMultiSelectionBuilder(config: config),
      );
      final feed = await harness.repository.saveFeed(
        profileId: _feedConfig.id,
        name: 'Native feed',
        queries: ['cat'],
      );
      final source = (await harness.repository.getById(feed.sourceIds.single))!;
      final incompatible = _feedPost(43).copyWith(
        origin: PostOrigin.fromSource(
          booruType: BooruType.gelbooruV2,
          booruId: _feedConfig.booruId,
          source: _otherFeedConfig.url,
          profileIdHint: _otherFeedConfig.id,
        ),
      );
      await harness.repository.commitRefresh(
        SearchRefreshCommit(
          subscriptionId: source.id,
          expectedCreatedAt: source.createdAt,
          expectedCheckpoint: null,
          startedAt: checkedAt,
          identityRetentionBoundary: checkedAt,
          baseline: true,
          discoveredPosts: const [],
          feedPosts: [
            feedPostSnapshotFromPost(
              incompatible,
              dataCodec: const GelbooruV2PostCodec(),
            ),
          ],
        ),
      );
      await harness.container.read(searchSubscriptionsProvider.future);
      await harness.pump(
        tester,
        FollowingFeedPage(feedId: feed.id, profileId: _feedConfig.id),
      );

      final selection = tester
          .widget<SelectionMode>(find.byType(SelectionMode))
          .controller!;
      selection.enable(initialSelected: const [0]);
      await tester.pump();

      expect(find.text('native bulk mutation'), findsNothing);
      expect(find.text('Download'), findsNothing);
      expect(find.text('Bookmark'), findsNothing);
      expect(
        harness.container.read(currentBooruConfigProvider),
        testProfile,
      );
    },
  );

  testWidgets(
    'feed exposes no bulk actions for an incompatible owner-profile payload',
    (tester) async {
      harness.dispose();
      harness = PinnedSearchHarness(
        profiles: [testProfile, _feedConfig],
        postCapability: _feedCapability,
        listingSettings: Settings.defaultSettings.listing.copyWith(
          showPostListConfigHeader: false,
        ),
        booruBuilder: (config) => _FeedMultiSelectionBuilder(config: config),
      );
      final feed = await harness.repository.saveFeed(
        profileId: _feedConfig.id,
        name: 'Native feed',
        queries: ['cat'],
      );
      final source = (await harness.repository.getById(feed.sourceIds.single))!;
      final incompatible = _feedPost(44).copyWith(
        booruData: const UnknownPostData(
          typeKey: 'gelbooru_v2',
          schemaVersion: 99,
          custom: {'future': true},
          reason: UnknownPostDataReason.unsupportedVersion,
        ),
      );
      await harness.repository.commitRefresh(
        SearchRefreshCommit(
          subscriptionId: source.id,
          expectedCreatedAt: source.createdAt,
          expectedCheckpoint: null,
          startedAt: checkedAt,
          identityRetentionBoundary: checkedAt,
          baseline: true,
          discoveredPosts: const [],
          feedPosts: [feedPostSnapshotFromPost(incompatible)],
        ),
      );
      await harness.container.read(searchSubscriptionsProvider.future);
      await harness.pump(
        tester,
        FollowingFeedPage(feedId: feed.id, profileId: _feedConfig.id),
      );

      final selection = tester
          .widget<SelectionMode>(find.byType(SelectionMode))
          .controller!;
      selection.enable(initialSelected: const [0]);
      await tester.pump();

      expect(find.text('native bulk mutation'), findsNothing);
      expect(find.text('Download'), findsNothing);
      expect(find.text('Bookmark'), findsNothing);
      expect(
        harness.container.read(currentBooruConfigProvider),
        testProfile,
      );
    },
  );

  final thumbnailCases = [
    (
      quality: ImageQuality.low,
      expectedUrl: 'https://example.com/1-thumb.jpg',
    ),
    (quality: ImageQuality.high, expectedUrl: 'https://example.com/1.jpg'),
  ];
  for (final c in thumbnailCases) {
    testWidgets('feed thumbnails use ${c.quality.name} image quality', (
      tester,
    ) async {
      harness.dispose();
      harness = PinnedSearchHarness(
        listingSettings: Settings.defaultSettings.listing.copyWith(
          imageQuality: c.quality,
        ),
      );

      await harness.pump(
        tester,
        FeedPostThumbnail(
          post: decodeFeedPost(
            feedPostSnapshotFromPost(TestSearchPost(1, checkedAt)),
          ),
          config: testProfile.auth,
        ),
      );

      expect(
        tester.widget<BooruImage>(find.byType(BooruImage)).imageUrl,
        c.expectedUrl,
      );
    });
  }

  final automaticThumbnailCases = [
    (gridSize: GridSize.micro, expectedUrl: 'https://example.com/180.jpg'),
    (gridSize: GridSize.tiny, expectedUrl: 'https://example.com/360.jpg'),
    (gridSize: GridSize.normal, expectedUrl: 'https://example.com/720.jpg'),
  ];
  for (final c in automaticThumbnailCases) {
    testWidgets(
      'cached feed thumbnails use the ${c.gridSize.name} automatic variant',
      (tester) async {
        harness.dispose();
        harness = PinnedSearchHarness(
          listingSettings: Settings.defaultSettings.listing.copyWith(
            imageQuality: ImageQuality.automatic,
            gridSize: c.gridSize,
          ),
        );
        final post = feedPostSnapshotFromJson({
          'id': 1,
          'createdAt': checkedAt.toIso8601String(),
          'thumbnail': 'https://example.com/thumb.jpg',
          'sample': 'https://example.com/sample.jpg',
          'original': 'https://example.com/original.jpg',
          'tags': const <String>[],
          'rating': 'general',
          'width': 100,
          'height': 100,
          'format': 'jpg',
          'mediaVariants': const {
            '180x180': 'https://example.com/180.jpg',
            '360x360': 'https://example.com/360.jpg',
            '720x720': 'https://example.com/720.jpg',
          },
        });

        await harness.pump(
          tester,
          FeedPostThumbnail(
            post: decodeFeedPost(post),
            config: testProfile.auth,
          ),
        );

        expect(
          tester.widget<BooruImage>(find.byType(BooruImage)).imageUrl,
          c.expectedUrl,
        );
        expect(
          post.common['mediaVariants'],
          {
            '180x180': 'https://example.com/180.jpg',
            '360x360': 'https://example.com/360.jpg',
            '720x720': 'https://example.com/720.jpg',
          },
        );
      },
    );
  }

  testWidgets('rate limited source is visible on the feed overview', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final feed = await harness.repository.saveFeed(
        profileId: 12,
        name: 'Animals',
        queries: ['cat'],
      );
      final source = (await harness.repository.getById(feed.sourceIds.single))!;
      await harness.repository.recordRefreshFailure(
        source.id,
        expectedCreatedAt: source.createdAt,
        attemptedAt: checkedAt,
        kind: SearchRefreshErrorKind.rateLimited,
      );
      await harness.container.read(searchSubscriptionsProvider.future);
    });
    await harness.pump(tester, const FollowingFeedsPage());
    expect(
      find.text('Rate limited by the site. Try again later.'),
      findsOneWidget,
    );
  });
}

const _variantMediaVariants = {
  '180x180': 'https://example.com/180.jpg',
  '360x360': 'https://example.com/360.jpg',
  '720x720': 'https://example.com/720.jpg',
};

Post _variantSearchPost(int id, DateTime? createdAt) {
  final post = TestSearchPost(id, createdAt);
  return post.copyWith(
    core: PostCoreData(
      id: post.id,
      createdAt: post.createdAt,
      thumbnailImageUrl: post.thumbnailImageUrl,
      sampleImageUrl: post.sampleImageUrl,
      originalImageUrl: post.originalImageUrl,
      videoUrl: post.videoUrl,
      videoThumbnailUrl: post.videoThumbnailUrl,
      mediaVariants: _variantMediaVariants,
      width: post.width,
      height: post.height,
      format: post.format,
      md5: post.md5,
      fileSize: post.fileSize,
      duration: post.duration,
      hasSound: post.hasSound,
      tags: post.tags,
      rating: post.rating,
      hasComment: post.hasComment,
      isTranslated: post.isTranslated,
      hasParentOrChildren: post.hasParentOrChildren,
      source: post.source,
      score: post.score,
    ),
  );
}

final _feedConfig = BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.gelbooruV2,
    url: 'https://gelbooru.example',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': 99,
});

final _otherFeedConfig = BooruConfig.fromJson({
  ..._feedConfig.toJson(),
  'id': 100,
});

const _feedCapability = BooruPostCapability<BooruPostData>(
  booruType: BooruType.gelbooruV2,
  codec: GelbooruV2PostCodec(),
  presentation: _FeedPresentation(),
);

Post _feedPost(int id) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.gelbooruV2,
    booruId: _feedConfig.booruId,
    source: _feedConfig.url,
    profileIdHint: _feedConfig.id,
  ),
  core: PostCoreData(
    id: id,
    createdAt: checkedAt.add(Duration(seconds: id)),
    thumbnailImageUrl: 'https://example.com/$id-thumb.jpg',
    sampleImageUrl: 'https://example.com/$id.jpg',
    originalImageUrl: 'https://example.com/$id-original.jpg',
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 100,
    height: 100,
    format: 'jpg',
    md5: '$id',
    fileSize: 1,
    duration: 0,
    tags: const {'cat'},
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
  ),
  booruData: const GelbooruV2PostData(hasNotes: true),
);

final class _FeedPresentation
    implements BooruPostPresentation, BooruPostGridPresentation {
  const _FeedPresentation();

  @override
  PostDetailsWrapperBuilder? get detailsWrapperBuilder => null;

  @override
  bool supports(BooruPostData data) => data is GelbooruV2PostData;

  @override
  PostDetailsUIBuilder detailsBuilder(Post post) =>
      const PostDetailsUIBuilder();

  @override
  PostGridItemAdditions buildGridItemAdditions(
    BuildContext context, {
    required Post post,
    required BooruConfigAuth config,
  }) => const PostGridItemAdditions(
    quickActionButton: Text('native feed card'),
  );
}

final class _FeedMultiSelectionBuilder extends BaseBooruBuilder {
  _FeedMultiSelectionBuilder({required this.config, this.onBuild});

  final BooruConfigAuth config;
  final ValueChanged<BooruConfigAuth>? onBuild;

  @override
  MultiSelectionActionsBuilder get multiSelectionActionsBuilder =>
      (context, controller, postController) {
        onBuild?.call(config);
        return DefaultMultiSelectionActions(
          postController: postController,
          extraActions: (_) => const [Text('native bulk mutation')],
        );
      };
}
