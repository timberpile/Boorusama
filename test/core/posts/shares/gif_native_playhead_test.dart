import 'package:boorusama/core/posts/shares/src/gif_native_playhead.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'coarse source samples animate each frame and honor speed/pause',
    (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      final positions = <Duration>[];
      final playhead = GifNativePlayhead(
        onPosition: positions.add,
        start: Duration.zero,
        end: const Duration(seconds: 1),
        speed: 1,
      );
      playhead.sample(Duration.zero);
      playhead.setPlaying(true);
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(positions.length, greaterThan(10));
      expect(positions.last.inMilliseconds, 192);
      playhead.sample(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 16));
      expect(positions.last.inMilliseconds, 216);
      playhead.configure(
        start: Duration.zero,
        end: const Duration(seconds: 1),
        speed: .5,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(positions.last.inMilliseconds, 266);
      playhead.setPlaying(false);
      final held = positions.last;
      final count = positions.length;
      await tester.pump(const Duration(milliseconds: 300));
      expect(positions.last, held);
      expect(positions.length, count);
      playhead.sample(const Duration(milliseconds: 700));
      expect(positions.last.inMilliseconds, 700);
      playhead.setPlaying(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(positions.last.inMilliseconds, 750);
      playhead.dispose();
    },
  );

  testWidgets(
    'buffering holds; wraps and seeks use native samples; extrapolation is bounded',
    (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      final positions = <Duration>[];
      final playhead = GifNativePlayhead(
        onPosition: positions.add,
        start: Duration.zero,
        end: const Duration(seconds: 1),
        speed: 1,
      );
      playhead.sample(const Duration(milliseconds: 800));
      playhead.setPlaying(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(positions.last.inMicroseconds, 999999);
      playhead.sample(Duration.zero);
      expect(positions.last, Duration.zero);
      await tester.pump(const Duration(milliseconds: 100));
      playhead.setBuffering(true);
      final count = positions.length;
      await tester.pump(const Duration(milliseconds: 200));
      expect(positions.length, count);
      expect(positions.last.inMilliseconds, 100);
      playhead.setBuffering(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(positions.last.inMilliseconds, 116);
      playhead.sample(const Duration(milliseconds: 200));
      await tester.pump(const Duration(seconds: 2));
      expect(positions.last.inMilliseconds, 600);
      playhead.configure(
        start: const Duration(milliseconds: 700),
        end: const Duration(seconds: 1),
        speed: 1,
      );
      playhead.sample(const Duration(milliseconds: 400));
      expect(positions.last.inMilliseconds, 700);
      playhead.dispose();
      final disposedCount = positions.length;
      await tester.pump(const Duration(milliseconds: 50));
      expect(positions.length, disposedCount);
    },
  );
}
