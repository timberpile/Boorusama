import 'package:boorusama/core/posts/shares/src/gif_loop_frame_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wraps directly to the first VFR frame without an extra end hold', () {
    final clock = GifLoopFrameClock([0, 40000, 110000], 200000);
    expect(clock.frameAt(39999), 0);
    expect(clock.frameAt(40000), 1);
    expect(clock.frameAt(199999), 2);
    expect(clock.frameAt(200000), 0);
    expect(clock.frameAt(440000), 1);
  });

  test('rejects mismatched or non-monotonic presentation timestamps', () {
    expect(() => GifLoopFrameClock([0, 0], 100000), throwsFormatException);
    expect(() => GifLoopFrameClock([0, 200000], 100000), throwsFormatException);
    expect(() => GifLoopFrameClock([], 100000), throwsFormatException);
  });
}
