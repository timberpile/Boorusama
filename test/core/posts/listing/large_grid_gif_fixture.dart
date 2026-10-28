import 'dart:convert';
import 'dart:typed_data';

import 'package:boorusama/core/posts/listing/src/types/grid_thumbnail_url_generator_default.dart';

Uint8List largeGridGif({int frameCount = 1, bool corruptLastFrame = false}) {
  assert(frameCount > 0, 'GIF needs at least one frame');
  final minimal = base64Decode(
    'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
  );
  final output = BytesBuilder()..add(minimal.sublist(0, 19));
  for (var index = 0; index < frameCount; index++) {
    final frame = minimal.sublist(19, minimal.length - 1);
    if (corruptLastFrame && index == frameCount - 1) {
      frame[frame.length - 2] = 0xff;
    }
    output.add(frame);
  }
  output.add([0x21, 0xfe]);
  // A valid comment extension makes a small, cheap-to-decode GIF exceed 5 MB.
  for (var size = 0; size < maxAutoplayGridGifBytes + 256; size += 255) {
    output
      ..addByte(255)
      ..add(Uint8List(255));
  }
  output.add([0, 0x3b]);
  return output.takeBytes();
}
