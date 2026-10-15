import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:boorusama/core/posts/details/src/widgets/progressive_post_image.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/src/image/raw_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progressive_image_test_utils.dart';

class _CountingCache extends ImageCache {
  final resolutions = <({Object key, ImageStreamCompleter completer})>[];
  @override
  ImageStreamCompleter? putIfAbsent(
    Object key,
    ImageStreamCompleter Function() loader, {
    ImageErrorListener? onError,
  }) {
    final value = super.putIfAbsent(key, loader, onError: onError);
    if (value != null) resolutions.add((key: key, completer: value));
    return value;
  }
}

class _ControlCompleter extends ImageStreamCompleter {}

class _DecodeBinding extends AutomatedTestWidgetsFlutterBinding {
  var decodes = 0;
  var decodeDelay = Duration.zero;
  @override
  ImageCache createImageCache() => _CountingCache();
  @override
  Future<ui.Codec> instantiateImageCodecWithSize(
    ui.ImmutableBuffer buffer, {
    ui.TargetImageSizeCallback? getTargetSize,
  }) async {
    decodes++;
    if (decodeDelay > Duration.zero) {
      await Future<void>.delayed(decodeDelay);
    }
    return super.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: getTargetSize,
    );
  }
}

// These tests use real disk I/O and native decoding inside runAsync. Pumping
// frames for a fixed interval does not guarantee either operation has finished.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() ready,
  String description,
) async {
  final elapsed = Stopwatch()..start();
  do {
    await tester.pump();
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  } while (elapsed.elapsed < const Duration(seconds: 10));
  fail('Timed out waiting for $description');
}

int? _displayedWidth(WidgetTester tester) => tester
    .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
    .map((widget) => widget.image)
    .nonNulls
    .firstOrNull
    ?.width;

bool _candidateFinished(_CountingCache cache, String url) {
  final resolutions = cache.resolutions.where(
    (record) => record.key.toString().contains(url),
  );
  return resolutions.isNotEmpty &&
      resolutions.every((record) => !record.completer.hasListeners);
}

bool _allReleased(_CountingCache cache) =>
    cache.liveImageCount == 0 &&
    cache.pendingImageCount == 0 &&
    cache.resolutions.every((record) => !record.completer.hasListeners);

void main() {
  final binding = _DecodeBinding();
  test('framework zero-limit failed loads retain their cache-owned listener', () {
    final cache = ImageCache()
      ..maximumSize = 0
      ..maximumSizeBytes = 0;
    final completer = _ControlCompleter();
    cache.putIfAbsent('framework-control', () => completer);
    final listener = ImageStreamListener((_, _) {}, onError: (_, _) {});
    completer.addListener(listener);
    completer.reportError(
      context: ErrorDescription('framework control'),
      exception: StateError('failed load'),
      silent: true,
    );
    completer.removeListener(listener);
    expect(cache.pendingImageCount, 0);
    expect(cache.liveImageCount, 1);
    expect(
      completer.hasListeners,
      isTrue,
      reason:
          'Flutter installs a success-only listener without a pending entry when both limits are zero',
    );
    cache.clearLiveImages();
  });
  testWidgets(
    'progressive live handoff reuses the exact decoded completer when decoded cache admission is disabled',
    (tester) async {
      await tester.runAsync(() async {
        final decodedCache = binding.imageCache as _CountingCache;
        final oldCount = decodedCache.maximumSize;
        final oldBytes = decodedCache.maximumSizeBytes;
        final root = await Directory.systemTemp.createTemp(
          'progressive-not-admitted-',
        );
        final cache = DrainingImageCacheManager(
          cacheRootPathProvider: () => root.path,
        );
        final adapter = ControlledImageAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        const lower = 'https://non-admitted.test/lower.png';
        const target = 'https://non-admitted.test/target.png';
        try {
          decodedCache.clear();
          decodedCache.clearLiveImages();
          decodedCache.maximumSize = 0;
          decodedCache.maximumSizeBytes = 0;
          decodedCache.resolutions.clear();
          binding.decodes = 0;
          await tester.pumpWidget(
            testApp(
              RawProgressivePostImage(
                dio: dio,
                imageUrl: target,
                lowerMedia: const GridThumbnailMedia(
                  url: lower,
                  aspectRatio: 1,
                ),
                aspectRatio: 1,
                geometryAspectRatio: 1,
                cacheManager: cache,
              ),
            ),
          );
          await _pumpUntil(
            tester,
            () =>
                adapter.pending.containsKey(lower) &&
                adapter.pending.containsKey(target),
            'both image requests',
          );
          adapter.complete(lower, lowerPng);
          await _pumpUntil(
            tester,
            () => _displayedWidth(tester) == 2,
            'the decoded lower image',
          );
          final retainedPixels = tester
              .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
              .map((image) => image.image)
              .nonNulls
              .first;
          expect(
            (await retainedPixels.toByteData())!.buffer.asUint8List().take(4),
            [255, 0, 0, 255],
          );
          // Exercise decoding that outlasts the former fixed 400 ms wait.
          binding.decodeDelay = const Duration(milliseconds: 600);
          adapter.complete(target, targetPng);
          await _pumpUntil(
            tester,
            () => _displayedWidth(tester) == 8,
            'the decoded target image',
          );
          final pixels = tester
              .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
              .map((image) => image.image)
              .nonNulls
              .first;
          expect((await pixels.toByteData())!.buffer.asUint8List().take(4), [
            0,
            0,
            255,
            255,
          ]);
          expect(decodedCache.currentSizeBytes, 0);
          expect(
            binding.decodes,
            2,
            reason:
                'each stage decodes once; displaying its held stream must not decode again',
          );
          for (final url in [lower, target]) {
            final stages = decodedCache.resolutions
                .where((record) => record.key.toString().contains(url))
                .toList();
            expect(stages.length, greaterThanOrEqualTo(2));
            expect(
              stages.every(
                (record) => identical(record.completer, stages.first.completer),
              ),
              isTrue,
            );
            expect(
              adapter.requests.where(
                (request) => request.uri.toString() == url,
              ),
              hasLength(1),
            );
          }
          await tester.pumpWidget(const SizedBox());
          await _pumpUntil(
            tester,
            () => _allReleased(decodedCache),
            'image listener cleanup',
          );
          expect(decodedCache.liveImageCount, 0);
          expect(decodedCache.pendingImageCount, 0);
          for (final completer
              in decodedCache.resolutions
                  .map((record) => record.completer)
                  .toSet()) {
            expect(completer.hasListeners, isFalse);
            expect(
              completer.keepAlive,
              throwsStateError,
              reason:
                  'all candidate and display keepAlive handles must release',
            );
          }
        } finally {
          await tester.pumpWidget(const SizedBox());
          binding.decodeDelay = Duration.zero;
          decodedCache.maximumSize = oldCount;
          decodedCache.maximumSizeBytes = oldBytes;
          decodedCache.clear();
          decodedCache.clearLiveImages();
          dio.close(force: true);
          await cache.drain();
          await cache.dispose();
          await root.delete(recursive: true);
        }
      });
    },
  );
  for (final targetFirst in [true, false]) {
    testWidgets(
      'non-admitted candidates release listeners and handles after ${targetFirst ? "target-first ignored lower" : "supersession and decode failure"}',
      (tester) async {
        await tester.runAsync(() async {
          final decodedCache = binding.imageCache as _CountingCache;
          final oldCount = decodedCache.maximumSize;
          final oldBytes = decodedCache.maximumSizeBytes;
          final root = await Directory.systemTemp.createTemp(
            'progressive-candidate-cleanup-',
          );
          final cache = DrainingImageCacheManager(
            cacheRootPathProvider: () => root.path,
          );
          final adapter = ControlledImageAdapter();
          final dio = Dio()..httpClientAdapter = adapter;
          const lower = 'https://cleanup.test/lower.png';
          const target = 'https://cleanup.test/target.png';
          const replacement = 'https://cleanup.test/replacement.png';
          var representationChanges = 0;
          Widget page(String url) => testApp(
            RawProgressivePostImage(
              key: const ValueKey('same-post'),
              onRepresentationChanged: (_) => representationChanges++,
              dio: dio,
              imageUrl: url,
              lowerMedia: const GridThumbnailMedia(url: lower, aspectRatio: 1),
              aspectRatio: 1,
              geometryAspectRatio: 1,
              cacheManager: cache,
            ),
          );

          try {
            decodedCache.clear();
            decodedCache.clearLiveImages();
            // A positive one-byte budget rejects these decoded PNGs while keeping
            // Flutter's pending-error cleanup active for cancelled/failed loads.
            decodedCache.maximumSize = targetFirst ? 0 : 1;
            decodedCache.maximumSizeBytes = targetFirst ? 0 : 1;
            decodedCache.resolutions.clear();
            binding.decodes = 0;
            await tester.pumpWidget(page(target));
            await _pumpUntil(
              tester,
              () =>
                  adapter.pending.containsKey(lower) &&
                  adapter.pending.containsKey(target),
              'both image requests',
            );
            if (targetFirst) {
              adapter.complete(target, targetPng);
              await _pumpUntil(
                tester,
                () => _displayedWidth(tester) == 8,
                'the decoded target image',
              );
              adapter.complete(lower, lowerPng);
              await _pumpUntil(
                tester,
                () => _candidateFinished(decodedCache, lower),
                'the ignored lower image to finish',
              );
            } else {
              adapter.complete(lower, lowerPng);
              await _pumpUntil(
                tester,
                () => _displayedWidth(tester) == 2,
                'the decoded lower image',
              );
              await tester.pumpWidget(page(replacement));
              await _pumpUntil(
                tester,
                () =>
                    adapter.pending.containsKey(replacement) &&
                    _candidateFinished(decodedCache, target),
                'replacement request and superseded target cancellation',
              );
              adapter.complete(target, targetPng);
              adapter.complete(replacement, Uint8List.fromList([1, 2, 3]));
              await _pumpUntil(
                tester,
                () => _candidateFinished(decodedCache, replacement),
                'the replacement decode failure',
              );
            }
            final pixels = tester
                .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
                .map((image) => image.image)
                .nonNulls
                .first;
            expect(
              (await pixels.toByteData())!.buffer.asUint8List().take(4),
              targetFirst ? [0, 0, 255, 255] : [255, 0, 0, 255],
            );
            expect(binding.decodes, 2);
            expect(decodedCache.currentSizeBytes, 0);
            if (!targetFirst) {
              // The cancelled URL can immediately be selected again. The failed
              // decoder's disk bytes are separate: clear those invalid bytes
              // explicitly before the server supplies a repaired image.
              await tester.pumpWidget(page(target));
              await _pumpUntil(
                tester,
                () =>
                    adapter.requests
                            .where(
                              (request) => request.uri.toString() == target,
                            )
                            .length >=
                        2 &&
                    _displayedWidth(tester) == 8,
                'the reselected target to decode and display',
              );
              expect(
                adapter.requests.where(
                  (request) => request.uri.toString() == target,
                ),
                hasLength(2),
              );
              expect(binding.decodes, 3);
              await cache.clearCache(cache.generateCacheKey(replacement));
              adapter.pending.remove(replacement);
              await tester.pumpWidget(page(replacement));
              await _pumpUntil(
                tester,
                () =>
                    adapter.requests
                        .where(
                          (request) => request.uri.toString() == replacement,
                        )
                        .length >=
                    2,
                'a fresh replacement request',
              );
              final beforeRecovery = representationChanges;
              adapter.complete(replacement, targetPng);
              await _pumpUntil(
                tester,
                // The superseded target can also be blue; wait for this
                // replacement's decoded handoff before inspecting its pixels.
                () =>
                    representationChanges > beforeRecovery &&
                    _displayedWidth(tester) == 8,
                'the recovered target image',
              );
              final recovered = tester
                  .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
                  .map((image) => image.image)
                  .nonNulls
                  .first;
              expect(
                (await recovered.toByteData())!.buffer.asUint8List().take(4),
                [0, 0, 255, 255],
              );
              expect(
                adapter.requests.where(
                  (request) => request.uri.toString() == replacement,
                ),
                hasLength(2),
              );
              expect(binding.decodes, 4);
              expect(decodedCache.currentSizeBytes, 0);
            }
            await tester.pumpWidget(const SizedBox());
            await _pumpUntil(
              tester,
              () => _allReleased(decodedCache),
              'image listener cleanup',
            );
            expect(decodedCache.liveImageCount, 0);
            expect(decodedCache.pendingImageCount, 0);
            for (final completer
                in decodedCache.resolutions
                    .map((record) => record.completer)
                    .toSet()) {
              expect(completer.hasListeners, isFalse);
              expect(completer.keepAlive, throwsStateError);
            }
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            decodedCache.maximumSize = oldCount;
            decodedCache.maximumSizeBytes = oldBytes;
            decodedCache.clear();
            decodedCache.clearLiveImages();
            dio.close(force: true);
            await cache.drain();
            await cache.dispose();
            await root.delete(recursive: true);
          }
        });
      },
    );
  }
}
