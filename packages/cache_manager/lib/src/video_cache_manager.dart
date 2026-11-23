import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'cache_manager.dart';

class VideoCacheManager implements ImageCacheManager {
  VideoCacheManager({
    required this.fileDownloader,
    required this.dio,
    this.cacheDirName = defaultSubPath,
    this.maxTotalCacheSize = 1 * 1024 * 1024 * 1024, // 1GB
    this.maxItemSize = 100 * 1024 * 1024, // 100MB
    this.evictionThreshold = 0.8,
    this.enableLogging = false,
    this.cacheRootPathProvider,
  });

  final String cacheDirName;
  final int maxTotalCacheSize;
  final int maxItemSize;
  final double evictionThreshold;
  final bool enableLogging;
  final FutureOr<String> Function()? cacheRootPathProvider;
  final FileDownloader fileDownloader;
  final Dio dio;

  Directory? _cacheDir;
  Future<Directory>? _cacheDirFuture;
  final _activeLeases = <String, int>{};
  final _pendingDeletes = <String>{};
  final _guardedTokens = <CancelToken>{};
  Future<void> _guardedQueue = Future.value();
  bool _disposed = false;
  int _stageSerial = 0;
  int _guardedWaiters = 0;
  int _clearsInProgress = 0;
  final _guardedTransfers = <CancelToken, (String, Future<void>)>{};

  static const String defaultSubPath = 'cachevideo';
  static const String videoCacheGroup = 'video_cache';

  FutureOr<Directory> getCacheDirectory() {
    if (_cacheDir != null) {
      return _cacheDir!;
    }

    if (_cacheDirFuture != null) {
      return _cacheDirFuture!;
    }
    _cacheDirFuture = _initializeCacheDirectory();

    return _cacheDirFuture!
        .then((dir) {
          _cacheDir = dir;
          return dir;
        })
        .catchError((e) {
          _cacheDirFuture = null;
          throw e;
        });
  }

  Future<Directory> _initializeCacheDirectory() async {
    final rootPath = cacheRootPathProvider != null
        ? await cacheRootPathProvider!()
        : (await getTemporaryDirectory()).path;
    final dirPath = join(rootPath, cacheDirName);
    final dir = Directory(dirPath);

    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  @override
  String generateCacheKey(String url, {String? customKey}) {
    if (customKey != null) {
      return customKey;
    }

    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  FutureOr<bool> hasValidCache(String key, {Duration? maxAge}) {
    final fileResult = _getCachedFile(key, maxAge: maxAge);

    if (fileResult is Future<File?>) {
      return fileResult.then((file) => file != null);
    }

    return fileResult != null;
  }

  Future<bool> isVideoCached(String url, {Duration? maxAge}) async {
    final cacheKey = generateCacheKey(url);
    return await hasValidCache(cacheKey, maxAge: maxAge);
  }

  FutureOr<File?> _getCachedFile(String key, {Duration? maxAge}) {
    final dirResult = getCacheDirectory();

    if (dirResult is Future<Directory>) {
      return dirResult.then((cacheDir) => _getValidFile(cacheDir, key, maxAge));
    }

    final cacheDir = dirResult;
    return _getValidFile(cacheDir, key, maxAge);
  }

  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) async {
    final fileResult = await _getCachedFile(key, maxAge: maxAge);

    return fileResult?.path;
  }

  File? _getValidFile(Directory cacheDir, String key, Duration? maxAge) {
    try {
      if (_pendingDeletes.contains(key)) return null;
      final cacheFile = File(join(cacheDir.path, key));
      final stats = cacheFile.statSync();

      if (stats.type == FileSystemEntityType.notFound) {
        return null;
      }

      if (maxAge != null) {
        final now = DateTime.now();
        final isExpired = now.subtract(maxAge).isAfter(stats.modified);
        if (isExpired) {
          _log('Cache expired for video file: ${cacheFile.path}');
          if ((_activeLeases[key] ?? 0) > 0) {
            _pendingDeletes.add(key);
          } else {
            try {
              cacheFile.deleteSync();
            } catch (e) {
              _log('Error deleting expired video cache file: $e');
            }
          }
          return null;
        }
      }

      return cacheFile;
    } catch (e) {
      _log('Error getting cached video file: $e');
      return null;
    }
  }

  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) {
    final fileResult = _getCachedFile(key, maxAge: maxAge);

    if (fileResult is Future<File?>) {
      return fileResult.then((file) => _readFileBytes(file, key));
    }

    final file = fileResult;
    return _readFileBytes(file, key);
  }

  Future<String?> getCachedVideoPath(String url, {Duration? maxAge}) async {
    final cacheKey = generateCacheKey(url);
    final file = await _getCachedFile(cacheKey, maxAge: maxAge);

    if (file != null && file.existsSync()) {
      await _touchFile(file);
      return file.path;
    }

    return null;
  }

  Future<VideoCacheLease?> acquireVideo(
    String url, {
    Duration? maxAge,
  }) async {
    final key = generateCacheKey(url);
    final file = await _getCachedFile(key, maxAge: maxAge);
    if (file == null || !file.existsSync()) return null;
    _activeLeases[key] = (_activeLeases[key] ?? 0) + 1;
    await _touchFile(file);
    return VideoCacheLease._(file.path, () => _releaseVideo(key, file));
  }

  /// Prepares a source-scoped local file using only the supplied transport.
  Future<VideoCacheLease> acquireGuardedVideo(
    String url, {
    required String namespace,
    required Dio transport,
    required bool Function() isCurrent,
    required CancelToken cancelToken,
    Map<String, String>? headers,
    bool retain = true,
  }) async {
    if (_disposed || _clearsInProgress > 0 || _guardedWaiters >= 64) {
      throw const VideoCacheException('Guarded video queue unavailable');
    }
    _guardedWaiters++;
    final previous = _guardedQueue;
    final finished = Completer<void>();
    _guardedQueue = finished.future;
    final ownedToken = CancelToken();
    final key = generateCacheKey('$namespace\n$url');
    _guardedTokens.add(ownedToken);
    _guardedTransfers[ownedToken] = (key, finished.future);
    cancelToken.whenCancel.then((error) {
      if (!ownedToken.isCancelled) ownedToken.cancel(error);
    });
    void check() {
      if (_disposed ||
          cancelToken.isCancelled ||
          ownedToken.isCancelled ||
          !isCurrent()) {
        throw const VideoCacheException(
          'Guarded video access cancelled or stale',
        );
      }
    }

    File? stage;
    IOSink? sink;
    try {
      await previous;
      check();
      final dir = await getCacheDirectory();
      check();
      final limit = maxItemSize < 0 || maxItemSize > 100 * 1024 * 1024
          ? 100 * 1024 * 1024
          : maxItemSize;
      final cached = _getValidFile(dir, key, null);
      if (cached != null) {
        final size = cached.lengthSync();
        if (size > limit ||
            (maxTotalCacheSize >= 0 && size > maxTotalCacheSize)) {
          throw const VideoCacheException('Video exceeds cache size limit');
        }
        _activeLeases[key] = (_activeLeases[key] ?? 0) + 1;
        if (!retain) _pendingDeletes.add(key);
        final lease = VideoCacheLease._(
          cached.path,
          () => _releaseVideo(key, cached),
        );
        await _touchFile(cached);
        try {
          check();
          return lease;
        } catch (_) {
          await lease.release();
          rethrow;
        }
      }
      if (_pendingDeletes.contains(key) || (_activeLeases[key] ?? 0) > 0) {
        throw const VideoCacheException(
          'Video cache entry is pending deletion',
        );
      }
      final response = await transport.get<ResponseBody>(
        url,
        cancelToken: ownedToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          extra: const {'boorusama.request.media': true},
        ),
      );
      check();
      final length = int.tryParse(
        response.headers.value('content-length') ?? '',
      );
      if (length != null &&
          (length > limit ||
              (maxTotalCacheSize >= 0 && length > maxTotalCacheSize))) {
        throw const VideoCacheException('Video exceeds cache size limit');
      }
      final body = response.data;
      if (body == null)
        throw const VideoCacheException('Missing video response body');
      stage = File(
        join(dir.path, '$key.${identityHashCode(this)}.${_stageSerial++}.part'),
      );
      sink = stage.openWrite();
      var size = 0;
      final iterator = StreamIterator(body.stream);
      final cancelled = ownedToken.whenCancel.then<bool>(
        (_) => throw const VideoCacheException('Guarded video cancelled'),
      );
      try {
        while (await Future.any([
          iterator.moveNext(),
          cancelled,
        ])) {
          check();
          final chunk = iterator.current;
          size += chunk.length;
          if (size > limit ||
              (maxTotalCacheSize >= 0 && size > maxTotalCacheSize)) {
            throw const VideoCacheException('Video exceeds cache size limit');
          }
          sink.add(chunk);
        }
      } finally {
        await iterator.cancel();
      }
      await sink.flush();
      check();
      await sink.close();
      sink = null;
      check();
      if (maxTotalCacheSize >= 0) {
        await _ensureSpaceAvailable(size);
        check();
        final used = dir
            .listSync()
            .whereType<File>()
            .where((file) => !file.path.endsWith('.part'))
            .fold<int>(0, (total, file) => total + file.lengthSync());
        if (used + size > maxTotalCacheSize) {
          throw const VideoCacheException('Video cache quota is occupied');
        }
      }
      check();
      final destination = File(join(dir.path, key));
      if (destination.existsSync() ||
          _pendingDeletes.contains(key) ||
          (_activeLeases[key] ?? 0) > 0) {
        throw const VideoCacheException(
          'Video cache entry changed during preparation',
        );
      }
      stage.renameSync(destination.path);
      stage = null;
      _activeLeases[key] = (_activeLeases[key] ?? 0) + 1;
      if (!retain) _pendingDeletes.add(key);
      return VideoCacheLease._(
        destination.path,
        () => _releaseVideo(key, destination),
      );
    } finally {
      try {
        if (!ownedToken.isCancelled)
          ownedToken.cancel('Guarded transfer finished');
        try {
          if (sink != null) await sink.close();
        } finally {
          if (stage != null && await stage.exists()) await stage.delete();
        }
      } finally {
        _guardedTokens.remove(ownedToken);
        _guardedTransfers.remove(ownedToken);
        _guardedWaiters--;
        finished.complete();
      }
    }
  }

  Future<void> _releaseVideo(String key, File file) async {
    final remaining = (_activeLeases[key] ?? 1) - 1;
    if (remaining > 0) {
      _activeLeases[key] = remaining;
      return;
    }
    _activeLeases.remove(key);
    if (!_pendingDeletes.contains(key)) return;
    try {
      if (await file.exists()) await file.delete();
      _pendingDeletes.remove(key);
    } catch (e) {
      _log('Error deleting released video cache file: $e');
    }
  }

  @override
  Future<void> saveFile(String key, Uint8List bytes) async {
    // Noop - not used for video caching, cacheVideo handles everything
  }

  Future<String?> cacheVideo(
    String url, {
    Map<String, String>? headers,
    int? fileSize,
  }) async {
    final key = generateCacheKey(url);
    // A deferred deletion still owns the physical path until its last reader
    // releases it. A new transfer must never replace that active payload.
    if (_pendingDeletes.contains(key) || (_activeLeases[key] ?? 0) > 0) {
      return null;
    }
    if (await isVideoCached(url)) {
      return null;
    }

    try {
      int? estimatedSize = fileSize;

      // Only make HEAD request if file size not provided
      if (estimatedSize == null) {
        final headResponse = await dio.head(
          url,
          options: Options(
            headers: headers,
            extra: const {'boorusama.request.media': true},
          ),
        );

        final contentLength = headResponse.headers.value('content-length');
        if (contentLength != null) {
          estimatedSize = int.tryParse(contentLength);
        }
      }

      // Check file size limit
      if (estimatedSize != null &&
          maxItemSize != -1 &&
          estimatedSize > maxItemSize) {
        throw VideoCacheException(
          'Video too large: $estimatedSize bytes exceeds max item size of $maxItemSize bytes',
        );
      }

      // Ensure space before downloading
      if (maxTotalCacheSize != -1 && estimatedSize != null) {
        await _ensureSpaceAvailable(estimatedSize);
      }

      final cacheDir = await getCacheDirectory();
      final cacheKey = generateCacheKey(url);

      final task = DownloadTask(
        url: url,
        filename: cacheKey,
        baseDirectory: BaseDirectory.root,
        directory: cacheDir.path,
        allowPause: false,
        retries: 1,
        updates: Updates.none,
        headers: headers,
        group: videoCacheGroup,
      );

      final existingTask = await fileDownloader.taskForId(task.taskId);
      if (existingTask != null) {
        return existingTask.taskId;
      }

      // HEAD/quota/downloader checks above can yield to a clear or acquisition.
      if (_pendingDeletes.contains(key) || (_activeLeases[key] ?? 0) > 0) {
        return null;
      }
      await fileDownloader.enqueue(task);
      return task.taskId;
    } catch (e) {
      _log('Failed to preload video: $e');
      rethrow;
    }
  }

  Future<bool> cancelPreload(String taskId) async {
    try {
      return await fileDownloader.cancelTaskWithId(taskId);
    } catch (e) {
      _log('Failed to cancel preload: $e');
      return false;
    }
  }

  @override
  Future<void> clearCache(String key) async {
    _clearsInProgress++;
    final matching = _guardedTransfers.entries
        .where((entry) => entry.value.$1 == key)
        .toList();
    for (final entry in matching) {
      entry.key.cancel('Video cache cleared');
    }
    try {
      await Future.wait(matching.map((entry) => entry.value.$2));
      final cacheDir = await getCacheDirectory();
      final cacheFile = File(join(cacheDir.path, key));

      if ((_activeLeases[key] ?? 0) > 0) {
        _pendingDeletes.add(key);
        return;
      }
      if (cacheFile.existsSync()) {
        await cacheFile.delete();
      }
      _pendingDeletes.remove(key);
    } catch (e) {
      _log('Error clearing video cache: $e');
    } finally {
      _clearsInProgress--;
    }
  }

  Future<void> clearVideo(String url) async {
    final cacheKey = generateCacheKey(url);
    await clearCache(cacheKey);
  }

  Future<void> clearAllVideos() async {
    _clearsInProgress++;
    for (final token in _guardedTokens.toList()) {
      token.cancel('Video cache cleared');
    }
    try {
      await _guardedQueue;
      final cacheDir = await getCacheDirectory();
      if (cacheDir.existsSync()) {
        if (_activeLeases.isEmpty) {
          await cacheDir.delete(recursive: true);
          _pendingDeletes.clear();
          invalidateCacheDirectory();
        } else {
          await for (final entity in cacheDir.list(followLinks: false)) {
            if (entity is! File) continue;
            final key = basename(entity.path);
            if ((_activeLeases[key] ?? 0) > 0) {
              _pendingDeletes.add(key);
            } else {
              await entity.delete();
              _pendingDeletes.remove(key);
            }
          }
        }
      }
    } catch (e) {
      _log('Error clearing all video cache: $e');
    } finally {
      _clearsInProgress--;
    }
  }

  @override
  Future<void> clearAllCache() => clearAllVideos();

  @override
  void invalidateCacheDirectory() {
    _cacheDir = null;
    _cacheDirFuture = null;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final token in _guardedTokens.toList()) {
      token.cancel('Video cache disposed');
    }
    await _guardedQueue;
    _cacheDir = null;
    _cacheDirFuture = null;
  }

  FutureOr<Uint8List?> _readFileBytes(File? file, String key) {
    if (file == null) return null;

    try {
      return file.readAsBytes();
    } catch (e) {
      _log('Error reading video cache: $e');
      return null;
    }
  }

  Future<void> _touchFile(File file) async {
    try {
      final now = DateTime.now();
      await file.setLastModified(now);
    } catch (e) {
      _log('Error touching video cache file: $e');
    }
  }

  Future<void> _ensureSpaceAvailable(int spaceNeeded) async {
    if (maxTotalCacheSize == -1) {
      return;
    }

    final cacheDir = await getCacheDirectory();
    final targetThreshold = (maxTotalCacheSize * evictionThreshold).round();

    final files = cacheDir
        .listSync()
        .whereType<File>()
        .where((file) => !file.path.endsWith('.part'))
        .toList();
    var currentSize = 0;

    final fileStats = <_FileWithStats>[];
    for (final file in files) {
      try {
        final stat = file.statSync();
        currentSize += stat.size;
        fileStats.add(_FileWithStats(file, stat));
      } catch (e) {
        _log('Error accessing file during eviction: $e');
      }
    }

    fileStats.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));

    final maxAllowedSize = targetThreshold - spaceNeeded;

    for (final fileWithStat in fileStats) {
      if (currentSize <= maxAllowedSize) break;
      final key = basename(fileWithStat.file.path);
      if (key.endsWith('.part') || (_activeLeases[key] ?? 0) > 0) continue;

      try {
        await fileWithStat.file.delete();
        currentSize -= fileWithStat.stat.size;
        _log(
          'Evicted file: ${fileWithStat.file.path} (${fileWithStat.stat.size} bytes)',
        );
      } catch (e) {
        _log('Error deleting file during eviction: $e');
      }
    }
  }

  void _log(String message) {
    if (enableLogging) {
      print('[VideoCacheManager] $message');
    }
  }
}

class VideoCacheLease {
  VideoCacheLease._(this.path, this._release);

  final String path;
  final Future<void> Function() _release;
  Future<void>? _released;

  Future<void> release() => _released ??= _release();
}

class _FileWithStats {
  const _FileWithStats(this.file, this.stat);
  final File file;
  final FileStat stat;
}

class VideoCacheException implements Exception {
  const VideoCacheException(this.message);
  final String message;

  @override
  String toString() => 'VideoCacheException: $message';
}
