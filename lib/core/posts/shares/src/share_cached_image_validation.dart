import 'dart:typed_data';

import 'package:image/image.dart' as img;

bool cachedImageMatches(Uint8List bytes, String extension) {
  final signatureMatches = switch (extension) {
    'jpg' || 'jpeg' => _prefix(bytes, [0xff, 0xd8, 0xff]),
    'png' => _prefix(bytes, [137, 80, 78, 71, 13, 10, 26, 10]),
    'gif' =>
      _prefix(bytes, [71, 73, 70, 56, 55, 97]) ||
          _prefix(bytes, [71, 73, 70, 56, 57, 97]),
    'webp' =>
      _prefix(bytes, [82, 73, 70, 70]) && _at(bytes, 8, [87, 69, 66, 80]),
    'bmp' => _prefix(bytes, [66, 77]),
    _ => false,
  };
  if (!signatureMatches) return false;
  try {
    return img.decodeImage(bytes) != null;
  } catch (_) {
    return false;
  }
}

bool _prefix(Uint8List bytes, List<int> prefix) => _at(bytes, 0, prefix);

bool _at(Uint8List bytes, int offset, List<int> signature) {
  if (bytes.length < offset + signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[offset + i] != signature[i]) return false;
  }
  return true;
}
