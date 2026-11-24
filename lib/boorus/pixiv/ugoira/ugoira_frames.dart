import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';

import 'ugoira_archive.dart';

class PreparedPixivUgoira {
  PreparedPixivUgoira(this.animation, this._openingFrames);

  static Future<PreparedPixivUgoira> prepare(
    PixivUgoiraAnimation animation,
    CancelToken token,
  ) async {
    final images = <ui.Image>[];
    try {
      for (final bytes in animation.frames.take(2)) {
        if (token.cancelError case final error?) throw error;
        images.add(await decodePixivUgoiraFrame(bytes));
      }
      if (token.cancelError case final error?) throw error;
      return PreparedPixivUgoira(animation, images);
    } catch (_) {
      for (final image in images) {
        image.dispose();
      }
      rethrow;
    }
  }

  final PixivUgoiraAnimation animation;
  final List<ui.Image> _openingFrames;
  var _references = 1;

  int get encodedBytes =>
      animation.frames.fold(0, (size, frame) => size + frame.length);
  int get decodedBytes => _openingFrames.fold(
    0,
    (size, image) => size + image.width * image.height * 4,
  );

  Map<int, ui.Image> cloneOpeningFrames() => {
    for (final (index, image) in _openingFrames.indexed) index: image.clone(),
  };

  void retain() => _references++;

  void release() {
    if (--_references != 0) return;
    for (final image in _openingFrames) {
      image.dispose();
    }
  }
}

Future<ui.Image> decodePixivUgoiraFrame(Uint8List bytes) async {
  const maxSourcePixels = 32 * 1024 * 1024;
  const maxRenderSide = 1920;
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final width = descriptor.width;
    final height = descriptor.height;
    if (width <= 0 || height <= 0 || width > maxSourcePixels ~/ height) {
      throw const FormatException('Invalid Ugoira frame dimensions');
    }
    codec = await descriptor.instantiateCodec(
      targetWidth: width >= height && width > maxRenderSide
          ? maxRenderSide
          : null,
      targetHeight: height > width && height > maxRenderSide
          ? maxRenderSide
          : null,
    );
    if (codec.frameCount != 1) {
      throw const FormatException('Invalid animated Ugoira frame');
    }
    return (await codec.getNextFrame()).image;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}
