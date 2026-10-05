import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:foundation/foundation.dart';

import 'share_avif_metadata_stub.dart'
    if (dart.library.ffi) 'share_avif_metadata_native.dart';

Future<String?> cachedShareImageDescription(Uint8List? bytes) async {
  if (bytes == null || bytes.isEmpty) return null;
  final format = _formatFromSignature(bytes);
  if (format == null) return null;
  Future<String?> fallback() async {
    if (format != 'AVIF') return null;
    final dimensions = await cachedAvifDimensions(bytes);
    if (dimensions == null) return null;
    return '${dimensions.width} × ${dimensions.height} · ${Filesize.parse(bytes.length, round: 1)} · AVIF';
  }

  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width <= 0 || descriptor.height <= 0) return fallback();
    return '${descriptor.width} × ${descriptor.height} · ${Filesize.parse(bytes.length, round: 1)} · $format';
  } on Exception {
    return fallback();
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}

String? _formatFromSignature(Uint8List bytes) {
  bool startsWith(List<int> signature, [int offset = 0]) {
    if (bytes.length < signature.length + offset) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i + offset] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return 'PNG';
  }
  if (startsWith([0xff, 0xd8, 0xff])) return 'JPG';
  if (startsWith([0x47, 0x49, 0x46, 0x38, 0x37, 0x61]) ||
      startsWith([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])) {
    return 'GIF';
  }
  if (startsWith([0x52, 0x49, 0x46, 0x46]) &&
      startsWith([0x57, 0x45, 0x42, 0x50], 8)) {
    return 'WEBP';
  }
  if (startsWith([0x42, 0x4d])) return 'BMP';
  if (startsWith([0x66, 0x74, 0x79, 0x70], 4) &&
      (startsWith([0x61, 0x76, 0x69, 0x66], 8) ||
          startsWith([0x61, 0x76, 0x69, 0x73], 8))) {
    return 'AVIF';
  }
  return null;
}
