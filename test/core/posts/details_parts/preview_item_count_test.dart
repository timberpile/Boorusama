import 'package:boorusama/core/configs/manage/providers.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:extended_image/src/image/raw_image.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:boorusama/boorus/gelbooru_v2/posts/grid_thumbnail_url.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/parser.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/types.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/widgets.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/posts/post/widgets.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/tags/tag/providers.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/foundation/info/device_info.dart';

import '../details/progressive_image_test_utils.dart';

void main() {
  const viewportCases = [
    (name: '320 px', width: 320.0, devicePixelRatio: 1.0),
    (name: '320 px at 2x', width: 320.0, devicePixelRatio: 2.0),
    (name: '900 px', width: 900.0, devicePixelRatio: 1.0),
  ];
  final dataCases = [
    (available: 3, expected: 3, nextBatch: null),
    (available: 6, expected: 6, nextBatch: null),
    (available: 9, expected: 6, nextBatch: 3),
    (available: 12, expected: 6, nextBatch: 6),
    (available: 13, expected: 6, nextBatch: 6),
    (available: 19, expected: 6, nextBatch: 6),
  ];
  final sections = [
    (
      name: 'artist',
      build: () => const DefaultInheritedArtistPostsSection<Post>(),
    ),
    (
      name: 'uploader',
      build: () => const UploaderPostsSection<Post>(
        query: UserColonUploaderQuery('artist'),
      ),
    ),
  ];

  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  const realbooruSections = {
    'Artist': DefaultInheritedArtistPostsSection<Post>(),
    'Uploader': GelbooruV2UploaderPostsSection(),
  };
  for (final section in realbooruSections.entries) {
    testWidgets(
      'Realbooru ${section.key} keeps the visible thumbnail after its poster fails',
      (tester) async {
        await _withRealbooruPreview(tester, section.value, video: true, (
          media,
        ) async {
          await media.waitForRequest(tester, _realbooruThumbnail);
          media.adapter.complete(_realbooruThumbnail, lowerPng);
          await waitForPixel(tester, _red);

          final images = find.byType(ExtendedImage);
          final thumbnail = tester.widgetList<ExtendedImage>(images).last;
          await media.cache.clearCache(_realbooruThumbnail);
          expect(await thumbnail.image.evict(), isTrue);
          final poster = tester.widgetList<ExtendedImage>(images).first;
          await media.fail(tester, '$_realbooruImage.jpg');
          await pumpUntil(
            tester,
            () => poster.controller!.loadState.value == LoadState.failed,
            reason: 'poster failure',
          );
          await tester.pump();

          expect(find.byType(ExtendedRawImage), findsOneWidget);
          await waitForPixel(tester, _red);
          expect(
            media.requests,
            unorderedEquals([
              _realbooruThumbnail,
              '$_realbooruImage.jpg',
            ]),
          );
          expect(find.byType(ImageRetryButton), findsNothing);
        });
      },
    );
  }

  testWidgets('Realbooru Artist uses an alternate format for a still image', (
    tester,
  ) async {
    await _withRealbooruPreview(tester, realbooruSections['Artist']!, (
      media,
    ) async {
      await media.waitForRequest(tester, _realbooruThumbnail);
      media.adapter.complete(_realbooruThumbnail, lowerPng);
      await waitForPixel(tester, _red);
      await media.fail(tester, '$_realbooruImage.jpg');
      await media.waitForRequest(tester, '$_realbooruImage.jpeg');
      media.adapter.complete('$_realbooruImage.jpeg', targetPng);
      await waitForPixel(tester, _blue);
      expect(find.byType(ImageRetryButton), findsNothing);
      expect(
        media.requests.where((url) => url == _realbooruThumbnail),
        hasLength(1),
      );
    });
  });

  testWidgets('Realbooru Uploader keeps its thumbnail when every probe fails', (
    tester,
  ) async {
    await _withRealbooruPreview(tester, realbooruSections['Uploader']!, (
      media,
    ) async {
      await media.waitForRequest(tester, _realbooruThumbnail);
      media.adapter.complete(_realbooruThumbnail, lowerPng);
      await waitForPixel(tester, _red);
      for (final extension in ['jpg', 'jpeg', 'png', 'webp', 'avif']) {
        await media.fail(tester, '$_realbooruImage.$extension');
      }
      await tester.pump();
      await waitForPixel(tester, _red);
      expect(find.byType(ImageRetryButton), findsNothing);
      expect(
        media.requests.where((url) => url == _realbooruThumbnail),
        hasLength(1),
      );
    });
  });

  testWidgets('Realbooru Uploader can retry when neither image loads', (
    tester,
  ) async {
    await _withRealbooruPreview(
      tester,
      realbooruSections['Uploader']!,
      video: true,
      (media) async {
        await media.fail(tester, _realbooruThumbnail);
        await media.fail(tester, '$_realbooruImage.jpg');
        final retry = find.byType(ImageRetryButton);
        await pumpUntil(
          tester,
          () => retry.evaluate().isNotEmpty,
          reason: 'Retry',
        );
        media.adapter.pending.remove(_realbooruThumbnail);
        await tester.tap(retry);
        await media.waitForRequest(tester, _realbooruThumbnail);
        media.adapter.complete(_realbooruThumbnail, lowerPng);
        await waitForPixel(tester, _red);
        expect(retry, findsNothing);
        expect(
          media.requests.where((url) => url == _realbooruThumbnail),
          hasLength(2),
        );
      },
    );
  });

  testWidgets('Realbooru Artist at Low quality requests only the thumbnail', (
    tester,
  ) async {
    await _withRealbooruPreview(
      tester,
      realbooruSections['Artist']!,
      quality: ImageQuality.low,
      (media) async {
        await media.waitForRequest(tester, _realbooruThumbnail);
        media.adapter.complete(_realbooruThumbnail, lowerPng);
        await waitForPixel(tester, _red);
        expect(media.requests, [_realbooruThumbnail]);
      },
    );
  });

  for (final section in sections) {
    for (final viewport in viewportCases) {
      for (final c in dataCases) {
        testWidgets(
          '${section.name} section initially renders ${c.expected} of ${c.available} posts at ${viewport.name}',
          (tester) async {
            final posts = List.generate(c.available, _post);
            final harness = _PreviewHarness(
              posts: posts,
              artistTags: const {'artist'},
              width: viewport.width,
              section: section.build(),
            );
            addTearDown(harness.dispose);

            _setViewport(tester, viewport.width, viewport.devicePixelRatio);

            await tester.pumpWidget(harness.build());
            await _pumpUntilGridCount(
              tester,
              c.expected,
              expectedPostWidgets: c.expected,
            );

            final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
            expect(grid.delegate.estimatedChildCount, c.expected);
            expect(find.byType(ImageGridItem), findsNWidgets(c.expected));
            if (c.nextBatch case final count?) {
              expect(find.text(_loadMoreLabel(count)), findsOneWidget);
            } else {
              expect(find.textContaining('Show '), findsNothing);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }

      testWidgets(
        '${section.name} loading placeholders stay at six without a load-more action at ${viewport.name}',
        (tester) async {
          final harness = _PreviewHarness(
            posts: const [],
            artistTags: const {'artist'},
            width: viewport.width,
            section: section.build(),
            keepPostsLoading: true,
          );
          addTearDown(harness.dispose);
          _setViewport(tester, viewport.width, viewport.devicePixelRatio);

          await tester.pumpWidget(harness.build());
          await _pumpUntilGridCount(tester, 6);

          final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
          expect(grid.delegate.estimatedChildCount, 6);
          expect(find.byType(ImageGridItem), findsNothing);
          expect(find.text(_loadMoreLabel(6)), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '${section.name} section reveals six more posts per press and hides the control at the end',
      (tester) async {
        final harness = _PreviewHarness(
          posts: List.generate(19, _post),
          artistTags: const {'artist'},
          width: 320,
          section: section.build(),
        );
        addTearDown(harness.dispose);
        _setViewport(tester, 320, 1);

        await tester.pumpWidget(harness.build());
        await _pumpUntilGridCount(tester, 6, expectedPostWidgets: 6);
        await _tapLoadMore(tester, 6);
        await _pumpUntilGridCount(tester, 12, expectedPostWidgets: 12);
        expect(find.text(_loadMoreLabel(6)), findsOneWidget);

        await _tapLoadMore(tester, 6);
        await _pumpUntilGridCount(tester, 18, expectedPostWidgets: 18);
        expect(find.text(_loadMoreLabel(1)), findsOneWidget);

        await _tapLoadMore(tester, 1);
        await _pumpUntilGridCount(tester, 19, expectedPostWidgets: 19);
        expect(find.textContaining('Show '), findsNothing);
        expect(find.textContaining('Show Less'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    final partialBatchCases = [
      (available: 9, firstBatch: 3, secondBatch: null),
      (available: 12, firstBatch: 6, secondBatch: null),
      (available: 13, firstBatch: 6, secondBatch: 1),
    ];
    for (final c in partialBatchCases) {
      testWidgets(
        '${section.name} section progressively reveals the remaining posts from ${c.available}',
        (tester) async {
          final harness = _PreviewHarness(
            posts: List.generate(c.available, _post),
            artistTags: const {'artist'},
            width: 320,
            section: section.build(),
          );
          addTearDown(harness.dispose);
          _setViewport(tester, 320, 1);

          await tester.pumpWidget(harness.build());
          await _pumpUntilGridCount(tester, 6, expectedPostWidgets: 6);
          expect(find.text(_loadMoreLabel(c.firstBatch)), findsOneWidget);

          await _tapLoadMore(tester, c.firstBatch);
          final expectedAfterFirstBatch = c.available < 12 ? c.available : 12;
          await _pumpUntilGridCount(
            tester,
            expectedAfterFirstBatch,
            expectedPostWidgets: expectedAfterFirstBatch,
          );
          if (c.secondBatch case final secondBatch?) {
            expect(find.text(_loadMoreLabel(secondBatch)), findsOneWidget);
            await _tapLoadMore(tester, secondBatch);
            await _pumpUntilGridCount(
              tester,
              c.available,
              expectedPostWidgets: c.available,
            );
          }
          expect(find.textContaining('Show '), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'artist preview resets its visible batch when the artist tag changes',
    (tester) async {
      final harness = _PreviewHarness(
        posts: List.generate(19, _post),
        artistTags: {'artist'},
        width: 320,
        section: const DefaultInheritedArtistPostsSection<Post>(),
      );
      addTearDown(harness.dispose);
      _setViewport(tester, 320, 1);

      await tester.pumpWidget(harness.build());
      await _pumpUntilGridCount(tester, 6, expectedPostWidgets: 6);
      await _tapLoadMore(tester, 6);
      await _pumpUntilGridCount(tester, 12, expectedPostWidgets: 12);

      harness.artistTags
        ..clear()
        ..add('other_artist');
      await tester.pumpWidget(harness.build(post: _post(100)));
      await _pumpUntilGridCount(tester, 6, expectedPostWidgets: 6);

      expect(find.text('other artist'), findsOneWidget);
      expect(find.text(_loadMoreLabel(6)), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'uploader preview resets its visible batch when the uploader query changes',
    (tester) async {
      final harness = _PreviewHarness(
        posts: List.generate(19, _post),
        artistTags: const {'artist'},
        width: 320,
        section: const UploaderPostsSection<Post>(
          query: UserColonUploaderQuery('artist'),
        ),
      );
      addTearDown(harness.dispose);
      _setViewport(tester, 320, 1);

      await tester.pumpWidget(harness.build());
      await _pumpUntilGridCount(tester, 6, expectedPostWidgets: 6);
      await _tapLoadMore(tester, 6);
      await _pumpUntilGridCount(tester, 12, expectedPostWidgets: 12);

      await tester.pumpWidget(
        harness.build(
          section: const UploaderPostsSection<Post>(
            query: UserColonUploaderQuery('other_artist'),
          ),
        ),
      );
      await _pumpUntilGridCount(tester, 6, expectedPostWidgets: 6);

      expect(find.text(_loadMoreLabel(6)), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'load-more control exposes a localized tap action with a comfortable target',
    (tester) async {
      final harness = _PreviewHarness(
        posts: List.generate(9, _post),
        artistTags: const {'artist'},
        width: 320,
        section: const DefaultInheritedArtistPostsSection<Post>(),
      );
      addTearDown(harness.dispose);
      _setViewport(tester, 320, 1);

      await tester.pumpWidget(harness.build());
      await _pumpUntilGridCount(tester, 6, expectedPostWidgets: 6);
      final label = find.text(_loadMoreLabel(3));
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();

      final tapTarget = find.ancestor(
        of: label,
        matching: find.byType(InkWell),
      );
      expect(tapTarget, findsOneWidget);
      expect(tester.getSize(tapTarget).height, greaterThanOrEqualTo(48));
      expect(
        tester
            .getSemantics(tapTarget)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

String _loadMoreLabel(int count) => 'Show $count more';

Future<void> _tapLoadMore(WidgetTester tester, int count) async {
  final label = find.text(_loadMoreLabel(count));
  expect(label, findsOneWidget);
  await tester.ensureVisible(label);
  await tester.pumpAndSettle();
  final tapTarget = find.ancestor(
    of: label,
    matching: find.byType(InkWell),
  );
  await tester.tap(tapTarget);
  await tester.pumpAndSettle();
}

void _setViewport(WidgetTester tester, double width, double devicePixelRatio) {
  tester.view.physicalSize = Size(
    width * devicePixelRatio,
    2400 * devicePixelRatio,
  );
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpUntilGridCount(
  WidgetTester tester,
  int expected, {
  int expectedPostWidgets = 0,
}) async {
  int? lastGridCount;
  var lastPostWidgetCount = 0;
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final grids = find.byType(SliverGrid);
    lastGridCount = grids.evaluate().isEmpty
        ? null
        : tester.widget<SliverGrid>(grids.first).delegate.estimatedChildCount;
    lastPostWidgetCount = find.byType(ImageGridItem).evaluate().length;
    if (lastGridCount == expected &&
        lastPostWidgetCount == expectedPostWidgets) {
      return;
    }
  }

  fail(
    'Timed out waiting for $expected grid children and '
    '$expectedPostWidgets post widgets; last observed '
    '$lastGridCount grid children and $lastPostWidgetCount post widgets.',
  );
}

class _PreviewHarness {
  _PreviewHarness({
    required this.posts,
    required this.artistTags,
    required this.width,
    required this.section,
    this.keepPostsLoading = false,
    this.realbooruMedia,
  }) : config = BooruConfig.defaultConfig(
         booruType: realbooruMedia == null
             ? BooruType.danbooru
             : BooruType.gelbooruV2,
         url: realbooruMedia == null
             ? 'https://danbooru.example'
             : _realbooruSite,
         customDownloadFileNameFormat: null,
       ) {
    container = ProviderContainer(
      overrides: [
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: [config]),
        ),
        settingsProvider.overrideWithValue(Settings.defaultSettings),
        colorSchemeProvider.overrideWithValue(
          ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        automaticMediaLoadingEnabledProvider.overrideWithValue(
          realbooruMedia != null,
        ),
        booruRepoProvider.overrideWith((ref, config) => null),
        if (realbooruMedia case final media?) ...[
          imageListingSettingsProvider.overrideWithValue(
            Settings.defaultSettings.listing.copyWith(
              imageQuality: media.quality,
              animatedPostsDefaultState: AnimatedPostsDefaultState.static,
              gridSize: GridSize.small,
            ),
          ),
          dioForWidgetProvider(config.auth).overrideWithValue(media.dio),
          httpHeadersProvider(config.auth).overrideWithValue(const {}),
          defaultImageCacheManagerProvider.overrideWithValue(media.cache),
          deviceInfoProvider.overrideWithValue(const DeviceInfo()),
        ] else
          gridThumbnailSettingsProvider.overrideWith(
            (ref, config) => const GridThumbnailSettings(
              imageQuality: ImageQuality.low,
              animatedPostsDefaultState: AnimatedPostsDefaultState.static,
              gridSize: GridSize.small,
            ),
          ),
        gridThumbnailUrlGeneratorProvider.overrideWith(
          (ref, config) => realbooruMedia == null
              ? const DefaultGridThumbnailUrlGenerator()
              : const DefaultGridThumbnailUrlGenerator(
                  mediaMapper: gelbooruV2ThumbnailOnlyGridThumbnailMedia,
                ),
        ),
        artistCharacterGroupProvider.overrideWith(
          () => _ArtistTagNotifier(artistTags),
        ),
        detailsPostsProvider.overrideWith((ref, params) {
          if (keepPostsLoading) return Completer<List<Post>>().future;
          return Future.value(posts);
        }),
      ],
    );
  }

  final List<Post> posts;
  final Set<String> artistTags;
  final double width;
  final Widget section;
  final bool keepPostsLoading;
  final _RealbooruMedia? realbooruMedia;
  final BooruConfig config;
  late final ProviderContainer container;

  Widget build({Widget? section, Post? post}) => UncontrolledProviderScope(
    container: container,
    child: BooruLocalization(
      child: MaterialApp(
        builder: (context, child) {
          final themed = KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: child!,
          );
          return realbooruMedia == null
              ? themed
              : MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                  ),
                  child: themed,
                );
        },
        home: CurrentBooruConfigScope(
          config: config,
          child: InheritedPost(
            presentationContext: PostPresentationContext.generic(
              post ?? _post(99),
            ),
            child: PostDetailsSheetConstraints(
              maxWidth: width,
              child: CustomScrollView(
                slivers: [section ?? this.section],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  void dispose() => container.dispose();
}

class _ArtistTagNotifier extends ArtistCharacterNotifier {
  _ArtistTagNotifier(this.tags);

  final Set<String> tags;

  @override
  FutureOr<ArtistCharacterGroup> build(ArtistCharacterGroupParams arg) =>
      ArtistCharacterGroup(characterTags: const {}, artistTags: tags);
}

Post _post(int id, {String? uploaderName}) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.danbooru,
    booruId: BooruType.danbooru.id,
    source: 'https://danbooru.example',
  ),
  core: PostCoreData(
    id: id,
    thumbnailImageUrl: 'https://danbooru.example/$id.jpg',
    sampleImageUrl: 'https://danbooru.example/$id.jpg',
    originalImageUrl: 'https://danbooru.example/$id.jpg',
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 300,
    height: 200,
    format: 'jpg',
    md5: '$id',
    fileSize: 1,
    duration: 0,
    tags: const {},
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
    uploaderName: uploaderName,
  ),
  booruData: const EmptyPostData(typeKey: 'test'),
);

const _realbooruSite = 'https://realbooru.test';
const _realbooruHash = '0123456789abcdef0123456789abcdef';
const _realbooruThumbnail =
    '$_realbooruSite/thumbnails/01/23/thumbnail_$_realbooruHash.jpg';
const _realbooruImage = '$_realbooruSite/images/01/23/$_realbooruHash';
const _red = [255, 0, 0, 255];
const _blue = [0, 0, 255, 255];

Future<void> _withRealbooruPreview(
  WidgetTester tester,
  Widget section,
  Future<void> Function(_RealbooruMedia) verify, {
  bool video = false,
  ImageQuality quality = ImageQuality.high,
}) async {
  final media = _RealbooruMedia(quality);
  final dto = parseRbPostsHtml(
    Response<String>(
      requestOptions: RequestOptions(path: '/index.php?page=post&s=list'),
      data:
          '''
        <div class="col thumb"><a id="p1">
          <img src="$_realbooruThumbnail" title="scenery"
              ${video ? 'style="border: 2px solid blue"' : ''} />
        </a></div>
        ''',
    ),
    const {},
  ).posts.single;
  final post = gelbooruV2PostDtoToGelbooruPostNoMetadata(
    dto,
    const GelbooruV2ImageUrlResolver(),
  );
  final harness = _PreviewHarness(
    posts: [post],
    artistTags: const {'artist'},
    width: 320,
    section: section,
    realbooruMedia: media,
  );
  _setViewport(tester, 320, 1);
  try {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        harness.build(post: _post(99, uploaderName: 'artist')),
      );
      await verify(media);
      expect(tester.takeException(), isNull);
    });
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    harness.dispose();
    media.dio.close(force: true);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}

class _RealbooruMedia {
  _RealbooruMedia(this.quality);

  final ImageQuality quality;
  final adapter = ControlledImageAdapter();
  final cache = TestImageCache({});
  late final dio = Dio()..httpClientAdapter = adapter;

  Iterable<String> get requests =>
      adapter.requests.map((request) => request.uri.toString());

  Future<void> waitForRequest(WidgetTester tester, String url) => pumpUntil(
    tester,
    () => adapter.pending.containsKey(url),
    reason: 'request for $url',
  );

  Future<void> fail(WidgetTester tester, String url) async {
    await waitForRequest(tester, url);
    adapter.complete(url, Uint8List(0), status: 404);
  }
}
