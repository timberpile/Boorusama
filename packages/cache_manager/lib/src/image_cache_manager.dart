import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'cache_utils.dart' as cache_utils;
import 'image_cache_index.dart';
import 'managed_image_cache.dart';
import 'memory_cache.dart';

class DefaultImageCacheManager implements ManagedImageCacheManager {
  DefaultImageCacheManager({
    this.cacheDirName = 'cacheimage',
    this.enableLogging = false,
    this.cacheRootPathProvider,
    MemoryCache? memoryCache,
    int maxBytes = 1024 * 1024 * 1024,
  }) : _memoryCache = memoryCache,
       _maxBytes = maxBytes < 0 ? 1024 * 1024 * 1024 : maxBytes;

  final String cacheDirName;
  final bool enableLogging;
  final FutureOr<String> Function()? cacheRootPathProvider;
  final MemoryCache? _memoryCache;
  @override
  final Object cacheDomain = Object();
  final _keyCache = <String, String>{};
  final _current = <String, _Generation>{};
  // Insertion order is least-to-most recently used. Probes and lease releases
  // do not refresh recency; real reads/touches move their generation to the end.
  final _generations = <String, _Generation>{};
  final _retired = <_Generation>{};
  var _occupied = 0;
  final _keyEpochs = <String, int>{};
  final _random = Random.secure();
  Future<void> _tail = Future.value();
  Directory? _directory;
  late Directory _transfers;
  late ImageCacheIndex _index;
  var _maxBytes = 1024 * 1024 * 1024;
  var _epoch = 0;
  var _use = 0;
  var _metadataDirty = false;

  /// Operations enqueue synchronously. I/O holds only its file ownership, not
  /// this queue; a release must always be able to enter the same queue.
  Future<T> _run<T>(Future<T> Function() operation) {
    final result = _tail.then((_) async {
      await _initialize();
      return operation();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _checkKey(String key) {
    if (key.isEmpty ||
        key == '.' ||
        key == '..' ||
        key.contains('/') ||
        key.contains('\\')) {
      throw ArgumentError.value(key, 'key');
    }
  }

  String _nonce() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';

  Future<void> _initialize() async {
    if (_directory != null) {
      await _directory!.create(recursive: true);
      return;
    }
    // A failed first reconciliation may have loaded only part of the index.
    // No caller can own a generation until initialization has succeeded.
    _current.clear();
    _generations.clear();
    _retired.clear();
    _occupied = 0;
    final root = cacheRootPathProvider != null
        ? await cacheRootPathProvider!()
        : (await getTemporaryDirectory()).path;
    final directory = Directory(p.join(root, cacheDirName));
    await directory.create(recursive: true);
    _transfers = Directory(p.join(root, '$cacheDirName-transfers'));
    _index = ImageCacheIndex(Directory(p.join(root, '$cacheDirName-index')));
    final indexed = await _index.load();
    final files = await directory
        .list(followLinks: false)
        .where((e) => e is File)
        .cast<File>()
        .toList();
    if (indexed) {
      for (final entry in _index.entries.values.toList()) {
        final file = File(p.join(directory.path, entry.filename));
        if (await file.exists() && await file.length() == entry.size) {
          final generation = _Generation(entry, file.path);
          _current[entry.key] = generation;
          _generations[entry.filename] = generation;
          _occupied += entry.size;
          _use = max(_use, entry.use);
        } else {
          _index.entries.remove(entry.key);
        }
      }
      for (final file in files) {
        if (!_generations.containsKey(p.basename(file.path))) {
          await file.delete();
        }
      }
    } else {
      // Adopt only the preexisting normal cache, never durable bookmark media.
      final dated = <({File file, DateTime modified})>[];
      for (final file in files) {
        if (file.path.endsWith('.partial')) {
          await file.delete();
        } else {
          dated.add((file: file, modified: await file.lastModified()));
        }
      }
      dated.sort((a, b) {
        final date = a.modified.compareTo(b.modified);
        return date == 0 ? a.file.path.compareTo(b.file.path) : date;
      });
      for (final value in dated) {
        final size = await value.file.length();
        if (size == 0) {
          await value.file.delete();
          continue;
        }
        final filename = p.basename(value.file.path);
        final marker = filename.lastIndexOf('.generation_');
        final key = marker > 0 ? filename.substring(0, marker) : filename;
        final previous = _current[key];
        if (previous != null) {
          await File(previous.path).delete();
          _generations.remove(previous.entry.filename);
          _occupied -= previous.entry.size;
        }
        final entry = ImageCacheEntry(
          key: key,
          filename: filename,
          size: size,
          use: ++_use,
        );
        final generation = _Generation(entry, value.file.path);
        _current[key] = generation;
        _generations[filename] = generation;
        _occupied += size;
        _index.entries[key] = entry;
      }
    }
    // Journal key order is not recency order. Rebuild once after loading,
    // then maintain order incrementally without sorting during admission.
    final ordered = _generations.values.toList()
      ..sort((a, b) => a.entry.use.compareTo(b.entry.use));
    _generations
      ..clear()
      ..addEntries(ordered.map((g) => MapEntry(g.entry.filename, g)));
    // This manager is the sole owner of these scratch files; after process
    // restart there cannot be a live operation owning an old partial/transient.
    try {
      if (await _transfers.exists()) {
        await for (final entity in _transfers.list(followLinks: false)) {
          if (entity is File) await entity.delete();
        }
      }
    } on FileSystemException {
      // Write-only scratch availability cannot prevent reading payloads.
    }
    await _persist(_index.checkpoint);
    _directory = directory;
    await _trim();
  }

  Future<Directory> getCacheDirectory() => _run(() async => _directory!);

  Future<void> _persist(Future<void> Function() operation) async {
    try {
      if (_metadataDirty) {
        await _index.checkpoint();
        _metadataDirty = false;
      }
      await operation();
    } on FileSystemException {
      _metadataDirty = true;
      if (enableLogging) {
        print('[ImageCache] Usage persistence is temporarily unavailable.');
      }
    }
  }

  Future<void> _recordUse(_Generation generation) async {
    generation.entry.use = ++_use;
    _generations.remove(generation.entry.filename);
    _generations[generation.entry.filename] = generation;
    if (!generation.retired) await _persist(() => _index.put(generation.entry));
  }

  @override
  Future<void> touch(String key) => _run(() async {
    final generation = _current[key];
    if (generation != null) await _recordUse(generation);
  });

  Future<_Generation?> _valid(String key, Duration? maxAge) async {
    _checkKey(key);
    final generation = _current[key];
    if (generation == null) return null;
    final file = File(generation.path);
    try {
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file ||
          stat.size != generation.entry.size ||
          (maxAge != null &&
              DateTime.now().subtract(maxAge).isAfter(stat.modified))) {
        await _retire(generation);
        return null;
      }
      return generation;
    } on FileSystemException {
      await _retire(generation);
      return null;
    }
  }

  @override
  Future<String?> getCachedFilePath(String key, {Duration? maxAge}) =>
      _run(() async => (await _valid(key, maxAge))?.path);

  @override
  Future<ImageCacheFileLease?> acquireFile(String key, {Duration? maxAge}) =>
      _run(() async {
        final generation = await _valid(key, maxAge);
        if (generation == null) return null;
        generation.pins++;
        try {
          await _recordUse(generation);
        } on Object {
          generation.pins--;
          rethrow;
        }
        return _lease(generation);
      });

  ImageCacheFileLease _lease(_Generation generation) => _FileLease(
    generation.path,
    true,
    () => _run(() async {
      generation.pins--;
      if (generation.retired && generation.pins == 0) await _delete(generation);
      await _trim();
    }),
  );

  @override
  Future<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) async {
    // RAM bytes still require a current entry: clear/trim must invalidate them.
    final cached = await _run(() async {
      final generation = await _valid(key, maxAge);
      if (generation == null) return null;
      final bytes = _memoryCache?.get(key);
      if (bytes != null) await _recordUse(generation);
      return bytes;
    });
    if (cached != null) return cached;
    final lease = await acquireFile(key, maxAge: maxAge);
    if (lease == null) return null;
    try {
      final bytes = await File(lease.path).readAsBytes();
      await _run(() async {
        if (_current[key]?.path == lease.path) _memoryCache?.put(key, bytes);
      });
      return bytes;
    } on FileSystemException {
      return null;
    } finally {
      await lease.release();
    }
  }

  @override
  Future<void> saveFile(String key, Uint8List bytes) async {
    ImageCacheWriteSession? session;
    try {
      session = await beginFileWrite(key);
      await session.saveBytes(bytes);
    } on Object {
      await session?.abort();
      if (enableLogging) print('[ImageCache] Payload was not retained.');
    }
  }

  @override
  Future<bool> hasValidCache(String key, {Duration? maxAge}) =>
      _run(() async => await _valid(key, maxAge) != null);

  @override
  Future<ImageCacheWriteSession> beginFileWrite(String key) => _run(() async {
    _checkKey(key);
    await _transfers.create(recursive: true);
    return _WriteSession(
      this,
      key,
      p.join(_transfers.path, 'write_${_nonce()}.partial'),
      _epoch,
      _keyEpochs[key] ?? 0,
    );
  });

  Future<ImageCacheFileLease> _commit(_WriteSession session) => _run(() async {
    if (session.finished) throw StateError('Image write already ended');
    final staged = File(session.stagedPath);
    final size = await staged.length();
    if (size == 0) throw StateError('Empty image write');
    if (session.epoch != _epoch ||
        session.keyEpoch != (_keyEpochs[session.key] ?? 0) ||
        _maxBytes == 0 ||
        size > _maxBytes) {
      return _transient(session);
    }
    final needed = _occupied + size - _maxBytes;
    final selection = needed > 0
        ? _selectVictims(needed, replacing: _current[session.key])
        : (chosen: <_Generation>[], remaining: needed);
    if (selection.remaining > 0) return _transient(session);
    // Prepare the immutable completed file before any destructive retirement.
    // A failed final rename must leave every previous generation/index intact.
    final filename = '${session.key}.generation_${_nonce()}';
    final file = await staged.rename(p.join(_directory!.path, filename));
    try {
      for (final victim in selection.chosen) {
        await _retire(victim);
      }
      // Existing readers own the old immutable generation, even for the same key.
      if (_current[session.key] case final old?) await _retire(old);
      final entry = ImageCacheEntry(
        key: session.key,
        filename: filename,
        size: size,
        use: ++_use,
      );
      final generation = _Generation(entry, file.path)..pins = 1;
      _current[session.key] = generation;
      _generations[filename] = generation;
      _occupied += size;
      session.finished = true;
      await _persist(() => _index.put(entry));
      return _lease(generation);
    } on Object {
      if (!session.finished && await file.exists()) await file.delete();
      rethrow;
    }
  });

  Future<ImageCacheFileLease> _transient(_WriteSession session) async {
    final path = p.join(_transfers.path, 'transfer_${_nonce()}');
    await File(session.stagedPath).rename(path);
    session.finished = true;
    return _FileLease(path, false, () async {
      final file = File(path);
      if (await file.exists()) await file.delete();
    });
  }

  Future<void> _retire(_Generation generation) async {
    if (!generation.retired) {
      generation.retired = true;
      _retired.add(generation);
      if (identical(_current[generation.entry.key], generation)) {
        _current.remove(generation.entry.key);
        _memoryCache?.remove(generation.entry.key);
        await _persist(() => _index.remove(generation.entry.key));
      }
    }
    if (generation.pins == 0) await _delete(generation);
  }

  Future<void> _delete(_Generation generation) async {
    final file = File(generation.path);
    if (await file.exists()) await file.delete();
    // Missing files count as deleted. Failed I/O above leaves ownership and
    // occupied bytes intact so a later trim can retry the retired generation.
    if (_generations.remove(generation.entry.filename) != null) {
      _occupied -= generation.entry.size;
    }
    _retired.remove(generation);
  }

  ({List<_Generation> chosen, int remaining}) _selectVictims(
    int needed, {
    _Generation? replacing,
  }) {
    final chosen = <_Generation>[];
    // Preserve replacement priority without moving any other key's recency.
    final preferReplacement = replacing != null && replacing.pins == 0;
    if (preferReplacement) {
      chosen.add(replacing);
      needed -= replacing.entry.size;
    }
    if (needed > 0) {
      for (final generation in _generations.values) {
        if (preferReplacement && identical(generation, replacing)) continue;
        if (generation.pins != 0) continue;
        chosen.add(generation);
        needed -= generation.entry.size;
        if (needed <= 0) break;
      }
    }
    // Selection completes before asynchronous retirement mutates the map.
    return (chosen: chosen, remaining: needed);
  }

  Future<void> _trim() async {
    // Retired readers still own their immutable bytes. Retry only retired
    // generations here; ordinary lease releases must not scan the live cache.
    for (final generation in _retired.toList()) {
      if (generation.pins == 0) await _delete(generation);
    }
    if (_maxBytes == 0) {
      for (final generation in _current.values.toList()) {
        await _retire(generation);
      }
      return;
    }
    if (_occupied <= _maxBytes) return;
    final victims = _selectVictims(_occupied - _maxBytes).chosen;
    for (final victim in victims) {
      if (_occupied <= _maxBytes) break;
      await _retire(victim);
    }
  }

  @override
  Future<void> setMaxBytes(int bytes) {
    if (bytes < 0) throw ArgumentError.value(bytes, 'bytes');
    return _run(() async {
      _maxBytes = bytes;
      await _trim();
    });
  }

  @override
  Future<ImageCacheStats> getStats() => _run(() async {
    for (final key in _current.keys.toList()) {
      await _valid(key, null);
    }
    return ImageCacheStats(
      retainedBytes: _occupied,
      retainedFileCount: _generations.length,
    );
  });

  @override
  Future<void> clearCache(String key) => _run(() async {
    _keyEpochs[key] = (_keyEpochs[key] ?? 0) + 1;
    if (_current[key] case final generation?) await _retire(generation);
  });

  @override
  Future<void> clearAllCache() => _run(() async {
    _epoch++;
    _memoryCache?.clear();
    for (final generation in _current.values.toList()) {
      await _retire(generation);
    }
  });

  @override
  String generateCacheKey(String url, {String? customKey}) =>
      cache_utils.generateCacheKey(
        url,
        customKey: customKey,
        keyToMd5: (key) =>
            _keyCache.putIfAbsent(key, () => cache_utils.keyToMd5(key)),
      );

  @override
  void invalidateCacheDirectory() {
    // Operations reconcile missing files; dropping live ownership is unsafe.
  }

  @override
  Future<void> dispose() => _run(() async {
    await _persist(_index.checkpoint);
    _memoryCache?.clear();
    _keyCache.clear();
  });
}

class _Generation {
  _Generation(this.entry, this.path);
  final ImageCacheEntry entry;
  final String path;
  var pins = 0;
  var retired = false;
}

class _FileLease implements ImageCacheFileLease {
  _FileLease(this.path, this.isRetained, this._release);
  @override
  final String path;
  @override
  final bool isRetained;
  final Future<void> Function() _release;
  Future<void>? _released;
  @override
  Future<void> release() => _released ??= _release();
}

class _WriteSession implements ImageCacheWriteSession {
  _WriteSession(
    this.manager,
    this.key,
    this.stagedPath,
    this.epoch,
    this.keyEpoch,
  );
  final DefaultImageCacheManager manager;
  final String key;
  @override
  final String stagedPath;
  final int epoch;
  final int keyEpoch;
  var finished = false;
  @override
  Future<void> saveBytes(Uint8List bytes) async {
    if (finished) throw StateError('Image write already ended');
    try {
      await File(stagedPath).writeAsBytes(bytes, flush: true);
      final lease = await commit();
      await lease.release();
    } finally {
      await abort();
    }
  }

  @override
  Future<ImageCacheFileLease> commit() => manager._commit(this);
  @override
  Future<void> abort() => manager._run(() async {
    if (finished) return;
    finished = true;
    final staged = File(stagedPath);
    if (await staged.exists()) await staged.delete();
  });
}
