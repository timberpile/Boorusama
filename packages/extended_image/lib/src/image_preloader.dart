import 'shared_image_read.dart';
// Flutter imports:
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:dio/dio.dart';
import 'package:retriable/retriable.dart';

// Project imports:
import 'image_fetcher.dart';
import 'pending_image_cache_write.dart';

class ImagePreloader {
  const ImagePreloader({
    required this.cacheManager,
    required this.dio,
    this.enableLogging = false,
  });

  final ImageCacheManager cacheManager;
  final Dio dio;
  final bool enableLogging;

  Future<void> preloadImage(
    String url, {
    Map<String, String>? headers,
    FetchStrategyBuilder? fetchStrategy,
    CancelToken? cancelToken,
    String? customKey,
    Duration? maxAge,
    // Scheduling owners can distinguish transport failure from completion.
    // Direct best-effort callers retain the existing default.
    bool propagateErrors = false,
  }) async {
    final cacheKey = customKey ?? cacheManager.generateCacheKey(url);

    // Check if already cached
    var hasValidCache = false;
    try {
      final result = cacheManager.hasValidCache(cacheKey, maxAge: maxAge);
      hasValidCache = result is Future<bool> ? await result : result;
    } on Object {
      // Optional cache lookup cannot prevent a preload transport attempt.
    }

    if (hasValidCache) {
      if (cancelToken?.isCancelled == true) return;
      if (cacheManager case final ManagedImageCacheManager manager) {
        await manager.touch(cacheKey);
      }
      _log('Image already cached: $url');
      return;
    }

    try {
      await SharedImageRead.run(
        dio: dio,
        manager: cacheManager,
        key: cacheKey,
        headers: headers,
        owner: cancelToken,
        load: (sharedToken) async {
          final write = await PendingImageCacheWrite.begin(
            cacheManager,
            cacheKey,
          );
          try {
            final bytes = await ImageFetcher.fetchImageBytes(
              url: url,
              dio: dio,
              headers: headers,
              fetchStrategy: fetchStrategy,
              cancelToken: sharedToken,
              printError: enableLogging,
            );
            if (!sharedToken.isCancelled) await write.save(bytes);
            return bytes;
          } finally {
            await write.abort();
          }
        },
      );
    } catch (_) {
      if (propagateErrors) rethrow;
    }
  }

  void _log(String message) {
    if (enableLogging && kDebugMode) {
      debugPrint('[ImagePreloader] $message');
    }
  }
}
