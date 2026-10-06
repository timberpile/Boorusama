// Flutter imports:
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

// Package imports:
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:extended_image/src/dio_extended_image_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

// Project imports:
import 'package:boorusama/core/images/booru_image.dart';

void main() {
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

Widget _testApp(Widget child) => MaterialApp(
  builder: (context, child) => KurumiTheme(
    data: KurumiThemeData.fromMaterial(Theme.of(context)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

List<String> _networkUrls(WidgetTester tester) => tester
    .widgetList<ExtendedImage>(find.byType(ExtendedImage))
    .map((image) => image.image)
    .whereType<DioExtendedNetworkImageProvider>()
    .map((provider) => provider.url)
    .toList();
