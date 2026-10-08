import 'dart:typed_data';

import 'cache_manager.dart';

/// Application image storage. Video continues to use ImageCacheManager directly.
abstract class ManagedImageCacheManager implements ImageCacheManager {
  Object get cacheDomain;
  Future<void> touch(String key);
  Future<ImageCacheFileLease?> acquireFile(String key, {Duration? maxAge});
  Future<ImageCacheWriteSession> beginFileWrite(String key);
  Future<void> setMaxBytes(int bytes);
  Future<ImageCacheStats> getStats();
}

abstract class ImageCacheFileLease {
  String get path;
  bool get isRetained;
  Future<void> release();
}

abstract class ImageCacheWriteSession {
  String get stagedPath;

  /// Saves owned transport bytes through this session's admission epoch.
  /// Byte callers need no platform file API or persistent file lease.
  Future<void> saveBytes(Uint8List bytes);
  Future<ImageCacheFileLease> commit();
  Future<void> abort();
}

class ImageCacheStats {
  const ImageCacheStats({
    required this.retainedBytes,
    required this.retainedFileCount,
  });
  final int retainedBytes;
  final int retainedFileCount;
}
