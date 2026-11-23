import 'package:boorusama/boorus/danbooru/posts/search/src/widgets/search_series_grid.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_capability.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/posts/details/src/routes/details_route_context.dart';
import 'package:boorusama/core/posts/details/src/routes/viewer_navigation_scope.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/pools/pool_grid_item.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/selection/ordered_selection_controller.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../bookmarks/pool_bookmark_test_utils.dart';
import '../../search/following_topics/following_topic_test_utils.dart';

void main() {
  for (final textScale in [1.0, 2.0]) {
    testWidgets(
      'View Options aligns the Related label with other rows at scale $textScale',
      (tester) async {
        final f = _Fixture(relatedEnabled: false, customListing: true);
        addTearDown(f.dispose);
        await f.mount(tester, textScale: textScale);
        await f.openOptions(tester);
        final relatedLeft = tester
            .getRect(find.text('Group Related Posts'))
            .left;
        final rows = tester.widgetList<KurumiSettingsTile>(
          find.descendant(
            of: find.byType(PostGridActionSheet),
            matching: find.byWidgetPredicate(
              (widget) => widget is KurumiSettingsTile,
            ),
          ),
        );
        expect(rows, hasLength(4));
        for (final row in rows) {
          expect(
            relatedLeft,
            closeTo(tester.getRect(find.byWidget(row.title)).left, .01),
          );
        }
        expect(tester.takeException(), isNull);
        f.closeOptions(tester);
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('Related defaults off and global updates leave Series grouped', (
    tester,
  ) async {
    final f = _Fixture(relatedEnabled: false, customListing: true);
    addTearDown(f.dispose);
    await f.mount(tester);
    expect(f.controller.grouping.value, isFalse);
    expect(
      tester.widget<PoolGridItem>(find.byType(PoolGridItem)).kind,
      PoolGridItemKind.series,
    );
    final requests = f.capability.requests;
    final raw = f.controller.items.toList();
    f.selection.enable(initialSelected: [0]);
    await tester.pumpAndSettle();
    await f.harness.container
        .read(settingsNotifierProvider.notifier)
        .updateWith(
          (settings) => settings.copyWith(groupRelatedPosts: true),
        );
    await tester.pumpAndSettle();
    expect(find.byType(PoolGridItem), findsNothing);
    expect(f.controller.items.toList(), raw);
    f.selection.disable();
    await tester.pumpAndSettle();
    expect(find.byType(PoolGridItem), findsNWidgets(2));
    await f.toggle(tester, false);
    expect(
      tester.widget<PoolGridItem>(find.byType(PoolGridItem)).kind,
      PoolGridItemKind.series,
    );
    expect(
      f.harness.container.read(settingsProvider).groupRelatedPosts,
      isFalse,
    );
    expect(f.controller.items.toList(), raw);
    expect(f.fetches, 1);
    expect(f.capability.requests, requests);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Group Related Posts persists only Related without fetching and survives selection and Back',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.mount(tester);
      final settings = f.harness.container.read(settingsProvider);
      expect(f.controller.grouping.value, isTrue);
      expect(
        tester
            .widgetList<PoolGridItem>(find.byType(PoolGridItem))
            .map((item) => item.kind),
        [PoolGridItemKind.related, PoolGridItemKind.series],
      );
      expect(find.byKey(const ValueKey('pool-source-icon')), findsNothing);
      for (final card in tester.widgetList<PoolGridItem>(
        find.byType(PoolGridItem),
      )) {
        expect(card.sourceIcon, isNull);
      }
      final requests = f.capability.requests;
      await f.toggle(tester, false);
      expect(find.byType(PoolGridItem), findsOneWidget);
      expect(
        tester.widget<PoolGridItem>(find.byType(PoolGridItem)).kind,
        PoolGridItemKind.series,
      );
      for (final post in f.posts.where(
        (post) => post.id != 21 && post.id != 22,
      )) {
        expect(find.text('raw-${post.id}'), findsOneWidget);
      }
      f.selection.enable(initialSelected: [0]);
      await tester.pumpAndSettle();
      f.selection.disable();
      await tester.pumpAndSettle();
      expect(f.controller.grouping.value, isFalse);
      await tester.tap(find.text('raw-11'));
      await tester.pumpAndSettle();
      expect(f.opened!.entries!.whereType<GroupViewerEntry>(), hasLength(1));
      expect(f.opened!.entries!.whereType<PostViewerEntry>(), hasLength(3));
      f.router.pop();
      await tester.pumpAndSettle();
      expect(f.controller.grouping.value, isFalse);
      expect(find.byType(PoolGridItem), findsOneWidget);
      await f.toggle(tester, true);
      expect(find.byType(PoolGridItem), findsNWidgets(2));
      f.selection.enable(initialSelected: [0]);
      await tester.pumpAndSettle();
      expect(find.byType(PoolGridItem), findsNothing);
      f.selection.disable();
      await tester.pumpAndSettle();
      expect(find.byType(PoolGridItem), findsNWidgets(2));
      expect(f.controller.items.toList(), f.posts);
      expect(f.fetches, 1);
      expect(f.capability.requests, requests);
      expect(f.harness.container.read(settingsProvider), settings);
      await f.toggle(tester, false);
      f.change(() => f.query = 'new-query');
      await tester.pumpAndSettle();
      expect(f.controller.grouping.value, isFalse);
      expect(find.byType(PoolGridItem), findsOneWidget);
      expect(
        f.harness.container.read(settingsProvider).groupRelatedPosts,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('unsupported and explicit-family timelines omit the switch', (
    tester,
  ) async {
    final f = _Fixture();
    addTearDown(f.dispose);
    f.query = 'parent:10';
    await f.mount(tester);
    expect(find.byType(PoolGridItem), findsNothing);
    await f.openOptions(tester);
    expect(find.text('Group Related Posts'), findsNothing);
    expect(find.byType(PostGridActionSheet), findsOneWidget);
    f.closeOptions(tester);
    await tester.pumpAndSettle();
    // A plain timeline/controller has never opted into grouped presentation.
    final ordinary = PostGridController<Post>(
      fetcher: (_) => TaskEither.right(
        PostResult(posts: f.posts, total: null, hasMore: false),
      ),
      blacklistedTagsFetcher: () async => {},
      mountedChecker: () => true,
      duplicateTracker: PostDuplicateTracker<Post>(),
      onError: (_) {},
    );
    addTearDown(ordinary.dispose);
    expect(ordinary.grouping.supported, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'duplicate-only pages retain a bounded fill cycle and manual continuation',
    (tester) async {
      final f = _Fixture(repeatedPages: true);
      addTearDown(f.dispose);
      await f.mount(tester);
      for (var page = 0; page < 3; page++) {
        await tester.pump(f.controller.debounceDuration);
        await tester.pumpAndSettle();
      }
      expect(f.requestedPages, [1, 2, 3, 4]);
      expect(f.controller.items, hasLength(4));
      expect(find.byType(PoolGridItem), findsOneWidget);
      final first = tester.widget<PoolGridItem>(find.byType(PoolGridItem));
      expect(first.total, isNull);
      expect(find.text('Load More'), findsOneWidget);
      await tester.pump();
      expect(f.requestedPages, [1, 2, 3, 4]);
      await tester.tap(find.text('Load More'));
      for (var page = 0; page < 4; page++) {
        await tester.pump(f.controller.debounceDuration);
        await tester.pumpAndSettle();
      }
      expect(f.requestedPages, [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(f.controller.items, hasLength(8));
      expect(find.byType(PoolGridItem), findsOneWidget);
      expect(f.controller.hasMore, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'toggle keeps a mid-scroll raw anchor at narrow width and enlarged text',
    (tester) async {
      final f = _Fixture(long: true);
      addTearDown(f.dispose);
      await f.mount(tester);
      final scrolling = f.scroll.scrollToIndex(
        50,
        preferPosition: AutoScrollPosition.begin,
        duration: const Duration(milliseconds: 1),
      );
      await tester.pumpAndSettle();
      await scrolling;
      // Natural Masonry heights can leave a partially visible item above the
      // row crossing y=100. Preserve the actual first item below the header.
      List<MapEntry<int, AutoScrollTagState>> visibleAnchors() {
        final visible = f.scroll.tagMap.entries.where((entry) {
          final box = entry.value.context.findRenderObject()! as RenderBox;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          return rect.bottom > 56 && rect.top < 900;
        }).toList();
        visible.sort((a, b) {
          final aBox = a.value.context.findRenderObject()! as RenderBox;
          final bBox = b.value.context.findRenderObject()! as RenderBox;
          final byTop = aBox
              .localToGlobal(Offset.zero)
              .dy
              .compareTo(bBox.localToGlobal(Offset.zero).dy);
          return byTop == 0 ? a.key.compareTo(b.key) : byTop;
        });
        return visible;
      }

      final anchor = visibleAnchors().first;
      final index = anchor.key;
      final before = (anchor.value.context.findRenderObject()! as RenderBox)
          .localToGlobal(Offset.zero)
          .dy;
      await f.toggle(tester, false);
      final after =
          (f.scroll.tagMap[index]!.context.findRenderObject()! as RenderBox)
              .localToGlobal(Offset.zero)
              .dy;
      expect(after, closeTo(before, 2));
      expect(f.scroll.offset, greaterThan(0));
      // Expansion can expose another Post on the same first visible row.
      // Preserve that row's earliest raw Post when grouping is enabled again.
      final visible = visibleAnchors();
      final regroupIndex = visible.first.key;
      final regroupTop =
          (visible.first.value.context.findRenderObject()! as RenderBox)
              .localToGlobal(Offset.zero)
              .dy;
      await f.toggle(tester, true);
      final grouped =
          (f.scroll.tagMap[regroupIndex]!.context.findRenderObject()!
                  as RenderBox)
              .localToGlobal(Offset.zero)
              .dy;
      expect(grouped, closeTo(regroupTop, 2));
      expect(f.fetches, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'distant hidden member maps to its representative and returns to its raw anchor',
    (tester) async {
      final f = _Fixture(distant: true);
      addTearDown(f.dispose);
      await f.mount(tester);
      await f.toggle(tester, false);
      final scrolling = f.scroll.scrollToIndex(
        41,
        preferPosition: AutoScrollPosition.begin,
        duration: const Duration(milliseconds: 1),
      );
      await tester.pumpAndSettle();
      await scrolling;
      final before =
          (f.scroll.tagMap[41]!.context.findRenderObject()! as RenderBox)
              .localToGlobal(Offset.zero)
              .dy;
      await f.toggle(tester, true);
      expect(f.scroll.tagMap[41], same(f.scroll.tagMap[0]));
      expect(
        (f.scroll.tagMap[41]!.context.findRenderObject()! as RenderBox)
            .localToGlobal(Offset.zero)
            .dy,
        closeTo(before, 2),
      );
      await f.toggle(tester, false);
      expect(f.scroll.tagMap[41], isNot(same(f.scroll.tagMap[0])));
      expect(
        (f.scroll.tagMap[41]!.context.findRenderObject()! as RenderBox)
            .localToGlobal(Offset.zero)
            .dy,
        closeTo(before, 2),
      );
      expect(find.text('raw-12').hitTestable(), findsOneWidget);
      expect(f.fetches, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Fixture {
  _Fixture({
    bool long = false,
    bool repeatedPages = false,
    bool distant = false,
    bool relatedEnabled = true,
    bool customListing = false,
  }) {
    config = BooruConfig.fromJson({
      ...testProfile.toJson(),
      'url': 'https://danbooru.donmai.us',
      'booruId': poolOrigin().booruType.id,
      'booruIdHint': poolOrigin().booruType.id,
    });
    posts = [
      testRelatedPost(11, parent: 10),
      if (!repeatedPages) ...[
        testRelatedPost(12, parent: 10),
        testRelatedPost(21),
        testRelatedPost(22),
        testRelatedPost(99),
      ],
      if (long)
        for (var i = 0; i < 80; i++)
          testRelatedPost(100 + i, parent: i < 15 ? 10 : null),
    ].map((p) => p.copyWith(origin: postOriginFromConfig(config))).toList();
    if (distant) {
      posts
        ..clear()
        ..addAll(
          [
            testRelatedPost(11, parent: 10),
            for (var i = 0; i < 40; i++) testRelatedPost(100 + i),
            testRelatedPost(12, parent: 10),
            for (var i = 0; i < 40; i++) testRelatedPost(200 + i),
          ].map((p) => p.copyWith(origin: postOriginFromConfig(config))),
        );
    }
    harness = FollowingTopicHarness(
      settings: Settings.defaultSettings.copyWith(
        groupRelatedPosts: relatedEnabled,
      ),
      listingSettings: distant
          ? Settings.defaultSettings.listing.copyWith(gridSize: GridSize.large)
          : null,
      profiles: [config],
      overrides: [
        if (customListing)
          hasCustomListingSettingsProvider.overrideWithValue(true),
        poolBookmarkCapabilityProvider.overrideWith((ref, arg) => capability),
      ],
    );
    controller = PostGridController<Post>(
      fetcher: (page) {
        fetches++;
        requestedPages.add(page);
        final pagePosts = repeatedPages
            ? [
                testRelatedPost(
                  10 + page,
                  parent: 10,
                ).copyWith(origin: postOriginFromConfig(config)),
              ]
            : posts;
        return TaskEither.right(
          PostResult(
            posts: pagePosts,
            total: null,
            hasMore: repeatedPages && page < 8,
          ),
        );
      },
      blacklistedTagsFetcher: () async => {},
      mountedChecker: () => true,
      duplicateTracker: PostDuplicateTracker<Post>(),
      onError: (_) {},
    );
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => CurrentBooruConfigScope(
            config: config,
            child: StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                return Scaffold(
                  body: PostGrid<Post>(
                    controller: controller,
                    scrollController: scroll,
                    selectionModeController: selection,
                    header: const SizedBox.shrink(),
                    multiSelectActions: const SizedBox.shrink(),
                    sliverHeaders: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _OptionsHeader(controller),
                      ),
                    ],
                    itemBuilder: (context, i, scroll, hero) => AutoScrollTag(
                      key: ValueKey('raw-${controller.items.elementAt(i).id}'),
                      controller: scroll,
                      index: i,
                      child: Builder(
                        builder: (context) => TextButton(
                          onPressed: () =>
                              ViewerNavigationScope.maybeOf(context)
                                  ?.open(i, null),
                          child: Text(
                            'raw-${controller.items.elementAt(i).id}',
                          ),
                        ),
                      ),
                    ),
                    gridBuilder: (context, itemBuilder) => SearchSeriesGrid(
                      controller: controller,
                      config: config,
                      query: query,
                      itemBuilder: itemBuilder,
                      index: index,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        GoRoute(
          path: '/details',
          builder: (_, state) {
            opened = state.extra! as DetailsRouteContext;
            return const Scaffold(body: Text('viewer'));
          },
        ),
      ],
    );
    harness.router = router;
  }
  late final BooruConfig config;
  late final List<Post> posts;
  late final FollowingTopicHarness harness;
  late final PostGridController<Post> controller;
  late final GoRouter router;
  final index = SearchSeriesIndex();
  final capability = _Capability();
  final selection = OrderedSelectionController<Object>();
  final scroll = AutoScrollController();
  var query = 'artist';
  var fetches = 0;
  final requestedPages = <int>[];
  late StateSetter change;
  DetailsRouteContext? opened;

  Future<void> mount(WidgetTester tester, {double textScale = 2}) async {
    await index.loadPage(config, posts, capability);
    await ensureI18nInitialized('en-US');
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      harness.wrap(
        MaterialApp.router(
          routerConfig: router,
          builder: themeBuilder,
          theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openOptions(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(PostGridConfigIconButton),
        matching: find.byType(KurumiPopupMenuButton),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Options'));
    await tester.pumpAndSettle();
  }

  void closeOptions(WidgetTester tester) =>
      Navigator.of(tester.element(find.byType(PostGridActionSheet))).pop();
  Future<void> toggle(WidgetTester tester, bool enabled) async {
    await openOptions(tester);
    expect(find.text('Group Related Posts'), findsOneWidget);
    final toggle = tester.widget<KurumiSwitchListTile>(
      find.byType(KurumiSwitchListTile),
    );
    expect(toggle.value, !enabled);
    await tester.tap(find.text('Group Related Posts'));
    await tester.pumpAndSettle();
    closeOptions(tester);
    await tester.pumpAndSettle();
    expect(controller.grouping.value, enabled);
  }

  void dispose() {
    router.dispose();
    controller.dispose();
    selection.dispose();
    scroll.dispose();
    index.dispose();
    harness.dispose();
  }
}

class _OptionsHeader extends SliverPersistentHeaderDelegate {
  _OptionsHeader(this.controller);
  final PostGridController<Post> controller;
  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    child: Align(
      alignment: Alignment.centerRight,
      child: PostGridConfigIconButton(postController: controller),
    ),
  );
  @override
  bool shouldRebuild(_OptionsHeader oldDelegate) =>
      controller != oldDelegate.controller;
}

class _Capability implements PoolBookmarkCapability {
  var requests = 0;
  @override
  Future<Map<int, List<RemoteBookmarkPool>>> getBookmarkSeries(
    BooruConfig config,
    List<Post> posts,
  ) async {
    requests++;
    return {
      for (final p in posts)
        if (p.id == 21 || p.id == 22)
          p.id: [
            const RemoteBookmarkPool(
              id: 42,
              title: 'Series',
              category: BookmarkedPoolCategory.series,
              total: 2,
            ),
          ],
    };
  }

  @override
  Future<RemoteBookmarkPool?> getBookmarkPool(
    BooruConfig config,
    int id,
  ) async => null;
  @override
  Future<void> openBookmarkPool(
    WidgetRef ref,
    BooruConfig config,
    int id,
  ) async {}
}
