import 'package:boorusama/core/posts/shares/src/gif_editor_selection.dart';
import 'package:boorusama/core/posts/shares/src/gif_export_contract.dart';
import 'package:flutter_test/flutter_test.dart';

GifEditorSelection selection({
  double fps = 24,
  int rotation = 0,
  int width = 1440,
  int height = 1080,
  Duration duration = const Duration(seconds: 13),
}) => GifEditorSelection.initial(
  GifSourceMetadata(
    duration: duration,
    complete: true,
    width: width,
    height: height,
    rotationDegrees: rotation,
    sampleAspectRatio: 1,
    frameRate: fps,
  ),
  'video/mp4',
);

void main() {
  test('defaults select the full source at 480 and preserve source frames', () {
    final value = selection();
    expect(value.dimensions, (480, 360));
    expect((value.plan.width, value.plan.height), value.dimensions);
    expect(value.sourceFrameRate, 24);
    expect(value.speed, 1);
    expect(value.duration, const Duration(seconds: 13));
    expect(value.speedChoices.map((e) => e.frameRate), [
      6,
      12,
      18,
      24,
      36,
      48,
      72,
      96,
    ]);
  });
  test('trim handles can extend beyond six seconds to the entire source', () {
    final value = selection()
        .moveEnd(const Duration(seconds: 4))
        .moveEnd(const Duration(seconds: 13));
    expect(value.duration, const Duration(seconds: 13));
    expect(value.plan.duration, value.sourceDuration);
    expect(value.canCreate, isTrue);
    final moved = selection()
        .moveEnd(const Duration(seconds: 6))
        .moveWindow(const Duration(seconds: 7));
    expect(
      moved.moveStart(Duration.zero).duration,
      const Duration(seconds: 13),
    );
    final long = selection(duration: const Duration(hours: 1));
    expect(
      long.moveEnd(long.sourceDuration).plan.duration,
      long.sourceDuration,
    );
  });
  test('window drags preserve duration and clamp to the video', () {
    final value = selection()
        .moveEnd(const Duration(seconds: 6))
        .moveWindow(const Duration(seconds: 11));
    expect(value.start, const Duration(seconds: 7));
    expect(value.end, const Duration(seconds: 13));
    expect(value.moveWindow(const Duration(seconds: -1)).start, Duration.zero);
    final shortened = value.moveStart(const Duration(seconds: 9));
    expect(shortened.duration, const Duration(seconds: 4));
    expect(
      shortened.moveWindow(const Duration(seconds: 2)).end,
      const Duration(seconds: 6),
    );
    expect(
      shortened.moveEnd(const Duration(seconds: 30)).end,
      const Duration(seconds: 13),
    );
    expect(
      shortened.moveStart(const Duration(seconds: 15)).duration,
      GifEditorSelection.minimumWindow,
    );
  });
  test('presets scale both rotated axes and estimate excludes speed', () {
    final value = selection(
      rotation: 90,
    ).copyWith(resolution: GifResolution.px720);
    expect(value.dimensions, (540, 720));
    expect(value.plan.width, 540);
    expect(value.estimatedBytes, 540 * 720 * 312 ~/ 2);
    expect(
      value.copyWith(speedPreset: .5).estimatedBytes,
      value.estimatedBytes,
    );
    expect(
      value.copyWith(sourceFrameRate: 12).estimatedBytes,
      value.estimatedBytes ~/ 2,
    );
  });
  for (final (edge, options, defaultResolution) in [
    (300, [GifResolution.original], GifResolution.original),
    (360, [GifResolution.original], GifResolution.original),
    (
      400,
      [GifResolution.px360, GifResolution.original],
      GifResolution.original,
    ),
    (
      480,
      [GifResolution.px360, GifResolution.original],
      GifResolution.original,
    ),
    (
      640,
      [GifResolution.px360, GifResolution.px480, GifResolution.original],
      GifResolution.px480,
    ),
    (
      720,
      [
        GifResolution.px360,
        GifResolution.px480,
        GifResolution.px640,
        GifResolution.original,
      ],
      GifResolution.px480,
    ),
    (
      1080,
      [
        GifResolution.px360,
        GifResolution.px480,
        GifResolution.px640,
        GifResolution.px720,
        GifResolution.original,
      ],
      GifResolution.px480,
    ),
  ]) {
    test(
      'presets below original $edge never upscale or duplicate Original',
      () {
        final value = selection(width: edge, height: edge ~/ 2);
        expect(value.resolutions, options);
        expect(value.resolution, defaultResolution);
        for (final option in options) {
          final selected = value.copyWith(resolution: option);
          final (w, h) = selected.dimensions;
          expect(w, lessThanOrEqualTo(edge));
          expect(h, lessThanOrEqualTo(edge ~/ 2));
          expect((selected.plan.width, selected.plan.height), (w, h));
        }
      },
    );
  }
  test(
    'low source FPS merges duplicate speed states and keeps the chosen ratio',
    () {
      final value = selection().copyWith(sourceFrameRate: 1, speedPreset: .5);
      expect(value.speedChoices.map((e) => e.frameRate), [1, 2, 3, 4]);
      expect(value.speedIndex, 0);
      expect(value.copyWith(sourceFrameRate: 24).playbackFrameRate, 12);
      expect(
        value.copyWith(sourceFrameRate: 24).outputDuration,
        const Duration(seconds: 26),
      );
    },
  );
  test(
    'fractional native FPS has an original endpoint and integer playback steps',
    () {
      final value = selection(fps: 24000 / 1001);
      expect(value.sourceFrameRates.last, 24000 / 1001);
      expect(value.playbackFrameRate, 24);
      expect(value.copyWith(speedPreset: 4).playbackFrameRate, 95);
      expect(value.speedChoices.length, 8);
    },
  );
  test('high playback rate drops retained images and preserves duration', () {
    final plan = selection(fps: 60).copyWith(speedPreset: 4).plan;
    expect(plan.playbackFrameRate, 240);
    expect(plan.encodedPlaybackFrameRate, 100);
    expect(plan.encodedSourceFrameRate, 25);
    expect(plan.outputDuration, const Duration(milliseconds: 3250));
  });
  test('1280 by 720 retains Original alongside longest-edge presets', () {
    final value = selection(width: 1280, height: 720);
    expect(value.resolutions, [
      GifResolution.px360,
      GifResolution.px480,
      GifResolution.px640,
      GifResolution.px720,
      GifResolution.original,
    ]);
    expect(value.dimensions, (480, 270));
    final original = value.copyWith(resolution: GifResolution.original);
    expect((original.plan.width, original.plan.height), (1280, 720));
    final reduced = value.copyWith(resolution: GifResolution.px720);
    expect((reduced.plan.width, reduced.plan.height), (720, 405));
  });
  test('too few retained frames disable conversion', () {
    final value = selection()
        .moveEnd(const Duration(milliseconds: 200))
        .copyWith(sourceFrameRate: 1);
    expect(value.canCreate, isFalse);
  });
}
