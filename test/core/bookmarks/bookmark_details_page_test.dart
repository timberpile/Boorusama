import 'package:boorusama/core/groups/folder_tree.dart';
import '../search/subscriptions/subscription_test_utils.dart';
import 'package:selection_mode/selection_mode.dart';
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/foundation.dart';
import 'package:boorusama/core/bookmarks/src/providers/local_providers.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_search_bar.dart';
import 'package:boorusama/foundation/networking.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/src/image/raw_image.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/foundation/info/device_info.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_page.dart';
import '../posts/details/progressive_image_test_utils.dart';
// Dart imports:
import 'dart:async';
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_details_page.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/downloads/downloader/providers.dart';
import 'package:boorusama/core/downloads/downloader/types.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/details_parts/types.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/widgets/booru_menu_button_row.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/core/themes/colors/src/colors.dart';

void main() {
  testWidgets(
    'nested bookmark groups render literal leaf names and restore breadcrumb history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const root = CollectionFolder(id: 'root', name: 'Cookie');
      const child = CollectionFolder(
        id: 'child',
        name: 'Deep // literal',
        parentId: 'root',
      );
      final state = BookmarkLibraryState(
        bookmarks: [],
        folders: [root, child],
        groups: [
          BookmarkGroup(
            id: '550e8400-e29b-41d4-a716-446655440099',
            name: 'Leaf // literal',
            bookmarkIds: {},
            folderId: 'child',
          ),
        ],
        activeTarget: const BookmarkTarget.defaultGroup(),
      );
      final controller = _controller([]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _BookmarkViewerHarness(
          controller: controller,
          bookmarkNotifier: _CacheBookmarkNotifier(state),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(2),
            ),
            child: const BookmarkGroupBrowserPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cookie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deep // literal'));
      await tester.pumpAndSettle();
      expect(find.text('Leaf // literal'), findsOneWidget);
      expect(
        find.text('Cookie / Deep // literal / Leaf // literal'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Bookmark Groups'), findsOneWidget);
      expect(find.text('Leaf // literal'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  const compactGroupId = '550e8400-e29b-41d4-a716-446655440000';
  for (final view in [
    const BookmarkView.all(),
    const BookmarkView.defaultGroup(),
    BookmarkView.group(compactGroupId),
  ]) {
    testWidgets('compact bookmark header recovers empty filters in $view', (
      tester,
    ) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      // Keep focused text-field animations from blocking result assertions.
      Future<void> pumpHeader() async {
        for (var frame = 0; frame < 12; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      final bookmarks = List.generate(
        8,
        (index) => Bookmark.empty.copyWith(
          id: index + 1,
          postId: () => index + 1,
          sourceUrl: _config.url,
          originalUrl: 'https://gelbooru.example/${index + 1}.jpg',
          width: 1200,
          height: 1200,
          tags: const {'red'},
          createdAt: DateTime(2026, 1, index + 1),
        ),
      );
      final library = BookmarkLibraryState(
        bookmarks: bookmarks,
        groups: [
          BookmarkGroup(
            id: defaultBookmarkGroupId,
            name: 'Default',
            bookmarkIds: const {5, 6, 7, 8},
          ),
          BookmarkGroup(
            id: compactGroupId,
            name: 'Saved',
            bookmarkIds: const {1, 2, 3, 4},
          ),
        ],
        activeTarget: const BookmarkTarget.defaultGroup(),
      );
      final unusedController = _controller([]);
      addTearDown(unusedController.dispose);
      await tester.pumpWidget(
        _BookmarkViewerHarness(
          controller: unusedController,
          bookmarkNotifier: _CacheBookmarkNotifier(library),
          home: BookmarkPage(view: view),
        ),
      );
      await pumpHeader();
      final search = find.descendant(
        of: find.byType(BookmarkSearchBar),
        matching: find.byType(TextField),
      );
      expect(search, findsOneWidget);
      expect(find.text('Source: All'), findsOneWidget);
      expect(find.text('Newest'), findsOneWidget);
      expect(tester.widget<AppBar>(find.byType(AppBar).first).actions, isNull);
      final pageContext = tester.element(find.byType(BookmarkSearchBar));
      final container = ProviderScope.containerOf(pageContext);
      final controller = PostScope.of<Post>(pageContext);
      final expectedCount = view.kind == BookmarkViewKind.all ? 8 : 4;
      expect(controller.items.length, expectedCount);
      expect(find.text('$expectedCount bookmarks'), findsOneWidget);
      await tester.enterText(search, 'absent_tag');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await pumpHeader();
      expect(controller.items, isEmpty);
      expect(find.text('0 bookmarks'), findsOneWidget);
      expect(search, findsOneWidget);
      expect(find.text('Source: All'), findsOneWidget);
      expect(find.text('Newest'), findsOneWidget);
      await tester.tap(find.byIcon(Symbols.clear));
      await pumpHeader();
      expect(controller.items.length, expectedCount);
      // A selected source remains visible even when it has no matches in this view.
      container.read(selectedBooruUrlProvider.notifier).state =
          'missing.example';
      await pumpHeader();
      expect(controller.items, isEmpty);
      expect(find.text('0 bookmarks'), findsOneWidget);
      expect(find.text('Source: missing.example'), findsOneWidget);
      await _tapFilter(tester, 'Source: missing.example');
      await pumpHeader();
      await tester.tap(
        find.ancestor(
          of: find.text('All'),
          matching: find.byType(KurumiPopupMenuItem),
        ),
      );
      await pumpHeader();
      expect(controller.items.length, expectedCount);
      await tester.enterText(search, 'red');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await pumpHeader();
      container.read(selectedBooruUrlProvider.notifier).state =
          'gelbooru.example';
      await pumpHeader();
      await _tapFilter(tester, 'Newest');
      await pumpHeader();
      await tester.tap(
        find.ancestor(
          of: find.text('Random'),
          matching: find.byType(KurumiPopupMenuItem),
        ),
      );
      await pumpHeader();
      final firstOrder = controller.items.map((post) => post.id).toList();
      // Retry is valid: a random permutation can coincidentally repeat.
      var changed = false;
      for (var attempt = 0; attempt < 8 && !changed; attempt++) {
        await tester.tap(find.byTooltip('Shuffle bookmarks'));
        await pumpHeader();
        changed = !listEquals(
          firstOrder,
          controller.items.map((post) => post.id).toList(),
        );
      }
      expect(changed, isTrue);
      expect(controller.items.length, expectedCount);
      expect(container.read(selectedBooruUrlProvider), 'gelbooru.example');
      expect(tester.widget<TextField>(search).controller!.text, 'red');
      expect(container.read(bookmarkProvider).requireValue, same(library));
      await tester.tap(
        find.descendant(
          of: find.byType(PostGridConfigIconButton),
          matching: find.byType(KurumiPopupMenuButton),
        ),
      );
      await pumpHeader();
      await tester.tap(
        find.ancestor(
          of: find.text('Select'),
          matching: find.byType(KurumiPopupMenuItem),
        ),
      );
      await pumpHeader();
      final selection = SelectionMode.of(pageContext);
      expect(selection.isActive, isTrue);
      await tester.tap(find.byIcon(Symbols.select_all));
      await pumpHeader();
      expect(selection.selection.length, expectedCount);
      final download = tester.widget<MultiSelectButton>(
        find.byWidgetPredicate(
          (widget) => widget is MultiSelectButton && widget.name == 'Download',
        ),
      );
      expect(download.onPressed, isNotNull);
      final groupActions = find.byWidgetPredicate(
        (widget) =>
            widget is MultiSelectPopupButton && widget.name == 'Bookmarks',
      );
      expect(
        tester.widget<MultiSelectPopupButton>(groupActions).enabled,
        isTrue,
      );
      await tester.tap(
        find.descendant(
          of: groupActions,
          matching: find.byType(KurumiPopupMenuButton),
        ),
      );
      await pumpHeader();
      expect(find.text('Remove from group'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(bookmarkProvider).requireValue, same(library));

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpHeader();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'bookmark grid group previews and viewer decode from the same ordinary cache without a download',
    (tester) async {
      await tester.runAsync(() async {
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        final root = await Directory.systemTemp.createTemp(
          'bookmark-common-widget-',
        );
        final cache = DefaultImageCacheManager(
          cacheRootPathProvider: () => root.path,
        );
        final bookmark = Bookmark(
          id: 42,
          postId: 42,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          width: 1200,
          height: 1200,
          md5: '',
          tags: const {},
          realSourceUrl: null,
          format: 'png',
          metadata: const {},
          imageUrlResolver: const DefaultImageUrlResolver(),
          booruId: _config.booruId,
          sourceUrl: _config.url,
          thumbnailUrl: 'https://bookmark-cache.test/thumb.png',
          sampleUrl: 'https://bookmark-cache.test/sample.png',
          originalUrl: 'https://bookmark-cache.test/original.png',
        );
        for (final url in [
          bookmark.thumbnailUrl,
          bookmark.sampleUrl,
          bookmark.originalUrl,
        ]) {
          await cache.saveFile(cache.generateCacheKey(url), lowerPng);
        }
        final favicon = PostSource.from(
          _config.url,
        ).whenWeb((source) => source.faviconUrl, () => '');
        if (favicon.isNotEmpty) {
          await cache.saveFile(cache.generateCacheKey(favicon), lowerPng);
        }
        final adapter = ControlledImageAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final state = BookmarkLibraryState(
          bookmarks: [bookmark],
          groups: const [],
          activeTarget: const BookmarkTarget.defaultGroup(),
        );
        final controller = PostGridController<Post>(
          fetcher: (_) => TaskEither.right(
            PostResult(posts: [bookmark.toPost()], total: 1),
          ),
          blacklistedTagsFetcher: () async => const {},
          mountedChecker: () => true,
          duplicateTracker: PostDuplicateTracker(),
          onError: (_) {},
          debounceDuration: Duration.zero,
        );
        await controller.refresh();
        try {
          for (final home in [
            const BookmarkGroupBrowserPage(),
            const BookmarkPage(),
            null,
          ]) {
            await tester.pumpWidget(
              _BookmarkViewerHarness(
                controller: controller,
                home: home,
                bookmarkNotifier: _CacheBookmarkNotifier(state),
                commonCache: cache,
                imageDio: dio,
              ),
            );
            for (var i = 0; i < 10; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 60));
              await tester.pump();
            }
            final decoded = tester
                .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
                .where((image) => image.image != null)
                .toList();
            expect(
              decoded,
              isNotEmpty,
              reason:
                  '${home?.runtimeType ?? "BookmarkDetailsPage"} must display actual cached pixels',
            );
            expect(
              (await decoded.first.image!.toByteData())!.buffer
                  .asUint8List()
                  .take(4),
              [255, 0, 0, 255],
            );
            expect(
              adapter.requests,
              isEmpty,
              reason:
                  'all bookmark surfaces reuse ordinary URL-keyed cache files',
            );
            for (final image in tester.widgetList<BooruRawImage>(
              find.byType(BooruRawImage),
            )) {
              expect(image.imageCacheManager, same(cache));
            }
            await tester.pumpWidget(const SizedBox());
          }
        } finally {
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
          dio.close(force: true);
          await cache.dispose();
          await root.delete(recursive: true);
        }
      });
    },
  );

  testWidgets(
    'bookmark viewer renders only the active booru toolbar',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      var fetchCount = 0;
      final posts = [_nativePost(), _fallbackPost()];
      final controller = PostGridController<Post>(
        fetcher: (_) {
          fetchCount++;
          return TaskEither.right(
            PostResult(posts: posts, total: posts.length),
          );
        },
        blacklistedTagsFetcher: () async => const {},
        mountedChecker: () => true,
        duplicateTracker: PostDuplicateTracker(),
        onError: (_) {},
        debounceDuration: Duration.zero,
      );
      addTearDown(controller.dispose);
      await controller.refresh();

      await tester.pumpWidget(_BookmarkViewerHarness(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('native@gelbooru.example'), findsOneWidget);
      expect(find.byType(BooruMenuButtonRow), findsOneWidget);
      expect(find.byType(PostPresentationFallbackWarning), findsNothing);
      expect(fetchCount, 1);

      await tester.drag(find.byType(PageView).first, const Offset(-700, 0));
      await tester.pumpAndSettle();

      expect(find.text('native@gelbooru.example'), findsNothing);
      expect(find.byType(PostPresentationFallbackWarning), findsOneWidget);
      expect(find.byType(BooruMenuButtonRow), findsOneWidget);
      expect(fetchCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bookmark viewer keeps its opened posts after the grid changes', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    final post = _nativePost();
    final controller = PostGridController<Post>(
      fetcher: (_) => TaskEither.right(PostResult(posts: [post], total: 1)),
      blacklistedTagsFetcher: () async => const {},
      mountedChecker: () => true,
      duplicateTracker: PostDuplicateTracker(),
      onError: (_) {},
      debounceDuration: Duration.zero,
    );
    addTearDown(controller.dispose);
    await controller.refresh();

    await tester.pumpWidget(_BookmarkViewerHarness(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('native@gelbooru.example'), findsOneWidget);

    controller.remove([post.id], (candidate) => candidate.id);
    await tester.pumpAndSettle();

    expect(find.text('native@gelbooru.example'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bookmark context menu uses the post origin profile', (
    tester,
  ) async {
    final post = _nativePost();
    final controller = PostGridController<Post>(
      fetcher: (_) => TaskEither.right(PostResult(posts: [post], total: 1)),
      blacklistedTagsFetcher: () async => const {},
      mountedChecker: () => true,
      duplicateTracker: PostDuplicateTracker(),
      onError: (_) {},
      debounceDuration: Duration.zero,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    final otherConfig = BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: BooruType.gelbooruV2,
        url: 'https://other.example',
        customDownloadFileNameFormat: null,
      ).toJson(),
      'id': '00000000-0000-4000-8000-000000000063',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: [_config]),
          ),
          currentReadOnlyBooruConfigAuthProvider.overrideWithValue(
            otherConfig.auth,
          ),
          booruPostPresentationProvider.overrideWith(
            (ref, request) => const _NativePresentation(),
          ),
        ],
        child: MaterialApp(
          home: PostGridContextMenu(
            controller: controller,
            index: 0,
            child: const Text('card'),
          ),
        ),
      ),
    );

    expect(find.text('menu@gelbooru.example'), findsOneWidget);
    expect(find.text('menu@other.example'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final fixture in [
    (name: 'legacy', bookmark: _legacyBookmark()),
    (name: 'malformed', bookmark: _malformedBookmark()),
  ]) {
    testWidgets(
      'opening silently repairs one ${fixture.name} bookmark and preserves viewer order, identity, and groups',
      (tester) async {
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        final legacy = fixture.bookmark;
        final group = BookmarkGroup(
          id: 'kept',
          name: 'Kept',
          bookmarkIds: {legacy.id},
        );
        final notifier = _RecoveryBookmarkNotifier(legacy, group);
        final repositoryConfigs = <BooruConfig>[];
        final response = Completer<Either<BooruError, Post?>>();
        final repository = _RecoveryPostRepository(
          result: TaskEither(() => response.future),
        );
        final controller = _controller([
          _nativePost(id: 90),
          legacy.post,
          _nativePost(id: 92),
        ]);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _BookmarkViewerHarness(
            controller: controller,
            initialIndex: 1,
            bookmarkNotifier: notifier,
            recoveryRepository: repository,
            repositoryConfigs: repositoryConfigs,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PostPresentationFallbackWarning), findsNothing);
        expect(find.text('Retry'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byType(BookmarkPostActionToolbar), findsOneWidget);
        expect(repository.requests, [const NumericPostId(91)]);

        await tester.drag(find.byType(PageView).first, const Offset(-700, 0));
        await tester.pumpAndSettle();
        expect(find.text('post:92'), findsOneWidget);
        await tester.drag(find.byType(PageView).first, const Offset(700, 0));
        await tester.pumpAndSettle();
        expect(find.byType(PostPresentationFallbackWarning), findsNothing);
        expect(repository.requests, hasLength(1));

        await tester.drag(find.byType(PageView).first, const Offset(-700, 0));
        await tester.pumpAndSettle();
        response.complete(Right(_nativePost(id: 91)));
        await tester.pumpAndSettle();
        expect(find.text('post:92'), findsOneWidget);
        await tester.drag(find.byType(PageView).first, const Offset(700, 0));
        await tester.pumpAndSettle();

        expect(find.text('post:91'), findsOneWidget);
        expect(find.byType(PostPresentationFallbackWarning), findsNothing);
        expect(repositoryConfigs, [_config]);
        final persisted = notifier.state.requireValue.items.single;
        expect(persisted.id, legacy.id);
        expect(persisted.createdAt, legacy.createdAt);
        expect(persisted.post.id, 91);
        expect(
          notifier.state.requireValue.groups.single.bookmarkIds,
          {legacy.id},
        );
        expect(
          persisted.snapshot.toJson().toString(),
          isNot(contains('secret')),
        );

        await tester.drag(find.byType(PageView).first, const Offset(-700, 0));
        await tester.pumpAndSettle();
        expect(find.text('post:92'), findsOneWidget);

        await tester.drag(find.byType(PageView).first, const Offset(700, 0));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(PageView).first, const Offset(700, 0));
        await tester.pumpAndSettle();
        expect(find.text('post:90'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'missing refreshed bookmark stays generic with a removed warning',
    (
      tester,
    ) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      final legacy = _legacyBookmark();
      final notifier = _RecoveryBookmarkNotifier(
        legacy,
        BookmarkGroup(id: 'kept', name: 'Kept', bookmarkIds: {legacy.id}),
      );
      final controller = _controller([legacy.post]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _BookmarkViewerHarness(
          controller: controller,
          bookmarkNotifier: notifier,
          recoveryRepository: _RecoveryPostRepository(
            result: TaskEither.right(null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      expect(
        find.text('The post is no longer available on its original site.'),
        findsOneWidget,
      );
      expect(notifier.upgrades, 0);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        find.text('The post is no longer available on its original site.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed automatic recovery retains manual Retry without a rebuild loop',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      final legacy = _legacyBookmark();
      final notifier = _RecoveryBookmarkNotifier(
        legacy,
        BookmarkGroup(id: 'kept', name: 'Kept', bookmarkIds: {legacy.id}),
      );
      final response = Completer<Either<BooruError, Post?>>();
      final repository = _RecoveryPostRepository(
        result: TaskEither(() => response.future),
      );
      final controller = _controller([legacy.post, _nativePost(id: 92)]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _BookmarkViewerHarness(
          controller: controller,
          bookmarkNotifier: notifier,
          recoveryRepository: repository,
        ),
      );
      expect(find.byType(PostPresentationFallbackWarning), findsNothing);
      await tester.pumpAndSettle();
      expect(repository.requests, [const NumericPostId(91)]);
      expect(find.byType(PostPresentationFallbackWarning), findsNothing);
      response.complete(
        Left(ServerError(httpStatusCode: 503, message: 'unavailable')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(PostPresentationFallbackWarning), findsOneWidget);
      await tester.drag(find.byType(PageView).first, const Offset(-700, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView).first, const Offset(700, 0));
      await tester.pumpAndSettle();
      expect(repository.requests, hasLength(1));
      expect(notifier.upgrades, 0);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repository.requests, hasLength(2));
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('complete bookmarks open without requesting recovery', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    final repository = _RecoveryPostRepository(
      result: TaskEither.right(_nativePost(id: 91)),
    );
    final controller = _controller([_nativePost(id: 91)]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _BookmarkViewerHarness(
        controller: controller,
        recoveryRepository: repository,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('post:91'), findsOneWidget);
    expect(repository.requests, isEmpty);
    expect(find.byType(PostPresentationFallbackWarning), findsNothing);
  });

  testWidgets('closing the viewer while recovery is pending is safe', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    final legacy = _legacyBookmark();
    final notifier = _RecoveryBookmarkNotifier(
      legacy,
      BookmarkGroup(id: 'kept', name: 'Kept', bookmarkIds: {legacy.id}),
    );
    final response = Completer<Either<BooruError, Post?>>();
    final repository = _RecoveryPostRepository(
      result: TaskEither(() => response.future),
    );
    final controller = _controller([legacy.post]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _BookmarkViewerHarness(
        controller: controller,
        bookmarkNotifier: notifier,
        recoveryRepository: repository,
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.requests, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(Right(_nativePost(id: 91)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(repository.requests, hasLength(1));
  });

  testWidgets(
    'repaired snapshot survives a Hive reload and reopening makes no request',
    (tester) async {
      await tester.runAsync(() async {
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        late Directory directory;
        late Box<BookmarkHiveObject> bookmarkBox;
        late Box<BookmarkGroupHiveObject> groupBox;
        late BookmarkHiveRepository bookmarkRepository;
        late BookmarkGroupRepositoryHive groupRepository;
        final legacy = _legacyBookmark();
        directory = await Directory.systemTemp.createTemp(
          'bookmark_silent_recovery_',
        );
        Hive.init(directory.path);
        if (!Hive.isAdapterRegistered(4)) {
          Hive.registerAdapter(BookmarkHiveObjectAdapter());
        }
        if (!Hive.isAdapterRegistered(5)) {
          Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
        }
        bookmarkBox = await Hive.openBox<BookmarkHiveObject>(
          'silent_bookmarks',
        );
        groupBox = await Hive.openBox<BookmarkGroupHiveObject>('silent_groups');
        bookmarkRepository = BookmarkHiveRepository(
          bookmarkBox,
          postDataCodec: (_) => const GelbooruV2PostCodec(),
        );
        groupRepository = BookmarkGroupRepositoryHive(
          groupBox,
          organizationBox: MemoryBox<dynamic>(),
        );
        await bookmarkBox.put(legacy.id, favoriteToHiveObject(legacy));
        await groupRepository.createGroup(
          'Kept',
          id: '00000000-0000-4000-8000-000000000051',
        );
        await groupRepository.addBookmarks(
          '00000000-0000-4000-8000-000000000051',
          {legacy.id},
        );
        final repository = _RecoveryPostRepository(
          result: TaskEither.right(_nativePost(id: 91)),
        );
        final controller = _controller([legacy.post]);
        await controller.refresh();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _BookmarkViewerHarness(
            controller: controller,
            bookmarkRepository: bookmarkRepository,
            groupRepository: groupRepository,
            recoveryRepository: repository,
          ),
        );
        expect(find.byType(PostPresentationFallbackWarning), findsNothing);
        // Hive uses real IO; allow provider loading and recovery writes to settle.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.text('post:91'), findsOneWidget);
        expect(find.byType(PostPresentationFallbackWarning), findsNothing);
        expect(repository.requests, hasLength(1));
        await tester.pumpWidget(const SizedBox.shrink());
        late Bookmark persisted;
        await bookmarkBox.close();
        bookmarkBox = await Hive.openBox<BookmarkHiveObject>(
          'silent_bookmarks',
        );
        bookmarkRepository = BookmarkHiveRepository(
          bookmarkBox,
          postDataCodec: (_) => const GelbooruV2PostCodec(),
        );
        persisted = (await bookmarkRepository.getAllBookmarksOrEmpty(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        )).single;
        expect(
          (await groupRepository.getGroup(
            '00000000-0000-4000-8000-000000000051',
          ))!.bookmarkIds,
          {
            legacy.id,
          },
        );
        expect(persisted.id, legacy.id);
        expect(persisted.createdAt, legacy.createdAt);
        expect(persisted.identity, legacy.identity);
        expect(persisted.post.booruData, isA<GelbooruV2PostData>());
        final reopened = _controller([persisted.post]);
        await reopened.refresh();
        addTearDown(reopened.dispose);
        await tester.pumpWidget(
          _BookmarkViewerHarness(
            controller: reopened,
            bookmarkRepository: bookmarkRepository,
            groupRepository: groupRepository,
            recoveryRepository: repository,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.text('post:91'), findsOneWidget);
        expect(repository.requests, hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await bookmarkBox.close();
        await groupBox.close();
        await directory.delete(recursive: true);
      });
    },
  );

  testWidgets(
    'legacy bookmark without an upstream post ID does not offer retry',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      final legacy = _legacyBookmark(postId: null);
      final notifier = _RecoveryBookmarkNotifier(
        legacy,
        BookmarkGroup(id: 'kept', name: 'Kept', bookmarkIds: {legacy.id}),
      );
      final controller = _controller([legacy.post]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _BookmarkViewerHarness(
          controller: controller,
          bookmarkNotifier: notifier,
          recoveryRepository: _RecoveryPostRepository(
            result: TaskEither.right(_nativePost(id: 91)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PostPresentationFallbackWarning), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(notifier.upgrades, 0);
    },
  );
}

final _config = BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.gelbooruV2,
    url: 'https://gelbooru.example',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': '00000000-0000-4000-8000-00000000000c',
});

Post _nativePost({int id = 1}) => _post(
  data: const GelbooruV2PostData(hasNotes: true),
  tags: const {'native'},
  id: id,
);

Post _fallbackPost() => _post(
  data: const UnknownPostData(
    typeKey: 'gelbooru_v2',
    schemaVersion: 99,
    custom: {'broken': true},
    reason: UnknownPostDataReason.malformedData,
  ),
  tags: const {'cached_tag'},
  id: 2,
);

Post _post({
  required BooruPostData data,
  required Set<String> tags,
  int id = 1,
}) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.gelbooruV2,
    booruId: _config.booruId,
    source: _config.url,
    profileIdHint: _config.id,
  ),
  core: PostCoreData(
    id: id,
    thumbnailImageUrl: 'thumbnail-$id',
    sampleImageUrl: 'sample-$id',
    originalImageUrl: 'original-$id',
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 100,
    height: 100,
    format: 'jpg',
    md5: 'md5-$id',
    fileSize: 1,
    duration: 0,
    tags: tags,
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
  ),
  booruData: data,
);

class _BookmarkViewerHarness extends StatelessWidget {
  const _BookmarkViewerHarness({
    required this.controller,
    this.initialIndex = 0,
    this.bookmarkNotifier,
    this.recoveryRepository,
    this.repositoryConfigs,
    this.bookmarkRepository,
    this.groupRepository,
    this.home,
    this.commonCache,
    this.imageDio,
  });

  final PostGridController<Post> controller;
  final int initialIndex;
  final BookmarkLibraryNotifier? bookmarkNotifier;
  final PostRepository<Post>? recoveryRepository;
  final List<BooruConfig>? repositoryConfigs;
  final BookmarkHiveRepository? bookmarkRepository;
  final BookmarkGroupRepositoryHive? groupRepository;
  final Widget? home;
  final ImageCacheManager? commonCache;
  final Dio? imageDio;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(
        () => SettingsNotifier(
          Settings.defaultSettings.copyWith(reduceAnimations: true),
        ),
      ),
      colorSchemeProvider.overrideWithValue(
        ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      connectivityProvider.overrideWith(
        (ref) => Stream.value([ConnectivityResult.wifi]),
      ),
      settingsProvider.overrideWithValue(
        Settings.defaultSettings.copyWith(reduceAnimations: true),
      ),
      initialSettingsBooruConfigProvider.overrideWithValue(_config),
      booruConfigProvider.overrideWith(
        () => BooruConfigNotifier(initialConfigs: [_config]),
      ),
      booruEngineRegistryProvider.overrideWithValue(_CodecRegistry()),
      if (bookmarkRepository == null)
        bookmarkProvider.overrideWith(
          () => bookmarkNotifier ?? _EmptyBookmarkNotifier(),
        ),
      if (bookmarkRepository case final repository?)
        bookmarkRepoProvider.overrideWith((ref) => repository),
      if (groupRepository case final repository?)
        bookmarkGroupRepoProvider.overrideWith((ref) => repository),
      bookmarkUrlResolverProvider.overrideWith(
        (ref, _) => const DefaultImageUrlResolver(),
      ),
      booruPostPresentationProvider.overrideWith(
        (ref, request) => switch (request.data) {
          GelbooruV2PostData() => const _NativePresentation(),
          _ => const GenericPostPresentation(),
        },
      ),
      mediaUrlResolverProvider.overrideWith(
        (ref, config) => const _MediaResolver(),
      ),
      booruRepoProvider.overrideWith(
        (ref, config) =>
            recoveryRepository == null ? null : _AvailableBooruRepository(),
      ),
      originAwarePostRepoProvider.overrideWith((ref, config) {
        repositoryConfigs?.add(config);
        return recoveryRepository ?? EmptyPostRepository();
      }),
      booruBuilderProvider.overrideWith((ref, config) => null),
      automaticMediaLoadingEnabledProvider.overrideWithValue(
        commonCache != null,
      ),
      if (commonCache case final cache?)
        defaultImageCacheManagerProvider.overrideWithValue(cache),
      if (imageDio case final dio?)
        dioForWidgetProvider.overrideWith((ref, config) => dio),
      deviceInfoProvider.overrideWithValue(DeviceInfo.empty()),
      hasPremiumLayoutProvider.overrideWithValue(false),
      showPremiumFeatsProvider.overrideWithValue(false),
      downloadServiceProvider.overrideWithValue(_DownloadService()),
      httpHeadersProvider.overrideWith((ref, config) => const {}),
      loggerProvider.overrideWithValue(const _Logger()),
      favoriteRepoProvider.overrideWith(
        (ref, config) => EmptyFavoriteRepository(),
      ),
    ],
    child: BooruLocalization(
      child: MaterialApp(
        theme: ThemeData(
          extensions: const [KurumiExtendedColorScheme()],
        ).withBoorusamaColors(),
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(
            Theme.of(context).withBoorusamaColors(),
          ),
          child: child!,
        ),
        home:
            home ??
            BookmarkDetailsPage(
              initialIndex: initialIndex,
              initialThumbnailUrl: null,
              controller: controller,
            ),
      ),
    ),
  );
}

final class _EmptyBookmarkNotifier extends BookmarkLibraryNotifier {
  @override
  FutureOr<BookmarkLibraryState> build() => BookmarkLibraryState(
    bookmarks: const [],
    groups: const [],
    activeTarget: const BookmarkTarget.defaultGroup(),
  );
}

final class _NativePresentation
    implements BooruPostPresentation, BooruPostGridContextMenuPresentation {
  const _NativePresentation();

  @override
  PostDetailsWrapperBuilder? get detailsWrapperBuilder => null;

  @override
  bool supports(BooruPostData data) => data is GelbooruV2PostData;

  @override
  PostDetailsUIBuilder detailsBuilder(Post post) => PostDetailsUIBuilder(
    preview: {
      DetailsPart.toolbar: (context) => SliverToBoxAdapter(
        child: Column(
          children: [
            const Text('native@gelbooru.example'),
            Text('post:${post.id}'),
            const BooruMenuButtonRow(buttons: []),
          ],
        ),
      ),
    },
    full: {
      DetailsPart.toolbar: (context) => SliverToBoxAdapter(
        child: Column(
          children: [
            const Text('native@gelbooru.example'),
            Text('post:${post.id}'),
            const BooruMenuButtonRow(buttons: []),
          ],
        ),
      ),
    },
  );

  @override
  Widget buildGridContextMenu(
    BuildContext context, {
    required Post post,
    required int index,
    required Widget child,
  }) => Consumer(
    builder: (context, ref, _) => Text(
      'menu@${Uri.parse(ref.watchConfigAuth.url).host}',
    ),
  );
}

PostGridController<Post> _controller(List<Post> posts) {
  final controller = PostGridController<Post>(
    fetcher: (_) => TaskEither.right(
      PostResult(posts: posts, total: posts.length),
    ),
    blacklistedTagsFetcher: () async => const {},
    mountedChecker: () => true,
    duplicateTracker: PostDuplicateTracker(),
    onError: (_) {},
    debounceDuration: Duration.zero,
  );
  controller.refresh();
  return controller;
}

Bookmark _legacyBookmark({int? postId = 91}) => Bookmark(
  id: 501,
  booruId: BooruType.gelbooruV2.id,
  createdAt: DateTime.utc(2025),
  updatedAt: DateTime.utc(2025, 1, 2),
  thumbnailUrl: 'thumbnail-91',
  sampleUrl: 'sample-91',
  originalUrl: 'original-91',
  sourceUrl: _config.url,
  width: 100,
  height: 100,
  md5: 'legacy-91',
  tags: const {'cached'},
  realSourceUrl: null,
  format: 'jpg',
  imageUrlResolver: const DefaultImageUrlResolver(),
  postId: postId,
  metadata: const {},
);

Bookmark _malformedBookmark() {
  final legacy = _legacyBookmark();
  final post = _post(
    id: 91,
    tags: const {'cached'},
    data: const UnknownPostData(
      typeKey: 'gelbooru_v2',
      schemaVersion: 1,
      custom: {'broken': true},
      reason: UnknownPostDataReason.malformedData,
    ),
  );
  return Bookmark.fromSnapshot(
    id: legacy.id,
    createdAt: legacy.createdAt,
    updatedAt: legacy.updatedAt,
    snapshot: const StoredPostCodec().encode(post),
    post: post,
    postId: post.id,
    sourceUrl: legacy.sourceUrl,
  );
}

final class _RecoveryBookmarkNotifier extends BookmarkLibraryNotifier {
  _RecoveryBookmarkNotifier(this.bookmark, this.group);

  final Bookmark bookmark;
  final BookmarkGroup group;
  var upgrades = 0;

  @override
  FutureOr<BookmarkLibraryState> build() => BookmarkLibraryState(
    bookmarks: [bookmark],
    groups: [group],
    activeTarget: const BookmarkTarget.defaultGroup(),
  );

  @override
  Future<void> upgradeBookmarkSnapshot(Bookmark bookmark, Post post) async {
    upgrades++;
    final snapshot = const StoredPostCodec().encode(
      post,
      dataCodec: const GelbooruV2PostCodec(),
    );
    final upgraded = Bookmark.fromSnapshot(
      id: bookmark.id,
      createdAt: bookmark.createdAt,
      updatedAt: DateTime.utc(2026),
      snapshot: snapshot,
      post: post,
      postId: post.id,
      sourceUrl: bookmark.sourceUrl,
    );
    state = AsyncValue.data(
      BookmarkLibraryState(
        bookmarks: [upgraded],
        groups: [group],
        activeTarget: const BookmarkTarget.defaultGroup(),
      ),
    );
  }
}

final class _RecoveryPostRepository extends PostRepository<Post> {
  _RecoveryPostRepository({required this.result});

  final PostOrError<Post> result;
  final requests = <PostId>[];

  @override
  PostOrError<Post> getPost(PostId id, {PostFetchOptions? options}) {
    requests.add(id);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _AvailableBooruRepository implements BooruRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MediaResolver implements MediaUrlResolver {
  const _MediaResolver();

  @override
  String resolveMediaUrl(Post post, BooruConfigViewer config) =>
      post.sampleImageUrl;

  @override
  double? resolveMediaAspectRatio(Post post, BooruConfigViewer config) => 1;

  @override
  String resolveVideoUrl(Post post, BooruConfigViewer config) => post.videoUrl;

  @override
  double? resolveVideoAspectRatio(Post post, BooruConfigViewer config) => 1;
}

final class _DownloadService implements DownloadService {
  @override
  Future<DownloadResult> download(DownloadOptions options) async =>
      DownloadEnqueued(DownloadTaskInfo(path: '', id: options.url));

  @override
  Future<bool> cancelAll(String group) async => true;

  @override
  Future<void> pauseAll(String group) async {}

  @override
  Future<void> resumeAll(String group) async {}
}

final class _Logger implements Logger {
  const _Logger();

  @override
  String getDebugName() => 'bookmark details test';

  @override
  void debug(String serviceName, String message) {}

  @override
  void error(String serviceName, String message) {}

  @override
  void info(String serviceName, String message) {}

  @override
  void verbose(String serviceName, String message) {}

  @override
  void warn(String serviceName, String message) {}
}

final class _CodecRegistry extends BooruEngineRegistry {
  @override
  BooruPostCapability<BooruPostData>? getPostCapability(BooruType type) =>
      type == BooruType.gelbooruV2
      ? const BooruPostCapability(
          booruType: BooruType.gelbooruV2,
          codec: GelbooruV2PostCodec(),
          presentation: _NativePresentation(),
        )
      : null;
}

class _CacheBookmarkNotifier extends BookmarkLibraryNotifier {
  _CacheBookmarkNotifier(this.library);
  final BookmarkLibraryState library;
  @override
  FutureOr<BookmarkLibraryState> build() => library;
}

Future<void> _tapFilter(WidgetTester tester, String label) async {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byType(KurumiPopupMenuButton),
  );
  await tester.ensureVisible(button);
  await tester.pump();
  final viewport = find.byWidgetPredicate(
    (widget) =>
        widget is SingleChildScrollView &&
        widget.scrollDirection == Axis.horizontal,
  );
  final visible = tester.getRect(button).intersect(tester.getRect(viewport));
  expect(visible.isEmpty, isFalse);
  await tester.tapAt(visible.center);
}
