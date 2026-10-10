import 'dart:typed_data';

import 'package:boorusama/core/posts/shares/src/gif_loop_refinement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GifLoopFrames frames(List<int> values, {int interval = 100000}) => GifLoopFrames(
    pixels: Uint8List.fromList(values),
    timestamps: [for (var i = 0; i < values.length; i++) i * interval],
    pixelsPerFrame: 1,
  );
  GifLoopRequest request(int start, int end, {int duration = 3000000}) =>
      GifLoopRequest(start: start, end: end, sourceDuration: duration);

  test('radius is proportional, capped, and has no six-second trim limit', () {
    expect(request(0, 500000).radius, 125000);
    expect(request(0, 1000000).radius, 250000);
    expect(request(0, 5000000, duration: 6000000).radius, 350000);
    expect(request(0, 8000000, duration: 9000000).isValid, isTrue);
  });

  test('full source is hidden, either shortened boundary enables refinement', () {
    expect(request(0, 3000000).isFullSource, isTrue);
    expect(request(10000, 3000000).isFullSource, isFalse);
    expect(request(0, 2990000).isFullSource, isFalse);
    expect(request(0, 2999999).isFullSource, isTrue);
  });

  test('uses a verified sequence to recover both exact frame boundaries', () {
    final data = frames(List.generate(30, (i) => [0, 40, 80, 120, 160, 200, 160, 120, 80, 40][i % 10]));
    final input = request(17000, 1030000);
    final result = refineGifLoop(data, input);
    expect(result.kind, GifLoopMatchKind.repeatedSequence);
    expect(result.start, 0);
    expect(result.end, 1000000);
    expect((result.start! - input.start).abs(), lessThanOrEqualTo(input.radius));
    expect((result.end! - input.end).abs(), lessThanOrEqualTo(input.radius));
  });

  test('a static clip never supplies a reliable match', () {
    expect(
      refineGifLoop(frames(List.filled(30, 42)), request(0, 1000000)).matched,
      isFalse,
    );
  });

  test('matching boundary poses cannot override contradicting following frames', () {
    final data = frames([0, 100, 200, 50, 150, 0, 210, 50, 220, 80,
      190, 40, 120, 220, 30, 160, 90, 200, 40, 130]);
    final result = refineGifLoop(data, request(0, 500000, duration: 2000000));
    expect(result.kind, GifLoopMatchKind.none);
  });

  test('single cycle at source end may produce a seam hint, never repetition', () {
    final data = frames([0, 50, 100, 150, 100, 50, 0]);
    final result = refineGifLoop(data, request(0, 690000, duration: 700000));
    expect(result.kind, GifLoopMatchKind.seamOnly);
    expect(result.end, 700000);
  });

  test('variable presentation timestamps are retained without index/FPS mapping', () {
    final cycle = [0, 40000, 100000, 170000, 230000, 320000, 410000, 500000];
    final data = GifLoopFrames(
      pixels: Uint8List.fromList([
        for (var repeat = 0; repeat < 3; repeat++)
          for (var i = 0; i < cycle.length; i++) i * 28,
      ]),
      timestamps: [
        for (var repeat = 0; repeat < 3; repeat++)
          for (final stamp in cycle) repeat * 600000 + stamp,
      ],
      pixelsPerFrame: 1,
    );
    final result = refineGifLoop(data, request(5000, 615000, duration: 1800000));
    expect(result.kind, GifLoopMatchKind.repeatedSequence);
    expect(result.end! - result.start!, 600000);
    expect(data.timestamps, contains(result.start));
    expect(data.timestamps, contains(result.end));
  });

  test('invalid or non-monotonic PTS fails without guessing', () {
    final data = GifLoopFrames(
      pixels: Uint8List.fromList([0, 100, 0]),
      timestamps: [0, 100000, 100000],
      pixelsPerFrame: 1,
    );
    expect(refineGifLoop(data, request(0, 500000)).reason,
        GifLoopNoMatchReason.invalidFrames);
  });

  test('a truncated decode cannot be used as a fake end-of-source seam', () {
    final data = frames([0, 50, 100, 150, 100, 50, 0]);
    final result = refineGifLoop(data, request(0, 600000, duration: 5000000));
    expect(result.matched, isFalse);
  });

  test('selection near the end of a long video remains source-relative', () {
    final data = frames(List.generate(30, (i) => [0, 40, 80, 120, 160, 200, 160, 120, 80, 40][i % 10]));
    final offset = 85000000;
    final shifted = GifLoopFrames(
      pixels: data.pixels,
      timestamps: data.timestamps.map((t) => t + offset).toList(),
      pixelsPerFrame: 1,
    );
    final result = refineGifLoop(
      shifted, request(offset + 10000, offset + 1020000, duration: 88000000),
    );
    expect(result.kind, GifLoopMatchKind.repeatedSequence);
    expect(result.start, offset);
    expect(result.end, offset + 1000000);
  });

  test('high-motion context cannot relax a quiet candidate seam', () {
    final data = frames([0, 255, 0, 255, 0, 3, 6, 9, 12, 15]);
    final result = refineGifLoop(data, request(500000, 990000, duration: 1000000));
    expect(result.matched, isFalse);
  });

  test('comparison budget aborts instead of returning a biased partial winner', () {
    final result = refineGifLoop(
      frames(List.generate(30, (i) => [0, 40, 80, 120, 160, 200, 160, 120, 80, 40][i % 10])),
      request(0, 1000000),
      maximumComparisons: 1,
    );
    expect(result.matched, isFalse);
    expect(result.reason, GifLoopNoMatchReason.budget);
  });
}
