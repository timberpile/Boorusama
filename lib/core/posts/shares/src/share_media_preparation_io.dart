// ignore_for_file: avoid_slow_async_io
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:path/path.dart' as p;

import 'share_cached_image_validation.dart';
import 'share_image_file_validation.dart';
import 'share_platform_staging_cleanup.dart';
import 'share_resolution_control.dart';

enum ShareMediaKind { image, original, video, gif }

enum ShareMediaFailure {
  network,
  unavailable,
  authentication,
  storage,
  unsupported,
  empty,
  cancelled,
}

class ShareMediaException implements Exception {
  const ShareMediaException(this.failure);
  final ShareMediaFailure failure;
}

class ShareMediaLease {
  ShareMediaLease({
    required this.path,
    required this.mimeType,
    this.deleteOnRelease = true,
  });

  final String path;
  final String mimeType;
  final bool deleteOnRelease;
  var _owners = 1;

  void retain() {
    if (_owners == 0) throw StateError('Share file already released');
    _owners++;
  }

  Future<void> release() async {
    if (_owners == 0) return;
    _owners--;
    if (_owners == 0 && deleteOnRelease) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
}

typedef CachedShareBytes = Future<Uint8List?> Function(String url);

class ShareMediaPreparation {
  ShareMediaPreparation({
    required this.rootPath,
    required this.dio,
    required this.cachedBytes,
    this.imageCacheManager,
  });

  final String rootPath;
  final Dio dio;
  final CachedShareBytes cachedBytes;
  final ImageCacheManager? imageCacheManager;

  Directory get _directory => Directory(p.join(rootPath, 'boorusama-share'));

  Future<ShareMediaLease> prepare({
    required String url,
    required ShareMediaKind kind,
    required String? fallbackExtension,
    required Map<String, String> headers,
    CancelToken? cancelToken,
    void Function(double fraction)? onProgress,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw const ShareMediaException(ShareMediaFailure.unsupported);
    }
    final extension = _extension(uri, kind, fallbackExtension);
    checkShareCancellation(cancelToken);

    if (imageCacheManager case final cacheManager?
        when kind == ShareMediaKind.image || kind == ShareMediaKind.original) {
      return _prepareImageInCache(
        cacheManager: cacheManager,
        url: url,
        extension: extension,
        kind: kind,
        headers: headers,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
    }

    final directory = _directory;
    try {
      await directory.create(recursive: true);
    } on FileSystemException {
      throw const ShareMediaException(ShareMediaFailure.storage);
    }
    checkShareCancellation(cancelToken);
    final random = Random.secure();
    final name =
        'boorusama_share_${DateTime.now().microsecondsSinceEpoch}_${random.nextInt(1 << 32)}.${extension ?? 'tmp'}';
    var file = File(p.join(directory.path, name));
    var effectiveExtension = extension;

    try {
      Uint8List? bytes;
      if (extension != null &&
          (kind == ShareMediaKind.image || kind == ShareMediaKind.original)) {
        try {
          bytes = await awaitShareOrCancellation(cachedBytes(url), cancelToken);
        } on ShareMediaException {
          rethrow;
        } catch (_) {
          bytes = null;
        }
      }
      checkShareCancellation(cancelToken);
      if (bytes != null &&
          extension != null &&
          cachedImageMatches(bytes, extension)) {
        await file.writeAsBytes(bytes);
        checkShareCancellation(cancelToken);
        onProgress?.call(1);
      } else {
        final response = await dio.download(
          url,
          file.path,
          options: Options(
            headers: headers,
            extra: const {'boorusama.request.media': true},
          ),
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) =>
              onProgress?.call(total > 0 ? received / total : -1),
        );
        checkShareCancellation(cancelToken);
        final contentType = response.headers
            .value(Headers.contentTypeHeader)
            ?.split(';')
            .first
            .trim()
            .toLowerCase();
        final declared = _extensionForMime(contentType, kind);
        if ((extension == null && declared == null) ||
            (contentType != null &&
                contentType != 'application/octet-stream' &&
                declared == null)) {
          throw const ShareMediaException(ShareMediaFailure.unsupported);
        }
        effectiveExtension = declared ?? extension;
      }
      final length = await file.length();
      checkShareCancellation(cancelToken);
      if (length == 0) {
        throw const ShareMediaException(ShareMediaFailure.empty);
      }
      if (effectiveExtension == null) {
        throw const ShareMediaException(ShareMediaFailure.unsupported);
      }
      if (effectiveExtension != (extension ?? 'tmp')) {
        final renamedPath = p.join(
          directory.path,
          '${p.basenameWithoutExtension(file.path)}.$effectiveExtension',
        );
        file = await file.rename(renamedPath);
        checkShareCancellation(cancelToken);
      }
      return ShareMediaLease(
        path: file.path,
        mimeType: _mimeType(effectiveExtension),
      );
    } catch (error) {
      if (await file.exists()) await file.delete();
      if (error is ShareMediaException) rethrow;
      if (error is DioException) {
        if (CancelToken.isCancel(error)) {
          throw const ShareMediaException(ShareMediaFailure.cancelled);
        }
        if (error.response?.statusCode == 401 ||
            error.response?.statusCode == 403) {
          throw const ShareMediaException(ShareMediaFailure.authentication);
        }
        throw const ShareMediaException(ShareMediaFailure.network);
      }
      if (error is FileSystemException) {
        throw const ShareMediaException(ShareMediaFailure.storage);
      }
      rethrow;
    }
  }

  Future<ShareMediaLease> _prepareImageInCache({
    required ImageCacheManager cacheManager,
    required String url,
    required String? extension,
    required ShareMediaKind kind,
    required Map<String, String> headers,
    required CancelToken? cancelToken,
    required void Function(double fraction)? onProgress,
  }) async {
    final key = cacheManager.generateCacheKey(url);
    try {
      final cachedPath = await cacheManager.getCachedFilePath(key);
      if (cachedPath != null) {
        final cachedExtension = await validateShareImageFile(File(cachedPath));
        if (cachedExtension != null) {
          return ShareMediaLease(
            path: cachedPath,
            mimeType: _mimeType(cachedExtension),
            deleteOnRelease: false,
          );
        }
      }

      final targetPath = await cacheManager.getCacheFilePathForKey(key);
      if (targetPath == null) {
        throw const ShareMediaException(ShareMediaFailure.unsupported);
      }
      final target = File(targetPath);
      await target.parent.create(recursive: true);
      final random = Random.secure();
      final staged = File(
        '${target.path}.${DateTime.now().microsecondsSinceEpoch}_${random.nextInt(1 << 32)}.partial',
      );
      checkShareCancellation(cancelToken);
      try {
        final response = await dio.download(
          url,
          staged.path,
          options: Options(
            headers: headers,
            extra: const {'boorusama.request.media': true},
          ),
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) =>
              onProgress?.call(total > 0 ? received / total : -1),
        );
        checkShareCancellation(cancelToken);
        final contentType = response.headers
            .value(Headers.contentTypeHeader)
            ?.split(';')
            .first
            .trim()
            .toLowerCase();
        final responseExtension = _extensionForMime(contentType, kind);
        if ((extension == null && responseExtension == null) ||
            (contentType != null &&
                contentType != 'application/octet-stream' &&
                responseExtension == null)) {
          throw const ShareMediaException(ShareMediaFailure.unsupported);
        }
        if (await staged.length() == 0) {
          throw const ShareMediaException(ShareMediaFailure.empty);
        }
        final actualExtension = await validateShareImageFile(staged);
        final expectedExtension = responseExtension ?? extension;
        if (actualExtension == null ||
            expectedExtension == null ||
            _canonicalImageExtension(actualExtension) !=
                _canonicalImageExtension(expectedExtension)) {
          throw const ShareMediaException(ShareMediaFailure.unsupported);
        }
        checkShareCancellation(cancelToken);
        await cacheManager.replaceCachedFile(key, staged.path);
        onProgress?.call(1);
        return ShareMediaLease(
          path: target.path,
          mimeType: _mimeType(actualExtension),
          deleteOnRelease: false,
        );
      } finally {
        if (await staged.exists()) await staged.delete();
      }
    } on ShareMediaException {
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const ShareMediaException(ShareMediaFailure.cancelled);
      }
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        throw const ShareMediaException(ShareMediaFailure.authentication);
      }
      throw const ShareMediaException(ShareMediaFailure.network);
    } on FileSystemException {
      throw const ShareMediaException(ShareMediaFailure.storage);
    }
  }

  Future<void> cleanupExpired() async {
    final directory = _directory;
    await cleanupExpiredPlatformShareCopies(rootPath);
    if (!await directory.exists()) return;
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File && (await entry.lastModified()).isBefore(cutoff)) {
        await entry.delete();
      }
    }
  }
}

Future<void> cleanupExpiredShareFiles(String? rootPath) async {
  if (rootPath == null) return;
  await ShareMediaPreparation(
    rootPath: rootPath,
    dio: Dio(),
    cachedBytes: (_) async => null,
  ).cleanupExpired();
}

String _canonicalImageExtension(String extension) =>
    extension == 'jpeg' ? 'jpg' : extension;

String? _extension(Uri uri, ShareMediaKind kind, String? fallback) {
  final pathExtension = p
      .extension(uri.path)
      .replaceFirst('.', '')
      .toLowerCase();
  final candidate = pathExtension.isNotEmpty
      ? pathExtension
      : fallback?.toLowerCase();
  if (candidate == null) return null;
  final supported = switch (kind) {
    ShareMediaKind.image || ShareMediaKind.original => {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'avif',
      'bmp',
    },
    ShareMediaKind.video => {'mp4', 'webm', 'mov', 'm4v'},
    ShareMediaKind.gif => {'gif'},
  };
  return supported.contains(candidate) ? candidate : null;
}

String? _extensionForMime(String? mime, ShareMediaKind kind) {
  final extension = switch (mime) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    'image/avif' => 'avif',
    'image/bmp' => 'bmp',
    'video/mp4' => 'mp4',
    'video/webm' => 'webm',
    'video/quicktime' => 'mov',
    _ => null,
  };
  if (extension == null) return null;
  return _extension(
    Uri.parse('https://local.invalid/file.$extension'),
    kind,
    null,
  );
}

String _mimeType(String extension) => switch (extension) {
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'gif' => 'image/gif',
  'webp' => 'image/webp',
  'avif' => 'image/avif',
  'bmp' => 'image/bmp',
  'mp4' || 'm4v' => 'video/mp4',
  'webm' => 'video/webm',
  'mov' => 'video/quicktime',
  _ => 'application/octet-stream',
};
