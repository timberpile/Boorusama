import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cache_manager/cache_manager.dart';

/// Adds an in-memory cache namespace and revocable access scope to a shared
/// image cache manager without owning or disposing the underlying cache.
final class ScopedImageCacheManager implements ImageCacheManager {
  ScopedImageCacheManager({
    required this.delegate,
    required this.namespace,
    required this.current,
    this.maxKnownKeys = 1024,
  }) {
    if (namespace.trim().isEmpty) {
      throw ArgumentError.value(namespace, 'namespace', 'Must not be empty');
    }
    if (maxKnownKeys <= 0) {
      throw ArgumentError.value(
        maxKnownKeys,
        'maxKnownKeys',
        'Must be greater than zero',
      );
    }
  }

  final ImageCacheManager delegate;
  final String namespace;
  final bool Function() current;
  final int maxKnownKeys;

  final _knownKeys = <String>{};
  var _disposed = false;

  @override
  String generateCacheKey(String url, {String? customKey}) {
    final key = delegate.generateCacheKey(
      url,
      customKey: jsonEncode([namespace, customKey ?? url]),
    );
    if (_isCurrent) _remember(key);
    return key;
  }

  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) async {
    if (!_admit(key)) return null;
    final result = await delegate.getCachedFilePath(key, maxAge: maxAge);
    return _isCurrent ? result : null;
  }

  @override
  FutureOr<Uint8List?> getCachedFileBytes(
    String key, {
    Duration? maxAge,
  }) async {
    if (!_admit(key)) return null;
    final result = await delegate.getCachedFileBytes(key, maxAge: maxAge);
    return _isCurrent ? result : null;
  }

  @override
  Future<void> saveFile(String key, Uint8List bytes) async {
    if (_disposed) return;
    if (!_knownKeys.contains(key)) {
      throw ArgumentError.value(
        key,
        'key',
        'Was not issued by this cache scope',
      );
    }
    _touch(key);
    if (!_isCurrent) return;

    await delegate.saveFile(key, bytes);
    if (!_isCurrent) {
      // The scope may be revoked while an underlying write is in flight. The
      // issued key is namespaced, so remove that late write before returning.
      await delegate.clearCache(key);
    }
  }

  @override
  FutureOr<bool> hasValidCache(String key, {Duration? maxAge}) async {
    if (!_admit(key)) return false;
    final result = await delegate.hasValidCache(key, maxAge: maxAge);
    return _isCurrent && result;
  }

  @override
  Future<void> clearCache(String key) async {
    if (_disposed || !_knownKeys.contains(key)) return;
    _touch(key);
    await delegate.clearCache(key);
  }

  @override
  Future<void> clearAllCache() async {
    if (_disposed) return;
    for (final key in _knownKeys.toList()) {
      await delegate.clearCache(key);
    }
  }

  @override
  void invalidateCacheDirectory() {
    if (_disposed) return;
    delegate.invalidateCacheDirectory();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _knownKeys.clear();
  }

  bool get _isCurrent => !_disposed && current();

  bool _admit(String key) {
    if (!_isCurrent || !_knownKeys.contains(key)) return false;
    _touch(key);
    return true;
  }

  void _remember(String key) {
    _knownKeys
      ..remove(key)
      ..add(key);
    while (_knownKeys.length > maxKnownKeys) {
      _knownKeys.remove(_knownKeys.first);
    }
  }

  void _touch(String key) {
    _knownKeys
      ..remove(key)
      ..add(key);
  }
}
