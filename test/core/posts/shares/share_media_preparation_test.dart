// ignore_for_file: avoid_slow_async_io
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:image/image.dart' as img;

void main() {
  late Directory root;

  setUp(
    () async => root = await Directory.systemTemp.createTemp('share-test-'),
  );
  tearDown(() => root.delete(recursive: true));

  test(
    'cached image is exported with the variant format and removed on release',
    () async {
      final pngBytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 1, height: 1)),
      );
      final service = ShareMediaPreparation(
        rootPath: root.path,
        dio: Dio(),
        cachedBytes: (_) async => pngBytes,
      );

      final lease = await service.prepare(
        url: 'https://site.test/sample.png?token=private',
        kind: ShareMediaKind.image,
        fallbackExtension: 'jpg',
        headers: const {'Authorization': 'secret'},
      );

      expect(lease.path, endsWith('.png'));
      expect(
        File(lease.path).uri.pathSegments.last,
        startsWith('boorusama_share_'),
      );
      expect(lease.mimeType, 'image/png');
      expect(lease.path, isNot(contains('private')));
      expect(lease.path, isNot(contains('secret')));
      expect(await File(lease.path).readAsBytes(), pngBytes);
      await lease.release();
      expect(await File(lease.path).exists(), isFalse);
    },
  );

  test(
    'cache miss downloads exact URL with authentication and cleans up',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      String? requestedUri;
      String? authorization;
      server.listen((request) async {
        requestedUri = request.uri.toString();
        authorization = request.headers.value('authorization');
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add([4, 5, 6]);
        await request.response.close();
      });
      final service = ShareMediaPreparation(
        rootPath: root.path,
        dio: Dio(),
        cachedBytes: (_) async => null,
      );
      final progress = <double>[];

      final lease = await service.prepare(
        url: 'http://127.0.0.1:${server.port}/variant.jpg?size=sample',
        kind: ShareMediaKind.image,
        fallbackExtension: 'png',
        headers: const {'Authorization': 'secret'},
        onProgress: progress.add,
      );

      expect(requestedUri, '/variant.jpg?size=sample');
      expect(authorization, 'secret');
      expect(lease.mimeType, 'image/jpeg');
      expect(await File(lease.path).readAsBytes(), [4, 5, 6]);
      expect(progress, isNotEmpty);
      await lease.release();
      expect(await File(lease.path).exists(), isFalse);
    },
  );
  test(
    'downloaded content type determines the exported image format',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) async {
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add([137, 80, 78, 71]);
        await request.response.close();
      });
      final service = ShareMediaPreparation(
        rootPath: root.path,
        dio: Dio(),
        cachedBytes: (_) async => null,
      );

      final lease = await service.prepare(
        url: 'http://127.0.0.1:${server.port}/wrong.jpg',
        kind: ShareMediaKind.image,
        fallbackExtension: 'jpg',
        headers: const {},
      );

      expect(lease.path, endsWith('.png'));
      expect(lease.mimeType, 'image/png');
      await lease.release();
    },
  );

  test('startup cleanup removes expired files but keeps recent ones', () async {
    final directory = Directory('${root.path}/boorusama-share');
    await directory.create();
    final old = File('${directory.path}/old.jpg');
    final recent = File('${directory.path}/recent.jpg');
    await old.writeAsBytes([1]);
    await recent.writeAsBytes([2]);
    await old.setLastModified(
      DateTime.now().subtract(const Duration(hours: 25)),
    );
    final service = ShareMediaPreparation(
      rootPath: root.path,
      dio: Dio(),
      cachedBytes: (_) async => null,
    );

    await service.cleanupExpired();

    expect(await old.exists(), isFalse);
    expect(await recent.exists(), isTrue);
  });
  test(
    'image cache miss is downloaded into the viewer cache under its URL key',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final pngBytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 1, height: 1)),
      );
      server.listen((request) async {
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(pngBytes);
        await request.response.close();
      });
      final cache = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
      );
      addTearDown(cache.dispose);
      final url = 'http://127.0.0.1:${server.port}/original.png?token=private';
      final service = ShareMediaPreparation(
        rootPath: root.path,
        dio: Dio(),
        cachedBytes: (_) async => null,
        imageCacheManager: cache,
      );

      final lease = await service.prepare(
        url: url,
        kind: ShareMediaKind.original,
        fallbackExtension: 'png',
        headers: const {},
      );
      final cachedPath = await cache.getCachedFilePath(
        cache.generateCacheKey(url),
      );

      expect(lease.path, cachedPath);
      expect(lease.path, contains('/cacheimage/'));
      await lease.release();
      expect(await File(lease.path).exists(), isTrue);
      expect(await Directory('${root.path}/boorusama-share').exists(), isFalse);
    },
  );
  test(
    'invalid download does not replace a cached image or leave a partial',
    () async {
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 1, height: 1)),
      );
      final cache = _ForcedMissCacheManager(
        cacheRootPathProvider: () => root.path,
        key: 'preserved-image',
      );
      addTearDown(cache.dispose);
      const key = 'preserved-image';
      await cache.saveFile(key, png);
      final targetPath = await cache.getCacheFilePathForKey(key);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) async {
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(png.take(8).toList());
        await request.response.close();
      });
      final service = ShareMediaPreparation(
        rootPath: root.path,
        dio: Dio(),
        cachedBytes: (_) async => null,
        imageCacheManager: cache,
      );

      await expectLater(
        service.prepare(
          url: 'http://127.0.0.1:${server.port}/original.png',
          kind: ShareMediaKind.original,
          fallbackExtension: 'png',
          headers: const {},
        ),
        throwsA(isA<ShareMediaException>()),
      );

      expect(await File(targetPath!).readAsBytes(), png);
      expect(
        await Directory(
          '${root.path}/cacheimage',
        ).list().where((file) => file.path.endsWith('.partial')).toList(),
        isEmpty,
      );
    },
  );

  test('truncated cached image header is downloaded again', () async {
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 1, height: 1)),
    );
    final cache = _ForcedMissCacheManager(
      cacheRootPathProvider: () => root.path,
      key: 'truncated-image',
      forceMiss: false,
    );
    addTearDown(cache.dispose);
    const key = 'truncated-image';
    await cache.saveFile(key, Uint8List.fromList(png.take(8).toList()));
    var requests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      requests++;
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.add(png);
      await request.response.close();
    });
    final url = 'http://127.0.0.1:${server.port}/original.png';
    final service = ShareMediaPreparation(
      rootPath: root.path,
      dio: Dio(),
      cachedBytes: (_) async => null,
      imageCacheManager: cache,
    );

    final lease = await service.prepare(
      url: url,
      kind: ShareMediaKind.original,
      fallbackExtension: 'png',
      headers: const {},
    );

    expect(requests, 1);
    expect(await File(lease.path).readAsBytes(), png);
    await lease.release();
  });

  test(
    'cancellation preserves the previous cache entry and removes partial',
    () async {
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 1, height: 1)),
      );
      final cache = _ForcedMissCacheManager(
        cacheRootPathProvider: () => root.path,
        key: 'cancelled-image',
      );
      addTearDown(cache.dispose);
      const key = 'cancelled-image';
      await cache.saveFile(key, png);
      final targetPath = await cache.getCacheFilePathForKey(key);
      final started = Completer<void>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) async {
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(png.take(8).toList());
        await request.response.flush();
        started.complete();
        await Future<void>.delayed(const Duration(seconds: 1));
        request.response.add(png.skip(8).toList());
        await request.response.close();
      });
      final token = CancelToken();
      final service = ShareMediaPreparation(
        rootPath: root.path,
        dio: Dio(),
        cachedBytes: (_) async => null,
        imageCacheManager: cache,
      );
      final pending = service.prepare(
        url: 'http://127.0.0.1:${server.port}/original.png',
        kind: ShareMediaKind.original,
        fallbackExtension: 'png',
        headers: const {},
        cancelToken: token,
      );
      await started.future;
      token.cancel();

      await expectLater(pending, throwsA(isA<ShareMediaException>()));
      expect(await File(targetPath!).readAsBytes(), png);
      expect(
        await Directory(
          '${root.path}/cacheimage',
        ).list().where((file) => file.path.endsWith('.partial')).toList(),
        isEmpty,
      );
    },
  );
}

class _ForcedMissCacheManager extends DefaultImageCacheManager {
  _ForcedMissCacheManager({
    required super.cacheRootPathProvider,
    required this.key,
    this.forceMiss = true,
  });

  final String key;
  final bool forceMiss;

  @override
  String generateCacheKey(String url, {String? customKey}) => key;

  @override
  Future<String?> getCachedFilePath(String key, {Duration? maxAge}) async =>
      forceMiss ? null : super.getCachedFilePath(this.key, maxAge: maxAge);
}
