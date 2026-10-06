import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:cache_manager/cache_manager.dart';

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
  ShareMediaLease({required this.path, required this.mimeType});
  final String path;
  final String mimeType;
  void retain() {}
  Future<void> release() async {}
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

  Future<ShareMediaLease> prepare({
    required String url,
    required ShareMediaKind kind,
    required String? fallbackExtension,
    required Map<String, String> headers,
    CancelToken? cancelToken,
    void Function(double fraction)? onProgress,
  }) async => throw const ShareMediaException(ShareMediaFailure.unsupported);

  Future<void> cleanupExpired() async {}
}

Future<void> cleanupExpiredShareFiles(String? rootPath) async {}
