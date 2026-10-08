import 'dart:async';
import 'dart:io';

import 'package:cache_manager/cache_manager.dart';
import 'package:cache_manager/src/image_cache_manager_web.dart' as web;
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final kind in ['normal', 'avif', 'preload']) {
    for (final clearKey in [false, true]) {
      test(
        '$kind transport started before ${clearKey ? "key" : "all"} clear displays bytes without refilling disk',
        () async {
          final root = await Directory.systemTemp.createTemp(
            'transport-epoch-',
          );
          final cache = DefaultImageCacheManager(
            cacheRootPathProvider: () => root.path,
          );
          final bytes = await File(
            kind == 'avif'
                ? 'test/fixtures/red.avif'
                : '../../test/fixtures/post_quality/lower.png',
          ).readAsBytes();
          final adapter = _BarrierTransport(bytes);
          final dio = Dio()..httpClientAdapter = adapter;
          final url =
              'https://epoch.test/image.${kind == "avif" ? "avif" : "png"}';
          final key = cache.generateCacheKey(url);
          Future<void> load() => kind == 'preload'
              ? ImagePreloader(cacheManager: cache, dio: dio).preloadImage(url)
              : _decode(
                  ExtendedImage.network(
                    url,
                    dio: dio,
                    cacheManager: cache,
                    platform: TargetPlatform.linux,
                    cancelToken: CancelToken(),
                  ).image,
                  kind == 'avif' ? [255, 0, 1, 255] : [255, 0, 0, 255],
                );
          try {
            PaintingBinding.instance.imageCache.clear();
            final loading = load();
            await adapter.started.future;
            if (clearKey) {
              await cache.clearCache(key);
            } else {
              await cache.clearAllCache();
            }
            adapter.release.complete();
            await loading;
            expect(adapter.requests, 1);
            expect(
              await cache.getCachedFilePath(key),
              isNull,
              reason: 'the in-flight owner belongs to the cleared epoch',
            );
            expect((await cache.getStats()).retainedBytes, 0);
            expect(
              await Directory(
                '${root.path}/cacheimage-transfers',
              ).list().toList(),
              isEmpty,
            );
            PaintingBinding.instance.imageCache.clear();
            await load();
            expect(adapter.requests, 2);
            expect(await cache.getCachedFileBytes(key), bytes);
          } finally {
            PaintingBinding.instance.imageCache.clear();
            PaintingBinding.instance.imageCache.clearLiveImages();
            dio.close(force: true);
            await cache.dispose();
            await root.delete(recursive: true);
          }
        },
      );
    }
  }
  for (final cancelled in [false, true]) {
    for (final kind in ['normal', 'avif', 'preload']) {
      test(
        '$kind ${cancelled ? "cancelled" : "failed"} transport leaves no admission or partial file',
        () async {
          final root = await Directory.systemTemp.createTemp(
            'transport-abort-',
          );
          final cache = DefaultImageCacheManager(
            cacheRootPathProvider: () => root.path,
          );
          final bytes = await File(
            kind == 'avif'
                ? 'test/fixtures/red.avif'
                : '../../test/fixtures/post_quality/lower.png',
          ).readAsBytes();
          final adapter = _BarrierTransport(
            bytes,
            status: cancelled ? 200 : 404,
          );
          final dio = Dio()..httpClientAdapter = adapter;
          final token = CancelToken();
          final url =
              'https://abort.test/image.${kind == "avif" ? "avif" : "png"}';
          const strategy = FetchStrategyBuilder(maxAttempts: 1, silent: true);
          ImageProvider? image;
          try {
            final Future<void> loading;
            if (kind == 'preload') {
              loading = ImagePreloader(
                cacheManager: cache,
                dio: dio,
              ).preloadImage(url, cancelToken: token, fetchStrategy: strategy);
            } else {
              image = ExtendedImage.network(
                url,
                dio: dio,
                cacheManager: cache,
                platform: TargetPlatform.linux,
                cancelToken: token,
                fetchStrategy: strategy,
              ).image;
              loading = _decode(image, []);
            }
            final checked = kind == 'preload'
                ? loading
                : expectLater(loading, throwsA(isA<StateError>()));
            await adapter.started.future;
            if (cancelled) token.cancel('test cancellation');
            adapter.release.complete();
            await checked;
            expect(adapter.requests, 1);
            expect((await cache.getStats()).retainedBytes, 0);
            expect(
              await Directory(
                '${root.path}/cacheimage-transfers',
              ).list().toList(),
              isEmpty,
            );
            expect(
              await cache.hasValidCache(cache.generateCacheKey(url)),
              isFalse,
            );
          } finally {
            await image?.evict();
            dio.close(force: true);
            await cache.dispose();
            await root.delete(recursive: true);
          }
        },
      );
    }
  }
  for (final clearKey in [false, true]) {
    test(
      'web memory write respects ${clearKey ? "key" : "all"} clear during actual provider transport',
      () async {
        final cache = web.DefaultImageCacheManager();
        final bytes = await File(
          '../../test/fixtures/post_quality/lower.png',
        ).readAsBytes();
        final adapter = _BarrierTransport(bytes);
        final dio = Dio()..httpClientAdapter = adapter;
        const url = 'https://web-epoch.test/image.png';
        final key = cache.generateCacheKey(url);
        Future<void> load() => _decode(
          ExtendedImage.network(
            url,
            dio: dio,
            cacheManager: cache,
            cancelToken: CancelToken(),
          ).image,
          [255, 0, 0, 255],
        );
        try {
          final loading = load();
          await adapter.started.future;
          if (clearKey) {
            await cache.clearCache(key);
          } else {
            await cache.clearAllCache();
          }
          adapter.release.complete();
          await loading;
          expect(await cache.getCachedFileBytes(key), isNull);
          await load();
          expect(adapter.requests, 2);
          expect(await cache.getCachedFileBytes(key), bytes);
        } finally {
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          dio.close(force: true);
          await cache.dispose();
        }
      },
    );
  }
}

Future<void> _decode(ImageProvider provider, List<int> expectedPixel) async {
  final stream = provider.resolve(ImageConfiguration.empty);
  final done = Completer<void>();
  late ImageStreamListener listener;
  listener = ImageStreamListener((info, _) async {
    try {
      final rgba = await info.image.toByteData();
      expect(rgba!.buffer.asUint8List().take(4), expectedPixel);
      done.complete();
    } catch (error, stack) {
      done.completeError(error, stack);
    } finally {
      info.dispose();
    }
  }, onError: done.completeError);
  stream.addListener(listener);
  try {
    await done.future;
  } finally {
    stream.removeListener(listener);
  }
}

class _BarrierTransport implements HttpClientAdapter {
  _BarrierTransport(this.bytes, {this.status = 200});
  final Uint8List bytes;
  final int status;
  final started = Completer<void>();
  final release = Completer<void>();
  var requests = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    expect(options.extra['boorusama.request.media'], true);
    if (requests == 1) {
      started.complete();
      await release.future;
    }
    return ResponseBody.fromBytes(bytes, status);
  }

  @override
  void close({bool force = false}) {}
}
