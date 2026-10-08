import 'dart:typed_data';

import 'package:image/image.dart' as image;

import 'gif_export_contract.dart';

/// Parse the entire container strictly; the image decoder alone accepts some
/// truncated files. Decode frames one at a time to keep memory bounded.
GifOutputValidation inspectGifOutput(Uint8List bytes) {
  const invalid = GifOutputValidation(
    fullDecodeSucceeded: false,
    canvasWidth: null,
    canvasHeight: null,
    allFramesMatchCanvas: false,
    frameCount: null,
    frameDelayCentiseconds: null,
    infiniteLoop: null,
  );
  try {
    if (bytes.length < 14 || bytes.length > GifExportPlan.maxOutputBytes) {
      return invalid;
    }
    final reader = _GifReader(bytes);
    final signature = String.fromCharCodes(reader.take(6));
    if (signature != 'GIF89a' && signature != 'GIF87a') return invalid;
    final width = reader.word();
    final height = reader.word();
    if (width <= 0 ||
        height <= 0 ||
        width > GifExportPlan.maxFramePixels ~/ height) {
      return invalid;
    }
    final flags = reader.byte();
    reader.take(2);
    if (flags & 0x80 != 0) reader.take(3 * (1 << ((flags & 7) + 1)));
    bool? infiniteLoop;
    var fits = true;
    var delay = 0;
    final delays = <int>[];
    var ended = false;
    while (reader.position < bytes.length) {
      final marker = reader.byte();
      if (marker == 0x3b) {
        ended = reader.position == bytes.length;
        break;
      }
      if (marker == 0x21) {
        final label = reader.byte();
        if (label == 0xf9) {
          if (reader.byte() != 4) return invalid;
          reader.byte();
          delay = reader.word();
          reader.byte();
          if (reader.byte() != 0) return invalid;
        } else if (label == 0xff) {
          final application = String.fromCharCodes(reader.take(reader.byte()));
          final recognized =
              application == 'NETSCAPE2.0' || application == 'ANIMEXTS1.0';
          final data = reader.blocks(capture: recognized);
          if (recognized) {
            if (data.length != 3 || data[0] != 1) return invalid;
            infiniteLoop = data[1] == 0 && data[2] == 0;
          }
        } else {
          reader.blocks();
        }
      } else if (marker == 0x2c) {
        final x = reader.word();
        final y = reader.word();
        final frameWidth = reader.word();
        final frameHeight = reader.word();
        fits &=
            frameWidth > 0 &&
            frameHeight > 0 &&
            x + frameWidth <= width &&
            y + frameHeight <= height;
        if (!fits) return invalid;
        final flags = reader.byte();
        if (flags & 0x80 != 0) reader.take(3 * (1 << ((flags & 7) + 1)));
        final codeSize = reader.byte();
        if (codeSize < 2 || codeSize > 8) return invalid;
        reader.blocks();
        delays.add(delay);
        delay = 0;
      } else {
        return invalid;
      }
    }
    if (!ended || delays.isEmpty) return invalid;
    final decoder = image.GifDecoder();
    final info = decoder.startDecode(bytes);
    if (info == null || info.numFrames != delays.length) return invalid;
    for (var frame = 0; frame < info.numFrames; frame++) {
      if (decoder.decodeFrame(frame) == null) return invalid;
    }
    return GifOutputValidation(
      fullDecodeSucceeded: true,
      canvasWidth: width,
      canvasHeight: height,
      allFramesMatchCanvas: fits,
      frameCount: delays.length,
      frameDelayCentiseconds: delays,
      infiniteLoop: infiniteLoop,
    );
  } on Exception {
    return invalid;
    // Malformed third-party image bytes may raise a bounds error in the decoder.
    // ignore: avoid_catching_errors
  } on RangeError {
    return invalid;
  }
}

class _GifReader {
  _GifReader(this.bytes);
  final Uint8List bytes;
  var position = 0;
  int byte() {
    if (position >= bytes.length) throw const FormatException('Truncated GIF');
    return bytes[position++];
  }

  int word() => byte() | (byte() << 8);
  Uint8List take(int count) {
    if (count < 0 || position + count > bytes.length) {
      throw const FormatException('Truncated GIF block');
    }
    final result = Uint8List.sublistView(bytes, position, position + count);
    position += count;
    return result;
  }

  List<int> blocks({bool capture = false}) {
    final result = <int>[];
    for (var size = byte(); size != 0; size = byte()) {
      final block = take(size);
      if (capture) {
        if (result.length + size > 3) {
          throw const FormatException('Invalid GIF loop block');
        }
        result.addAll(block);
      }
    }
    return result;
  }
}
