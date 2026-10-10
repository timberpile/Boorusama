import 'dart:typed_data';

import 'package:boorusama/core/posts/shares/src/gif_loop_refinement.dart';
import 'package:boorusama/core/posts/shares/src/gif_loop_refinement_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts raw original frames and PTS without an fps filter', () {
    const request = GifLoopRequest(start: 85000000, end: 86000000, sourceDuration: 90000000);
    final args = gifLoopDecodeArguments('/cache/source.mp4', '/cache/frame.gray', request);
    expect(args, containsAll(['-copyts', '-start_at_zero', '-fps_mode', 'passthrough']));
    expect(args[args.indexOf('-ss') + 1], '84.650000');
    expect(args[args.indexOf('-t') + 1], '2.050000');
    expect(args[args.indexOf('-vf') + 1], isNot(contains('fps=')));
    expect(args[args.indexOf('-frames:v') + 1], '4501');
  });

  test('integer PTS/time base retains precision lost by pts_time text', () {
    final frames = gifLoopFramesFromOutput(Uint8List(3 * 4096), '''
[Parsed_showinfo_2] config in time_base: 1/90000, frame_rate: 24/1
[Parsed_showinfo_2] n: 0 pts: 7650000 pts_time:85
[Parsed_showinfo_2] n: 1 pts: 7653750 pts_time:85.0417
[Parsed_showinfo_2] n: 2 pts: 7657500 pts_time:85.0833
''');
    expect(frames.timestamps, [85000000, 85041667, 85083333]);
  });

  test('missing logs, partial bytes, duplicate PTS and changing time bases fail', () {
    expect(() => gifLoopFramesFromOutput(Uint8List(4097), ''), throwsFormatException);
    expect(() => gifLoopFramesFromOutput(Uint8List(4096), ''), throwsFormatException);
    expect(() => gifLoopFramesFromOutput(Uint8List(8192), '''
config in time_base: 1/1000
n: 0 pts: 50 pts_time:0.05
n: 1 pts: 50 pts_time:0.05
'''), throwsFormatException);
    expect(() => gifLoopFramesFromOutput(Uint8List(4096), '''
config in time_base: 1/1000
config in time_base: 1/90000
n: 0 pts: 0 pts_time:0
'''), throwsFormatException);
  });

  test('overflow frame is a hard budget failure', () {
    expect(() => gifLoopFramesFromOutput(Uint8List(4501 * 4096), ''),
        throwsA(isA<GifLoopBudgetException>()));
  });
}
