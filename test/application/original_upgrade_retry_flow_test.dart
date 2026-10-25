import 'dart:typed_data';

import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../core/posts/details/progressive_image_test_utils.dart';
import 'support/fake_booru_backend.dart';
import 'support/fake_image_dio.dart';
import 'support/headless_app_harness.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Original retry remains tappable above the actual viewer footer at ${scale}x',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        const thumbnail = 'https://media.test/preview.png';
        const sample = 'https://media.test/sample.png';
        const original = 'https://media.test/original.png';
        final backend = FakeBooruBackend();
        backend.posts
          ..clear()
          ..add(
            TestPost(
              id: 101,
              thumbnailImageUrl: thumbnail,
              sampleImageUrl: sample,
              originalImageUrl: original,
              format: 'png',
              width: 0,
              height: 0,
            ),
          );
        final adapter = ControlledImageAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final cache = TestImageCache({thumbnail: lowerPng, sample: targetPng});
        final settings = Settings.defaultSettings.copyWith(
          viewer: Settings.defaultSettings.viewer.copyWith(
            postQuality: PostQuality.original,
          ),
        );
        final harness = await HeadlessAppHarness.mount(
          tester,
          booruBackend: backend,
          viewportSize: const Size(320, 700),
          runtime: backend.createRuntime(settings: settings),
          additionalOverrides: [
            dioForWidgetProvider.overrideWith((_, _) => dio),
            defaultImageCacheManagerProvider.overrideWithValue(cache),
            deterministicFaviconDioOverride(),
          ],
        );
        await harness.openFirstPost(tester);
        await tester.runAsync(() async {
          await pumpUntil(
            tester,
            () => adapter.pending.containsKey(original),
            reason: 'Original request',
          );
          adapter.complete(original, Uint8List(0), status: 404);
          await pumpUntil(
            tester,
            () => find.text('Retry').evaluate().isNotEmpty,
            reason: 'retained sample after failed Original',
          );
          await waitForPixel(tester, [0, 0, 255, 255]);
        });
        await harness.settle(tester);
        expect(find.byType(DefaultInheritedPostActionToolbar), findsWidgets);
        expect(find.text('Retry').hitTestable(), findsOneWidget);
        adapter.pending.remove(original);
        await tester.tap(find.text('Retry'));
        await tester.runAsync(() async {
          await pumpUntil(
            tester,
            () => adapter.pending.containsKey(original),
            reason: 'tappable retry',
          );
          await waitForPixel(tester, [0, 0, 255, 255]);
          adapter.complete(original, originalPng);
          await waitForPixel(tester, [0, 255, 0, 255]);
        });
        expect(
          adapter.requests.where((r) => r.uri.toString() == original),
          hasLength(2),
        );
        expect(
          adapter.requests.where((r) => r.uri.toString() == sample),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
