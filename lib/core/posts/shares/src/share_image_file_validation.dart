import 'dart:io';
import 'dart:math';

const _maxHeaderBytes = 64 * 1024;

Future<String?> validateShareImageFile(File file) async {
  final length = await file.length();
  if (length < 12) return null;
  final handle = await file.open();
  try {
    final head = await handle.read(
      length < _maxHeaderBytes ? length : _maxHeaderBytes,
    );
    final tailLength = min(length, 12);
    await handle.setPosition(length - tailLength);
    final tail = await handle.read(tailLength);
    if (_png(head, tail, length)) return 'png';
    if (_jpeg(head, tail)) return 'jpg';
    if (_gif(head, tail)) return 'gif';
    if (_bmp(head, length)) return 'bmp';
    if (_webp(head, length)) return 'webp';
    if (_avif(head, length)) return 'avif';
    return null;
  } finally {
    await handle.close();
  }
}

bool _png(List<int> b, List<int> tail, int length) {
  if (length < 45 || !_at(b, 0, [137, 80, 78, 71, 13, 10, 26, 10])) {
    return false;
  }
  if (_u32(b, 8) != 13 || !_at(b, 12, [73, 72, 68, 82])) return false;
  if (_u32(b, 16) == 0 || _u32(b, 20) == 0) return false;
  if (_crc32(b, 12, 29) != _u32(b, 29)) return false;
  if (!_at(tail, tail.length - 8, [73, 69, 78, 68]) ||
      _u32(tail, tail.length - 12) != 0 ||
      _u32(tail, tail.length - 4) != 0xae426082) {
    return false;
  }
  var offset = 33;
  while (offset + 8 <= b.length && offset < _maxHeaderBytes) {
    final size = _u32(b, offset);
    final type = String.fromCharCodes(b.skip(offset + 4).take(4));
    if (size > length || offset + 12 + size > length) return false;
    if (type == 'IDAT') return size > 0 && offset + 12 + size <= length - 12;
    offset += 12 + size;
  }
  return false;
}

bool _jpeg(List<int> b, List<int> tail) {
  if (!_at(b, 0, [0xff, 0xd8]) || !_at(tail, tail.length - 2, [0xff, 0xd9])) {
    return false;
  }
  var offset = 2;
  var sawFrame = false;
  var sawScan = false;
  while (offset + 4 <= b.length && offset < _maxHeaderBytes) {
    if (b[offset] != 0xff) return false;
    while (offset < b.length && b[offset] == 0xff) {
      offset++;
    }
    if (offset >= b.length) return false;
    final marker = b[offset++];
    if (marker == 0xda) {
      if (offset + 2 > b.length || _u16(b, offset) < 2) return false;
      sawScan = true;
      break;
    }
    if (marker == 0xd8 ||
        marker == 0x01 ||
        (marker >= 0xd0 && marker <= 0xd7)) {
      continue;
    }
    if (offset + 2 > b.length) return false;
    final size = _u16(b, offset);
    if (size < 2 || offset + size > b.length) return false;
    if (_isSof(marker)) {
      if (size < 8 || _u16(b, offset + 3) == 0 || _u16(b, offset + 5) == 0) {
        return false;
      }
      sawFrame = true;
    }
    offset += size;
  }
  return sawFrame && sawScan;
}

bool _gif(List<int> b, List<int> tail) =>
    b.length >= 13 &&
    (_at(b, 0, [71, 73, 70, 56, 55, 97]) ||
        _at(b, 0, [71, 73, 70, 56, 57, 97])) &&
    _u16le(b, 6) > 0 &&
    _u16le(b, 8) > 0 &&
    tail.last == 0x3b;

bool _bmp(List<int> b, int length) {
  if (b.length < 26 || !_at(b, 0, [66, 77])) return false;
  final declaredLength = _u32le(b, 2);
  final pixelOffset = _u32le(b, 10);
  final dibLength = _u32le(b, 14);
  if ((declaredLength != 0 && declaredLength != length) ||
      dibLength < 12 ||
      14 + dibLength > length ||
      pixelOffset < 14 + dibLength ||
      pixelOffset >= length) {
    return false;
  }
  if (dibLength == 12) return _u16le(b, 18) > 0 && _u16le(b, 20) > 0;
  return dibLength >= 40 && _u32le(b, 18) > 0 && _u32le(b, 22) > 0;
}

bool _webp(List<int> b, int length) {
  if (b.length < 30 ||
      !_at(b, 0, [82, 73, 70, 70]) ||
      _u32le(b, 4) + 8 != length ||
      !_at(b, 8, [87, 69, 66, 80])) {
    return false;
  }
  final chunkSize = _u32le(b, 16);
  final kind = String.fromCharCodes(b.skip(12).take(4));
  final minSize = switch (kind) {
    'VP8 ' => 10,
    'VP8L' => 5,
    'VP8X' => 10,
    _ => null,
  };
  if (minSize == null) return false;
  return chunkSize >= minSize && 20 + chunkSize <= length;
}

bool _avif(List<int> b, int length) {
  if (b.length < 24 || !_at(b, 4, [102, 116, 121, 112])) return false;
  final ftypSize = _u32(b, 0);
  if (ftypSize < 16 || ftypSize > 4096 || ftypSize + 8 > length) return false;
  var hasBrand = _brand(b, 8);
  for (var i = 16; i + 4 <= ftypSize; i += 4) {
    hasBrand |= _brand(b, i);
  }
  if (!hasBrand) return false;
  final nextType = String.fromCharCodes(b.skip(ftypSize + 4).take(4));
  final nextSize = _u32(b, ftypSize);
  return nextType == 'meta' && nextSize >= 12 && ftypSize + nextSize <= length;
}

bool _brand(List<int> b, int offset) =>
    _at(b, offset, [97, 118, 105, 102]) || _at(b, offset, [97, 118, 105, 115]);

bool _isSof(int marker) =>
    marker >= 0xc0 &&
    marker <= 0xcf &&
    marker != 0xc4 &&
    marker != 0xc8 &&
    marker != 0xcc;

bool _at(List<int> bytes, int offset, List<int> expected) =>
    offset >= 0 &&
    offset + expected.length <= bytes.length &&
    expected.asMap().entries.every(
      (entry) => bytes[offset + entry.key] == entry.value,
    );

int _u16(List<int> b, int o) => (b[o] << 8) | b[o + 1];
int _u32(List<int> b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
int _u16le(List<int> b, int o) => b[o] | (b[o + 1] << 8);
int _u32le(List<int> b, int o) =>
    b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

int _crc32(List<int> bytes, int start, int end) {
  var crc = 0xffffffff;
  for (var i = start; i < end; i++) {
    crc ^= bytes[i];
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
