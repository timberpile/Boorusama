import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../foundation/filesystem.dart';
import '../settings/providers.dart';

final defaultCachedImageFileProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>(
      (ref, imageUrl) async {
        final cacheManager = ref.watch(defaultImageCacheManagerProvider);
        final cacheKey = cacheManager.generateCacheKey(imageUrl);
        final bytes = await cacheManager.getCachedFileBytes(cacheKey);

        return bytes;
      },
    );

final defaultImageCacheManagerProvider = Provider<ImageCacheManager>(
  (ref) {
    final fs = ref.watch(appFileSystemProvider);
    final manager = createDefaultImageCacheManager(
      fs,
      maxBytes: ref.read(settingsProvider).imageCacheMaxSize.bytes,
    );
    ref.listen(settingsProvider.select((s) => s.imageCacheMaxSize), (_, limit) {
      unawaited(manager.setMaxBytes(limit.bytes));
    });

    ref.onDispose(() {
      manager.dispose();
    });

    return manager;
  },
);

ManagedImageCacheManager createDefaultImageCacheManager(
  AppFileSystem fs, {
  int maxBytes = 1024 * 1024 * 1024,
}) {
  return DefaultImageCacheManager(
    maxBytes: maxBytes,
    enableLogging: kDebugMode,
    cacheRootPathProvider: () async {
      final path = await fs.getTemporaryPath();
      if (path == null) throw Exception('Cache directory not available');
      return path;
    },
    memoryCache: LRUMemoryCache(
      maxEntries: 500,
    ),
  );
}
