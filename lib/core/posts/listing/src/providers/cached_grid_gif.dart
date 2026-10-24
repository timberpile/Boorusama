import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef CachedGridGifRequest = ({
  ImageCacheManager manager,
  String url,
  int? originalSize,
});

final cachedGridGifProvider = FutureProvider.autoDispose
    .family<Uint8List?, CachedGridGifRequest>((ref, request) {
      return readCachedGridGif(
        request.manager,
        request.url,
        originalSize: request.originalSize,
      );
    });

/// Own the cached bytes before choosing playback. Eviction after this read must
/// never turn a local autoplay decision into an automatic network download.
Future<Uint8List?> readCachedGridGif(
  ImageCacheManager manager,
  String url, {
  int? originalSize,
}) async {
  try {
    final bytes = await manager.getCachedFileBytes(
      manager.generateCacheKey(url),
    );
    if (bytes == null ||
        (originalSize != null && bytes.length != originalSize) ||
        !isCompleteGridGif(bytes)) {
      return null;
    }
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1,
      targetHeight: 1,
    );
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
    return bytes;
  } on Object {
    return null;
  }
}

/// Validate GIF block boundaries, palettes, image data and the final trailer.
/// The cache's committed-file checks exclude staged/truncated cache generations.
bool isCompleteGridGif(Uint8List bytes) {
  if (bytes.length < 14) return false;
  final header = String.fromCharCodes(bytes.take(6));
  if (header != 'GIF87a' && header != 'GIF89a') return false;
  int word(int offset) => bytes[offset] | (bytes[offset + 1] << 8);
  if (word(6) == 0 || word(8) == 0) return false;
  var offset = 13;
  if (bytes[10] & 0x80 != 0) {
    offset += 3 * (1 << ((bytes[10] & 7) + 1));
  }
  var images = 0;
  bool subBlocks({bool requireData = false}) {
    var hasData = false;
    while (offset < bytes.length) {
      final size = bytes[offset++];
      if (size == 0) return !requireData || hasData;
      hasData = true;
      offset += size;
      if (offset > bytes.length) return false;
    }
    return false;
  }

  while (offset < bytes.length) {
    switch (bytes[offset++]) {
      case 0x3b:
        return images > 0 && offset == bytes.length;
      case 0x21:
        if (offset >= bytes.length) return false;
        offset++; // Extension label; its payload is a sequence of sub-blocks.
        if (!subBlocks()) return false;
      case 0x2c:
        if (offset + 9 > bytes.length) return false;
        if (word(offset + 4) == 0 || word(offset + 6) == 0) return false;
        final packed = bytes[offset + 8];
        offset += 9;
        if (packed & 0x80 != 0) offset += 3 * (1 << ((packed & 7) + 1));
        if (offset >= bytes.length) return false;
        final codeSize = bytes[offset++];
        if (codeSize < 2 || codeSize > 8 || !subBlocks(requireData: true)) {
          return false;
        }
        images++;
      default:
        return false;
    }
  }
  return false;
}
