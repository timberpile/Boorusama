import 'dart:async';

import 'package:kurumi/kurumi.dart';

import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/images/types.dart';

import 'package:boorusama/core/tags/categories/types.dart';

import 'package:boorusama/boorus/danbooru/artists/artist/src/pages/artist_page.dart';
import 'package:boorusama/boorus/danbooru/posts/count/providers.dart';
import 'package:boorusama/core/posts/count/types.dart';
import 'package:boorusama/boorus/danbooru/artists/artist/src/widgets/artist_identity.dart';
import 'package:boorusama/boorus/danbooru/artists/artist/src/widgets/artist_related_tags_sheet.dart';
import 'package:boorusama/boorus/danbooru/artists/urls/widgets.dart';
import 'package:boorusama/boorus/danbooru/tags/related/types.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/widgets/custom_context_menu_overlay.dart';
import 'package:flutter/services.dart';

import 'package:boorusama/boorus/danbooru/artists/artist/src/providers/artist_notifier.dart';
import 'package:boorusama/boorus/danbooru/artists/artist/src/types/artist.dart';
import 'package:boorusama/boorus/danbooru/artists/artist/src/widgets/artist_details.dart';
import 'package:boorusama/boorus/danbooru/artists/artist/src/widgets/artist_posts_header.dart';
import 'package:boorusama/boorus/danbooru/artists/urls/types.dart';
import 'package:boorusama/boorus/danbooru/tags/details/src/artist_tag_cloud.dart';
import 'package:boorusama/boorus/danbooru/wikis/providers.dart';
import 'package:boorusama/boorus/danbooru/wikis/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:boorusama/core/tags/tag/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/search/following_topics/following_topic_test_utils.dart';
import '../core/search/following_topics/topic_test_utils.dart';

void main() {
  testWidgets('artist Search keeps the originating profile and sort on Back', (
    tester,
  ) async {
    final queries = <String>[];
    final harness = FollowingTopicHarness(
      overrides: [
        danbooruArtistProvider.overrideWith(() => _Artist(_artist)),
        danbooruWikiProvider.overrideWith(() => _Wiki(_wiki)),
        danbooruRelatedTagCloudProvider.overrideWith((ref, tag) => []),
        originAwarePostRepoProvider.overrideWith(
          (ref, config) => TestSearchPostRepository((query, page, limit) async {
            queries.add(query);
            return Either.of(
              PostResult(
                posts: [
                  for (var id = 1; id <= 30; id++)
                    _MediaPost(testSearchPost(id, DateTime(2026)), 'jpg'),
                ],
                total: null,
              ),
            );
          }),
        ),
      ],
    );
    addTearDown(harness.dispose);
    SearchRouteContext? opened;
    String? query;
    harness.router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => CurrentBooruConfigScope(
            config: otherTestProfile,
            child: const Scaffold(
              body: DanbooruArtistPage(artistName: 'artist_one'),
            ),
          ),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) {
            opened = state.extra! as SearchRouteContext;
            query = state.uri.queryParameters[kInitialQueryKey];
            return const Scaffold(body: Text('Separate Search'));
          },
        ),
      ],
    );
    addTearDown(harness.router.dispose);
    await harness.pump(tester, const SizedBox.shrink());
    await tester.pumpWidget(
      harness.wrap(
        MaterialApp.router(
          theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
          routerConfig: harness.router,
          builder: themeBuilder,
        ),
      ),
    );
    await pumpArtistGrid(tester);
    await tester.ensureVisible(find.text('Popular'));
    await tester.tap(find.text('Popular'));
    await pumpArtistGrid(tester);
    final controller = tester
        .widget<PostGrid<Post>>(
          find.byType(PostGrid<Post>),
        )
        .controller;
    expect(queries.last, contains('order:score'));
    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('0 posts'), findsNothing);
    expect(find.text('30'), findsOneWidget);
    final vertical = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .last;
    final position = tester.state<ScrollableState>(vertical).position;
    position.jumpTo(
      (position.pixels + tester.getCenter(find.text('Search')).dy - 200).clamp(
        0,
        position.maxScrollExtent,
      ),
    );
    await tester.pump();
    final artistOffset = position.pixels;
    final requestsBefore = queries.length;
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(opened?.config, otherTestProfile);
    expect(opened?.originatingTopicId, isNull);
    expect(query, 'artist_one');
    harness.router.pop();
    await pumpArtistGrid(tester);
    expect(
      tester
          .widget<DanbooruArtistPostsHeader>(
            find.byType(DanbooruArtistPostsHeader),
          )
          .category,
      TagFilterCategory.popular,
    );
    expect(queries, hasLength(requestsBefore));
    expect(position.pixels, artistOffset);
    expect(find.byType(PostScope<Post>), findsOneWidget);
    expect(
      tester.widget<PostGrid<Post>>(find.byType(PostGrid<Post>)).controller,
      same(controller),
    );
    expect(harness.container.read(selectedTestProfileProvider), testProfile);
  });

  for (final available in [true, false]) {
    testWidgets('artist details omit missing metadata ($available)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = FollowingTopicHarness(
        overrides: [
          danbooruRelatedTagCloudProvider.overrideWith((ref, tag) => []),
          danbooruArtistProvider.overrideWith(
            () => _Artist(available ? _artist : DanbooruArtist.empty()),
          ),
          danbooruWikiProvider.overrideWith(
            () => _Wiki(available ? _wiki : null),
          ),
        ],
      );
      addTearDown(harness.dispose);
      await harness.container.read(followingTopicsProvider.future);
      await harness.pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: DanbooruArtistDetails(artistName: 'artist_one'),
          ),
        ),
      );
      expect(find.text('Follow'), findsNothing);
      expect(
        find.text('Aliases 2'),
        available ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Socials'),
        available ? findsOneWidget : findsNothing,
      );
      expect(find.text('Wiki'), available ? findsOneWidget : findsNothing);
      if (available) {
        expect(find.text('user ID 123').hitTestable(), findsNothing);
        await tester.tap(find.byTooltip('Show All (4)'));
        await tester.pumpAndSettle();
        expect(find.text('user ID 123').hitTestable(), findsOneWidget);
        await tester.tap(find.byTooltip('Show Less'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<DanbooruArtistUrlChips>(
                find.byType(DanbooruArtistUrlChips),
              )
              .singleRow,
          isTrue,
        );
        expect(find.text('another name'), findsNothing);
        await tester.tap(find.text('Aliases 2'));
        await tester.pumpAndSettle();
        expect(find.text('another name'), findsOneWidget);
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        await tester.tap(find.text('another name'));
        await tester.pump();
        expect(copied, 'another_name');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
        await tester.tap(find.text('Aliases 2'));
        await tester.pumpAndSettle();
        expect(find.text('another name'), findsNothing);
      }
      expect(find.text('Browse Posts'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Socials only offers expansion when its single row overflows', (
    tester,
  ) async {
    final artist = DanbooruArtist(
      id: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      isBanned: false,
      groupName: '',
      isDeleted: false,
      otherNames: const [],
      name: 'artist_one',
      urls: const [
        DanbooruArtistUrl(url: 'https://x.com/artist_a', isActive: true),
        DanbooruArtistUrl(url: 'https://x.com/artist_b', isActive: true),
      ],
    );
    final harness = FollowingTopicHarness(
      overrides: [
        danbooruArtistProvider.overrideWith(() => _Artist(artist)),
        danbooruWikiProvider.overrideWith(() => _Wiki(null)),
        danbooruRelatedTagCloudProvider.overrideWith((ref, tag) => []),
      ],
    );
    addTearDown(harness.dispose);
    Widget details(double width) => Scaffold(
      body: SizedBox(
        width: width,
        child: const DanbooruArtistDetails(artistName: 'artist_one'),
      ),
    );
    await harness.pump(tester, details(700));
    await tester.pumpAndSettle();
    expect(find.text('Socials'), findsOneWidget);
    expect(find.byTooltip('Show All (2)'), findsNothing);
    expect(find.byTooltip('Show Less'), findsNothing);
    expect(find.byType(OutlinedButton), findsNWidgets(2));
    expect(find.text('External Profiles'), findsNothing);
    expect(find.textContaining('Known Names'), findsNothing);
    await harness.pump(tester, details(160));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show All (2)'), findsOneWidget);
    expect(find.text('Show All (2)'), findsNothing);
    expect(
      find.descendant(
        of: find.byTooltip('Show All (2)'),
        matching: find.byIcon(Symbols.chevron_right),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Show All (2)'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DanbooruArtistUrlChips>(find.byType(DanbooruArtistUrlChips))
          .singleRow,
      isFalse,
    );
    expect(find.byTooltip('Show Less'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byTooltip('Show Less'),
        matching: find.byIcon(Symbols.expand_more),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Show Less'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DanbooruArtistUrlChips>(find.byType(DanbooruArtistUrlChips))
          .singleRow,
      isTrue,
    );
    expect(find.byTooltip('Show Less'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('artist controls and aliases fit narrow enlarged layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = FollowingTopicHarness(
      overrides: [
        danbooruRelatedTagCloudProvider.overrideWith((ref, tag) => []),
        danbooruArtistProvider.overrideWith(() => _Artist(_artist)),
        danbooruWikiProvider.overrideWith(() => _Wiki(_wiki)),
      ],
    );
    addTearDown(harness.dispose);
    await harness.container.read(followingTopicsProvider.future);
    await harness.pump(
      tester,
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const DanbooruArtistDetails(artistName: 'artist_one'),
                DanbooruArtistPostsHeader(
                  artistName: 'artist_one',
                  category: TagFilterCategory.newest,
                  onCategoryChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aliases 2'));
    await tester.pump();
    await tester.ensureVisible(find.text('Search'));
    expect(find.text('Newest'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 400.0, 1200.0]) {
    testWidgets('complete artist page fits width $width at enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final queries = <String>[];
      final harness = FollowingTopicHarness(
        overrides: [
          danbooruArtistProvider.overrideWith(() => _Artist(_artist)),
          danbooruWikiProvider.overrideWith(() => _Wiki(_wiki)),
          danbooruRelatedTagCloudProvider.overrideWith(
            (ref, tag) => _relatedTags,
          ),
          originAwarePostRepoProvider.overrideWith(
            (ref, config) =>
                TestSearchPostRepository((query, page, limit) async {
                  queries.add(query);
                  return Either.of(const PostResult(posts: <Post>[], total: 0));
                }),
          ),
        ],
      );
      addTearDown(harness.dispose);
      await harness.pump(
        tester,
        MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: const TextScaler.linear(2),
            viewInsets: const EdgeInsets.only(bottom: 240),
          ),
          child: const Scaffold(
            body: DanbooruArtistPage(
              artistName: 'a_very_long_artist_name_漢字_アーティスト',
            ),
          ),
        ),
      );
      await pumpArtistGrid(tester);
      await tester.scrollUntilVisible(
        find.text('Search'),
        180,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await tester.scrollUntilVisible(
        find.text('Popular').hitTestable(),
        100,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await tester.tap(find.text('Popular'));
      await pumpArtistGrid(tester);
      expect(queries, hasLength(2));
      expect(find.text('Posts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'resizing phone and desktop retains the grid and expanded names',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var requests = 0;
      final harness = FollowingTopicHarness(
        overrides: [
          danbooruArtistProvider.overrideWith(() => _Artist(_artist)),
          danbooruWikiProvider.overrideWith(() => _Wiki(_wiki)),
          danbooruRelatedTagCloudProvider.overrideWith((ref, tag) => []),
          originAwarePostRepoProvider.overrideWith(
            (ref, config) =>
                TestSearchPostRepository((query, page, limit) async {
                  requests++;
                  return Either.of(const PostResult(posts: <Post>[], total: 0));
                }),
          ),
        ],
      );
      addTearDown(harness.dispose);
      await harness.pump(
        tester,
        const Scaffold(body: DanbooruArtistPage(artistName: 'artist_one')),
      );
      await pumpArtistGrid(tester);
      final controller = tester
          .widget<PostGrid<Post>>(find.byType(PostGrid<Post>))
          .controller;
      await tester.tap(find.text('Aliases 2'));
      await tester.pump();
      expect(find.text('another name'), findsOneWidget);
      tester.view.physicalSize = const Size(1200, 900);
      await tester.pump();
      await pumpArtistGrid(tester);
      expect(
        tester.widget<PostGrid<Post>>(find.byType(PostGrid<Post>)).controller,
        same(controller),
      );
      expect(requests, 1);
      expect(find.text('another name'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 900);
      await tester.pump();
      await pumpArtistGrid(tester);
      expect(requests, 1);
      expect(find.text('another name'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Wiki and sheet tag searches retain the originating profile', (
    tester,
  ) async {
    final harness = FollowingTopicHarness(
      overrides: [
        danbooruArtistProvider.overrideWith(() => _Artist(_artist)),
        danbooruWikiProvider.overrideWith(() => _Wiki(_wiki)),
        danbooruRelatedTagCloudProvider.overrideWith(
          (ref, tag) => _relatedTags,
        ),
      ],
    );
    addTearDown(harness.dispose);
    Object? wikiConfig;
    SearchRouteContext? search;
    String? query;
    harness.router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, state) => CurrentBooruConfigScope(
            config: otherTestProfile,
            child: const CustomContextMenuOverlay(
              child: Scaffold(
                body: DanbooruArtistDetails(artistName: 'artist_one'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/danbooru/wiki_pages/:name',
          builder: (_, state) {
            wikiConfig = state.extra;
            return const Scaffold(body: Text('Wiki destination'));
          },
        ),
        GoRoute(
          path: '/search',
          builder: (_, state) {
            search = state.extra! as SearchRouteContext;
            query = state.uri.queryParameters[kInitialQueryKey];
            return const Scaffold(body: Text('Tag Search destination'));
          },
        ),
      ],
    );
    addTearDown(harness.router.dispose);
    await harness.pump(tester, const SizedBox.shrink());
    await tester.pumpWidget(
      harness.wrap(
        MaterialApp.router(routerConfig: harness.router, builder: themeBuilder),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wiki'));
    await tester.pumpAndSettle();
    expect(wikiConfig, otherTestProfile);
    harness.router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Tags 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();
    expect(query, 'alpha');
    expect(search?.config, otherTestProfile);
    expect(search?.originatingTopicId, isNull);
    expect(harness.container.read(selectedTestProfileProvider), testProfile);
  });

  testWidgets(
    'a video-only page gets a separate newest still without changing the grid',
    (tester) async {
      final requests = <(String, int, int?)>[];
      final harness = FollowingTopicHarness(
        overrides: [
          danbooruArtistProvider.overrideWith(() => _Artist(_artist)),
          danbooruWikiProvider.overrideWith(() => _Wiki(null)),
          danbooruRelatedTagCloudProvider.overrideWith((ref, tag) => []),
          originAwarePostRepoProvider.overrideWith((ref, config) {
            expect(config, otherTestProfile);
            return TestSearchPostRepository((query, page, limit) async {
              requests.add((query, page, limit));
              return Either.of(
                PostResult(
                  posts: query.contains('filetype:')
                      ? [testSearchPost(42, DateTime(2026))]
                      : [_MediaPost(testSearchPost(1, DateTime(2026)), 'mp4')],
                  total: null,
                ),
              );
            });
          }),
        ],
      );
      addTearDown(harness.dispose);
      await harness.pump(
        tester,
        CurrentBooruConfigScope(
          config: otherTestProfile,
          child: const Scaffold(
            body: DanbooruArtistPage(artistName: 'artist_one'),
          ),
        ),
      );
      await pumpArtistGrid(tester);
      await tester.pumpAndSettle();
      final banner = tester
          .widget<ArtistIdentity>(find.byType(ArtistIdentity))
          .banner;
      expect(banner.post?.id, 42);
      final controller = tester
          .widget<PostGrid<Post>>(find.byType(PostGrid<Post>))
          .controller;
      expect(controller.allItems.single.id, 1);
      expect(controller.allItems.single.isVideo, isTrue);
      expect(controller.page, 1);
      expect(requests, [
        ('artist_one', 1, null),
        ('artist_one filetype:jpg,png,webp,avif -animated', 1, 20),
      ]);
      expect(harness.container.read(selectedTestProfileProvider), testProfile);
    },
  );

  test(
    'banner searches past videos and animated posts in newest results',
    () async {
      final still = testSearchPost(1, DateTime(2026));
      final controller = PostGridController<Post>(
        fetcher: (_) => TaskEither.right(
          PostResult(
            posts: [
              _MediaPost(testSearchPost(3, DateTime(2026)), 'mp4'),
              _MediaPost(testSearchPost(2, DateTime(2026)), 'gif'),
              still,
            ],
            total: 3,
          ),
        ),
        blacklistedTagsFetcher: () async => {},
        duplicateTracker: PostDuplicateTracker<Post>(),
        mountedChecker: () => true,
        onError: (_) {},
      );
      final banner = ArtistBannerSnapshot()..attach(controller);
      addTearDown(banner.dispose);
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(banner.post?.id, 1);
      expect(controller.allItems, hasLength(3));
    },
  );

  test(
    'banner follows filtered newest results and survives popular sorting',
    () async {
      var results = [
        testSearchPost(3, DateTime(2026)),
        testSearchPost(2, DateTime(2025)),
      ];
      var requests = 0;
      final controller = PostGridController<Post>(
        fetcher: (_) {
          requests++;
          return TaskEither.right(
            PostResult(posts: results, total: results.length),
          );
        },
        blacklistedTagsFetcher: () async => {},
        duplicateTracker: PostDuplicateTracker<Post>(),
        mountedChecker: () => true,
        onError: (_) {},
      );
      final banner = ArtistBannerSnapshot()..attach(controller);
      await controller.refresh();
      expect(banner.post?.id, 3);
      banner.newest = false;
      results = [testSearchPost(1, DateTime(2024))];
      await controller.refresh();
      expect(banner.post?.id, 3);
      expect(requests, 2);
      await controller.setBlacklistedTags({'blocked_tag'});
      expect(banner.post, isNull);
      banner.newest = true;
      results = [];
      await controller.refresh();
      expect(banner.post, isNull);
      banner.dispose();
      controller.dispose();
    },
  );

  testWidgets(
    'banner uses the grid thumbnail settings and skips animated media',
    (tester) async {
      final source = testSearchPost(42, DateTime(2026));
      final banner = ArtistBannerSnapshot()..post = source;
      addTearDown(banner.dispose);
      const settings = GridThumbnailSettings(
        imageQuality: ImageQuality.low,
        animatedPostsDefaultState: AnimatedPostsDefaultState.static,
        gridSize: GridSize.tiny,
      );
      final generator = _ThumbnailGenerator();
      final harness = FollowingTopicHarness(
        overrides: [
          gridThumbnailSettingsProvider.overrideWith((ref, config) => settings),
          gridThumbnailUrlGeneratorProvider.overrideWith(
            (ref, config) => generator,
          ),
        ],
      );
      addTearDown(harness.dispose);
      await harness.pump(
        tester,
        Scaffold(
          body: ArtistIdentity(artistName: 'artist_one', banner: banner),
        ),
      );
      final image = tester.widget<BooruImage>(find.byType(BooruImage));
      expect(image.imageUrl, 'https://example.com/exact-grid-tier.jpg');
      expect(image.fallbackUrl, isNull);
      expect(image.placeholderUrl, isNull);
      expect(image.errorWidget, isA<ColoredBox>());
      expect(generator.settings, same(settings));
      expect(generator.post, same(source));
      for (final format in ['gif', 'mp4']) {
        banner.post = _MediaPost(source, format);
        banner.notifyListeners();
        await tester.pump();
        expect(find.byType(BooruImage), findsNothing);
      }
    },
  );

  testWidgets('long related tags keep global counts visible at enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const name = 'a_very_long_related_tag_that_must_fit_at_enlarged_text';
    final tag = DanbooruRelatedTagItem(
      tag: name,
      category: TagCategory.general(),
      postCount: 900000,
      jaccardSimilarity: 0,
      cosineSimilarity: 0,
      overlapCoefficient: 0,
      frequency: 0,
    );
    final harness = FollowingTopicHarness(
      overrides: [
        danbooruRelatedTagCloudProvider.overrideWith((ref, artist) => [tag]),
      ],
    );
    addTearDown(harness.dispose);
    await harness.pump(
      tester,
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
        child: Scaffold(
          body: ArtistRelatedTagsSheet(
            tags: [tag],
            initialSort: ArtistRelatedTagSort.count,
            onSortChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final count = tester.getRect(find.text('900K'));
    final label = tester.getRect(find.text(name.replaceAll('_', ' ')));
    final chip = tester.getRect(find.byType(ActionChip));
    expect(label.right, lessThan(count.left));
    expect(count.right, lessThanOrEqualTo(chip.right));
    expect(chip.right, lessThanOrEqualTo(320));
    expect(chip.top, greaterThanOrEqualTo(0));
    expect(chip.bottom, lessThanOrEqualTo(640));
    expect(find.byTooltip('900000 posts with this tag'), findsOneWidget);
    await tester.tap(find.text('A–Z'));
    await tester.pumpAndSettle();
    expect(find.text('900K'), findsOneWidget);
    expect(find.byType(ActionChip).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'related sheet offers both sorts with DTO totals and no extra requests',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final countQueries = <List<String>>[];
      var relatedQueries = 0;
      final harness = FollowingTopicHarness(
        overrides: [
          danbooruPostCountRepoProvider.overrideWith(
            (ref, config) => PostCountRepositoryBuilder(
              countTags: (tags) async {
                countQueries.add(tags);
                return {'alpha': 8, 'zeta': 2}[tags.last];
              },
            ),
          ),
          danbooruArtistProvider.overrideWith(() => _Artist(_artist)),
          danbooruWikiProvider.overrideWith(() => _Wiki(_wiki)),
          danbooruRelatedTagCloudProvider.overrideWith(
            (ref, tag) {
              relatedQueries++;
              return _relatedTags;
            },
          ),
        ],
      );
      addTearDown(harness.dispose);
      await harness.pump(
        tester,
        const CustomContextMenuOverlay(
          child: Scaffold(
            body: DanbooruArtistDetails(artistName: 'artist_one'),
          ),
        ),
      );
      expect(countQueries, isEmpty);
      await tester.tap(find.textContaining('Tags 3'));
      await tester.pumpAndSettle();
      final sheet = find.byType(ArtistRelatedTagsSheet);
      expect(sheet, findsOneWidget);
      List<String> labels() => tester
          .widgetList<ActionChip>(
            find.descendant(of: sheet, matching: find.byType(ActionChip)),
          )
          .map(
            (chip) => tester
                .widgetList<Text>(
                  find.descendant(
                    of: find.byWidget(chip),
                    matching: find.byType(Text),
                  ),
                )
                .map((text) => text.data!)
                .join(' '),
          )
          .toList();
      expect(labels(), ['zeta 20', 'alpha 10', 'unknown']);
      expect(countQueries, isEmpty);
      expect(relatedQueries, 1);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byTooltip('20 posts with this tag'), findsOneWidget);
      expect(find.text('A–Z'), findsOneWidget);
      expect(find.text('By count'), findsOneWidget);
      await tester.tap(find.text('A–Z'));
      await tester.pumpAndSettle();
      expect(labels(), ['alpha 10', 'unknown', 'zeta 20']);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      await tester.tap(find.textContaining('Tags 3'));
      await tester.pumpAndSettle();
      expect(labels(), ['alpha 10', 'unknown', 'zeta 20']);
      await tester.tap(find.text('By count'));
      await tester.pumpAndSettle();
      expect(labels(), ['zeta 20', 'alpha 10', 'unknown']);
      expect(relatedQueries, 1);
      expect(countQueries, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

// The empty grid contains a looping Lottie animation, so frame settlement is
// not a completion signal. Await observable grid state under the test clock.
Future<void> pumpArtistGrid(WidgetTester tester) async {
  final deadline = tester.binding.clock.fromNowBy(const Duration(seconds: 30));
  while (tester.binding.clock.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 16));
    final grids = find.byType(PostGrid<Post>);
    if (grids.evaluate().length == 1) {
      final controller = tester.widget<PostGrid<Post>>(grids).controller;
      if (!controller.refreshing &&
          (controller.count.value != null || controller.total > 0)) {
        return;
      }
    }
  }
  fail('The artist grid did not finish its controlled repository request.');
}

class _Artist extends DanbooruArtistNotifier {
  _Artist(this.value);
  final DanbooruArtist value;
  @override
  FutureOr<DanbooruArtist> build(String arg) => value;
}

class _Wiki extends WikiNotifier {
  _Wiki(this.value);
  final Wiki? value;
  @override
  FutureOr<Wiki?> build(String arg) => value;
}

final _artist = DanbooruArtist(
  id: 1,
  createdAt: DateTime(2020),
  updatedAt: DateTime(2021),
  isBanned: false,
  groupName: '',
  isDeleted: false,
  otherNames: const ['another_name', 'a_long_alternative_artist_name'],
  name: 'artist_one',
  urls: const [
    DanbooruArtistUrl(url: 'https://www.pixiv.net/users/123', isActive: true),
    DanbooruArtistUrl(url: 'javascript:alert(1)', isActive: true),
    DanbooruArtistUrl(url: 'https://x.com/first', isActive: true),
    DanbooruArtistUrl(url: 'https://x.com/second', isActive: true),
    DanbooruArtistUrl(url: 'https://x.com/third', isActive: true),
  ],
);
const _wiki = Wiki(
  id: 1,
  title: 'artist_one',
  body: 'Artist information',
  otherNames: [],
  type: TagWiki(tag: 'artist_one'),
);

final _relatedTags = [
  for (final pair in [('zeta', 20), ('alpha', 10), ('unknown', 0)])
    DanbooruRelatedTagItem(
      tag: pair.$1,
      postCount: pair.$2,
      category: TagCategory.general(),
      jaccardSimilarity: 0,
      cosineSimilarity: 0,
      overlapCoefficient: 0,
      frequency: 0,
    ),
];

class _ThumbnailGenerator extends GridThumbnailUrlGenerator {
  Post? post;
  GridThumbnailSettings? settings;
  @override
  GridThumbnailMedia resolve(
    Post post, {
    required GridThumbnailSettings settings,
  }) {
    this.post = post;
    this.settings = settings;
    return const GridThumbnailMedia(
      url: 'https://example.com/exact-grid-tier.jpg',
      aspectRatio: 1,
    );
  }
}

final class _MediaPost extends Post {
  _MediaPost(Post source, this.format)
    : super(
        origin: source.origin,
        core: source.core,
        booruData: source.booruData,
      );
  @override
  final String format;
  @override
  double get width => 200;
  @override
  double get height => 300;
}
