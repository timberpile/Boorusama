import 'dart:async';

import 'package:material_symbols_icons/symbols.dart';

import 'package:boorusama/boorus/danbooru/posts/post/src/danbooru_post_codec.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_capability.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/details/src/routes/details_route_context.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/post/widgets.dart';
import 'package:boorusama/core/posts/pools/pool_grid_item.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/search/following_topics/src/pages/topic_feeds_page.dart';
import 'package:boorusama/core/search/following_topics/src/types/feed_series_membership.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:selection_mode/selection_mode.dart';

import 'feed_grouping_test_utils.dart';
import 'following_topic_test_utils.dart';
import 'topic_test_utils.dart';

void main() {
  testWidgets(
    'cached feed defaults to Series only and reopens with the global Related preference',
    (tester) async {
      final f = _FeedFixture(relatedEnabled: false);
      addTearDown(f.dispose);
      await f.mount(tester);
      expect(f.cards(tester).single.kind, PoolGridItemKind.series);
      expect(find.byIcon(Symbols.photo_library), findsNWidgets(2));
      await f.toggle(tester, true);
      expect(f.cards(tester), hasLength(2));
      expect(find.byIcon(Symbols.photo_library), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await f.reopen(tester);
      expect(f.cards(tester), hasLength(2));
      await f.toggle(tester, false);
      expect(f.cards(tester).single.kind, PoolGridItemKind.series);
      await tester.pumpWidget(const SizedBox.shrink());
      await f.reopen(tester);
      expect(f.cards(tester).single.kind, PoolGridItemKind.series);
      expect(find.byIcon(Symbols.photo_library), findsNWidgets(2));
      expect(
        f.harness.container.read(settingsProvider).groupRelatedPosts,
        isFalse,
      );
      expect(f.capability.calls, isEmpty);
      expect(f.historyRequests, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'cached feed groups both types without requests at scale $scale',
      (tester) async {
        final f = _FeedFixture();
        addTearDown(f.dispose);
        await f.mount(tester, scale: scale);
        final raw = f.controller(tester).items.toList();
        expect(f.cards(tester).map((card) => card.kind), [
          PoolGridItemKind.related,
          PoolGridItemKind.series,
        ]);
        expect(f.cards(tester).first.total, isNull);
        expect(f.capability.calls, isEmpty);
        expect(f.historyRequests, 0);
        await f.toggle(tester, false);
        expect(f.cards(tester).single.kind, PoolGridItemKind.series);
        expect(f.controller(tester).items.toList(), raw);
        await tester.tap(find.byType(ImageGridItem).first);
        await tester.pumpAndSettle();
        expect(f.opened!.entries, hasLength(raw.length - 1));
        expect(f.opened!.entries!.whereType<PostViewerEntry>(), hasLength(3));
        expect(f.opened!.entries!.whereType<GroupViewerEntry>(), hasLength(1));
        f.harness.router.pop();
        await tester.pumpAndSettle();
        expect(f.controller(tester).grouping.value, isFalse);
        await f.toggle(tester, true);
        expect(f.cards(tester), hasLength(2));
        final ordinary = find.byType(ImageGridItem).first;
        await tester.ensureVisible(ordinary);
        await tester.tap(ordinary);
        await tester.pumpAndSettle();
        final opened = f.opened!;
        expect(opened.entries!.whereType<GroupViewerEntry>(), hasLength(2));
        expect(opened.entrySource!.pagination.hasMore(), isFalse);
        await opened.entrySource!.pagination.fetchMore();
        await tester.pump(f.controllerBeforeOpen!.debounceDuration);
        expect(f.historyRequests, 0);
        f.harness.router.pop();
        await tester.pumpAndSettle();
        expect(f.controller(tester).grouping.value, isTrue);
        expect(f.capability.calls, isEmpty);
        expect(f.historyRequests, 0);
        final related = find.byWidgetPredicate(
          (w) => w is PoolGridItem && w.kind == PoolGridItemKind.related,
        );
        await tester.ensureVisible(related);
        await tester.longPress(related);
        await tester.pumpAndSettle();
        expect(find.byType(PoolGridItem), findsNothing);
        final selection = SelectionMode.of(
          tester.element(find.byType(ImageGridItem).first),
        );
        expect(selection.isActive, isTrue);
        selection.disable();
        await tester.pumpAndSettle();
        expect(f.controller(tester).grouping.value, isTrue);
        expect(f.controller(tester).items.toList(), raw);
        expect(f.capability.calls, isEmpty);
        expect(f.historyRequests, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await f.reopen(tester);
        expect(f.cards(tester), hasLength(2));
        expect(f.capability.calls, isEmpty);
        expect(f.historyRequests, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'cached filtering keeps a verified singleton and never unlocks history',
    (tester) async {
      final f = _FeedFixture();
      addTearDown(f.dispose);
      await f.mount(tester);
      await tester.enterText(find.byType(TextField).first, 'only_one');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(f.controller(tester).items.map((post) => post.id), [100]);
      expect(f.cards(tester).single.kind, PoolGridItemKind.related);
      expect(f.cards(tester).single.total, isNull);
      expect(f.cards(tester).single.displayedCount, isNull);
      await f.toggle(tester, false);
      expect(find.byType(PoolGridItem), findsNothing);
      await f.toggle(tester, true);
      expect(f.cards(tester), hasLength(1));
      expect(f.capability.calls, isEmpty);
      expect(f.historyRequests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'refreshing only membership metadata reprojections cached tiles without requests',
    (tester) async {
      final f = _FeedFixture(cacheSeries: false);
      addTearDown(f.dispose);
      await f.mount(tester);
      expect(f.cards(tester), hasLength(1));
      final source = (await f.harness.repository.getById(
        f.feed.sourceIds.single,
      ))!;
      final memberships = [
        for (final id in [99, 98])
          feedMembership(source, feedGroupingPost(id), [7]),
      ];
      await f.harness.container
          .read(followingTopicsProvider.notifier)
          .runSerializedMutation(
            (repository) => repository.commitRefresh(
              SearchRefreshCommit(
                topicId: source.id,
                expectedCreatedAt: source.createdAt,
                expectedCheckpoint: source.lastSuccessfulCheckAt,
                startedAt: checkedAt.add(const Duration(hours: 1)),
                identityRetentionBoundary: checkedAt,
                baseline: false,
                discoveredPosts: const [],
                feedSeriesMemberships: {
                  for (final entry in memberships) entry.key: entry,
                },
              ),
            ),
          );
      await tester.pumpAndSettle();
      expect(f.cards(tester).map((card) => card.kind), [
        PoolGridItemKind.related,
        PoolGridItemKind.series,
      ]);
      expect(f.historyRequests, 0);
      expect(f.capability.calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'overlapping Series representative leaves the distant Related Post navigable',
    (tester) async {
      final f = _FeedFixture(overlap: true);
      addTearDown(f.dispose);
      await f.mount(tester);
      final ordinary = find.byType(ImageGridItem).first;
      await tester.ensureVisible(ordinary);
      await tester.tap(ordinary);
      await tester.pumpAndSettle();
      final entries = f.opened!.entries!;
      final groups = entries.whereType<GroupViewerEntry>().toList();
      expect(groups.map((entry) => entry.summary.reference.sourceKey), [
        'pool:7',
        'related:10',
      ]);
      expect(
        entries.whereType<PostViewerEntry>().map((entry) => entry.post.id),
        isNot(contains(60)),
      );
      expect(f.opened!.posts.map((post) => post.id), contains(60));
      expect(entries.last, isA<GroupViewerEntry>());
      expect(f.historyRequests, 0);
      expect(f.capability.calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'mixed profiles keep Series and Related groups isolated and bind every viewer entry',
    (tester) async {
      final f = _FeedFixture(mixed: true);
      addTearDown(f.dispose);
      await f.mount(tester);
      final before = f.harness.container.read(
        currentReadOnlyBooruConfigProvider,
      );
      expect(
        f.cards(tester).where((card) => card.kind == PoolGridItemKind.series),
        hasLength(2),
      );
      expect(
        f.cards(tester).where((card) => card.kind == PoolGridItemKind.related),
        hasLength(2),
      );
      await tester.tap(find.byType(PoolGridItem).first);
      await tester.pumpAndSettle();
      final entries = f.opened!.entries!;
      expect(entries, everyElement(isA<GroupViewerEntry>()));
      expect(entries.map((entry) => entry.source!.config.id), [
        feedGroupingConfig.id,
        otherGroupingConfig.id,
        feedGroupingConfig.id,
        otherGroupingConfig.id,
      ]);
      expect(
        f.harness.container.read(currentReadOnlyBooruConfigProvider),
        before,
      );
      expect(f.historyRequests, 0);
      expect(f.capability.calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'explicit history keeps successfully loaded Posts when Series lookup fails',
    (tester) async {
      final f = _FeedFixture();
      addTearDown(f.dispose);
      await f.mount(tester);
      f.capability.respond = (_) => throw StateError('metadata offline');
      await f.toggle(tester, false);
      final before = f.controller(tester).items.length;
      f.scroll(tester).jumpTo(f.scroll(tester).position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(f.historyRequests, 0);
      await tester.tap(find.byKey(const ValueKey('cached-feed-load-older')));
      await tester.pump(f.controller(tester).debounceDuration);
      await tester.pumpAndSettle();
      expect(f.historyRequests, 2);
      expect(f.capability.calls, hasLength(1));
      expect(f.controller(tester).items.length, before + 1);
      expect(f.controller(tester).items.map((post) => post.id), contains(90));
      expect(f.controller(tester).errors.value, isNull);
      expect(f.controller(tester).grouping.value, isFalse);
      expect(f.cards(tester).single.kind, PoolGridItemKind.series);
      await f.toggle(tester, true);
      expect(f.scroll(tester).tagMap[5], same(f.scroll(tester).tagMap[0]));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'source replacement rejects a pending history membership response',
    (tester) async {
      final f = _FeedFixture();
      addTearDown(f.dispose);
      await f.mount(tester);
      final pending = Completer<Map<int, List<RemoteBookmarkPool>>>();
      final entered = Completer<void>();
      f.capability.respond = (_) {
        entered.complete();
        return pending.future;
      };
      f.scroll(tester).jumpTo(f.scroll(tester).position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cached-feed-load-older')));
      await tester.pump(f.controller(tester).debounceDuration);
      await entered.future;
      await f.harness.container
          .read(followingTopicsProvider.notifier)
          .runSerializedMutation(
            (repository) => repository.saveFeed(
              id: f.feed.id,
              profileId: feedGroupingConfig.id,
              name: 'Cached',
              queries: ['dog'],
            ),
          );
      await tester.pump();
      pending.complete({
        90: [feedPool(8)],
      });
      await tester.pumpAndSettle();
      final feed = (await f.harness.repository.getFeeds()).single;
      expect(feed.posts.map(feedPostId), isNot(contains(90)));
      expect(
        feed.seriesMemberships.values.any((entry) => entry.postId == 90),
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _FeedFixture {
  _FeedFixture({
    this.mixed = false,
    this.overlap = false,
    this.cacheSeries = true,
    this.relatedEnabled = true,
  });
  final bool overlap;
  final bool cacheSeries;
  final bool relatedEnabled;
  final bool mixed;
  final capability = FeedSeriesCapability();
  late FollowingTopicHarness harness;
  late TopicFeed feed;
  var historyRequests = 0;
  DetailsRouteContext? opened;
  PostGridController<Post>? controllerBeforeOpen;

  Future<void> mount(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    harness = FollowingTopicHarness(
      settings: Settings.defaultSettings.copyWith(
        groupRelatedPosts: relatedEnabled,
      ),
      profiles: [feedGroupingConfig, otherGroupingConfig],
      postCapability: const BooruPostCapability<BooruPostData>(
        booruType: BooruType.danbooru,
        codec: DanbooruPostCodec(),
        presentation: GenericPostPresentation(),
      ),
      overrides: [
        poolBookmarkCapabilityProvider.overrideWith((_, _) => capability),
        originAwarePostRepoProvider.overrideWith(
          (_, _) => TestSearchPostRepository((_, page, _) async {
            historyRequests++;
            return Either.of(
              PostResult(
                posts: page == 1 ? [feedGroupingPost(90, parent: 10)] : [],
                total: null,
                hasMore: page == 1,
              ),
            );
          }),
        ),
      ],
    );
    if (mixed) {
      final sources = [
        await harness.repository.create(
          profileId: feedGroupingConfig.id,
          query: 'cat',
          name: null,
        ),
        await harness.repository.create(
          profileId: otherGroupingConfig.id,
          query: 'bird',
          name: null,
        ),
      ];
      const folder = '550e8400-e29b-41d4-a716-446655440003';
      await harness.repository.replaceOrganization(
        TopicOrganization(
          folders: [
            TopicFolder(
              id: folder,
              name: 'Mixed',
              feedEnabled: true,
              searchIds: sources.map((source) => source.id),
            ),
          ],
        ),
      );
      feed = (await harness.repository.ensureFolderFeed(folder))!;
      for (var i = 0; i < sources.length; i++) {
        final config = i == 0 ? feedGroupingConfig : otherGroupingConfig;
        final source = sources[i];
        final posts = [
          feedGroupingPost(100 - i * 2, config: config),
          feedGroupingPost(99 - i * 2, config: config),
          feedGroupingPost(80 - i * 2, parent: 10, config: config),
          feedGroupingPost(79 - i * 2, parent: 10, config: config),
        ];
        final memberships = [
          for (final post in posts.take(2)) feedMembership(source, post, [7]),
        ];
        await seed(source, posts, {
          for (final entry in memberships) entry.key: entry,
        });
      }
    } else {
      feed = await harness.repository.saveFeed(
        profileId: feedGroupingConfig.id,
        name: 'Cached',
        queries: ['cat'],
      );
      final source = (await harness.repository.getById(feed.sourceIds.single))!;
      final posts = [
        feedGroupingPost(100, parent: 10, tags: {'cat', 'only_one'}),
        feedGroupingPost(99),
        feedGroupingPost(98),
        feedGroupingPost(97),
        feedGroupingPost(96, parent: 10),
      ];
      if (overlap) {
        posts
          ..clear()
          ..addAll([
            feedGroupingPost(100, parent: 10),
            feedGroupingPost(99),
            for (var i = 98; i >= 70; i--) feedGroupingPost(i),
            feedGroupingPost(60, parent: 10),
          ]);
      }
      final memberships = [
        for (final post in posts.where(
          (p) => overlap ? p.id == 100 || p.id == 99 : p.id == 99 || p.id == 98,
        ))
          feedMembership(source, post, [7]),
      ];
      await seed(
        source,
        posts,
        cacheSeries
            ? {
                for (final entry in memberships) entry.key: entry,
              }
            : {},
      );
    }
    await harness.container.read(followingTopicsProvider.future);
    await reopen(tester);
  }

  Future<void> seed(
    FollowingTopic source,
    List<Post> posts,
    Map<String, FeedSeriesMembership> memberships,
  ) => harness.repository
      .commitRefresh(
        SearchRefreshCommit(
          topicId: source.id,
          expectedCreatedAt: source.createdAt,
          expectedCheckpoint: null,
          startedAt: checkedAt,
          identityRetentionBoundary: checkedAt,
          baseline: true,
          discoveredPosts: const [],
          feedPosts: [
            for (final post in posts)
              feedPostSnapshotFromPost(
                post,
                dataCodec: const DanbooruPostCodec(),
              ),
          ],
          feedSeriesMemberships: memberships,
        ),
      )
      .then((_) {});

  Future<void> reopen(WidgetTester tester) async {
    if (opened != null) opened = null;
    harness.router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              TopicFeedPage(feedId: feed.id, profileId: feed.profileId),
        ),
        GoRoute(
          path: '/details',
          builder: (_, state) {
            opened = state.extra! as DetailsRouteContext;
            return const Scaffold(body: Text('grouped feed viewer'));
          },
        ),
      ],
    );
    addTearDown(harness.router.dispose);
    await ensureI18nInitialized('en-US');
    await tester.pumpWidget(
      harness.wrap(
        MaterialApp.router(
          routerConfig: harness.router,
          builder: themeBuilder,
          theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controllerBeforeOpen = controller(tester);
  }

  PostGridController<Post> controller(WidgetTester tester) =>
      tester.widget<PostGrid<Post>>(find.byType(PostGrid<Post>)).controller;
  AutoScrollController scroll(WidgetTester tester) => tester
      .widget<PostGrid<Post>>(find.byType(PostGrid<Post>))
      .scrollController!;
  List<PoolGridItem> cards(WidgetTester tester) =>
      tester.widgetList<PoolGridItem>(find.byType(PoolGridItem)).toList();
  Future<void> toggle(WidgetTester tester, bool enabled) async {
    final icon = find.descendant(
      of: find.byType(PostGridConfigIconButton),
      matching: find.byType(KurumiPopupMenuButton),
    );
    await tester.ensureVisible(icon);
    await tester.tap(icon);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Options'));
    await tester.pumpAndSettle();
    final tile = tester.widget<KurumiSwitchListTile>(
      find.byWidgetPredicate(
        (w) =>
            w is KurumiSwitchListTile &&
            w.title is Text &&
            (w.title! as Text).data == 'Group Related Posts',
      ),
    );
    tile.onChanged!(enabled);
    Navigator.of(tester.element(find.byType(PostGridActionSheet))).pop();
    await tester.pumpAndSettle();
  }

  void dispose() => harness.dispose();
}
