import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/foundation/info/device_info.dart';

import '../../../support/fakes/test_post.dart';
import '../details/progressive_image_test_utils.dart'
    show DrainingImageCacheManager, lowerPng, pumpUntil;
import 'large_grid_gif_fixture.dart';

import 'package:boorusama/core/posts/listing/src/providers/cached_grid_gif.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:boorusama/core/configs/gesture/types.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/selection/ordered_selection_controller.dart';
import 'package:boorusama/core/selection/selection_input.dart';
// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import 'package:boorusama/boorus/danbooru/posts/favorites/widgets.dart';
import 'package:boorusama/boorus/danbooru/posts/listing/widgets.dart';
import 'package:boorusama/boorus/danbooru/posts/post/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/post/widgets.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/themes/colors/types.dart';

void main() {
  for (final cacheState in ['valid', 'missing', 'partial', 'invalid']) {
    for (final autoplay in [false, true]) {
      testWidgets(
        'large GIF grid uses owned cache bytes: $cacheState / autoplay=$autoplay',
        (tester) async {
          await tester.runAsync(() async {
            final directory = await Directory.systemTemp.createTemp(
              'grid-cached-gif-',
            );
            final cache = DrainingImageCacheManager(
              cacheRootPathProvider: () => directory.path,
            );
            final adapter = _RecordingGridImageAdapter();
            final dio = Dio()..httpClientAdapter = adapter;
            final bytes = largeGridGif();
            const original = 'https://grid-cache.test/original.gif';
            const thumbnail = 'https://grid-cache.test/thumb.png';
            await cache.saveFile(cache.generateCacheKey(thumbnail), lowerPng);
            ImageCacheWriteSession? partial;
            switch (cacheState) {
              case 'valid':
                await cache.saveFile(cache.generateCacheKey(original), bytes);
              case 'invalid':
                await cache.saveFile(
                  cache.generateCacheKey(original),
                  Uint8List(bytes.length),
                );
              case 'partial':
                partial = await cache.beginFileWrite(
                  cache.generateCacheKey(original),
                );
                await File(partial.stagedPath)
                    .writeAsBytes(bytes.sublist(0, 100));
            }
            final post = TestPost(
              id: 42,
              thumbnailImageUrl: thumbnail,
              sampleImageUrl: original,
              originalImageUrl: original,
              format: 'gif',
              fileSize: bytes.length,
            );
            try {
              await tester.pumpWidget(
                _TestApp(
                  automaticMediaLoading: true,
                  thumbnailGenerator: const DefaultGridThumbnailUrlGenerator(),
                  thumbnailSettings: GridThumbnailSettings(
                    imageQuality: ImageQuality.high,
                    animatedPostsDefaultState: autoplay
                        ? AnimatedPostsDefaultState.autoplay
                        : AnimatedPostsDefaultState.static,
                    gridSize: GridSize.normal,
                  ),
                  mediaOverrides: [
                    defaultImageCacheManagerProvider.overrideWithValue(cache),
                    dioForWidgetProvider.overrideWith((ref, config) => dio),
                    httpHeadersProvider.overrideWith((ref, config) => const {}),
                    deviceInfoProvider.overrideWithValue(DeviceInfo.empty()),
                  ],
                  child: Center(
                    child: SizedBox.square(
                      dimension: 160,
                      child: PostGridItem(
                        post: post,
                        index: 0,
                        useHero: false,
                        multiSelectEnabled: true,
                        config: _config.auth,
                        onTap: (_) {},
                        additions: PostGridItemAdditions.empty,
                      ),
                    ),
                  ),
                ),
              );
              final shouldAnimate = autoplay && cacheState == 'valid';
              final container = ProviderScope.containerOf(
                tester.element(find.byType(PostGridItem)),
              );
              final request = (
                manager: cache as ImageCacheManager,
                url: original,
                originalSize: bytes.length,
              );
              expect(
                container.exists(cachedGridGifProvider(request)),
                autoplay,
              );
              if (autoplay) {
                await container.read(cachedGridGifProvider(request).future);
                await tester.pump();
              }

              await pumpUntil(tester, () {
                final raw = tester.widgetList<BooruRawImage>(
                  find.byType(BooruRawImage),
                );
                if (raw.isEmpty) return false;
                return shouldAnimate
                    ? raw.single.cachedImageBytes != null
                    : raw.single.cachedImageBytes == null;
              }, reason: 'real grid cached GIF selection');
              // Observe the real future to completion, including negative probes.
              await tester.pumpAndSettle();
              final image = tester.widget<BooruRawImage>(
                find.byType(BooruRawImage),
              );
              expect(image.cachedImageBytes != null, shouldAnimate);
              expect(image.imageUrl, shouldAnimate ? original : thumbnail);
              expect(adapter.requests, isEmpty);
              if (shouldAnimate) {
                await cache.clearCache(cache.generateCacheKey(original));
                await tester.pump();
                expect(
                  tester
                      .widget<BooruRawImage>(find.byType(BooruRawImage))
                      .cachedImageBytes,
                  isNotNull,
                );
                final navigator = Navigator.of(
                  tester.element(find.byType(PostGridItem)),
                );
                unawaited(
                  navigator.push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('Viewer')),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                navigator.pop();
                await tester.pumpAndSettle();
                await pumpUntil(
                  tester,
                  () =>
                      tester
                          .widget<BooruRawImage>(find.byType(BooruRawImage))
                          .cachedImageBytes ==
                      null,
                  reason: 'cache recheck after viewer return',
                );
                expect(adapter.requests, isEmpty);
              }
              expect(tester.takeException(), isNull);
            } finally {
              await tester.pumpWidget(const SizedBox());
              await partial?.abort();
              dio.close(force: true);
              await cache.drain();
              await cache.dispose();
              await directory.delete(recursive: true);
            }
          });
        },
      );
    }
  }

  testWidgets(
    'active post cards retain hold-drag reversal and normal scrolling',
    (tester) async {
      final selection = SelectionModeController();
      final scroll = ScrollController();
      await tester.pumpWidget(
        _TestApp(
          selection: selection,
          scroll: scroll,
          child: SelectionCanvas(
            child: GridView.builder(
              controller: scroll,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemCount: 30,
              itemBuilder: (context, index) => PostGridItem(
                post: _post(id: index + 1),
                index: index,
                useHero: false,
                multiSelectEnabled: true,
                config: _config.auth,
                onTap: (_) => fail('drag navigated'),
                presentation: const GenericPostPresentation(),
                imageBuilder: (_) =>
                    SizedBox.expand(key: ValueKey('image-$index')),
              ),
            ),
          ),
        ),
      );
      selection.enable(initialSelected: [0]);
      await tester.pump();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('image-1'))),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('image-5'))),
      );
      await tester.pump();
      expect(selection.selection, containsAll([0, 1, 2, 3, 4, 5]));
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('image-2'))),
      );
      await tester.pump();
      expect(selection.selection, {0, 1, 2});
      await gesture.up();
      await tester.pump();
      await tester.drag(find.byType(GridView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      selection.dispose();
      scroll.dispose();
    },
  );

  for (final action in <String?>[
    null,
    kSelectAction,
    kDisabledAction,
    kDownloadAction,
    kUpvoteAction,
  ]) {
    for (final contextMenuOnLongPress in [false, true]) {
      testWidgets(
        'grid long press dispatches ${action ?? 'default'} with context menu $contextMenuOnLongPress exactly once and active drag owns it',
        (tester) async {
          final selection = OrderedSelectionController<int>()
            ..setEntries([0, 1, 2]);
          final repository = _GestureRepository();
          await tester.pumpWidget(
            _TestApp(
              selection: selection,
              longPress: action,
              contextMenuOnLongPress: contextMenuOnLongPress,
              repository: repository,
              child: SelectionCanvas(
                child: GridView.count(
                  crossAxisCount: 3,
                  children: [
                    for (var index = 0; index < 3; index++)
                      ListenableBuilder(
                        listenable: selection,
                        builder: (context, _) => KurumiContextMenuPolicy(
                          touchLongPress:
                              contextMenuOnLongPress &&
                              action == null &&
                              !selection.isActive,
                          child: KurumiContextMenu(
                            menuItemsBuilder: (_) => [
                              KurumiContextMenuTile(
                                title: 'Select fixture',
                                onTap: () =>
                                    selection.enable(initialSelected: [0]),
                              ),
                            ],
                            child: PostGridItem(
                              post: _post(id: index + 1),
                              index: index,
                              useHero: false,
                              multiSelectEnabled: selection.isActive,
                              config: _config.auth,
                              onTap: (_) => fail('selection navigated'),
                              presentation: const GenericPostPresentation(),
                              quickActionButton: const SizedBox.shrink(),
                              imageBuilder: (_) => SizedBox.expand(
                                key: ValueKey('dispatch-$index'),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
          await tester.longPress(find.byKey(const ValueKey('dispatch-0')));
          await tester.pump();
          final selects =
              action == kSelectAction ||
              (action == null && !contextMenuOnLongPress);
          expect(selection.selection, selects ? {0} : isEmpty);
          expect(
            repository.calls,
            action == kDownloadAction || action == kUpvoteAction
                ? [action]
                : isEmpty,
          );
          if (contextMenuOnLongPress && action == null) {
            await tester.pumpAndSettle();
            await tester.tap(find.text('Select fixture'));
            await tester.pumpAndSettle();
          }
          selection.enable(initialSelected: [0]);
          await tester.pump();
          final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey('dispatch-1'))),
          );
          await tester.pump(
            kLongPressTimeout + const Duration(milliseconds: 10),
          );
          await gesture.moveTo(
            tester.getCenter(find.byKey(const ValueKey('dispatch-2'))),
          );
          await tester.pump();
          expect(selection.selection, {0, 1, 2});
          await gesture.up();
          expect(
            repository.calls.length,
            action == kDownloadAction || action == kUpvoteAction ? 1 : 0,
          );
          await tester.pumpWidget(const SizedBox());
          selection.dispose();
        },
      );
    }
  }

  for (final platform in [TargetPlatform.linux, TargetPlatform.macOS]) {
    testWidgets(
      '$platform dispatches modifier clicks through actual post taps',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final selection = OrderedSelectionController<int>()
          ..setEntries([0, 1, 2, 3, 4, 5]);
        var opened = 0;
        await tester.pumpWidget(
          _TestApp(
            selection: selection,
            child: SelectionCanvas(
              child: GridView.count(
                crossAxisCount: 3,
                children: [
                  for (var index = 0; index < 6; index++)
                    ListenableBuilder(
                      listenable: selection,
                      builder: (context, _) => Focus(
                        autofocus: index == 0,
                        child: PostGridItem(
                          post: _post(id: index + 1),
                          index: index,
                          useHero: false,
                          multiSelectEnabled: selection.isActive,
                          config: _config.auth,
                          onTap: (_) => opened++,
                          presentation: const GenericPostPresentation(),
                          imageBuilder: (_) =>
                              SizedBox.expand(key: ValueKey('modifier-$index')),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        final modifier = platform == TargetPlatform.macOS
            ? LogicalKeyboardKey.metaLeft
            : LogicalKeyboardKey.controlLeft;
        await tester.sendKeyDownEvent(modifier);
        await tester.tap(find.byKey(const ValueKey('modifier-1')));
        await tester.sendKeyUpEvent(modifier);
        await tester.pump();
        expect(selection.selection, {1});
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.tap(find.byKey(const ValueKey('modifier-5')));
        await tester.pump();
        expect(selection.selection, {1, 2, 3, 4, 5});
        await tester.tap(find.byKey(const ValueKey('modifier-2')));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(selection.selection, {1, 2});
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.tap(find.byKey(const ValueKey('modifier-0')));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(modifier);
        await tester.pump();
        expect(selection.selection, {0, 1, 2});
        expect(opened, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(selection.isActive, isFalse);
        await tester.tap(find.byKey(const ValueKey('modifier-0')));
        expect(opened, 1);
        debugDefaultTargetPlatformOverride = null;
        await tester.pumpWidget(const SizedBox());
        selection.dispose();
      },
    );
  }

  const sources = ['search', 'favorites', 'bookmarks', 'feed'];

  for (final source in sources) {
    testWidgets('$source keeps every shared post-card semantic', (
      tester,
    ) async {
      final post = _post();

      await tester.pumpWidget(
        _TestApp(
          child: Stack(
            fit: StackFit.expand,
            children: [
              PostGridItem(
                post: post,
                index: 0,
                useHero: false,
                multiSelectEnabled: false,
                config: _config.auth,
                onTap: (_) {},
                presentation: const GenericPostPresentation(),
                quickActionButton: const SizedBox(
                  key: Key('quick-action'),
                ),
                leadingIcons: const [Icon(Icons.star, key: Key('leading'))],
                imageBuilder: (media) => SizedBox.expand(
                  child: Text(
                    '${media.url}:${media.aspectRatio}',
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
              Text(source, textDirection: TextDirection.ltr),
            ],
          ),
        ),
      );

      expect(find.text('quality-url:1.5'), findsOneWidget);
      expect(find.text(source), findsOneWidget);
      expect(find.byType(ExplicitContentBlockOverlay), findsOneWidget);
      expect(find.byType(DefaultTagListPrevewTooltip), findsOneWidget);
      expect(find.byKey(const Key('quick-action')), findsOneWidget);
      expect(find.byKey(const Key('leading')), findsOneWidget);

      final item = tester.widget<ImageGridItem>(find.byType(ImageGridItem));
      expect(item.isAnimated, isTrue);
      expect(item.isGif, isFalse);
      expect(item.isTranslated, isTrue);
      expect(item.hasComments, isTrue);
      expect(item.hasParentOrChildren, isTrue);
      expect(item.isAI, isTrue);
      expect(item.hasSound, isTrue);
      expect(item.duration, 12);
      expect(item.scoreWidget, isA<ImageScoreWidget>());
    });
  }

  testWidgets(
    'compatible Danbooru data adds native actions and moderation overlay',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: Stack(
            fit: StackFit.expand,
            children: [
              PostGridItem(
                post: _post(data: _danbooruData, status: 'banned'),
                index: 0,
                useHero: false,
                multiSelectEnabled: false,
                config: _config.auth,
                onTap: (_) {},
                presentation: const DanbooruPostGridPresentation(),
                imageBuilder: (_) => const SizedBox.expand(),
              ),
              const Text('NEW', textDirection: TextDirection.ltr),
              const Text('group', textDirection: TextDirection.ltr),
            ],
          ),
        ),
      );

      expect(find.byType(DanbooruQuickFavoriteButton), findsOneWidget);
      expect(find.text('artist tag'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('group'), findsOneWidget);
    },
  );

  testWidgets('incompatible data never receives Danbooru additions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: PostGridItem(
          post: _post(
            data: const EmptyPostData(typeKey: 'other'),
            status: 'banned',
          ),
          index: 0,
          useHero: false,
          multiSelectEnabled: false,
          config: _config.auth,
          onTap: (_) {},
          presentation: const DanbooruPostGridPresentation(),
          imageBuilder: (_) => const SizedBox.expand(),
        ),
      ),
    );

    expect(find.byType(DanbooruQuickFavoriteButton), findsNothing);
    expect(find.text('artist tag'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final _config = BooruConfig.defaultConfig(
  booruType: BooruType.danbooru,
  url: 'https://danbooru.example',
  customDownloadFileNameFormat: null,
);

Post _post({
  int id = 42,
  BooruPostData data = const EmptyPostData(typeKey: 'test'),
  String? status,
}) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.danbooru,
    booruId: BooruType.danbooru.id,
    source: _config.url,
  ),
  core: PostCoreData(
    id: id,
    thumbnailImageUrl: 'thumb',
    sampleImageUrl: 'sample',
    originalImageUrl: 'original',
    videoUrl: 'video',
    videoThumbnailUrl: 'video-thumb',
    width: 300,
    height: 200,
    format: 'webm',
    md5: 'hash',
    fileSize: 1024,
    duration: 12,
    hasSound: true,
    tags: const {'ai-generated'},
    rating: Rating.general,
    hasComment: true,
    isTranslated: true,
    hasParentOrChildren: true,
    source: PostSource.none(),
    score: 17,
    artistTags: const {'artist_tag'},
    status: status,
  ),
  booruData: data,
);

const _danbooruData = DanbooruPostData(
  lastCommentAt: null,
  upScore: 10,
  downScore: -2,
  favCount: 3,
  approverId: null,
  generalTags: {},
  metaTags: {},
  hasChildren: false,
  hasLarge: true,
  pixelHash: 'pixel',
);

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.child,
    this.selection,
    this.scroll,
    this.longPress,
    this.contextMenuOnLongPress = false,
    this.repository,
    this.automaticMediaLoading = false,
    this.thumbnailGenerator = const _ProbeGenerator(),
    this.thumbnailSettings,
    this.mediaOverrides = const [],
  });

  final bool automaticMediaLoading;
  final GridThumbnailUrlGenerator thumbnailGenerator;
  final GridThumbnailSettings? thumbnailSettings;
  final List<Override> mediaOverrides;

  final String? longPress;
  final bool contextMenuOnLongPress;
  final BooruRepository? repository;

  final SelectionModeController? selection;
  final ScrollController? scroll;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(
          Settings.defaultSettings.copyWith(
            postLongPressContextMenu: contextMenuOnLongPress,
          ),
        ),
        currentReadOnlyBooruConfigProvider.overrideWithValue(_config),
        currentReadOnlyBooruConfigAuthProvider.overrideWithValue(_config.auth),
        imageListingSettingsProvider.overrideWithValue(
          Settings.defaultSettings.listing.copyWith(showScoresInGrid: true),
        ),
        gridThumbnailUrlGeneratorProvider.overrideWith(
          (ref, config) => thumbnailGenerator,
        ),
        currentReadOnlyBooruConfigGestureProvider.overrideWithValue(
          PostGestureConfig.undefined().withPreviewLongPress(longPress),
        ),
        booruRepoProvider.overrideWith((ref, config) => repository),
        booruBuilderProvider.overrideWith((ref, config) => null),
        canFavoriteProvider.overrideWith((ref, config) => false),
        automaticMediaLoadingEnabledProvider.overrideWithValue(
          automaticMediaLoading,
        ),
        if (thumbnailSettings case final settings?)
          gridThumbnailSettingsProvider.overrideWith((ref, config) => settings),
        ...mediaOverrides,
      ],
      child: SelectionMode(
        controller: selection,
        scrollController: scroll,
        options: const SelectionOptions(
          behavior: SelectionBehavior.manual,
          dragSelection: DragSelectionOptions(),
        ),
        child: MaterialApp(
          theme: Kurumi.themeFrom(
            KurumiThemeMode.light,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            systemDarkMode: false,
          ).withBoorusamaColors(),
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => SelectionInput(
                controller: SelectionMode.of(context),
                itemCount: 30,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ProbeGenerator implements GridThumbnailUrlGenerator {
  const _ProbeGenerator();

  @override
  GridThumbnailMedia resolve(
    Post post, {
    required GridThumbnailSettings settings,
  }) => const GridThumbnailMedia(url: 'quality-url', aspectRatio: 1.5);
}

class _GestureRepository implements BooruRepository {
  final calls = <String?>[];
  @override
  bool handlePostGesture(WidgetRef ref, String? action, Post post) {
    calls.add(action);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingGridImageAdapter implements HttpClientAdapter {
  final requests = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri.toString());
    return ResponseBody.fromBytes(
      lowerPng,
      200,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
