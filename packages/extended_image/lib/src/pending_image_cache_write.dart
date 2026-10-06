import 'dart:typed_data';

import 'package:cache_manager/cache_manager.dart';

/// Optional cache ownership reserved before transport, including clear epochs.
class PendingImageCacheWrite {
  PendingImageCacheWrite._(this.manager, this.key, this.session);
  final ImageCacheManager manager;
  final String key;
  final ImageCacheWriteSession? session;

  static Future<PendingImageCacheWrite> begin(
    ImageCacheManager manager,
    String key,
  ) async {
    ImageCacheWriteSession? session;
    if (manager is ManagedImageCacheManager) {
      try {
        session = await manager.beginFileWrite(key);
      } on Object {
        // Optional admission failure must not prevent transport or pixels.
      }
    }
    return PendingImageCacheWrite._(manager, key, session);
  }

  Future<void> save(Uint8List bytes) async {
    try {
      if (session case final owner?) {
        await owner.saveBytes(bytes);
      } else if (manager is! ManagedImageCacheManager) {
        await manager.saveFile(key, bytes);
      }
      // A failed managed reservation cannot become a new post-clear write.
    } on Object {
      // Display owns these bytes independently of optional cache admission.
    }
  }

  Future<void> abort() async {
    try {
      await session?.abort();
    } on Object {
      // Storage cleanup failures must not become image errors.
    }
  }
}
