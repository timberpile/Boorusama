import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/boorus/defaults/widgets.dart';
import 'package:boorusama/boorus/danbooru/posts/search/widgets.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/boorus/danbooru/posts/search/src/widgets/search_series_grid.dart';
import 'package:boorusama/core/posts/pools/pool_grid_item.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/feed_post_thumbnail.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/danbooru.dart' as api;
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/pools/bookmarks.dart';
import 'package:boorusama/boorus/danbooru/pools/details/src/pool_detail_page.dart';
import 'package:boorusama/boorus/danbooru/pools/pool/types.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_multi_selection.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_pool_card.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_scroll_view.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_search_bar.dart';
import 'package:boorusama/core/bookmarks/src/widgets/pool_bookmark_button.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:selection_mode/selection_mode.dart';

import '../core/bookmarks/pool_bookmark_test_utils.dart';
import '../core/search/following_topics/topic_test_utils.dart';
import '../support/fakes/memory_repositories.dart';
import 'support/app_flow_driver.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/fake_image_dio.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets(
    'normal Search collapses confirmed Series and explicit pool Search stays expanded',
    (tester) async {
      final setup = await _mount(tester, realSearch: true);
      final harness = setup.harness;
      harness.booruBackend.enqueuePosts(
        page: 1,
        query: 'malberrybush',
        posts: harness.booruBackend.posts,
      );
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('malberrybush');
      final seriesGrid = find.byType(SearchSeriesGrid);
      await harness.pumpUntilFound(tester, seriesGrid);
      final card = find.descendant(
        of: seriesGrid,
        matching: find.byType(PoolGridItem),
      );
      await harness.pumpUntilFound(tester, card);
      expect(tester.widget<PoolGridItem>(card).total, 20);
      expect(tester.widget<PoolGridItem>(card).category, 'Series');
      expect(find.text('Series · 2/20'), findsOneWidget);
      final grid = tester.widget<SearchSeriesGrid>(seriesGrid);
      expect(grid.controller.items.map((p) => p.id), [101, 102]);
      expect(
        setup.adapter.requests.where((r) => r.path == '/pools.json'),
        hasLength(1),
      );
      final selection = SelectionMode.of(tester.element(card));
      await tester.longPress(card);
      await harness.settle(tester);
      expect(card, findsNothing);
      expect(grid.controller.items, hasLength(2));
      selection.disable();
      await harness.settle(tester);
      expect(card, findsOneWidget);
      await tester.tap(card);
      await harness.pumpUntilFound(tester, find.byType(PoolDetailPage));
      expect(
        find.descendant(
          of: find.byType(PoolDetailPage),
          matching: find.byType(SearchSeriesGrid),
        ),
        findsNothing,
      );
      await tester.pageBack();
      await harness.settle(tester);
      expect(card, findsOneWidget);
      expect(
        tester.widget<SearchSeriesGrid>(seriesGrid).controller.items,
        hasLength(2),
      );
      await driver.clearSelectedSearchTags();
      await driver.submitSearch('pool:10');
      await harness.settle(tester);
      expect(
        find.descendant(of: seriesGrid, matching: find.byType(PoolGridItem)),
        findsNothing,
      );
      expect(
        tester.widget<SearchSeriesGrid>(seriesGrid).controller.items,
        hasLength(2),
      );
      expect(
        setup.adapter.requests.where((r) => r.path == '/pools.json'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'normal Search admits bounded later metadata without moving the visible anchor',
    (tester) async {
      final setup = await _mount(
        tester,
        realSearch: true,
        seriesMembers: [114, 113],
      );
      final harness = setup.harness;
      final config = harness.booruBackend.config;
      final posts = [
        for (var id = 190; id >= 101; id--)
          testPoolPost(id).post.copyWith(origin: postOriginFromConfig(config)),
      ];
      harness.booruBackend.enqueuePosts(page: 1, query: 'cat', posts: posts);
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('cat');
      final series = find.byType(SearchSeriesGrid);
      await harness.pumpUntilFound(tester, series);
      final grid = tester.widget<PostGrid<Post>>(
        find.ancestor(of: series, matching: find.byType(PostGrid<Post>)),
      );
      final scroll = grid.scrollController!;
      final card = find.descendant(
        of: series,
        matching: find.byType(PoolGridItem),
      );
      for (var step = 0; step < 30 && card.evaluate().isEmpty; step++) {
        scroll.jumpTo(
          (scroll.offset + 250).clamp(0, scroll.position.maxScrollExtent),
        );
        await harness.settle(tester);
      }
      expect(card, findsOneWidget);
      expect(grid.controller.items, hasLength(90));
      final offset = scroll.offset;
      await harness.settle(tester);
      expect(scroll.offset, offset);
      final requests = setup.adapter.requests
          .where((r) => r.path == '/pools.json')
          .toList();
      expect(requests.length, lessThan(10));
      for (final request in requests) {
        expect(
          (request.queryParameters['search[post_ids_include_any]'] as String)
              .split(' ')
              .length,
          lessThanOrEqualTo(40),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rolling Search groups across pages, preserves holes and raw selection indices',
    (tester) async {
      final setup = await _mount(
        tester,
        realSearch: true,
        seriesMembers: [101, 103, 105],
      );
      final harness = setup.harness;
      List<Post> posts(List<int> ids) => [
        for (final id in ids)
          testPoolPost(id).post.copyWith(
            origin: postOriginFromConfig(harness.booruBackend.config),
          ),
      ];
      harness.booruBackend.enqueuePosts(
        page: 1,
        query: 'cat',
        posts: posts([101, 102, 103]),
        hasMore: true,
      );
      harness.booruBackend.enqueuePosts(
        page: 2,
        query: 'cat',
        posts: posts([104, 105]),
        hasMore: false,
      );
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('cat');
      await harness.pumpUntilFound(tester, find.text('Series · 3/20'));
      final series = find.byType(SearchSeriesGrid);
      final controller = tester.widget<SearchSeriesGrid>(series).controller;
      expect(controller.page, 2);
      expect(controller.hasMore, isFalse);
      expect(controller.items.map((p) => p.id), [101, 102, 103, 104, 105]);
      expect(postTile(102), findsOneWidget);
      expect(postTile(104), findsOneWidget);
      final grid = tester.widget<PostGrid<Post>>(
        find.ancestor(of: series, matching: find.byType(PostGrid<Post>)),
      );
      expect(grid.scrollController!.tagMap.keys, containsAll([0, 1, 2, 3, 4]));
      final card = find.descendant(
        of: series,
        matching: find.byType(PoolGridItem),
      );
      final cover = tester.widget<FeedPostThumbnail>(
        find.descendant(of: card, matching: find.byType(FeedPostThumbnail)),
      );
      expect(cover.post.id, 101);
      final selection = SelectionMode.of(tester.element(card));
      await tester.longPress(card);
      await harness.settle(tester);
      expect(
        selection
            .selectedFrom(controller.items.toList())
            .toList()
            .map((p) => p.id)
            .toList(),
        [101],
      );
      expect(card, findsNothing);
      expect(
        tester
            .widget<PostGridSliver<Post>>(
              find.descendant(
                of: series,
                matching: find.byType(PostGridSliver<Post>),
              ),
            )
            .displayItemCount,
        5,
      );
      await harness.pumpUntilComplete(
        tester,
        grid.scrollController!.scrollToIndex(4),
      );
      expect(postTile(105), findsOneWidget);
      selection.replaceSelection(3);
      expect(
        selection
            .selectedFrom(controller.items.toList())
            .toList()
            .map((p) => p.id)
            .toList(),
        [104],
      );
      selection.disable();
      grid.scrollController!.jumpTo(0);
      await harness.settle(tester);
      expect(find.text('Series · 3/20'), findsOneWidget);
      expect(
        identical(
          grid.scrollController!.tagMap[0],
          grid.scrollController!.tagMap[4],
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'collapsed viewport fill stops after three pages and manual Load More can continue',
    (tester) async {
      final setup = await _mount(tester, realSearch: true);
      final harness = setup.harness;
      for (var page = 1; page <= 6; page++) {
        harness.booruBackend.enqueuePosts(
          page: page,
          query: 'cat',
          posts: [
            for (var id = 99 + page * 2; id <= 100 + page * 2; id++)
              testPoolPost(id).post.copyWith(
                origin: postOriginFromConfig(harness.booruBackend.config),
              ),
          ],
          hasMore: page < 6,
        );
      }
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('cat');
      await harness.pumpUntilFound(tester, find.text('Series · 8/20'));
      await harness.settle(tester);
      final controller = tester
          .widget<SearchSeriesGrid>(find.byType(SearchSeriesGrid))
          .controller;
      expect(controller.page, 4);
      expect(controller.hasMore, isTrue);
      expect(controller.loadingMore, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(
        controller.page,
        4,
        reason: 'rebuilds cannot renew an automatic request budget',
      );
      final load = find.widgetWithText(FilledButton, 'Load More');
      expect(load, findsOneWidget);
      // The bottom navigation overlaps the footer center on the small phone.
      // Tap its visible upper edge, exercising the actual manual button.
      await tester.tapAt(tester.getTopLeft(load) + const Offset(60, 4));
      await harness.pumpUntilFound(tester, find.text('Series · 12/20'));
      await harness.settle(tester);
      expect(controller.page, 6);
      expect(controller.hasMore, isFalse);
      expect(controller.items, hasLength(12));
      expect(tester.takeException(), isNull);
    },
  );

  for (final error in <BooruError>[
    ServerError(httpStatusCode: 503, message: 'unavailable'),
    RequestCancelledError(),
  ]) {
    testWidgets(
      'collapsed viewport fill stops on ${error.runtimeType} and explicit retry retains raw state',
      (tester) async {
        final setup = await _mount(tester, realSearch: true);
        final harness = setup.harness;
        harness.booruBackend.enqueuePosts(
          page: 1,
          query: 'cat',
          posts: harness.booruBackend.posts,
          hasMore: true,
        );
        final gate = harness.booruBackend.enqueuePostGate(
          siteUrl: harness.booruBackend.config.url,
          query: 'cat',
          page: 2,
        );
        final driver = AppFlowDriver(tester: tester, harness: harness);
        await driver.openSearch();
        await driver.submitSearch('cat');
        await harness.pumpUntil(
          tester,
          () => harness.booruBackend.requests
              .whereType<FakeBooruPostRequest>()
              .any((r) => r.query == 'cat' && r.page == 2),
        );
        final controller = tester
            .widget<SearchSeriesGrid>(find.byType(SearchSeriesGrid))
            .controller;
        gate.completeFailure(error);
        await harness.pumpUntil(
          tester,
          () => controller.errors.value != null && !controller.loadingMore,
        );
        expect(controller.errors.value, error);
        expect(controller.page, 1);
        expect(controller.items.map((p) => p.id), [101, 102]);
        final count = harness.booruBackend.requests
            .whereType<FakeBooruPostRequest>()
            .where((r) => r.query == 'cat')
            .length;
        await tester.pump(const Duration(seconds: 2));
        expect(
          harness.booruBackend.requests.whereType<FakeBooruPostRequest>().where(
            (r) => r.query == 'cat',
          ),
          hasLength(count),
        );
        harness.booruBackend.enqueuePosts(
          page: 2,
          query: 'cat',
          posts: [
            testPoolPost(103).post.copyWith(
              origin: postOriginFromConfig(harness.booruBackend.config),
            ),
          ],
          hasMore: false,
        );
        await harness.pumpUntilComplete(tester, controller.fetchMore());
        expect(controller.errors.value, isNull);
        expect(controller.page, 2);
        expect(controller.hasMore, isFalse);
        expect(find.text('Series · 3/20'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'query replacement cancels an in-flight fill without publishing old posts or restarting its cycle',
    (tester) async {
      final setup = await _mount(tester, realSearch: true);
      final harness = setup.harness;
      final backend = harness.booruBackend;
      backend.enqueuePosts(
        page: 1,
        query: 'cat',
        posts: backend.posts,
        hasMore: true,
      );
      final gate = backend.enqueuePostGate(
        siteUrl: backend.config.url,
        query: 'cat',
        page: 2,
      );
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('cat');
      await harness.pumpUntil(
        tester,
        () => backend.requests.whereType<FakeBooruPostRequest>().any(
          (r) => r.query == 'cat' && r.page == 2,
        ),
      );
      backend.enqueuePosts(
        page: 1,
        query: 'dog',
        posts: [
          for (final id in [201, 202])
            testPoolPost(id).post
                .copyWith(origin: postOriginFromConfig(backend.config)),
        ],
        hasMore: false,
      );
      await driver.clearSelectedSearchTags();
      await driver.submitSearch('dog');
      await harness.pumpUntilFound(tester, postTile(201));
      gate.completeSuccess(
        PostResult(posts: [testPoolPost(103).post], total: null, hasMore: true),
      );
      await harness.settle(tester);
      final current = tester.widget<SearchSeriesGrid>(
        find.byType(SearchSeriesGrid),
      );
      expect(current.query, 'dog');
      expect(current.controller.items.map((p) => p.id), [201, 202]);
      expect(
        backend.requests.whereType<FakeBooruPostRequest>().where(
          (r) => r.query == 'cat' && r.page > 1,
        ),
        hasLength(1),
      );
      expect(find.byType(PoolGridItem), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'paginated Search keeps a collapsed page without automatic viewport fill',
    (tester) async {
      final setup = await _mount(tester, realSearch: true);
      final harness = setup.harness;
      await harness.pumpUntilComplete(
        tester,
        setup.container
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (s) => s.copyWith(
                listing: s.listing.copyWith(pageMode: PageMode.paginated),
              ),
            ),
      );
      harness.booruBackend.enqueuePosts(
        page: 1,
        query: 'cat',
        posts: harness.booruBackend.posts,
        hasMore: true,
      );
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('cat');
      await harness.pumpUntilFound(tester, find.text('Series · 2/20'));
      await harness.settle(tester);
      final controller = tester
          .widget<SearchSeriesGrid>(find.byType(SearchSeriesGrid))
          .controller;
      expect(controller.pageMode, PageMode.paginated);
      expect(controller.page, 1);
      expect(controller.hasMore, isTrue);
      expect(
        harness.booruBackend.requests.whereType<FakeBooruPostRequest>().where(
          (r) => r.query == 'cat' && r.page > 1,
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Search waits for bounded initial metadata and timeout keeps built raw tiles stable',
    (tester) async {
      final setup = await _mount(tester, realSearch: true, holdSeries: true);
      final harness = setup.harness;
      harness.booruBackend.enqueuePosts(
        page: 1,
        query: 'cat',
        posts: harness.booruBackend.posts,
      );
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('cat');
      await harness.pumpUntil(
        tester,
        () => setup.adapter.membershipRequested.isCompleted,
      );
      final grid = find.byType(SearchSeriesGrid);
      final controller = tester.widget<SearchSeriesGrid>(grid).controller;
      expect(controller.refreshing, isTrue);
      expect(controller.items, isEmpty);
      expect(
        setup.adapter.requests.where((r) => r.path == '/pools.json'),
        hasLength(1),
      );
      await tester.pump(const Duration(seconds: 11));
      await harness.settle(tester);
      expect(controller.refreshing, isFalse);
      expect(controller.items, hasLength(2));
      expect(
        find.descendant(of: grid, matching: find.byType(PoolGridItem)),
        findsNothing,
      );
      final bounds = tester.getRect(postTile(101));
      setup.adapter.seriesGate!.complete();
      await harness.settle(tester);
      expect(tester.getRect(postTile(101)), bounds);
      expect(
        find.descendant(of: grid, matching: find.byType(PoolGridItem)),
        findsNothing,
      );
      expect(
        setup.adapter.requests.where((r) => r.path == '/pools.json').length,
        lessThanOrEqualTo(2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Series whole and partial labels stay bounded at 320dp ${scale}x',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final setup = await _mount(tester, realSearch: true);
        final harness = setup.harness;
        harness.booruBackend.enqueuePosts(
          page: 1,
          query: 'cat',
          posts: [
            for (var id = 101; id <= 120; id++)
              testPoolPost(id).post.copyWith(
                origin: postOriginFromConfig(harness.booruBackend.config),
              ),
          ],
        );
        final driver = AppFlowDriver(tester: tester, harness: harness);
        await driver.openSearch();
        await driver.submitSearch('cat');
        await harness.pumpUntilFound(tester, find.text('Series · 20'));
        expect(find.text('Series · 20/20'), findsNothing);
        final card = find.byType(PoolGridItem);
        expect(
          tester.getRect(find.text('Series · 20')).right,
          lessThanOrEqualTo(tester.getRect(card).right),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'an existing persisted cover resolves High and changes quality without changing the reference',
    (tester) async {
      final setup = await _mount(
        tester,
        seedReference: true,
        legacyCover: true,
      );
      final harness = setup.harness;
      final library = await harness.pumpUntilComplete(
        tester,
        setup.container.read(bookmarkProvider.future),
      );
      final saved = library.pools.single;
      expect(saved.cover, isNull);
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      final notifier = setup.container.read(settingsNotifierProvider.notifier);
      Future<void> quality(ImageQuality value) => harness.pumpUntilComplete(
        tester,
        notifier.updateWith(
          (settings) => settings.copyWith(
            listing: settings.listing.copyWith(imageQuality: value),
          ),
        ),
      );
      final image = find.descendant(
        of: find.byType(BookmarkPoolCoverImage),
        matching: find.byType(BooruImage),
      );
      await quality(ImageQuality.high);
      await harness.pumpUntil(
        tester,
        () =>
            image.evaluate().length == 1 &&
            tester.widget<BooruImage>(image).imageUrl ==
                harness.booruBackend.posts.first.sampleImageUrl,
      );
      expect(
        tester.widget<BooruImage>(image).config,
        harness.booruBackend.config.auth,
      );
      final calls = harness.booruBackend.requests.length;
      await quality(ImageQuality.low);
      await harness.settle(tester);
      expect(
        tester.widget<BooruImage>(image).imageUrl,
        harness.booruBackend.posts.first.thumbnailImageUrl,
      );
      await quality(ImageQuality.high);
      await harness.settle(tester);
      expect(
        tester.widget<BooruImage>(image).imageUrl,
        harness.booruBackend.posts.first.sampleImageUrl,
      );
      expect(harness.booruBackend.requests.length, calls);
      expect(
        setup.container.read(bookmarkProvider).requireValue.pools.single,
        saved,
      );
      expect(setup.posts.bookmarks, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('individual Bookmarks never request Series grouping metadata', (
    tester,
  ) async {
    final setup = await _mount(tester, seedPosts: true, seedPostCount: 90);
    final harness = setup.harness;
    await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
    await harness.settle(tester);
    final grid = tester.widget<PostGrid<Post>>(
      find.descendant(
        of: find.byType(BookmarkScrollView),
        matching: find.byType(PostGrid<Post>),
      ),
    );
    expect(grid.controller.items, hasLength(90));
    expect(find.byType(BookmarkPoolCard), findsNothing);
    grid.scrollController!.jumpTo(1200);
    await harness.settle(tester);
    await harness.pumpUntilComplete(tester, grid.controller.refresh());
    expect(grid.controller.items, hasLength(90));
    expect(
      setup.adapter.requests.where((r) => r.path == '/pools.json'),
      isEmpty,
    );
    expect(find.byType(BookmarkPoolCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('re-adding a Pool supersedes an older removal Undo', (
    tester,
  ) async {
    final setup = await _mount(tester, seedReference: true);
    final notifier = setup.container.read(bookmarkProvider.notifier);
    final library = await setup.harness.pumpUntilComplete(
      tester,
      setup.container.read(bookmarkProvider.future),
    );
    final saved = library.pools.single;
    final removal = await setup.harness.pumpUntilComplete(
      tester,
      notifier.removePostsFromGroup(
        setup.harness.booruBackend.config.auth,
        const [],
        poolGroupA,
        poolLocalIds: {saved.localId},
      ),
    );
    expect(setup.container.read(bookmarkProvider).requireValue.pools, isEmpty);
    await setup.harness.pumpUntilComplete(
      tester,
      notifier.togglePoolTarget(saved, groupId: poolGroupA),
    );
    final rejected = await setup.harness.pumpUntilComplete(
      tester,
      notifier
          .undoRemoval(removal)
          .then((_) => false, onError: (Object _) => true),
    );
    expect(rejected, isTrue);
    final current = setup.container
        .read(bookmarkProvider)
        .requireValue
        .pools
        .single;
    expect(current.localId, saved.localId);
    expect(current.groupIds, {poolGroupA});
    expect(setup.posts.bookmarks, isEmpty);
  });

  testWidgets(
    'bounded indexing can finish across frames before saving one reference',
    (tester) async {
      final setup = await _mount(tester, holdIndex: true);
      final harness = setup.harness;
      unawaited(
        setup.container
            .read(routerProvider)
            .push(
              '/danbooru/pools/10',
              extra: (pool: _pool(), config: harness.booruBackend.config),
            ),
      );
      await harness.pumpUntilFound(tester, find.byType(PoolBookmarkButton));
      await harness.settle(tester);
      await tester.tap(find.byType(PoolBookmarkButton));
      await harness.pumpUntil(
        tester,
        () => harness.booruBackend.requests
            .whereType<FakeBooruPostRequest>()
            .any((r) => r.query == 'pool:10' && r.pending),
      );
      await tester.pump();
      await tester.pump();
      expect(
        setup.container.read(bookmarkProvider).requireValue.pools,
        isEmpty,
      );
      setup.indexGate!.completeSuccess(
        PostResult(posts: harness.booruBackend.posts, total: 2),
      );
      await harness.pumpUntilFound(tester, find.byType(BookmarkGroupPicker));
      await harness.settle(tester);
      await tester.tap(find.text('Pool target'));
      await harness.pumpUntil(
        tester,
        () =>
            setup.container.read(bookmarkProvider).valueOrNull?.pools.length ==
            1,
        description: 'completed asynchronous Pool bookmark',
      );
      expect(setup.posts.bookmarks, isEmpty);
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'explicit refresh replaces a stored tag union without bookmarking members',
    (tester) async {
      final setup = await _mount(tester, seedReference: true);
      final harness = setup.harness;
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      await tester.tap(
        find.byType(BookmarkPoolCard),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await harness.pumpUntilFound(tester, find.text('Refresh metadata'));
      await tester.tap(find.text('Refresh metadata'));
      await harness.pumpUntil(
        tester,
        () =>
            setup.container
                .read(bookmarkProvider)
                .valueOrNull
                ?.pools
                .single
                .tags
                .contains('cat') ??
            false,
      );
      final saved = setup.container
          .read(bookmarkProvider)
          .requireValue
          .pools
          .single;
      expect(saved.tags, containsAll(['cat', 'landscape']));
      expect(saved.tags, isNot(contains('alpha')));
      expect(saved.groupIds, {poolGroupA});
      expect(saved.localId, testPool().localId);
      expect(setup.posts.bookmarks, isEmpty);
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Pool Bookmark uses the shared picker and stays one selectable entry at ${scale}x',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final setup = await _mount(tester);
        final harness = setup.harness;
        final container = setup.container;
        unawaited(
          container
              .read(routerProvider)
              .push(
                '/danbooru/pools/10',
                extra: (pool: _pool(), config: harness.booruBackend.config),
              ),
        );
        await harness.pumpUntilFound(tester, find.byType(PoolBookmarkButton));
        await harness.settle(tester);
        if (scale == 1) {
          await tester.tap(find.byType(PoolBookmarkButton));
        } else {
          await tester.longPress(find.byType(PoolBookmarkButton));
        }
        await harness.pumpUntilFound(tester, find.byType(BookmarkGroupPicker));
        expect(tester.takeException(), isNull);
        await harness.settle(tester);
        await tester.scrollUntilVisible(
          find.text('Pool target'),
          100,
          scrollable: find
              .descendant(
                of: find.byType(BookmarkGroupPicker),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await harness.settle(tester);
        await tester.tap(find.text('Pool target'));
        await harness.pumpUntil(
          tester,
          () => container.read(bookmarkProvider).valueOrNull?.pools.length == 1,
        );
        expect(setup.posts.bookmarks, isEmpty);
        final saved = container
            .read(bookmarkProvider)
            .requireValue
            .pools
            .single;
        expect(saved.groupIds, {poolGroupA});
        expect(saved.total, 20);
        expect(saved.coverage, PoolTagCoverage.partial);
        expect(saved.tags, containsAll(['cat', 'landscape']));
        await AppFlowDriver(tester: tester, harness: harness).goBack();
        await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
        await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
        expect(find.text('Series · 20'), findsOneWidget);
        await harness.settle(tester);
        expect(tester.takeException(), isNull);
        await tester.longPress(find.byType(BookmarkPoolCard));
        await harness.settle(tester);
        final selection = SelectionMode.of(
          tester.element(find.byType(BookmarkPoolCard)),
        );
        expect(selection.selection, {0});
        expect(find.text('Download'), findsNothing);
        expect(setup.posts.bookmarks, isEmpty);
        selection.disable();
        await harness.settle(tester);

        final beforeMetadata = setup.adapter.requests.length;
        final field = find
            .descendant(
              of: find.byType(BookmarkSearchBar),
              matching: find.byType(TextField),
            )
            .first;
        await tester.tap(field);
        await tester.enterText(field, 'cat -landscape');
        harness.keyboard.sync();
        expect(harness.keyboard.isShown, isTrue);
        expect(tester.takeException(), isNull);
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await harness.pumpUntil(
          tester,
          () => find.byType(BookmarkPoolCard).evaluate().isEmpty,
        );
        expect(setup.adapter.requests, hasLength(beforeMetadata));
        expect(
          container.read(bookmarkProvider).requireValue.pools,
          hasLength(1),
        );
      },
    );
  }

  testWidgets(
    'a Pool card opens the full remote Pool under its origin while another profile is active',
    (tester) async {
      final setup = await _mount(
        tester,
        initialOtherProfile: true,
        seedReference: true,
      );
      final harness = setup.harness;
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      await tester.tap(find.byType(BookmarkPoolCard));
      await harness.pumpUntilFound(tester, find.byType(PoolDetailPage));
      final page = tester.widget<PoolDetailPage>(find.byType(PoolDetailPage));
      expect(page.pool.id, 10);
      expect(page.pool.postIds, hasLength(20));
      final scoped = ProviderScope.containerOf(
        tester.element(find.byType(PoolDetailPage)),
        listen: false,
      );
      expect(
        scoped.read(currentReadOnlyBooruConfigProvider).id,
        harness.booruBackend.config.id,
      );
      final detail = setup.adapter.requests
          .where((r) => r.path == '/pools/10.json')
          .single;
      expect(detail.uri.host, Uri.parse(harness.booruBackend.config.url).host);
      expect(
        detail.uri.host,
        isNot(Uri.parse(harness.booruBackend.configB.url).host),
      );
      expect(setup.posts.bookmarks, isEmpty);
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'individual Posts and an explicit Series remain independent selectable Bookmarks',
    (tester) async {
      final setup = await _mount(tester, seedReference: true, seedPosts: true);
      final harness = setup.harness;
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      final grid = tester.widget<PostGrid<Post>>(
        find
            .descendant(
              of: find.byType(BookmarkScrollView),
              matching: find.byType(PostGrid<Post>),
            )
            .first,
      );
      await harness.pumpUntilComplete(tester, grid.controller.refresh());
      await harness.settle(tester);
      expect(find.byType(BookmarkPoolCard), findsOneWidget);
      expect(grid.controller.items, hasLength(3));
      expect(
        setup.adapter.requests.where((r) => r.path == '/pools.json'),
        isEmpty,
      );
      await tester.longPress(find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      final selection = SelectionMode.of(
        tester.element(find.byType(BookmarkPoolCard)),
      );
      expect(selection.selection, hasLength(1));
      final helpIcon = find
          .descendant(
            of: find.byType(BookmarkScrollView),
            matching: find.byIcon(Icons.info_outline),
          )
          .first;
      Focus.of(tester.element(helpIcon)).requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await harness.settle(tester);
      expect(selection.selection, hasLength(4));
      await tester.tap(find.byType(MultiSelectPopupButton).first);
      await harness.pumpUntilFound(
        tester,
        find.byType(BookmarkMultiSelectionMenu),
      );
      final menu = tester.widget<BookmarkMultiSelectionMenu>(
        find.byType(BookmarkMultiSelectionMenu),
      );
      expect(menu.posts, hasLength(3));
      expect(menu.pools, hasLength(1));
      expect(setup.posts.bookmarks, hasLength(3));
      await tester.tap(find.text('Remove From'));
      await harness.pumpUntilFound(tester, find.text('Pool target'));
      await harness.settle(tester);
      await tester.tap(find.text('Pool target'));
      await harness.pumpUntil(tester, () {
        final state = setup.container.read(bookmarkProvider).valueOrNull;
        return state != null && state.items.isEmpty && state.pools.isEmpty;
      });
      expect(selection.isActive, isFalse);
      await harness.pumpUntilFound(tester, find.text('Undo'));
      await tester.tap(find.text('Undo'));
      await harness.pumpUntil(tester, () {
        final state = setup.container.read(bookmarkProvider).valueOrNull;
        return state?.items.length == 3 && state?.pools.length == 1;
      });
      await harness.settle(tester);
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    },
  );
}

DanbooruPool _pool() => DanbooruPool(
  id: 10,
  postIds: [for (var id = 101; id <= 120; id++) id],
  category: DanbooruPoolCategory.series,
  description: '',
  postCount: 20,
  name: 'Series_10',
  createdAt: DateTime.utc(2000),
  updatedAt: DateTime.utc(2026),
);

Future<
  ({
    HeadlessAppHarness harness,
    ProviderContainer container,
    MemoryBookmarkRepository posts,
    _PoolAdapter adapter,
    FakeBooruPostGate? indexGate,
  })
>
_mount(
  WidgetTester tester, {
  bool initialOtherProfile = false,
  bool realSearch = false,
  bool seedReference = false,
  bool legacyCover = false,
  bool seedPosts = false,
  bool holdIndex = false,
  bool holdSeries = false,
  int seedPostCount = 3,
  List<int>? seriesMembers,
}) async {
  final backend = FakeBooruBackend();
  final indexGate = holdIndex
      ? backend.enqueuePostGate(
          siteUrl: backend.config.url,
          query: 'pool:10',
          page: 1,
        )
      : null;
  if (!holdIndex)
    backend.enqueuePosts(page: 1, query: 'pool:10', posts: backend.posts);
  backend.enqueuePosts(
    page: 1,
    query: 'pool:10 order:created_at',
    posts: [backend.posts.first],
  );
  backend.enqueuePosts(
    page: 1,
    query: 'pool:10 order:created_at_asc',
    posts: [backend.posts.last],
  );
  backend.enqueuePosts(
    page: 1,
    query: 'id:${[for (var id = 101; id <= 120; id++) id].join(',')}',
    posts: backend.posts,
  );
  final posts = MemoryBookmarkRepository();
  final groups = BookmarkGroupRepositoryHive(
    MemoryBox<BookmarkGroupHiveObject>(),
    organizationBox: MemoryBox<dynamic>(),
  );
  await groups.createGroup('Pool target', id: poolGroupA);
  if (seedReference)
    await groups.writePoolBookmarks([
      PoolBookmark.fromJson({
        ...testPool()
            .copyWith(origin: postOriginFromConfig(backend.config))
            .toJson(),
        if (legacyCover) ...{
          'coverUrl': backend.posts.first.thumbnailImageUrl,
          'coverPolicy': poolCoverPolicy(backend.config, {}),
        },
      }),
    ]);
  if (seedPosts) {
    final bookmarks = [
      for (var id = 101; id < 101 + seedPostCount; id++)
        (() {
          final old = testPoolPost(id);
          final post = old.post.copyWith(
            origin: postOriginFromConfig(backend.config),
          );
          return old.copyWith(
            post: post,
            snapshot: const StoredPostCodec().encode(post),
          );
        })(),
    ];
    await posts.addBookmarkWithBookmarks(bookmarks);
    await groups.addBookmarks(poolGroupA, bookmarks.map((b) => b.id).toSet());
  }
  final adapter = _PoolAdapter(
    holdSeries: holdSeries,
    seriesMembers: seriesMembers,
  );
  final runtime = backend.createRuntime(
    configs: [backend.config, backend.configB],
    initialConfig: initialOtherProfile ? backend.configB : backend.config,
    bookmarkRepository: posts,
  );
  final harness = await HeadlessAppHarness.mount(
    tester,
    runtime: runtime,
    booruBackend: backend,
    phone: TestPhone.smallPortrait,
    additionalOverrides: [
      if (realSearch)
        booruBuilderProvider.overrideWith(
          (ref, auth) => _SeriesSearchBuilder(),
        ),
      deterministicImageDioOverride(),
      deterministicFaviconDioOverride(),
      bookmarkGroupRepoProvider.overrideWith((_) async => groups),
      blacklistTagsProvider.overrideWith((_, _) async => <String>{}),
      poolBookmarkCapabilityProvider.overrideWith(
        (ref, _) => DanbooruPoolBookmarks(ref),
      ),
      danbooruClientProvider.overrideWith((ref, config) {
        final dio = Dio(BaseOptions(baseUrl: config.url))
          ..httpClientAdapter = adapter;
        ref.onDispose(dio.close);
        return api.DanbooruClient(baseUrl: config.url, dio: dio);
      }),
    ],
  );
  await harness.pumpUntilFound(
    tester,
    postTile(initialOtherProfile ? 201 : 101),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PostGrid<Post>).first),
    listen: false,
  );
  return (
    harness: harness,
    container: container,
    posts: posts,
    adapter: adapter,
    indexGate: indexGate,
  );
}

class _PoolAdapter implements HttpClientAdapter {
  _PoolAdapter({bool holdSeries = false, this.seriesMembers})
    : seriesGate = holdSeries ? Completer<void>() : null;
  final Completer<void>? seriesGate;
  final List<int>? seriesMembers;
  final requests = <RequestOptions>[];
  final membershipRequested = Completer<void>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final json = {
      'id': 10,
      'name': 'Series_10',
      'category': 'series',
      'post_count': 20,
      'post_ids': seriesMembers ?? [for (var id = 101; id <= 120; id++) id],
      'created_at': '2000-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };
    if (options.path == '/pools.json') {
      if (!membershipRequested.isCompleted) membershipRequested.complete();
      await seriesGate?.future;
      return ResponseBody.fromString(
        jsonEncode([json]),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('.json'))
      return ResponseBody.fromString(
        jsonEncode(json),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    return ResponseBody.fromString(
      '<div id="description"></div>',
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html'],
      },
    );
  }

  @override
  void close({bool force = false}) {
    if (seriesGate != null && !seriesGate!.isCompleted) seriesGate!.complete();
  }
}

Future<void> _drainNotifications(WidgetTester tester) async {
  dismissAllToast(showAnim: false);
  // Drain notification lifetimes using the widget's controlled clock.
  await tester.pump(const Duration(seconds: 6));
}

class _SeriesSearchBuilder extends BaseBooruBuilder {
  @override
  SearchPageBuilder get searchPageBuilder =>
      (context, params) => DanbooruSearchPage(params: params);
}
