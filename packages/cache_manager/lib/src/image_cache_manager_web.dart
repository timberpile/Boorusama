import 'dart:async';
import 'dart:typed_data';

import 'managed_image_cache.dart';
import 'cache_utils.dart' as cache_utils;
import 'memory_cache.dart';

class DefaultImageCacheManager implements ManagedImageCacheManager {
  DefaultImageCacheManager({
    this.cacheDirName = 'cacheimage',
    this.enableLogging = false,
    this.cacheRootPathProvider,
    MemoryCache? memoryCache,
    int maxBytes = 1024 * 1024 * 1024,
  }) : _memoryCache = memoryCache ?? LRUMemoryCache();

  final String cacheDirName;
  final bool enableLogging;
  final FutureOr<String> Function()? cacheRootPathProvider;
  final MemoryCache _memoryCache;
  final _keyCache = <String, String>{};
  var _epoch = 0;
  final _keyEpochs = <String, int>{};

  @override
  final Object cacheDomain = Object();
  @override
  Future<void> touch(String key) async {}
  @override
  Future<void> setMaxBytes(int bytes) async {
    if (bytes < 0) throw ArgumentError.value(bytes, 'bytes');
  }

  @override
  Future<ImageCacheFileLease?> acquireFile(
    String key, {
    Duration? maxAge,
  }) async => null;
  @override
  Future<ImageCacheWriteSession> beginFileWrite(String key) async =>
      _MemoryWriteSession(this, key, _epoch, _keyEpochs[key] ?? 0);
  @override
  Future<ImageCacheStats> getStats() async =>
      const ImageCacheStats(retainedBytes: 0, retainedFileCount: 0);

  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) {
    // Web doesn't support file paths, return null
    return null;
  }

  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) {
    return _memoryCache.get(key);
  }

  @override
  Future<void> saveFile(String key, Uint8List bytes) async {
    _memoryCache.put(key, bytes);
  }

  @override
  FutureOr<bool> hasValidCache(String key, {Duration? maxAge}) {
    return _memoryCache.contains(key);
  }

  @override
  Future<void> clearCache(String key) async {
    _keyEpochs[key] = (_keyEpochs[key] ?? 0) + 1;
    _memoryCache.remove(key);
  }

  @override
  Future<void> clearAllCache() async {
    _epoch++;
    _memoryCache.clear();
  }

  @override
  String generateCacheKey(String url, {String? customKey}) {
    return cache_utils.generateCacheKey(
      url,
      customKey: customKey,
      keyToMd5: _keyToMd5,
    );
  }

  String _keyToMd5(String key) {
    if (_keyCache.containsKey(key)) {
      return _keyCache[key]!;
    }
    final md5Key = cache_utils.keyToMd5(key);
    _keyCache[key] = md5Key;
    return md5Key;
  }

  @override
  void invalidateCacheDirectory() {
    // No-op for web
  }

  @override
  Future<void> dispose() async {
    _epoch++;
    _memoryCache.clear();
    _keyCache.clear();
  }
}

class _MemoryWriteSession implements ImageCacheWriteSession {
  _MemoryWriteSession(this.manager, this.key, this.epoch, this.keyEpoch);
  final DefaultImageCacheManager manager;
  final String key;
  final int epoch;
  final int keyEpoch;
  var finished = false;
  @override
  String get stagedPath =>
      throw UnsupportedError('Web image cache does not use files');
  @override
  Future<ImageCacheFileLease> commit() async =>
      throw UnsupportedError('Web image cache does not use file leases');
  @override
  Future<void> saveBytes(Uint8List bytes) async {
    if (finished) throw StateError('Image write already ended');
    finished = true;
    if (epoch == manager._epoch && keyEpoch == (manager._keyEpochs[key] ?? 0)) {
      manager._memoryCache.put(key, bytes);
    }
  }

  @override
  Future<void> abort() async {
    finished = true;
  }
}
