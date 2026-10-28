import 'package:boorusama/core/http/client/src/providers/dio.dart';
import 'package:boorusama/core/posts/details/src/types/post_viewer_transformation_controller.dart';
import 'package:boorusama/core/posts/details/src/widgets/zoom_edge_page_gesture.dart';
import 'package:boorusama/core/posts/details_pageview/src/post_details_page_view_controller.dart';
import 'package:boorusama/core/posts/details_pageview/src/zoom_page_navigation_scope.dart';

import 'progressive_image_test_utils.dart';

import 'dart:typed_data';

import 'package:boorusama/core/posts/details/src/widgets/progressive_post_image.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/images/booru_image.dart' show ErrorPlaceholder;
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:extended_image/src/image/raw_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final failOriginal in [false, true]) {
    testWidgets(
      'Original upgrade retains a decoded High intermediate (failure=$failOriginal)',
      (tester) async {
        final fixture = _Fixture();
        await tester.pumpWidget(fixture.build(intermediates: [_second]));
        await tester.runAsync(() => waitForPixel(tester, [255, 0, 0, 255]));
        final state = tester.state(find.byType(ExtendedImage));
        final bounds = tester.getSize(find.byType(ExtendedRawImage));
        await tester.runAsync(() async {
          await pumpUntil(
            tester,
            () =>
                fixture.adapter.pending.containsKey(_second) &&
                fixture.adapter.pending.containsKey(_target),
            reason: 'High and Original requests',
          );
          fixture.adapter.complete(_second, targetPng);
          await waitForPixel(tester, [0, 0, 255, 255]);
          fixture.adapter.complete(
            _target,
            failOriginal ? Uint8List.fromList([1, 2, 3]) : originalPng,
          );
          if (failOriginal) {
            await pumpUntil(
              tester,
              () => find.text('Retry').evaluate().isNotEmpty,
              reason: 'Original failure retains High',
            );
            await waitForPixel(tester, [0, 0, 255, 255]);
          } else {
            await waitForPixel(tester, [0, 255, 0, 255]);
          }
        });
        if (failOriginal) {
          fixture.adapter.pending.remove(_target);
          await tester.tap(find.text('Retry'));
          await tester.runAsync(() async {
            await pumpUntil(
              tester,
              () => fixture.adapter.pending.containsKey(_target),
              reason: 'explicit Original retry',
            );
            await waitForPixel(tester, [0, 0, 255, 255]);
            fixture.adapter.complete(_target, originalPng);
            await waitForPixel(tester, [0, 255, 0, 255]);
          });
        }
        expect(tester.state(find.byType(ExtendedImage)), same(state));
        expect(tester.getSize(find.byType(ExtendedRawImage)), bounds);
        expect(fixture.adapter.requests.map((r) => r.uri.toString()).toSet(), {
          _second,
          _target,
        });
        expect(fixture.adapter.requests, hasLength(failOriginal ? 3 : 2));
        expect(
          fixture.adapter.requests.where((r) => r.uri.toString() == _second),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
        await fixture.finish(tester);
      },
    );
  }
  testWidgets(
    'missing and identical intermediates never duplicate rendition requests',
    (tester) async {
      final fixture = _Fixture();
      await tester.pumpWidget(
        fixture.build(
          intermediates: ['', _lower, _second, _second, _target],
          fallbackUrls: [_second],
        ),
      );
      await tester.runAsync(() async {
        await waitForPixel(tester, [255, 0, 0, 255]);
        await pumpUntil(
          tester,
          () =>
              fixture.adapter.pending.containsKey(_second) &&
              fixture.adapter.pending.containsKey(_target),
          reason: 'distinct candidates',
        );
        fixture.adapter.complete(_target, originalPng);
        await waitForPixel(tester, [0, 255, 0, 255]);
        fixture.adapter.complete(_second, targetPng);
        await pumpUntil(
          tester,
          () => fixture.cache.bytes.containsKey(_second),
          reason: 'late intermediate completed',
        );
        await tester.pump();
        await waitForPixel(tester, [0, 255, 0, 255]);
      });
      expect(fixture.adapter.requests, hasLength(2));
      await fixture.finish(tester);
    },
  );
  testWidgets(
    'an unresolved thumbnail target cannot replace the cached larger grid image',
    (tester) async {
      final fixture = _Fixture();
      fixture.cache.bytes[_lower] = targetPng;
      fixture.cache.bytes[_target] = lowerPng;
      await tester.pumpWidget(
        fixture.build(fallback: _target, placeholder: _target),
      );
      await tester.runAsync(() => waitForPixel(tester, [0, 0, 255, 255]));
      expect(fixture.adapter.requests, isEmpty);
      await fixture.finish(tester);
    },
  );

  testWidgets(
    'a missing grid image can still fall back to the unresolved thumbnail',
    (tester) async {
      final fixture = _Fixture(cached: false);
      fixture.cache.bytes[_target] = lowerPng;
      await tester.pumpWidget(fixture.build(fallback: _target));
      await tester.runAsync(() async {
        await pumpUntil(
          tester,
          () => fixture.adapter.pending.containsKey(_lower),
          reason: 'larger grid request',
        );
        fixture.adapter.complete(_lower, Uint8List(0), status: 404);
        await waitForPixel(tester, [255, 0, 0, 255]);
      });
      expect(
        fixture.adapter.requests.map((request) => request.uri.toString()),
        [_lower],
      );
      await tester.pumpWidget(
        fixture.build(target: _second, fallback: _target),
      );
      await tester.runAsync(() async {
        await pumpUntil(
          tester,
          () => fixture.adapter.pending.containsKey(_second),
          reason: 'resolved original request',
        );
        fixture.adapter.complete(_second, targetPng);
        await waitForPixel(tester, [0, 0, 255, 255]);
      });
      await fixture.finish(tester);
    },
  );

  testWidgets(
    'failed larger image and unresolved thumbnail expose a working retry',
    (tester) async {
      final fixture = _Fixture(cached: false);
      await tester.pumpWidget(fixture.build(fallback: _target));
      await tester.runAsync(() async {
        for (final url in [_lower, _target]) {
          await pumpUntil(
            tester,
            () => fixture.adapter.pending.containsKey(url),
            reason: 'candidate $url',
          );
          fixture.adapter.complete(url, Uint8List(0), status: 404);
        }
        await pumpUntil(
          tester,
          () => find.byType(ErrorPlaceholder).evaluate().isNotEmpty,
          reason: 'retry after all candidates fail',
        );
      });
      fixture.adapter.pending.remove(_lower);
      await tester.tap(find.text('Retry'));
      await tester.runAsync(() async {
        await pumpUntil(
          tester,
          () => fixture.adapter.pending.containsKey(_lower),
          reason: 'explicit larger image retry',
        );
        fixture.adapter.complete(_lower, targetPng);
        await waitForPixel(tester, [0, 0, 255, 255]);
      });
      expect(
        fixture.adapter.requests.map((request) => request.uri.toString()),
        [_lower, _target, _lower],
      );
      await fixture.finish(tester);
    },
  );

  testWidgets(
    'decoded lower pixels remain through pending target and invalid target bytes',
    (tester) async {
      final adapter = ControlledImageAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final controller = ExtendedImageController();
      final cache = TestImageCache({'https://fixture.test/lower': lowerPng});
      await tester.pumpWidget(
        testApp(
          RawProgressivePostImage(
            dio: dio,
            imageUrl: 'https://fixture.test/target',
            lowerMedia: const GridThumbnailMedia(
              url: 'https://fixture.test/lower',
              aspectRatio: 1,
            ),
            aspectRatio: 1,
            geometryAspectRatio: 1,
            cacheManager: cache,
            controller: controller,
          ),
        ),
      );
      await decodePump(tester);
      expect(await paintedPixel(tester), [255, 0, 0, 255]);
      final bounds = tester.getSize(find.byType(ExtendedRawImage).first);
      expect(adapter.pending.keys, contains('https://fixture.test/target'));
      adapter.complete(
        'https://fixture.test/target',
        Uint8List.fromList([1, 2, 3]),
      );
      await decodePump(tester);
      expect(
        tester
            .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
            .where((widget) => widget.image != null),
        isNotEmpty,
        reason: 'decoded lower image must remain after target decoder failure',
      );
      expect(await paintedPixel(tester), [255, 0, 0, 255]);
      expect(tester.getSize(find.byType(ExtendedRawImage).first), bounds);
      expect(find.text('Retry'), findsOneWidget);
      adapter.pending.remove('https://fixture.test/target');
      await tester.tap(find.text('Retry'));
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => adapter.pending.containsKey('https://fixture.test/target'),
          reason: 'explicit retry of failed target',
        ),
      );
      expect(await paintedPixel(tester), [255, 0, 0, 255]);
      adapter.complete('https://fixture.test/target', targetPng);
      await tester.runAsync(() => waitForPixel(tester, [0, 0, 255, 255]));
      expect(find.text('Retry'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      dio.close(force: true);
    },
  );
  testWidgets(
    'success replaces decoded pixels on the same surface with one marked request',
    (tester) async {
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.build());
      await decodePump(tester);
      expect(
        fixture.coordinator
            .snapshot(ApiQuotaKey.fromUri(Uri.parse(_target)))
            .inFlight,
        0,
      );
      expect(
        fixture.coordinator
            .snapshot(ApiQuotaKey.fromUri(Uri.parse(_target)))
            .queued,
        0,
      );
      final surface = tester.state(find.byType(ExtendedImage));
      final bounds = tester.getSize(find.byType(ExtendedRawImage));
      expect(await paintedPixel(tester), [255, 0, 0, 255]);
      expect(fixture.controller.imageInfo.value!.image.width, 2);
      fixture.adapter.complete(_target, targetPng);
      await decodePump(tester);
      expect(await paintedPixel(tester), [0, 0, 255, 255]);
      expect(fixture.controller.imageInfo.value!.image.width, 8);
      expect(tester.state(find.byType(ExtendedImage)), same(surface));
      expect(tester.getSize(find.byType(ExtendedRawImage)), bounds);
      expect(
        fixture.adapter.requests.where(
          (request) => request.uri.toString() == _target,
        ),
        hasLength(1),
      );
      expect(
        fixture.adapter.requests.single.extra['boorusama.request.media'],
        isTrue,
      );
      await fixture.finish(tester);
    },
  );
  testWidgets(
    'uncached lower decodes first and remains after transport failure',
    (tester) async {
      final fixture = _Fixture(cached: false);
      await tester.pumpWidget(fixture.build());
      await decodePump(tester);
      fixture.adapter.complete(_lower, lowerPng);
      await decodePump(tester);
      expect(await paintedPixel(tester), [255, 0, 0, 255]);
      fixture.adapter.complete(_target, Uint8List(0), status: 404);
      await decodePump(tester);
      expect(await paintedPixel(tester), [255, 0, 0, 255]);
      expect(fixture.controller.loadState.value, LoadState.completed);
      await fixture.finish(tester);
    },
  );
  testWidgets('target first cannot be downgraded by a late lower completion', (
    tester,
  ) async {
    final fixture = _Fixture(cached: false);
    await tester.pumpWidget(fixture.build());
    await decodePump(tester);
    fixture.adapter.complete(_target, targetPng);
    await decodePump(tester);
    fixture.adapter.complete(_lower, lowerPng);
    await decodePump(tester);
    expect(await paintedPixel(tester), [0, 0, 255, 255]);
    await fixture.finish(tester);
  });
  testWidgets(
    'a second upgrade retains the last successful image and ignores superseded targets',
    (tester) async {
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.build());
      await decodePump(tester);
      fixture.adapter.complete(_target, targetPng);
      await decodePump(tester);
      await tester.pumpWidget(fixture.build(target: _second));
      await decodePump(tester);
      expect(await paintedPixel(tester), [0, 0, 255, 255]);
      await tester.pumpWidget(fixture.build(target: _third));
      await decodePump(tester);
      fixture.adapter.complete(_third, portraitPng);
      await decodePump(tester);
      fixture.adapter.complete(_second, lowerPng);
      await decodePump(tester);
      expect(await paintedPixel(tester), [0, 255, 0, 255]);
      await fixture.finish(tester);
    },
  );
  testWidgets(
    'identity changes clear retained pixels and pending completions cannot cross the boundary',
    (tester) async {
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.build());
      await decodePump(tester);
      expect(await paintedPixel(tester), [255, 0, 0, 255]);
      await tester.pumpWidget(
        fixture.build(target: _second, key: 'other-auth-and-origin', lower: ''),
      );
      await decodePump(tester);
      expect(find.byType(ExtendedRawImage), findsNothing);
      fixture.adapter.complete(_target, targetPng);
      await decodePump(tester);
      expect(find.byType(ExtendedRawImage), findsNothing);
      fixture.adapter.complete(_second, portraitPng);
      await decodePump(tester);
      expect(await paintedPixel(tester), [0, 255, 0, 255]);
      await fixture.finish(tester);
    },
  );
  for (final hasLower in [false, true]) {
    testWidgets(
      'failed target with ${hasLower ? 'failed' : 'no'} lower shows the normal error',
      (tester) async {
        final fixture = _Fixture(cached: false);
        await tester.pumpWidget(fixture.build(lower: hasLower ? _lower : ''));
        await decodePump(tester);
        if (hasLower) {
          fixture.adapter.complete(_lower, Uint8List.fromList([1, 2, 3]));
        }
        fixture.adapter.complete(_target, Uint8List.fromList([1, 2, 3]));
        await decodePump(tester);
        expect(find.byType(ErrorPlaceholder), findsOneWidget);
        expect(fixture.controller.imageInfo.value, isNull);
        await fixture.finish(tester);
      },
    );
  }
  testWidgets('same lower and target URL uses one decoded request', (
    tester,
  ) async {
    final fixture = _Fixture(cached: false);
    await tester.pumpWidget(fixture.build(lower: _target));
    await decodePump(tester);
    fixture.adapter.complete(_target, targetPng);
    await decodePump(tester);
    expect(await paintedPixel(tester), [0, 0, 255, 255]);
    expect(fixture.adapter.requests, hasLength(1));
    await fixture.finish(tester);
  });
  testWidgets(
    'cropped lower stays visible inside target bounds and is not edge-ready',
    (tester) async {
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.build(aspectRatio: 0.25));
      await decodePump(tester);
      final bounds = tester.getSize(find.byType(ExtendedRawImage));
      expect(bounds, const Size(75, 300));
      expect(await paintedPixel(tester), [255, 0, 0, 255]);
      expect(fixture.ready, [false]);
      expect(
        tester.widget<ExtendedImage>(find.byType(ExtendedImage)).fit,
        BoxFit.contain,
      );
      fixture.adapter.complete(_target, portraitPng);
      await decodePump(tester);
      expect(await paintedPixel(tester), [0, 255, 0, 255]);
      expect(tester.getSize(find.byType(ExtendedRawImage)), bounds);
      expect(fixture.ready, [false, true]);
      await fixture.finish(tester);
    },
  );
  for (final alternate in [false, true]) {
    testWidgets(
      'configured lower fallback decodes while target remains pending (alternate=$alternate)',
      (tester) async {
        final fixture = _Fixture(cached: false);
        await tester.pumpWidget(
          fixture.build(
            fallback: alternate ? _third : _second,
            fallbackUrls: alternate ? [_second] : [],
          ),
        );
        await decodePump(tester);
        fixture.adapter.complete(_lower, Uint8List.fromList([1, 2, 3]));
        await decodePump(tester);
        fixture.adapter.complete(_second, lowerPng);
        await decodePump(tester);
        expect(await paintedPixel(tester), [255, 0, 0, 255]);
        expect(fixture.adapter.pending, isNot(contains(_third)));
        await fixture.finish(tester);
        fixture.adapter.complete(_target, targetPng);
        await decodePump(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'decoded lower geometry cannot inherit incompatible stored dimensions',
    (tester) async {
      final fixture = _Fixture();
      fixture.cache.bytes[_lower] = portraitPng;
      await tester.pumpWidget(fixture.build());
      await decodePump(tester);
      expect(await paintedPixel(tester), [0, 255, 0, 255]);
      expect(fixture.ready, [false]);
      await fixture.finish(tester);
    },
  );
  for (final lower in [_target, '']) {
    for (final result in ['success', 'decoder failure', 'transport failure']) {
      testWidgets(
        'distinct thumbnail survives $result when lower primary is ${lower.isEmpty ? 'empty' : 'target'}',
        (tester) async {
          final fixture = _Fixture();
          await tester.pumpWidget(
            fixture.build(
              lower: lower,
              placeholder: result == 'decoder failure' ? _target : _lower,
              fallback: result == 'decoder failure' ? _lower : _target,
            ),
          );
          await decodePump(tester);
          expect(await paintedPixel(tester), [255, 0, 0, 255]);
          expect(
            fixture.adapter.requests.where(
              (request) => request.uri.toString() == _target,
            ),
            hasLength(1),
          );
          final state = tester.state(find.byType(ExtendedImage));
          final bounds = tester.getSize(find.byType(ExtendedRawImage));
          fixture.adapter.complete(
            _target,
            result == 'success' ? targetPng : Uint8List.fromList([1, 2, 3]),
            status: result == 'transport failure' ? 404 : 200,
          );
          await decodePump(tester);
          expect(
            await paintedPixel(tester),
            result == 'success' ? [0, 0, 255, 255] : [255, 0, 0, 255],
          );
          expect(tester.state(find.byType(ExtendedImage)), same(state));
          expect(tester.getSize(find.byType(ExtendedRawImage)), bounds);
          expect(
            fixture.adapter.requests.where(
              (request) => request.uri.toString() == _target,
            ),
            hasLength(1),
          );
          await fixture.finish(tester);
        },
      );
    }
  }

  testWidgets(
    'geometry recovery recomputes decoded compatibility without fetching or replacing pixels',
    (tester) async {
      final fixture = _Fixture(cached: false);
      Widget build(double? ratio) =>
          fixture.build(lower: '', geometry: () => ratio);
      await tester.pumpWidget(build(null));
      await decodePump(tester);
      fixture.adapter.complete(_target, targetPng);
      await decodePump(tester);
      expect(fixture.ready, [false]);
      final state = tester.state(find.byType(ExtendedImage));
      final image = fixture.controller.imageInfo.value!.image;
      final bounds = tester.getSize(find.byType(ExtendedRawImage));
      await tester.pumpWidget(build(0.25));
      await tester.pump();
      expect(fixture.ready, [false]);
      await tester.pumpWidget(build(1));
      await tester.pump();
      expect(fixture.ready, [false, true]);
      await tester.pumpWidget(build(1));
      await tester.pump();
      expect(fixture.ready, [
        false,
        true,
      ], reason: 'unchanged compatibility must not notify');
      await tester.pumpWidget(build(0.25));
      await tester.pump();
      expect(fixture.ready, [false, true, false]);
      await tester.pumpWidget(build(null));
      await tester.pump();
      expect(fixture.ready, [false, true, false]);
      expect(tester.state(find.byType(ExtendedImage)), same(state));
      expect(fixture.controller.imageInfo.value!.image, same(image));
      expect(tester.getSize(find.byType(ExtendedRawImage)), bounds);
      expect(await paintedPixel(tester), [0, 0, 255, 255]);
      expect(fixture.adapter.requests, hasLength(1));
      await fixture.finish(tester);
    },
  );

  testWidgets(
    'decoded geometry transition cancels a held edge drag without refetching',
    (tester) async {
      final fixture = _Fixture(cached: false);
      final matrix = TransformationController(
        Matrix4.diagonal3Values(2, 2, 1)..setTranslationRaw(-300, -150, 0),
      );
      final transform = PostViewerTransformationController(matrix)
        ..viewportSize = const Size(300, 300);
      final pages = PostDetailsPageViewController(
        initialPage: 0,
        totalPage: 2,
        checkIfLargeScreen: () => false,
      )..zoom.value = true;
      final settled = ValueNotifier<int?>(0);
      final mediaState = ValueNotifier<int>(0);
      var nextCount = 0;
      final navigation = ZoomPageNavigationScope(
        previousLabel: 'Previous',
        nextLabel: 'Next',
        previousActionId: null,
        nextActionId: 1,
        onPrevious: null,
        onNext: () => nextCount++,
        child: const SizedBox(),
      );
      Widget build(double ratio) => testApp(
        ZoomEdgePageGesture(
          transform: transform,
          pageController: pages,
          currentSettledPage: settled,
          pageIndex: 0,
          contentSize: const Size(300, 300),
          navigation: navigation,
          enabled: true,
          mediaState: mediaState,
          child: RawProgressivePostImage(
            key: const ValueKey('same-identity-and-auth'),
            dio: fixture.dio,
            imageUrl: _target,
            intermediateImageUrls: const [_second],
            lowerMedia: const GridThumbnailMedia(url: '', aspectRatio: null),
            aspectRatio: 1,
            geometryAspectRatio: ratio,
            cacheManager: fixture.cache,
            controller: fixture.controller,
            onRepresentationChanged: (_) => mediaState.value++,
          ),
        ),
      );
      await tester.pumpWidget(build(1));
      final initialMatrix = matrix.value.storage.toList();
      await tester.runAsync(() async {
        await pumpUntil(
          tester,
          () =>
              fixture.adapter.pending.containsKey(_second) &&
              fixture.adapter.pending.containsKey(_target),
          reason: 'zoomed progressive candidates',
        );
        fixture.adapter.complete(_second, targetPng);
        await waitForPixel(tester, [0, 0, 255, 255]);
        expect(matrix.value.storage, initialMatrix);
        fixture.adapter.complete(_target, originalPng);
        await waitForPixel(tester, [0, 255, 0, 255]);
        expect(matrix.value.storage, initialMatrix);
      });
      final image = fixture.controller.imageInfo.value!.image;
      final before = matrix.value.storage.toList();
      final held = await tester.startGesture(
        tester.getCenter(find.byType(ExtendedRawImage)),
      );
      await held.moveBy(const Offset(-170, 0));
      await tester.pump();
      await tester.pumpWidget(build(0.25));
      await tester.pump();
      await held.up();
      await tester.pumpAndSettle();
      expect(
        nextCount,
        0,
        reason: 'a geometry-only compatibility change must invalidate the held drag',
      );
      expect(matrix.value.storage, before);
      expect(fixture.controller.imageInfo.value!.image, same(image));
      expect(await paintedPixel(tester), [0, 255, 0, 255]);
      expect(fixture.adapter.requests, hasLength(2));
      await tester.pumpWidget(build(1));
      await tester.pump();
      final fresh = await tester.startGesture(
        tester.getCenter(find.byType(ExtendedRawImage)),
      );
      await fresh.moveBy(const Offset(-170, 0));
      await fresh.up();
      await tester.pumpAndSettle();
      expect(nextCount, 1);
      await fixture.finish(tester);
      mediaState.dispose();
      settled.dispose();
      pages.dispose();
      matrix.dispose();
    },
  );
  for (final failure in ['404', 'timeout']) {
    testWidgets(
      'production media Dio single $failure retains decoded lower without unhandled errors',
      (tester) async {
        final fixture = _Fixture(production: true);
        const target = 'https://fixture.test/target.png';
        const lower = 'https://fixture.test/lower.png';
        fixture.cache.bytes[lower] = lowerPng;
        await tester.pumpWidget(fixture.build(target: target, lower: lower));
        await decodePump(tester);
        expect(await paintedPixel(tester), [255, 0, 0, 255]);
        expect(fixture.adapter.requests, hasLength(1));
        if (failure == '404') {
          fixture.adapter.complete(target, Uint8List(0), status: 404);
        } else {
          fixture.adapter.pending[target]!.completeError(
            DioException.receiveTimeout(
              timeout: const Duration(seconds: 30),
              requestOptions: fixture.adapter.requests.single,
            ),
          );
        }
        await decodePump(tester);
        expect(await paintedPixel(tester), [255, 0, 0, 255]);
        expect(fixture.controller.loadState.value, LoadState.completed);
        expect(fixture.adapter.requests, hasLength(1));
        expect(
          tester.takeException(),
          isNull,
          reason: 'production transport errors must have an owner while the lower image remains visible',
        );
        await fixture.finish(tester);
      },
    );
  }
}

const _lower = 'https://fixture.test/lower';
const _target = 'https://fixture.test/target';
const _second = 'https://fixture.test/second';
const _third = 'https://fixture.test/third';

class _Fixture {
  _Fixture({bool cached = true, bool production = false})
    : dio = production ? newGenericDio(baseUrl: null) : Dio(),
      cache = TestImageCache(cached ? {_lower: lowerPng} : {}) {
    dio.httpClientAdapter = adapter;
    coordinateApiDio(dio, coordinator);
  }
  final adapter = ControlledImageAdapter();
  final Dio dio;
  final coordinator = ApiRequestCoordinator();
  final controller = ExtendedImageController();
  final TestImageCache cache;
  final ready = <bool>[];
  Widget build({
    String target = _target,
    String lower = _lower,
    String? fallback,
    List<String> fallbackUrls = const [],
    List<String> intermediates = const [],
    String? placeholder,
    double? Function()? geometry,
    String key = 'same-post',
    double aspectRatio = 1,
  }) => testApp(
    Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: RawProgressivePostImage(
          key: ValueKey(key),
          dio: dio,
          imageUrl: target,
          intermediateImageUrls: intermediates,
          lowerMedia: GridThumbnailMedia(
            url: lower,
            aspectRatio: 1,
            fallbackUrl: fallback,
            fallbackUrls: fallbackUrls,
            placeholderUrl: placeholder,
          ),
          aspectRatio: aspectRatio,
          geometryAspectRatio: geometry == null ? aspectRatio : geometry(),
          cacheManager: cache,
          controller: controller,
          onRepresentationChanged: ready.add,
        ),
      ),
    ),
  );
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    dio.close(force: true);
    coordinator.dispose();
  }
}
