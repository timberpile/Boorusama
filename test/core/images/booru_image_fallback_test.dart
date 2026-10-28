// Flutter imports:
import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

// Package imports:
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:extended_image/src/dio_extended_image_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;

// Project imports:
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/info/device_info.dart';

import '../posts/details/progressive_image_test_utils.dart' as images;

void main() {
  testWidgets(
    'HTTP 404 advances extensions and a decoded PNG stops the chain',
    (
      tester,
    ) async {
      final adapter = images.ControlledImageAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      const prefix = 'https://example.test/actual';
      await tester.pumpWidget(
        _booruApp(
          dio,
          BooruImage(
            config: BooruConfig.empty.auth,
            imageUrl: '$prefix.jpg',
            fallbackUrls: const ['$prefix.jpeg', '$prefix.png', '$prefix.webp'],
            fallbackUrl: '$prefix-thumbnail.jpg',
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final extension in ['jpg', 'jpeg']) {
          final url = '$prefix.$extension';
          await images.pumpUntil(
            tester,
            () => adapter.pending.containsKey(url),
            reason: 'request for $extension',
          );
          adapter.complete(url, Uint8List(0), status: 404);
        }
        await images.pumpUntil(
          tester,
          () => adapter.pending.containsKey('$prefix.png'),
          reason: 'PNG fallback request',
        );
        adapter.complete('$prefix.png', images.targetPng);
        await images.waitForPixel(tester, [0, 0, 255, 255]);
      });
      expect(adapter.requests.map((request) => request.uri.toString()), [
        '$prefix.jpg',
        '$prefix.jpeg',
        '$prefix.png',
      ]);
      expect(find.byType(ErrorPlaceholder), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.binding.imageCache.clear();
    },
  );

  testWidgets('tries alternate image extensions lazily before the thumbnail', (
    tester,
  ) async {
    final config = BooruConfig.empty.auth;
    final adapter = _PendingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    const urls = [
      'https://example.test/image.jpg',
      'https://example.test/image.jpeg',
      'https://example.test/image.png',
      'https://example.test/thumbnail.jpg',
    ];
    await tester.pumpWidget(
      _booruApp(
        dio,
        BooruImage(
          config: config,
          imageUrl: urls.first,
          fallbackUrls: urls.sublist(1, 3),
          fallbackUrl: urls.last,
        ),
      ),
    );
    for (var index = 0; index < urls.length; index++) {
      expect(_networkUrls(tester), contains(urls[index]));
      expect(
        _networkUrls(tester),
        isNot(contains(anyOf(urls.skip(index + 1)))),
      );
      final image = tester
          .widgetList<ExtendedImage>(find.byType(ExtendedImage))
          .singleWhere(
            (image) =>
                image.image is DioExtendedNetworkImageProvider &&
                (image.image as DioExtendedNetworkImageProvider).url ==
                    urls[index],
          );
      image.controller!.changeLoadState(LoadState.failed);
      await tester.pump();
    }
    expect(find.byType(ErrorPlaceholder), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    expect(adapter.requests.map((request) => request.uri.toString()), urls);
    expect(
      adapter.requests.every(
        (request) => request.headers['Referer'] == 'https://example.test/',
      ),
      isTrue,
    );
    tester.binding.imageCache.clear();
  });

  testWidgets('shows the configured fallback after the primary image fails', (
    tester,
  ) async {
    final controller = ExtendedImageController();
    addTearDown(controller.dispose);
    final adapter = _PendingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));

    await tester.pumpWidget(
      _testApp(
        BooruRawImage(
          dio: dio,
          imageUrl: 'https://example.test/poster.jpg',
          fallbackUrl: 'https://example.test/thumbnail.jpg',
          controller: controller,
        ),
      ),
    );

    expect(_networkUrls(tester), contains('https://example.test/poster.jpg'));
    expect(
      _networkUrls(tester),
      isNot(contains('https://example.test/thumbnail.jpg')),
    );

    controller.changeLoadState(LoadState.failed);
    await tester.pump();

    expect(
      _networkUrls(tester),
      contains('https://example.test/thumbnail.jpg'),
    );
    expect(find.byType(ErrorPlaceholder), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      adapter.requests.map((request) => request.uri.toString()),
      containsAll([
        'https://example.test/poster.jpg',
        'https://example.test/thumbnail.jpg',
      ]),
    );
    tester.binding.imageCache.clear();
  });

  testWidgets('a decorative image can use a themed failure surface', (
    tester,
  ) async {
    final controller = ExtendedImageController();
    addTearDown(controller.dispose);
    final dio = Dio()..httpClientAdapter = _PendingAdapter();
    addTearDown(() => dio.close(force: true));
    const fallbackKey = ValueKey('themed-failure');
    await tester.pumpWidget(
      _testApp(
        BooruRawImage(
          dio: dio,
          imageUrl: 'https://example.test/decorative.jpg',
          controller: controller,
          errorWidget: const ColoredBox(key: fallbackKey, color: Colors.grey),
        ),
      ),
    );
    controller.changeLoadState(LoadState.failed);
    await tester.pump();
    expect(find.byKey(fallbackKey), findsOneWidget);
    expect(find.byType(ErrorPlaceholder), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    tester.binding.imageCache.clear();
  });

  testWidgets('uses the normal error placeholder when the fallback fails', (
    tester,
  ) async {
    final controller = ExtendedImageController();
    addTearDown(controller.dispose);
    final adapter = _PendingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));

    await tester.pumpWidget(
      _testApp(
        BooruRawImage(
          dio: dio,
          imageUrl: 'https://example.test/poster.jpg',
          fallbackUrl: 'https://example.test/thumbnail.jpg',
          controller: controller,
        ),
      ),
    );

    controller.changeLoadState(LoadState.failed);
    await tester.pump();

    final fallback = tester
        .widgetList<ExtendedImage>(find.byType(ExtendedImage))
        .singleWhere(
          (image) =>
              image.image is DioExtendedNetworkImageProvider &&
              (image.image as DioExtendedNetworkImageProvider).url ==
                  'https://example.test/thumbnail.jpg',
        );

    expect(fallback.errorWidget, isA<ErrorPlaceholder>());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      adapter.requests.map((request) => request.uri.toString()),
      containsAll([
        'https://example.test/poster.jpg',
        'https://example.test/thumbnail.jpg',
      ]),
    );
    tester.binding.imageCache.clear();
  });
}

// These tests drive the display state explicitly; transport stays pending
// without opening a socket or creating retry timers.
class _PendingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return Completer<ResponseBody>().future;
  }

  @override
  void close({bool force = false}) {}
}

Widget _booruApp(Dio dio, Widget child) => ProviderScope(
  overrides: [
    automaticMediaLoadingEnabledProvider.overrideWithValue(true),
    dioForWidgetProvider(BooruConfig.empty.auth).overrideWithValue(dio),
    httpHeadersProvider(BooruConfig.empty.auth).overrideWithValue({
      'Referer': 'https://example.test/',
    }),
    imageListingSettingsProvider.overrideWithValue(
      Settings.defaultSettings.listing,
    ),
    defaultImageCacheManagerProvider.overrideWithValue(
      images.TestImageCache({}),
    ),
    deviceInfoProvider.overrideWithValue(const DeviceInfo()),
  ],
  child: _testApp(child),
);

Widget _testApp(Widget child) => TranslationProvider(
  child: MaterialApp(
    builder: (context, child) => KurumiTheme(
      data: KurumiThemeData.fromMaterial(Theme.of(context)),
      child: child!,
    ),
    home: Scaffold(body: child),
  ),
);

List<String> _networkUrls(WidgetTester tester) => tester
    .widgetList<ExtendedImage>(find.byType(ExtendedImage))
    .map((image) => image.image)
    .whereType<DioExtendedNetworkImageProvider>()
    .map((provider) => provider.url)
    .toList();
