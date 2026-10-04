import 'dart:typed_data';

import 'package:flutter_libavif/flutter_libavif.dart';

Future<({int width, int height})?> cachedAvifDimensions(Uint8List bytes) async {
  AvifSequenceDecoder? decoder;
  try {
    decoder = await AvifSequenceDecoder.open(bytes);
    if (decoder.info.width <= 0 || decoder.info.height <= 0) return null;
    return (width: decoder.info.width, height: decoder.info.height);
  } on Object {
    return null;
  } finally {
    decoder?.dispose();
  }
}
