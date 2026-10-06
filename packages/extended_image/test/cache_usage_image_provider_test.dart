import 'dart:async';
import 'dart:io';

import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late DefaultImageCacheManager manager;
  late Uint8List png;
  late _Transport adapter;
  late Dio dio;
  setUp(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    root = await Directory.systemTemp.createTemp('decoded-usage-');
    png = await File(
      '../../test/fixtures/post_quality/lower.png',
    ).readAsBytes();
    manager = DefaultImageCacheManager(cacheRootPathProvider: () => root.path);
    adapter = _Transport(png);
    dio = Dio()..httpClientAdapter = adapter;
  });
  tearDown(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await manager.dispose();
    await root.delete(recursive: true);
    dio.close(force: true);
  });
  ImageProvider provider(
    String name, {
    bool resized = false,
    bool cache = true,
    Duration? maxAge,
    String? customCache,
  }) => ExtendedImage.network(
    'https://fixture.test/$name.png',
    dio: dio,
    cacheManager: manager,
    cacheWidth: resized ? 16 : null,
    cache: cache,
    cacheMaxAge: maxAge,
    imageCacheName: customCache,
  ).image;
  String key(String name) =>
      manager.generateCacheKey('https://fixture.test/$name.png');

  for (final resized in [false, true]) {
    test(
      'a ${resized ? "resized" : "normal"} decoded RAM hit updates restart LRU without another fetch or decode',
      () async {
        await manager.setMaxBytes(png.length * 2);
        final first = await _decoded(provider('A', resized: resized));
        await _decoded(provider('B', resized: resized));
        final hit = await _decoded(provider('A', resized: resized));
        expect(identical(hit.completer, first.completer), isTrue);
        expect(
          hit.synchronous,
          isTrue,
          reason: 'the held decoded provider handoff stays synchronous',
        );
        expect(adapter.requests, 2);
        await manager.dispose();
        final restarted = DefaultImageCacheManager(
          cacheRootPathProvider: () => root.path,
        );
        await restarted.setMaxBytes(png.length * 2);
        await restarted.saveFile(key('C'), png);
        expect(await restarted.hasValidCache(key('A')), isTrue);
        expect(await restarted.hasValidCache(key('B')), isFalse);
        await restarted.dispose();
      },
    );
  }

  for (final resized in [false, true]) {
    test(
      'live budget changes preserve ${resized ? "resized" : "normal"} decoded provider keys and completers',
      () async {
        final before = await _decoded(provider('limit', resized: resized));
        await manager.setMaxBytes(0);
        expect((await manager.getStats()).retainedBytes, 0);
        final disabled = await _decoded(provider('limit', resized: resized));
        expect(disabled.completer, same(before.completer));
        expect(disabled.synchronous, isTrue);
        await manager.setMaxBytes(png.length * 2);
        final enabled = await _decoded(provider('limit', resized: resized));
        expect(enabled.completer, same(before.completer));
        expect(adapter.requests, 1);
      },
    );
  }

  test(
    'an accepted cached preload records use while ordinary probes remain inert',
    () async {
      await manager.setMaxBytes(png.length * 2);
      await manager.saveFile(key('A'), png);
      await manager.saveFile(key('B'), png);
      await ImagePreloader(
        cacheManager: manager,
        dio: dio,
      ).preloadImage('https://fixture.test/A.png');
      await manager.hasValidCache(key('B'));
      await manager.saveFile(key('C'), png);
      expect(adapter.requests, 0);
      expect(await manager.hasValidCache(key('A')), isTrue);
      expect(await manager.hasValidCache(key('B')), isFalse);
    },
  );

  test(
    'custom decoded cache and raw bytes survive wrapping and explicit eviction',
    () async {
      final image = ExtendedImage.network(
        'https://fixture.test/raw.png',
        dio: dio,
        cacheManager: manager,
        cacheRawData: true,
        cacheWidth: 16,
        imageCacheName: 'usage-test',
      ).image;
      await _decoded(image);
      expect((image as ExtendedImageProvider).rawImageData, png);
      expect(
        (await image.obtainCacheStatus(
          configuration: ImageConfiguration.empty,
        ))?.keepAlive,
        isTrue,
      );
      await image.evict();
      expect(
        (await image.obtainCacheStatus(
          configuration: ImageConfiguration.empty,
        ))?.keepAlive,
        isFalse,
      );
      imageCaches.remove('usage-test')?.clear();
    },
  );

  test(
    'provider key, status and eviction probes do not count as image use',
    () async {
      await manager.setMaxBytes(png.length * 2);
      await _decoded(provider('A', resized: true));
      await _decoded(provider('B', resized: true));
      final probe = provider('A', resized: true);
      await probe.obtainKey(ImageConfiguration.empty);
      await probe.obtainCacheStatus(configuration: ImageConfiguration.empty);
      await probe.evict();
      await manager.saveFile(key('C'), png);
      expect(await manager.hasValidCache(key('A')), isFalse);
      expect(await manager.hasValidCache(key('B')), isTrue);
    },
  );

  test('ordinary image providers reuse disk bytes older than a week', () async {
    await manager.saveFile(key('A'), png);
    await File(
      (await manager.getCachedFilePath(key('A')))!,
    ).setLastModified(DateTime.now().subtract(const Duration(days: 9)));
    await _decoded(provider('A'));
    expect(adapter.requests, 0);
  });

  test(
    'an explicit mutable-image age policy still refetches expired bytes',
    () async {
      await manager.saveFile(key('A'), png);
      await File(
        (await manager.getCachedFilePath(key('A')))!,
      ).setLastModified(DateTime.now().subtract(const Duration(days: 9)));
      await _decoded(provider('A', maxAge: const Duration(hours: 1)));
      expect(adapter.requests, 1);
    },
  );

  test(
    'disabled image storage and cache false still decode successful network bytes',
    () async {
      await manager.setMaxBytes(0);
      await _decoded(provider('A'));
      await _decoded(provider('B', cache: false));
      expect(adapter.requests, 2);
      expect(await manager.hasValidCache(key('A')), isFalse);
      expect(await manager.hasValidCache(key('B')), isFalse);
      expect(
        await Directory('${root.path}/cacheimage').list().toList(),
        isEmpty,
      );
    },
  );

  test(
    'AVIF decoded RAM hits update LRU without replacing the exact decoded completer',
    () async {
      final avif = await File('test/fixtures/red.avif').readAsBytes();
      adapter = _Transport(avif);
      dio.httpClientAdapter = adapter;
      await manager.setMaxBytes(avif.length * 2);
      ImageProvider image(String name) => ExtendedImage.network(
        'https://fixture.test/$name.avif',
        dio: dio,
        cacheManager: manager,
        platform: TargetPlatform.linux,
      ).image;
      final first = await _decoded(image('A'));
      await _decoded(image('B'));
      final hit = await _decoded(image('A'));
      expect(identical(first.completer, hit.completer), isTrue);
      expect(hit.synchronous, isTrue);
      expect(adapter.requests, 2);
      await manager.saveFile(
        manager.generateCacheKey('https://fixture.test/C.avif'),
        avif,
      );
      expect(
        await manager.hasValidCache(
          manager.generateCacheKey('https://fixture.test/A.avif'),
        ),
        isTrue,
      );
      expect(
        await manager.hasValidCache(
          manager.generateCacheKey('https://fixture.test/B.avif'),
        ),
        isFalse,
      );
    },
  );

  test(
    'AVIF cache false decodes network bytes without disk admission',
    () async {
      final avif = await File('test/fixtures/red.avif').readAsBytes();
      adapter = _Transport(avif);
      dio.httpClientAdapter = adapter;
      final image = ExtendedImage.network(
        'https://fixture.test/A.avif',
        dio: dio,
        cacheManager: manager,
        cache: false,
        platform: TargetPlatform.linux,
      ).image;
      await _decoded(image);
      expect(adapter.requests, 1);
      expect(
        await manager.hasValidCache(
          manager.generateCacheKey('https://fixture.test/A.avif'),
        ),
        isFalse,
      );
    },
  );

  for (final avifBranch in [false, true]) {
    test(
      '${avifBranch ? "AVIF" : "ordinary"} standalone provider without a manager displays without creating a fallback disk coordinator',
      () async {
        if (avifBranch) {
          adapter = _Transport(
            await File('test/fixtures/red.avif').readAsBytes(),
          );
          dio.httpClientAdapter = adapter;
        }
        final image = ExtendedImage.network(
          'https://fixture.test/standalone.${avifBranch ? "avif" : "png"}',
          dio: dio,
          platform: TargetPlatform.linux,
        ).image;
        await _decoded(image);
        expect(adapter.requests, 1);
      },
    );
  }

  test(
    'different managers cannot borrow a decoded image from another cache domain',
    () async {
      await _decoded(provider('A'));
      final otherRoot = await Directory.systemTemp.createTemp('second-domain-');
      final other = DefaultImageCacheManager(
        cacheRootPathProvider: () => otherRoot.path,
      );
      final image = ExtendedImage.network(
        'https://fixture.test/A.png',
        dio: dio,
        cacheManager: other,
      ).image;
      await _decoded(image);
      expect(adapter.requests, 2);
      expect(await other.hasValidCache(key('A')), isTrue);
      await other.dispose();
      await otherRoot.delete(recursive: true);
    },
  );
}

Future<({ImageStreamCompleter? completer, bool synchronous})> _decoded(
  ImageProvider provider,
) async {
  final stream = provider.resolve(ImageConfiguration.empty);
  final done =
      Completer<({ImageStreamCompleter? completer, bool synchronous})>();
  late ImageStreamListener listener;
  listener = ImageStreamListener((info, synchronous) {
    info.dispose();
    done.complete((completer: stream.completer, synchronous: synchronous));
  }, onError: done.completeError);
  stream.addListener(listener);
  try {
    return await done.future;
  } finally {
    stream.removeListener(listener);
  }
}

class _Transport implements HttpClientAdapter {
  _Transport(this.png);
  final Uint8List png;
  var requests = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    expect(options.extra['boorusama.request.media'], true);
    return ResponseBody.fromBytes(png, 200);
  }

  @override
  void close({bool force = false}) {}
}
