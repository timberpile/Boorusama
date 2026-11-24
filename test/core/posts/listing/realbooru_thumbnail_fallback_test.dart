import 'dart:typed_data';

import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/grid_thumbnail_url.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/parser.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_item.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/info/device_info.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:extended_image/src/image/raw_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../details/progressive_image_test_utils.dart';

const _base = 'https://realbooru.test';
const _hash = '0123456789abcdef0123456789abcdef';
const _thumbnail = '$_base/thumbnails/01/23/thumbnail_$_hash.jpg';
const _poster = '$_base/images/01/23/$_hash.jpg';
const _red = [255, 0, 0, 255];
const _blue = [0, 0, 255, 255];
final _accessRequired = StateProvider<bool>((ref) => false);

void main() {
  testWidgets(
    'a visible thumbnail survives a poster failure after cache eviction',
    (
      tester,
    ) async {
      await _withVideoTile(tester, cachedThumbnail: true, (fixture) async {
        await waitForPixel(tester, _red);
        final thumbnail = tester
            .widgetList<ExtendedImage>(
              find.byType(ExtendedImage),
            )
            .last;
        await fixture.cache.clearCache(_thumbnail);
        expect(await thumbnail.image.evict(), isTrue);
        await fixture.failPoster(tester);

        expect(find.byType(ExtendedRawImage), findsOneWidget);
        await waitForPixel(tester, _red);
        expect(fixture.requests, [_poster]);
        expect(find.byType(ImageRetryButton), findsNothing);
      });
    },
  );

  testWidgets(
    'a pending thumbnail finishes on the original request after poster failure',
    (
      tester,
    ) async {
      await _withVideoTile(tester, (fixture) async {
        await fixture.waitForRequest(tester, _thumbnail);
        await fixture.failPoster(tester);
        expect(find.byType(ImageRetryButton), findsNothing);

        fixture.adapter.complete(_thumbnail, lowerPng);
        await waitForPixel(tester, _red);
        expect(
          fixture.requests.where((url) => url == _thumbnail),
          hasLength(1),
        );
      });
    },
  );

  testWidgets('a decoded poster replaces the thumbnail', (tester) async {
    await _withVideoTile(tester, cachedThumbnail: true, (fixture) async {
      await waitForPixel(tester, _red);
      await fixture.waitForRequest(tester, _poster);
      fixture.adapter.complete(_poster, targetPng);
      await waitForPixel(tester, _blue);
      expect(find.byType(ExtendedImage), findsOneWidget);
      expect(find.byType(ImageRetryButton), findsNothing);
    });
  });

  testWidgets('retry appears after both loads fail and reloads the thumbnail', (
    tester,
  ) async {
    await _withVideoTile(tester, (fixture) async {
      await fixture.waitForRequest(tester, _thumbnail);
      final thumbnail = tester
          .widgetList<ExtendedImage>(
            find.byType(ExtendedImage),
          )
          .last;
      fixture.adapter.complete(_thumbnail, Uint8List(0), status: 404);
      await pumpUntil(
        tester,
        () => thumbnail.controller?.loadState.value == LoadState.failed,
        reason: 'thumbnail failure while poster is pending',
      );
      await tester.pump();
      expect(find.byType(ImageRetryButton), findsNothing);

      await fixture.failPoster(tester);
      expect(find.byType(ImageRetryButton), findsOneWidget);
      fixture.adapter.pending.remove(_thumbnail);
      await tester.tap(find.byType(ImageRetryButton));
      await fixture.waitForRequest(tester, _thumbnail);
      fixture.adapter.complete(_thumbnail, lowerPng);
      await waitForPixel(tester, _red);
      expect(find.byType(ImageRetryButton), findsNothing);
      expect(fixture.requests.where((url) => url == _poster), hasLength(1));
      expect(fixture.requests.where((url) => url == _thumbnail), hasLength(2));
    });
  });

  testWidgets('revoking access removes a retained thumbnail', (tester) async {
    await _withVideoTile(tester, cachedThumbnail: true, (fixture) async {
      await waitForPixel(tester, _red);
      await fixture.failPoster(tester);
      await waitForPixel(tester, _red);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PostGridImage)),
      );
      container.read(_accessRequired.notifier).state = true;
      await tester.pump();
      expect(find.byType(ExtendedRawImage), findsNothing);
      expect(find.byType(ImageRetryButton), findsNothing);
      expect(fixture.requests, [_poster]);
    });
  });
}

Future<void> _withVideoTile(
  WidgetTester tester,
  Future<void> Function(_Fixture fixture) verify, {
  bool cachedThumbnail = false,
}) async {
  final fixture = _Fixture(cachedThumbnail: cachedThumbnail);
  try {
    await tester.runAsync(() async {
      await tester.pumpWidget(fixture.app());
      await verify(fixture);
      expect(tester.takeException(), isNull);
    });
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    fixture.dio.close(force: true);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}

class _Fixture {
  _Fixture({required bool cachedThumbnail})
    : cache = TestImageCache({if (cachedThumbnail) _thumbnail: lowerPng});

  final TestImageCache cache;
  final adapter = ControlledImageAdapter();
  late final dio = Dio()..httpClientAdapter = adapter;

  Iterable<String> get requests =>
      adapter.requests.map((request) => request.uri.toString());

  Future<void> waitForRequest(WidgetTester tester, String url) => pumpUntil(
    tester,
    () => adapter.pending.containsKey(url),
    reason: 'request for $url',
  );

  Future<void> failPoster(WidgetTester tester) async {
    await waitForRequest(tester, _poster);
    final image = tester
        .widgetList<ExtendedImage>(
          find.byType(ExtendedImage),
        )
        .first;
    adapter.complete(_poster, Uint8List(0), status: 404);
    await pumpUntil(
      tester,
      () => image.controller!.loadState.value == LoadState.failed,
      reason: 'poster failure',
    );
    await tester.pump();
  }

  Widget app() {
    final dto = parseRbPostsHtml(
      Response<String>(
        requestOptions: RequestOptions(path: '/index.php?page=post&s=list'),
        data:
            '''
          <div class="col thumb"><a id="p1">
            <img src="$_thumbnail" style="border: 2px solid blue" />
          </a></div>
          ''',
      ),
      const {},
    ).posts.single;
    final post = gelbooruV2PostDtoToGelbooruPostNoMetadata(
      dto,
      const GelbooruV2ImageUrlResolver(),
    );
    final media = gelbooruV2ThumbnailOnlyGridThumbnailMedia(
      post,
      const GridThumbnailSettings(
        imageQuality: ImageQuality.high,
        animatedPostsDefaultState: AnimatedPostsDefaultState.static,
        gridSize: GridSize.normal,
      ),
    );
    expect(media.url, _poster);
    expect(media.placeholderUrl, _thumbnail);
    expect(media.fallbackUrl, _thumbnail);

    final config = BooruConfig.empty.auth;
    return ProviderScope(
      overrides: [
        automaticMediaLoadingEnabledProvider.overrideWithValue(true),
        contentAccessRequiredProvider.overrideWith(
          (ref) => ref.watch(_accessRequired),
        ),
        dioForWidgetProvider(config).overrideWithValue(dio),
        httpHeadersProvider(config).overrideWithValue(const {}),
        imageListingSettingsProvider.overrideWithValue(
          Settings.defaultSettings.listing.copyWith(
            imageQuality: ImageQuality.high,
          ),
        ),
        defaultImageCacheManagerProvider.overrideWithValue(cache),
        deviceInfoProvider.overrideWithValue(const DeviceInfo()),
      ],
      child: testApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: Center(
              child: SizedBox.square(
                dimension: 120,
                child: PostGridImage(config: config, media: media),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
