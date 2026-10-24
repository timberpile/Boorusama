import 'dart:convert';
import 'dart:typed_data';

import 'package:boorusama/core/posts/listing/src/types/grid_thumbnail_url_generator_default.dart';

Uint8List largeGridGif() {
  final minimal = base64Decode(
    'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
  );
  final output = BytesBuilder()
    ..add(minimal.sublist(0, minimal.length - 1))
    ..add([0x21, 0xfe]);
  // A valid comment extension makes a small, cheap-to-decode GIF exceed 5 MB.
  for (var size = 0; size < maxAutoplayGridGifBytes + 256; size += 255) {
    output
      ..addByte(255)
      ..add(Uint8List(255));
  }
  output..add([0, 0x3b]);
  return output.takeBytes();
}
