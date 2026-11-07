import 'dart:async';
import 'dart:typed_data';

import 'package:boorusama/core/images/scoped_image_cache_manager.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/src/cached_network_avif_image.dart';
import 'package:extended_image/src/dio_extended_image_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scoped cache key isolation', () {
    test(
      'private, public and other public namespaces never share keys',
      () async {
        final delegate = _FakeImageCacheManager();
        const url = 'https://cdn.example.test/post.jpg';
        const privateBytes = [1, 2, 3];
        final privateKey = delegate.generateCacheKey(url);
        await delegate.saveFile(privateKey, Uint8List.fromList(privateBytes));

        final public = _scope(delegate, 'public:safebooru');
        final otherPublic = _scope(delegate, 'public:konachan');
        final publicKey = public.generateCacheKey(url);
        final otherPublicKey = otherPublic.generateCacheKey(url);

        expect(publicKey, isNot(privateKey));
        expect(otherPublicKey, isNot(publicKey));
        expect(await public.getCachedFileBytes(publicKey), isNull);
        expect(await otherPublic.getCachedFileBytes(publicKey), isNull);
        expect(await delegate.getCachedFileBytes(privateKey), privateBytes);
        expect(delegate.byteReadKeys, [publicKey, privateKey]);
      },
    );

    test(
      'late cache read completion is discarded after scope revocation',
      () async {
        var current = true;
        final delegate = _FakeImageCacheManager();
        final pending = Completer<Uint8List?>();
        delegate.readBytes = (_) => pending.future;
        final manager = _scope(
          delegate,
          'public:safebooru',
          current: () => current,
        );
        final key = manager.generateCacheKey(
          'https://cdn.example.test/post.jpg',
        );

        final read = Future<Uint8List?>.sync(
          () => manager.getCachedFileBytes(key),
        );
        expect(delegate.byteReadKeys, [key]);
        current = false;
        pending.complete(Uint8List.fromList([4, 5]));

        expect(await read.timeout(const Duration(seconds: 5)), isNull);
        expect(await manager.getCachedFileBytes(key), isNull);
        expect(await manager.hasValidCache(key), isFalse);
        expect(delegate.byteReadKeys, [key]);
        expect(delegate.validityReadKeys, isEmpty);
      },
    );

    test(
      'rejects unissued writes and suppresses writes after revocation',
      () async {
        var current = true;
        final delegate = _FakeImageCacheManager();
        final manager = _scope(
          delegate,
          'public:safebooru',
          current: () => current,
        );
        final key = manager.generateCacheKey(
          'https://cdn.example.test/post.jpg',
        );
        final bytes = Uint8List.fromList([1]);

        await expectLater(
          manager.saveFile('unissued-key', bytes),
          throwsArgumentError,
        );
        expect(delegate.saveKeys, isEmpty);
        await manager.saveFile(key, bytes);
        expect(delegate.saveKeys, [key]);

        current = false;
        await manager.saveFile(key, Uint8List.fromList([2]));
        expect(delegate.saveKeys, [key]);

        await manager.clearCache('unissued-key');
        expect(delegate.clearKeys, isEmpty);
        await manager.clearCache(key);
        expect(delegate.clearKeys, [key]);
        expect(delegate.bytesByKey, isEmpty);
      },
    );

    test('removes a write that finishes after scope revocation', () async {
      var current = true;
      final delegate = _FakeImageCacheManager();
      final saveGate = Completer<void>();
      delegate.saveGate = saveGate;
      final manager = _scope(
        delegate,
        'public:safebooru',
        current: () => current,
      );
      final key = manager.generateCacheKey('https://cdn.example.test/post.jpg');

      final save = manager.saveFile(key, Uint8List.fromList([7]));
      expect(delegate.saveKeys, [key]);
      current = false;
      saveGate.complete();
      await save.timeout(const Duration(seconds: 5));

      expect(delegate.clearKeys, [key]);
      expect(delegate.bytesByKey, isEmpty);
    });
  });

  group('bounded cleanup and lifecycle', () {
    test(
      'clearAll only clears currently known keys and dispose preserves data',
      () async {
        final delegate = _FakeImageCacheManager();
        final privateKey = delegate.generateCacheKey('private-image');
        final privateBytes = Uint8List.fromList([9]);
        await delegate.saveFile(privateKey, privateBytes);

        final manager = _scope(delegate, 'public:safebooru');
        final firstKey = manager.generateCacheKey('public-image-1');
        final secondKey = manager.generateCacheKey('public-image-2');
        await manager.saveFile(firstKey, Uint8List.fromList([1]));
        await manager.saveFile(secondKey, Uint8List.fromList([2]));
        await manager.clearAllCache();

        expect(delegate.clearKeys, [firstKey, secondKey]);
        expect(delegate.clearAllCalls, 0);
        expect(await delegate.getCachedFileBytes(privateKey), privateBytes);

        final retainedKey = manager.generateCacheKey('public-image-retained');
        await manager.saveFile(retainedKey, Uint8List.fromList([3]));
        await manager.dispose();

        expect(delegate.disposeCalls, 0);
        expect(await delegate.getCachedFileBytes(privateKey), privateBytes);
        expect(await delegate.getCachedFileBytes(retainedKey), [3]);
        expect(await manager.getCachedFileBytes(retainedKey), isNull);
      },
    );

    test(
      'LRU bound forgets evicted keys and cannot clear unrelated cache data',
      () async {
        final delegate = _FakeImageCacheManager();
        final privateKey = delegate.generateCacheKey('private-image');
        await delegate.saveFile(privateKey, Uint8List.fromList([8]));
        final manager = _scope(
          delegate,
          'public:safebooru',
          maxKnownKeys: 2,
        );
        final first = manager.generateCacheKey('public-image-1');
        await manager.saveFile(first, Uint8List.fromList([1]));
        final second = manager.generateCacheKey('public-image-2');
        await manager.saveFile(second, Uint8List.fromList([2]));
        final third = manager.generateCacheKey('public-image-3');
        await manager.saveFile(third, Uint8List.fromList([3]));

        expect(await manager.getCachedFileBytes(first), isNull);
        await manager.clearCache(first);
        await manager.clearAllCache();

        expect(delegate.clearKeys, [second, third]);
        expect(await delegate.getCachedFileBytes(first), [1]);
        expect(await delegate.getCachedFileBytes(privateKey), [8]);
        expect(delegate.clearAllCalls, 0);
      },
    );

    test('validates namespace and key-bound configuration', () {
      final delegate = _FakeImageCacheManager();
      expect(
        () => _scope(delegate, '  '),
        throwsArgumentError,
      );
      expect(
        () => _scope(delegate, 'public:safebooru', maxKnownKeys: 0),
        throwsArgumentError,
      );
    });
  });

  test(
    'image providers distinguish identical URLs in separate cache scopes',
    () {
      final delegate = _FakeImageCacheManager();
      final first = _scope(delegate, 'public:safebooru');
      final second = _scope(delegate, 'public:konachan');
      final dio = Dio();
      const url = 'https://cdn.example.test/post.avif';
      const headers = {'User-Agent': 'test'};

      final dioFirst = DioExtendedNetworkImageProvider(
        url,
        dio: dio,
        headers: headers,
        cache: true,
        cacheManager: first,
      );
      final dioSecond = DioExtendedNetworkImageProvider(
        url,
        dio: dio,
        headers: headers,
        cache: true,
        cacheManager: second,
      );
      final avifFirst = CustomCachedNetworkAvifImageProvider(
        url,
        dio: dio,
        headers: headers,
        cacheManager: first,
      );
      final avifSecond = CustomCachedNetworkAvifImageProvider(
        url,
        dio: dio,
        headers: headers,
        cacheManager: second,
      );

      expect(dioFirst, isNot(dioSecond));
      expect(avifFirst, isNot(avifSecond));
      dio.close(force: true);
    },
  );
}

ScopedImageCacheManager _scope(
  ImageCacheManager delegate,
  String namespace, {
  bool Function()? current,
  int maxKnownKeys = 1024,
}) => ScopedImageCacheManager(
  delegate: delegate,
  namespace: namespace,
  current: current ?? () => true,
  maxKnownKeys: maxKnownKeys,
);

final class _FakeImageCacheManager implements ImageCacheManager {
  final bytesByKey = <String, Uint8List>{};
  final byteReadKeys = <String>[];
  final pathReadKeys = <String>[];
  final validityReadKeys = <String>[];
  final saveKeys = <String>[];
  final clearKeys = <String>[];
  FutureOr<Uint8List?> Function(String key)? readBytes;
  Completer<void>? saveGate;
  var clearAllCalls = 0;
  var disposeCalls = 0;
  var invalidateCalls = 0;

  @override
  String generateCacheKey(String url, {String? customKey}) => customKey ?? url;

  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) {
    pathReadKeys.add(key);
    return bytesByKey.containsKey(key) ? 'fake://$key' : null;
  }

  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) {
    byteReadKeys.add(key);
    return readBytes?.call(key) ?? bytesByKey[key];
  }

  @override
  Future<void> saveFile(String key, Uint8List bytes) async {
    saveKeys.add(key);
    await saveGate?.future;
    bytesByKey[key] = Uint8List.fromList(bytes);
  }

  @override
  FutureOr<bool> hasValidCache(String key, {Duration? maxAge}) {
    validityReadKeys.add(key);
    return bytesByKey.containsKey(key);
  }

  @override
  Future<void> clearCache(String key) async {
    clearKeys.add(key);
    bytesByKey.remove(key);
  }

  @override
  Future<void> clearAllCache() async {
    clearAllCalls++;
    bytesByKey.clear();
  }

  @override
  void invalidateCacheDirectory() {
    invalidateCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
