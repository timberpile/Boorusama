import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:boorusama/core/posts/listing/src/providers/cached_grid_gif.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes/test_post.dart';
import 'large_grid_gif_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DefaultImageCacheManager cache;
  const url = 'https://cached-gif.test/original.gif';
  final bytes = largeGridGif();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('large-grid-gif-');
    cache = DefaultImageCacheManager(
      cacheRootPathProvider: () => directory.path,
    );
  });
  tearDown(() async {
    await cache.dispose();
    await directory.delete(recursive: true);
  });

  for (final size in [
    maxAutoplayGridGifBytes - 1,
    maxAutoplayGridGifBytes,
    maxAutoplayGridGifBytes + 1,
  ]) {
    for (final autoplay in AnimatedPostsDefaultState.values) {
      test(
        'size $size preserves the $autoplay policy without a valid cache',
        () {
          final post = TestPost(id: 1, format: 'gif', fileSize: size);
          final settings = GridThumbnailSettings(
            imageQuality: ImageQuality.high,
            animatedPostsDefaultState: autoplay,
            gridSize: GridSize.normal,
          );
          expect(
            shouldAutoplayGridGif(post, settings),
            autoplay == AnimatedPostsDefaultState.autoplay &&
                size <= maxAutoplayGridGifBytes,
          );
          final cached = GridThumbnailSettings(
            imageQuality: settings.imageQuality,
            animatedPostsDefaultState: autoplay,
            gridSize: settings.gridSize,
            allowLargeCachedGif: true,
          );
          expect(
            shouldAutoplayGridGif(post, cached),
            autoplay == AnimatedPostsDefaultState.autoplay,
          );
        },
      );
    }
  }

  test(
    'a missing cache entry remains missing without creating media',
    () async {
      expect(
        await readCachedGridGif(cache, url, originalSize: bytes.length),
        isNull,
      );
      expect((await cache.getStats()).retainedFileCount, 0);
    },
  );

  test('committed valid GIF bytes remain usable after eviction', () async {
    final key = cache.generateCacheKey(url);
    await cache.saveFile(key, bytes);
    final owned = await readCachedGridGif(
      cache,
      url,
      originalSize: bytes.length,
    );
    expect(owned, isNotNull);
    expect(owned!.length, greaterThan(maxAutoplayGridGifBytes));
    await cache.clearCache(key);
    expect(await cache.getCachedFilePath(key), isNull);
    expect(isCompleteGridGif(owned), isTrue);
  });

  test('eviction during eligibility cannot replace owned bytes with a network fetch', () async {
    final key = cache.generateCacheKey(url);
    await cache.saveFile(key, bytes);
    final reading = readCachedGridGif(cache, url, originalSize: bytes.length);
    await cache.clearCache(key);
    final owned = await reading;
    expect(owned, isNotNull);
    expect(isCompleteGridGif(owned!), isTrue);
  });

  test('uncommitted partial writes are never eligible', () async {
    final key = cache.generateCacheKey(url);
    final write = await cache.beginFileWrite(key);
    try {
      await File(write.stagedPath).writeAsBytes(bytes.sublist(0, 100));
      expect(await readCachedGridGif(cache, url), isNull);
    } finally {
      await write.abort();
    }
  });

  test(
    'empty, truncated, malformed and wrong-size cache entries remain static',
    () async {
      final key = cache.generateCacheKey(url);
      for (final invalid in [
        Uint8List(0),
        Uint8List(40),
        bytes.sublist(0, bytes.length - 1),
        Uint8List.fromList(
          [...bytes]
            ..[6] = 0
            ..[7] = 0,
        ),
      ]) {
        await cache.saveFile(key, invalid);
        expect(await readCachedGridGif(cache, url), isNull);
      }
      await cache.saveFile(key, bytes);
      expect(
        await readCachedGridGif(cache, url, originalSize: bytes.length + 1),
        isNull,
      );
    },
  );

  test(
    'a separately cached sample does not borrow the original byte count',
    () async {
      final sample = base64Decode(
        'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
      );
      await cache.saveFile(cache.generateCacheKey(url), sample);
      expect(await readCachedGridGif(cache, url), isNotNull);
      expect(
        await readCachedGridGif(cache, url, originalSize: bytes.length),
        isNull,
      );
    },
  );

  test(
    'a corrupt later animation frame cannot enable cached autoplay',
    () async {
      final invalid = largeGridGif(frameCount: 2, corruptLastFrame: true);
      expect(invalid.length, greaterThan(maxAutoplayGridGifBytes));
      expect(isCompleteGridGif(invalid), isTrue);
      final codec = await ui.instantiateImageCodec(
        invalid,
        targetWidth: 1,
        targetHeight: 1,
      );
      try {
        expect(codec.frameCount, 2);
        (await codec.getNextFrame()).image.dispose();
        await expectLater(codec.getNextFrame(), throwsA(isA<Exception>()));
      } finally {
        codec.dispose();
      }
      await cache.saveFile(cache.generateCacheKey(url), invalid);
      expect(
        await readCachedGridGif(cache, url, originalSize: invalid.length) ==
            null,
        isTrue,
      );
    },
  );

  test(
    'all frames of a valid cached animation enable playback',
    () async {
      final animation = largeGridGif(frameCount: 2);
      await cache.saveFile(cache.generateCacheKey(url), animation);
      expect(
        await readCachedGridGif(cache, url, originalSize: animation.length),
        isNotNull,
      );
    },
  );

  test(
    'long complete cached animations remain eligible after batched validation',
    () async {
      final animation = largeGridGif(frameCount: 1025);
      final key = cache.generateCacheKey(url);
      await cache.saveFile(key, animation);
      expect(
        await readCachedGridGif(cache, url, originalSize: animation.length),
        isNotNull,
      );
      expect(await cache.getCachedFilePath(key), isNotNull);
    },
  );

  test(
    'canceling admission while cache bytes are pending discards the result',
    () async {
      final pending = _PendingCacheRead();
      var cancelled = false;
      final result = readCachedGridGif(
        pending,
        url,
        isCancelled: () => cancelled,
      );
      await pending.started.future;
      cancelled = true;
      pending.bytes.complete(bytes);
      expect(await result, isNull);
    },
  );

  test('deleted committed files are treated as cache misses', () async {
    final key = cache.generateCacheKey(url);
    await cache.saveFile(key, bytes);
    final path = await cache.getCachedFilePath(key);
    await File(path!).delete();
    expect(await readCachedGridGif(cache, url), isNull);
  });
}

class _PendingCacheRead implements ImageCacheManager {
  final started = Completer<void>();
  final bytes = Completer<Uint8List?>();
  @override
  Future<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) {
    started.complete();
    return bytes.future;
  }

  @override
  String generateCacheKey(String url, {String? customKey}) => url;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
