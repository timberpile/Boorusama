import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/ugoira/ugoira_archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final zip = _zip({'000000.jpg': 1, '000001.jpg': 2, '000002.jpg': 3});
  const frames = [
    PixivUgoiraFrame(file: '000002.jpg', delay: 120),
    PixivUgoiraFrame(file: '000000.jpg', delay: 20),
    PixivUgoiraFrame(file: '000001.jpg', delay: 80),
  ];

  test(
    'uses metadata order and variable delays at frame and loop boundaries',
    () {
      final animation = decodePixivUgoiraArchive((zip: zip, frames: frames));

      expect(animation.frames.map((frame) => frame.last), [3, 1, 2]);
      expect(animation.durationMilliseconds, 220);
      expect(
        [0, 119, 120, 139, 140, 219, 220, 560].map(animation.frameAt),
        [0, 0, 1, 1, 2, 2, 0, 1],
      );
    },
  );

  test('rejects missing, duplicate, unsafe, or mistimed frames', () {
    const malformed = [
      PixivUgoiraFrame(file: 'missing.jpg', delay: 10),
      PixivUgoiraFrame(file: '000000.jpg', delay: 10),
      PixivUgoiraFrame(file: '../000002.jpg', delay: 10),
      PixivUgoiraFrame(file: '000002.jpg', delay: 0),
      PixivUgoiraFrame(file: '000002.jpg'),
    ];
    for (final frame in malformed) {
      expect(
        () => decodePixivUgoiraArchive((
          zip: zip,
          frames: [frame, ...frames.skip(1)],
        )),
        throwsFormatException,
      );
    }
  });

  test('rejects unexpected ZIP entries and unsupported image payloads', () {
    expect(
      () => decodePixivUgoiraArchive((
        zip: _zip({'000000.jpg': 1, '../000001.jpg': 2, '000002.jpg': 3}),
        frames: frames,
      )),
      throwsFormatException,
    );
    expect(
      () => decodePixivUgoiraArchive((
        zip: ZipEncoder().encodeBytes(
          Archive()..addFile(ArchiveFile.bytes('000000.jpg', [1, 2, 3])),
        ),
        frames: [frames[1]],
      )),
      throwsFormatException,
    );
  });
}

Uint8List _zip(Map<String, int> values) {
  final archive = Archive();
  for (final entry in values.entries) {
    archive.addFile(
      ArchiveFile.bytes(entry.key, [0xff, 0xd8, 0xff, entry.value]),
    );
  }
  return ZipEncoder().encodeBytes(archive);
}
