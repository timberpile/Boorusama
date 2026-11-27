import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/videos/player/src/types/local_mp4_playback_compatibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('mp4-check'));
  tearDown(() => dir.delete(recursive: true));

  final start = _fragment(sequence: 1, decodeTime: 0);
  final next = _fragment(sequence: 2, decodeTime: 30_000);
  final fmp4 = [..._initialization(), ...start, ...next];
  final different = [...fmp4]..[fmp4.length - 1] = 4;
  final cases = [
    (
      name: 'two fragmented streams with the same starting timeline',
      bytes: [...fmp4, ...fmp4],
      expected: true,
    ),
    (
      name: 'a restarted stream with different payload bytes',
      bytes: [...fmp4, ...different],
      expected: true,
    ),
    (
      name: 'a restarted stream with additional content after the duplicate',
      bytes: [
        ...fmp4,
        ...fmp4,
        ..._box('free', [1]),
      ],
      expected: true,
    ),
    (
      name: 'a single fragmented stream without a declared duration',
      bytes: fmp4,
      expected: false,
    ),
    (
      name: 'a restart without a second initialization',
      bytes: [...fmp4, ...start],
      expected: false,
    ),
    (
      name: 'a second initialization followed by continuous decode time',
      bytes: [
        ...fmp4,
        ..._initialization(),
        ..._fragment(sequence: 1, decodeTime: 60_000),
      ],
      expected: false,
    ),
    (
      name: 'a second initialization with advancing fragment numbering',
      bytes: [
        ...fmp4,
        ..._initialization(),
        ..._fragment(sequence: 3, decodeTime: 0),
      ],
      expected: false,
    ),
    (
      name: 'a second initialization alone',
      bytes: [...fmp4, ..._initialization()],
      expected: false,
    ),
    (
      name: 'embedded box names and initialization inside media data',
      bytes: [
        ..._initialization(),
        ..._box('mdat', [...fmp4, ...fmp4]),
      ],
      expected: false,
    ),
    (
      name: 'a regular unfragmented MP4',
      bytes: [
        ..._initialization(fragmented: false),
        ..._box('mdat', [3]),
      ],
      expected: false,
    ),
    (
      name: 'a truncated second fragment',
      bytes: [...fmp4, ...fmp4.take(_initialization().length + 12)],
      expected: false,
    ),
    (
      name: 'a scan that would exceed the box budget',
      bytes: [
        ...fmp4,
        for (var i = 0; i < 4096; i++) ..._box('free', []),
        ...fmp4,
      ],
      expected: false,
    ),
  ];
  for (final c in cases) {
    test('classifies ${c.name}', () async {
      final file = await File('${dir.path}/video.mp4').writeAsBytes(c.bytes);
      final timeline = await inspectLocalMp4Timeline(file);
      expect(timeline != null, c.expected);
      expect(
        timeline?.firstStreamLength,
        c.name == cases.first.name ? fmp4.length : null,
      );
      expect(await file.readAsBytes(), c.bytes);
    });
  }

  test('defaults to normal playback if the file cannot be read', () async {
    expect(
      await inspectLocalMp4Timeline(File('${dir.path}/missing.mp4')),
      isNull,
    );
  });

  test('checks the last partial chunk before limiting playback', () async {
    final stream = [...fmp4, ..._box('free', List.filled(65536, 1))];
    final bytes = [...stream, ...stream];
    final file = await File('${dir.path}/large.mp4').writeAsBytes(bytes);
    expect(
      (await inspectLocalMp4Timeline(file))?.firstStreamLength,
      stream.length,
    );
    bytes[bytes.length - 1] = 2;
    await file.writeAsBytes(bytes);
    final timeline = await inspectLocalMp4Timeline(file);
    expect(timeline, isNotNull);
    expect(timeline!.firstStreamLength, isNull);
  });
}

List<int> _initialization({bool fragmented = true}) => [
  ..._box('ftyp', [...'iso5'.codeUnits, ..._u32(512)]),
  ..._box('moov', [
    if (fragmented) ..._box('mvex', _box('trex', List.filled(24, 0))),
  ]),
];

List<int> _fragment({required int sequence, required int decodeTime}) => [
  ..._box('sidx', []),
  ..._box('moof', [
    ..._box('mfhd', [..._u32(0), ..._u32(sequence)]),
    ..._box('traf', [
      ..._box('tfhd', [..._u32(0), ..._u32(1)]),
      ..._box('tfdt', [
        ..._u32(1 << 24),
        ...(ByteData(8)..setUint64(0, decodeTime)).buffer.asUint8List(),
      ]),
    ]),
  ]),
  ..._box('mdat', [1, 2, 3]),
];

List<int> _box(String name, List<int> payload) => [
  ..._u32(payload.length + 8),
  ...name.codeUnits,
  ...payload,
];

Uint8List _u32(int value) =>
    (ByteData(4)..setUint32(0, value)).buffer.asUint8List();
