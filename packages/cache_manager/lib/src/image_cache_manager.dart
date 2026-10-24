import 'package:foundation/performance.dart';

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'cache_utils.dart' as cache_utils;
import 'image_cache_index.dart';
import 'image_cache_checkpoint.dart';
import 'managed_image_cache.dart';
import 'memory_cache.dart';

class DefaultImageCacheManager implements ManagedImageCacheManager {
  DefaultImageCacheManager({
    this.cacheDirName = 'cacheimage',
    this.enableLogging = false,
    this.cacheRootPathProvider,
    MemoryCache? memoryCache,
    ImageCacheCheckpointWriter checkpointWriter =
        writeImageCacheCheckpointInBackground,
    int maxBytes = 1024 * 1024 * 1024,
  }) : _checkpointWriter = checkpointWriter,
       _memoryCache = memoryCache,
       _maxBytes = maxBytes < 0 ? 1024 * 1024 * 1024 : maxBytes;

  final String cacheDirName;
  final bool enableLogging;
  final FutureOr<String> Function()? cacheRootPathProvider;
  final MemoryCache? _memoryCache;
  final ImageCacheCheckpointWriter _checkpointWriter;
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
  var _queuedOperations = 0;

  /// Operations enqueue synchronously. I/O holds only its file ownership, not
  /// this queue; a release must always be able to enter the same queue.
  Future<T> _run<T>(Future<T> Function() operation) {
    final queueSpan = performanceRecorder.begin(
      PerfOperation.cacheQueueWait,
      PerfSpanKind.asyncWall,
    );
    _queuedOperations++;
    performanceRecorder.count(PerfCounter.cacheQueueDepth, _queuedOperations);
    final result = _tail.then((_) async {
      _queuedOperations--;
      performanceRecorder.count(PerfCounter.cacheQueueDepth, _queuedOperations);
      queueSpan.finish();
      try {
        await _initialize();
        _recordDiagnosticsState();
        return await operation();
      } finally {
        _recordDiagnosticsState();
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _recordDiagnosticsState() {
    if (!performanceRecorder.enabled || _directory == null) return;
    // Maintained scalars and map lengths only; never getStats() or a disk scan.
    performanceRecorder.count(PerfCounter.cacheEntries, _current.length);
    performanceRecorder.count(
      PerfCounter.cacheGenerations,
      _generations.length,
    );
    performanceRecorder.count(
      PerfCounter.cacheRetiredGenerations,
      _retired.length,
    );
    performanceRecorder.count(PerfCounter.cacheRetainedBytes, _occupied);
    performanceRecorder.count(PerfCounter.cacheLimitBytes, _maxBytes);
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
    final performanceSpan = performanceRecorder.begin(
      PerfOperation.cacheInitialize,
      PerfSpanKind.asyncWall,
    );
    var performanceFailed = false;
    try {
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
      _index = ImageCacheIndex(
        Directory(p.join(root, '$cacheDirName-index')),
        checkpointWriter: _checkpointWriter,
      );
      final indexed = await _index.load();
      final files = await directory
          .list(followLinks: false)
          .where((e) => e is File)
          .cast<File>()
          .toList();
      if (indexed) {
        for (final entry in _index.entries.values.toList()) {
          var file = File(p.join(directory.path, entry.filename));
          if (await file.exists() && await file.length() == entry.size) {
            var normalizedEntry = entry;
            if (entry.filename != entry.key) {
              final target = File(p.join(directory.path, entry.key));
              if (await target.exists()) await target.delete();
              file = await file.rename(target.path);
              normalizedEntry = ImageCacheEntry(
                key: entry.key,
                filename: entry.key,
                size: entry.size,
                use: entry.use,
              );
              _index.entries[entry.key] = normalizedEntry;
            }
            final cacheFile = _Generation(normalizedEntry, file.path);
            _current[entry.key] = cacheFile;
            _generations[entry.key] = cacheFile;
            _occupied += normalizedEntry.size;
            _use = max(_use, normalizedEntry.use);
          } else {
            _index.entries.remove(entry.key);
          }
        }
        for (final file in files) {
          if (await file.exists() &&
              !_generations.containsKey(p.basename(file.path))) {
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
        for (final value in _current.entries.toList()) {
          final generation = value.value;
          if (generation.entry.filename == value.key) continue;
          final target = File(p.join(directory.path, value.key));
          if (await target.exists()) await target.delete();
          final file = await File(generation.path).rename(target.path);
          final entry = ImageCacheEntry(
            key: value.key,
            filename: value.key,
            size: generation.entry.size,
            use: generation.entry.use,
          );
          final normalized = _Generation(entry, file.path);
          _current[value.key] = normalized;
          _generations
            ..remove(generation.entry.filename)
            ..[value.key] = normalized;
          _index.entries[value.key] = entry;
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
    } catch (_) {
      performanceFailed = true;
      rethrow;
    } finally {
      performanceSpan.finish(failed: performanceFailed);
    }
  }

  Future<Directory> getCacheDirectory() => _run(() async => _directory!);

  Future<void> _persist(Future<void> Function() operation) async {
    try {
      if (_metadataDirty) {
        await _index.checkpoint();
        _metadataDirty = false;
      }
      await operation();
    } catch (error) {
      if (error is! FileSystemException &&
          error is! ImageCacheCheckpointWorkerException) {
        rethrow;
      }
      performanceRecorder.count(PerfCounter.cachePersistenceFailure, 1);
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
    if (generation == null) {
      performanceRecorder.count(PerfCounter.cacheLookupMiss, 1);
      return null;
    }
    final file = File(generation.path);
    try {
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file ||
          stat.size != generation.entry.size ||
          (maxAge != null &&
              DateTime.now().subtract(maxAge).isAfter(stat.modified))) {
        await _retire(generation);
        performanceRecorder.count(PerfCounter.cacheLookupMiss, 1);
        return null;
      }
      performanceRecorder.count(PerfCounter.cacheLookupHit, 1);
      return generation;
    } on FileSystemException {
      await _retire(generation);
      performanceRecorder.count(PerfCounter.cacheLookupMiss, 1);
      return null;
    }
  }

  @override
  Future<String?> getCachedFilePath(String key, {Duration? maxAge}) =>
      _run(() async => (await _valid(key, maxAge))?.path);

  @override
  Future<ImageCacheFileLease?> acquireFile(String key, {Duration? maxAge}) =>
      performanceRecorder.measureAsync(
        PerfOperation.cacheAcquireFile,
        () => _run(() async {
          final generation = await _valid(key, maxAge);
          if (generation == null) return null;
          return _pinForRead(generation);
        }),
      );

  // Called only while holding the serialized metadata boundary.
  Future<ImageCacheFileLease> _pinForRead(_Generation generation) async {
    generation.pins++;
    try {
      await _recordUse(generation);
    } on Object {
      generation.pins--;
      rethrow;
    }
    return _lease(generation);
  }

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
    final performanceSpan = performanceRecorder.begin(
      PerfOperation.cacheRead,
      PerfSpanKind.asyncWall,
    );
    var performanceFailed = false;
    try {
      // RAM bytes still require a current entry: clear/trim must invalidate them.
      // Validate and pin in one queue slot. Disk I/O remains outside the queue;
      // clear/eviction may retire the generation but cannot delete this lease.
      final cached =
          await _run<({Uint8List? bytes, ImageCacheFileLease? lease})>(
            () async {
              final generation = await _valid(key, maxAge);
              if (generation == null) return (bytes: null, lease: null);
              final bytes = _memoryCache?.get(key);
              if (bytes != null) {
                await _recordUse(generation);
                return (bytes: bytes, lease: null);
              }
              return (bytes: null, lease: await _pinForRead(generation));
            },
          );
      if (cached.bytes case final bytes?) return bytes;
      final lease = cached.lease;
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
    } catch (_) {
      performanceFailed = true;
      rethrow;
    } finally {
      performanceSpan.finish(failed: performanceFailed);
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
    if (await _valid(session.key, null) case final existing?) {
      // The key identifies the source URL. A concurrent completed download for
      // the same still-valid key is a duplicate, so keep its canonical file.
      await staged.delete();
      session.finished = true;
      existing.pins++;
      await _recordUse(existing);
      return _lease(existing);
    }
    // A cleared or stale file can remain readable while an earlier lease owns
    // it. Do not overwrite that canonical path; this download stays transient.
    if (_generations.containsKey(session.key)) return _transient(session);
    final needed = _occupied + size - _maxBytes;
    final selection = needed > 0
        ? _selectVictims(needed)
        : (chosen: <_Generation>[], remaining: needed);
    if (selection.remaining > 0) return _transient(session);
    // Publish under the URL-MD5 key before retiring capacity victims. A failed
    // rename therefore leaves the existing cache and its index untouched.
    final filename = session.key;
    final file = await staged.rename(p.join(_directory!.path, filename));
    try {
      for (final victim in selection.chosen) {
        await _retire(victim);
      }
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
    final performanceSpan = performanceRecorder.begin(
      PerfOperation.cacheEvictionScan,
      PerfSpanKind.sync,
      items: _generations.length,
    );
    var performanceFailed = false;
    final recording = performanceRecorder.enabled;
    var examined = 0;
    try {
      final chosen = <_Generation>[];
      // Preserve replacement priority without moving any other key's recency.
      final preferReplacement = replacing != null && replacing.pins == 0;
      if (preferReplacement) {
        chosen.add(replacing);
        needed -= replacing.entry.size;
      }
      if (needed > 0) {
        for (final generation in _generations.values) {
          if (recording) examined++;
          if (preferReplacement && identical(generation, replacing)) continue;
          if (generation.pins != 0) continue;
          chosen.add(generation);
          needed -= generation.entry.size;
          if (needed <= 0) break;
        }
      }
      if (recording) {
        performanceRecorder.count(PerfCounter.cacheEvictionExamined, examined);
        performanceRecorder.count(
          PerfCounter.cacheEvictionVictims,
          chosen.length,
        );
      }
      // Selection completes before asynchronous retirement mutates the map.
      return (chosen: chosen, remaining: needed);
    } catch (_) {
      performanceFailed = true;
      rethrow;
    } finally {
      performanceSpan.finish(failed: performanceFailed);
    }
  }

  Future<void> _trim() async {
    final performanceSpan = performanceRecorder.begin(
      PerfOperation.cacheTrim,
      PerfSpanKind.asyncWall,
      items: _generations.length,
    );
    var performanceFailed = false;
    try {
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
    } catch (_) {
      performanceFailed = true;
      rethrow;
    } finally {
      performanceSpan.finish(failed: performanceFailed);
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
