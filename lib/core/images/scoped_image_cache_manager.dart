import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cache_manager/cache_manager.dart';
import 'package:crypto/crypto.dart';

/// Adds an in-memory cache namespace and revocable access scope to a shared
/// image cache manager without owning or disposing the underlying cache.
base class ScopedImageCacheManager implements ImageCacheManager {
  factory ScopedImageCacheManager({
    required ImageCacheManager delegate,
    required String namespace,
    required bool Function() current,
    int maxKnownKeys = 1024,
  }) {
    _validate(namespace, maxKnownKeys);
    return switch (delegate) {
      final ManagedImageCacheManager managed => _ManagedScopedImageCacheManager(
        delegate: managed,
        namespace: namespace,
        current: current,
        maxKnownKeys: maxKnownKeys,
      ),
      _ => ScopedImageCacheManager._(
        delegate: delegate,
        namespace: namespace,
        current: current,
        maxKnownKeys: maxKnownKeys,
      ),
    };
  }

  ScopedImageCacheManager._({
    required this.delegate,
    required this.namespace,
    required bool Function() current,
    required this.maxKnownKeys,
  }) : _current = current;

  final ImageCacheManager delegate;
  final String namespace;
  final int maxKnownKeys;
  final _knownKeys = <String>{};
  final _cacheDomain = Object();
  bool Function()? _current;
  var _disposed = false;

  @override
  String generateCacheKey(String url, {String? customKey}) {
    final key = delegate.generateCacheKey(
      url,
      customKey: sha256
          .convert(utf8.encode(jsonEncode([namespace, customKey ?? url])))
          .toString(),
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
    _current = null;
    _knownKeys.clear();
  }

  bool get _isCurrent => !_disposed && (_current?.call() ?? false);

  bool _ownsCurrentKey(String key) => _knownKeys.contains(key) && _isCurrent;

  bool _admit(String key) {
    if (!_ownsCurrentKey(key)) return false;
    _touch(key);
    return true;
  }

  void _requireCurrentIssuedKey(String key) {
    if (!_knownKeys.contains(key)) {
      throw ArgumentError.value(
        key,
        'key',
        'Was not issued by this cache scope',
      );
    }
    if (!_isCurrent) throw StateError('Image cache scope is no longer active');
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

  static void _validate(String namespace, int maxKnownKeys) {
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
}

final class _ManagedScopedImageCacheManager extends ScopedImageCacheManager
    implements ManagedImageCacheManager {
  _ManagedScopedImageCacheManager({
    required ManagedImageCacheManager delegate,
    required super.namespace,
    required super.current,
    required super.maxKnownKeys,
  }) : _managedDelegate = delegate,
       super._(delegate: delegate);

  final ManagedImageCacheManager _managedDelegate;

  @override
  Object get cacheDomain => _cacheDomain;

  @override
  Future<void> touch(String key) async {
    if (!_admit(key)) return;
    await _managedDelegate.touch(key);
  }

  @override
  Future<ImageCacheFileLease?> acquireFile(
    String key, {
    Duration? maxAge,
  }) async {
    if (!_admit(key)) return null;
    final lease = await _managedDelegate.acquireFile(key, maxAge: maxAge);
    if (!_ownsCurrentKey(key)) {
      try {
        await lease?.release();
      } on Object {
        // A revoked read remains unavailable even if lease cleanup fails.
      }
      return null;
    }
    return lease;
  }

  @override
  Future<ImageCacheWriteSession> beginFileWrite(String key) async {
    _requireCurrentIssuedKey(key);
    _touch(key);
    final session = await _managedDelegate.beginFileWrite(key);
    if (!_ownsCurrentKey(key)) {
      await session.abort();
      throw StateError('Image cache scope was revoked during write admission');
    }
    return _ManagedScopedImageCacheWriteSession(
      owner: this,
      delegate: _managedDelegate,
      key: key,
      session: session,
    );
  }

  @override
  Future<void> setMaxBytes(int bytes) => _managedDelegate.setMaxBytes(bytes);

  @override
  Future<ImageCacheStats> getStats() => _managedDelegate.getStats();
}

final class _ManagedScopedImageCacheWriteSession
    implements ImageCacheWriteSession {
  _ManagedScopedImageCacheWriteSession({
    required this.owner,
    required this.delegate,
    required this.key,
    required this.session,
  });

  final _ManagedScopedImageCacheManager owner;
  final ManagedImageCacheManager delegate;
  final String key;
  final ImageCacheWriteSession session;
  var _finished = false;

  @override
  String get stagedPath => session.stagedPath;

  @override
  Future<void> saveBytes(Uint8List bytes) async {
    if (_finished) throw StateError('Image cache write session is finished');
    if (!owner._ownsCurrentKey(key)) {
      await abort();
      throw StateError('Image cache scope is no longer active');
    }
    await session.saveBytes(bytes);
    if (!owner._ownsCurrentKey(key)) {
      await abort();
      throw StateError('Image cache scope was revoked during byte staging');
    }
  }

  @override
  Future<ImageCacheFileLease> commit() async {
    if (_finished) throw StateError('Image cache write session is finished');
    if (!owner._ownsCurrentKey(key)) {
      await abort();
      throw StateError('Image cache scope is no longer active');
    }
    final lease = await session.commit();
    _finished = true;
    if (!owner._ownsCurrentKey(key)) {
      try {
        await lease.release();
      } finally {
        await delegate.clearCache(key);
      }
      throw StateError('Image cache scope was revoked during commit');
    }
    return lease;
  }

  @override
  Future<void> abort() async {
    if (_finished) return;
    _finished = true;
    await session.abort();
  }
}
