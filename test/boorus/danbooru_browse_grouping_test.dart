import 'dart:async';

import 'package:material_symbols_icons/symbols.dart';

import 'package:boorusama/boorus/danbooru/danbooru_builder.dart';
import 'package:boorusama/boorus/danbooru/home/widgets.dart';
import 'package:boorusama/boorus/danbooru/home/src/most_search_tag_list.dart';
import 'package:boorusama/boorus/danbooru/posts/search/src/widgets/search_series_grid.dart';
import 'package:boorusama/boorus/danbooru/tags/trending/providers.dart';
import 'package:boorusama/boorus/danbooru/tags/user_metatags/providers.dart';
import 'package:boorusama/core/announcements/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_capability.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/home/widgets.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/pools/pool_grid_item.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/tags/tag/types.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../core/bookmarks/pool_bookmark_test_utils.dart';
import '../core/search/following_topics/following_topic_test_utils.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets(
      'Browse groups Related and Series and exposes Group Related Posts at width $width',
      (tester) async {
        final f = _Browse();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          f.dispose();
        });
        await f.mount(tester, width);
        await tester.pumpAndSettle();
        expect(find.byType(LatestView), findsOneWidget);
        expect(find.byType(SearchSeriesGrid), findsOneWidget);
        expect(
          tester
              .widgetList<PoolGridItem>(find.byType(PoolGridItem))
              .map((card) => card.kind),
          [PoolGridItemKind.related, PoolGridItemKind.series],
        );
        expect(f.controller.grouping.supported, isTrue);
        expect(f.controller.grouping.value, isTrue);
        final fetches = f.repository.queries.length;
        final admissions = f.capability.calls;
        await f.toggle(tester, false);
        expect(find.byType(PoolGridItem), findsOneWidget);
        expect(
          tester.widget<PoolGridItem>(find.byType(PoolGridItem)).kind,
          PoolGridItemKind.series,
        );
        expect(f.controller.items, hasLength(5));
        expect(find.byIcon(Symbols.photo_library), findsNWidgets(2));
        expect(f.repository.queries, hasLength(fetches));
        expect(f.capability.calls, admissions);
        await f.toggle(tester, true);
        expect(find.byType(PoolGridItem), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'Browse query changes preserve the global preference and explicit family queries stay raw at width $width',
      (tester) async {
        final f = _Browse();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          f.dispose();
        });
        await f.mount(tester, width);
        await tester.pumpAndSettle();
        await f.toggle(tester, false);
        await f.search(tester, 'cat', desktop: width > 1000);
        await tester.pumpAndSettle();
        expect(f.repository.queries.last, 'cat');
        expect(
          tester.widget<SearchSeriesGrid>(find.byType(SearchSeriesGrid)).query,
          'cat',
        );
        expect(f.controller.grouping.value, isFalse);
        expect(find.byType(PoolGridItem), findsOneWidget);
        final admissions = f.capability.calls;
        await f.search(tester, 'parent:10', desktop: width > 1000);
        await tester.pumpAndSettle();
        expect(f.repository.queries.last, 'parent:10');
        expect(find.byType(PoolGridItem), findsNothing);
        expect(f.controller.grouping.supported, isFalse);
        expect(f.capability.calls, admissions);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'Browse waits for bounded Series membership before fixing its first tiles',
    (tester) async {
      final f = _Browse();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        f.dispose();
      });
      f.capability.gate = Completer<void>();
      await f.mount(tester, 320);
      expect(f.capability.calls, 1);
      expect(f.controller.refreshing, isTrue);
      expect(f.controller.items, isEmpty);
      f.capability.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(PoolGridItem), findsNWidgets(2));
      expect(f.capability.calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

class _Browse {
  _Browse({bool relatedEnabled = true}) {
    config = BooruConfig.fromJson({
      ...testProfile.toJson(),
      'url': 'https://danbooru.donmai.us',
      'booruId': poolOrigin().booruType.id,
      'booruIdHint': poolOrigin().booruType.id,
    });
    repository = _Repository(
      [
            testRelatedPost(11, parent: 10),
            testRelatedPost(21),
            testRelatedPost(99),
            testRelatedPost(12, parent: 10),
            testRelatedPost(22),
          ]
          .map((post) => post.copyWith(origin: postOriginFromConfig(config)))
          .toList(),
    );
    harness = FollowingTopicHarness(
      settings: Settings.defaultSettings.copyWith(
        groupRelatedPosts: relatedEnabled,
      ),
      profiles: [config],
      booruBuilder: (_) => DanbooruBuilder(),
      overrides: [
        originAwarePostRepoProvider.overrideWith((ref, _) => repository),
        poolBookmarkCapabilityProvider.overrideWith((ref, _) => capability),
        appAnnouncementsProvider.overrideWith((ref) => Future.value([])),
        colorSchemeProvider.overrideWithValue(
          ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        trendingTagsProvider.overrideWith((ref, _) => Future.value([])),
      ],
    );
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => CurrentBooruConfigScope(
            config: config,
            child: Scaffold(
              body: Builder(
                builder: (context) =>
                    DanbooruBuilder().homeViewBuilder(context),
              ),
            ),
          ),
        ),
      ],
    );
    harness.router = router;
  }
  late final BooruConfig config;
  late final FollowingTopicHarness harness;
  late final _Repository repository;
  late final GoRouter router;
  final capability = _Capability();
  late PostGridController<Post> controller;

  Future<void> mount(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await harness.pump(
      tester,
      MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
        builder: themeBuilder,
      ),
    );
    controller = tester
        .widget<PostGrid<Post>>(find.byType(PostGrid<Post>))
        .controller;
  }

  Future<void> toggle(WidgetTester tester, bool enabled) async {
    await tester.tap(
      find.descendant(
        of: find.byType(PostGridConfigIconButton),
        matching: find.byType(KurumiPopupMenuButton),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Options'));
    await tester.pumpAndSettle();
    expect(find.text('Group Related Posts'), findsOneWidget);
    expect(
      tester
          .widget<KurumiSwitchListTile>(find.byType(KurumiSwitchListTile))
          .value,
      !enabled,
    );
    await tester.tap(find.text('Group Related Posts'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(PostGridActionSheet))).pop();
    await tester.pumpAndSettle();
    expect(controller.grouping.value, enabled);
  }

  Future<void> search(
    WidgetTester tester,
    String query, {
    required bool desktop,
  }) async {
    if (desktop) {
      final bar = tester.widget<SliverHomeSearchBar>(
        find.byType(SliverHomeSearchBar).first,
      );
      bar.selectedTagController!.clear();
      bar.selectedTagController!.addTag(
        TagSearchItem.fromString(
          query,
          extractor: harness.container.read(
            danbooruMetatagExtractorProvider(config.auth),
          ),
        ),
      );
      bar.selectedTagString!.value = query;
      bar.onSearch();
    } else {
      tester
          .widget<PostGrid<Post>>(find.byType(PostGrid<Post>))
          .scrollController!
          .jumpTo(0);
      await tester.pumpAndSettle();
      tester
          .widget<MostSearchTagList>(
            find.byType(MostSearchTagList, skipOffstage: false),
          )
          .onSelected(
            Tag.noCount(name: query, category: Tag.empty().category),
            true,
          );
    }
  }

  void dispose() {
    if (capability.gate case final gate? when !gate.isCompleted) {
      gate.complete();
    }
    router.dispose();
    harness.dispose();
  }
}

class _Repository extends EmptyPostRepository {
  _Repository(this.posts);
  final List<Post> posts;
  final queries = <String>[];
  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) {
    queries.add(tags);
    return TaskEither.right(
      PostResult(posts: posts, total: posts.length, hasMore: false),
    );
  }

  @override
  PostsOrError<Post> getPostsFromController(
    SearchTagSet controller,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) =>
      getPosts(controller.rawTagsString, page, limit: limit, options: options);
}

class _Capability implements PoolBookmarkCapability {
  var calls = 0;
  Completer<void>? gate;
  @override
  Future<Map<int, List<RemoteBookmarkPool>>> getBookmarkSeries(
    BooruConfig config,
    List<Post> posts,
  ) async {
    calls++;
    await gate?.future;
    return {
      for (final post in posts)
        post.id: post.id == 21 || post.id == 22
            ? [
                const RemoteBookmarkPool(
                  id: 42,
                  title: 'Series',
                  category: BookmarkedPoolCategory.series,
                  total: 2,
                ),
              ]
            : [],
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
