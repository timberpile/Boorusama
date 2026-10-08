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

    final write = await PendingImageCacheWrite.begin(cacheManager, cacheKey);
    try {
      _log('Preloading image: $url');

      final bytes = await ImageFetcher.fetchImageBytes(
        url: url,
        dio: dio,
        headers: headers,
        fetchStrategy: fetchStrategy,
        cancelToken: cancelToken,
        printError: enableLogging,
      );

      await write.save(bytes);
      _log('Successfully preloaded: $url');
    } catch (e) {
      _log('Failed to preload $url: $e');
      // Don't rethrow - preloading is non-critical
    } finally {
      await write.abort();
    }
  }

  void _log(String message) {
    if (enableLogging && kDebugMode) {
      debugPrint('[ImagePreloader] $message');
    }
  }
}
