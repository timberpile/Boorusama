import 'package:boorusama/core/posts/shares/src/gif_loop_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

const _vfrLog = '''
[Parsed_showinfo_3] config in time_base: 1/90000, frame_rate: 30/1
[Parsed_showinfo_3] n: 0 pts: 90000 pts_time:1
[Parsed_showinfo_3] n: 1 pts: 93003 pts_time:1.03337
[Parsed_showinfo_3] n: 2 pts: 99000 pts_time:1.1
''';

void main() {
  test('preview extraction keeps integer PTS including variable intervals', () {
    expect(gifLoopBufferTimestamps(_vfrLog, 3), [1000000, 1033367, 1100000]);
  });

  test('missing and out-of-order PTS are rejected rather than guessed', () {
    expect(() => gifLoopBufferTimestamps(_vfrLog, 2), throwsFormatException);
    expect(
      () => gifLoopBufferTimestamps(_vfrLog.replaceFirst('n: 1', 'n: 2'), 3),
      throwsFormatException,
    );
    expect(
      () => gifLoopBufferTimestamps(
        _vfrLog.replaceFirst('pts: 93003', 'pts: 90000'),
        3,
      ),
      throwsFormatException,
    );
  });

  test(
    'preview decoding is local, regional, bounded, and does not change FPS',
    () {
      final arguments = gifLoopBufferArguments(
        '/cache/source.mp4',
        '/cache/frames.rgba',
        const Duration(seconds: 40),
        const Duration(seconds: 42),
        160,
        90,
      );
      expect(arguments[arguments.indexOf('-ss') + 1], '40.000000');
      expect(arguments[arguments.indexOf('-t') + 1], '2.000000');
      expect(
        arguments[arguments.indexOf('-vf') + 1],
        'trim=start=40.000000:end=42.000000,scale=160:90:flags=area,format=rgba,showinfo=checksum=0',
      );
      expect(
        arguments,
        containsAll(['-copyts', '-start_at_zero', 'passthrough']),
      );
      expect(arguments[arguments.indexOf('-frames:v') + 1], '601');
      expect(
        arguments[arguments.indexOf('-fs') + 1],
        '${24 * 1024 * 1024 + 1}',
      );
      expect(arguments.any((value) => value.contains('fps=')), isFalse);
    },
  );
}
