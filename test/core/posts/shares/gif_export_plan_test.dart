import 'package:boorusama/core/posts/shares/src/gif_export_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const complete = GifSourceMetadata(
    duration: Duration(seconds: 30),
    complete: true,
    width: 1920,
    height: 1080,
    rotationDegrees: 90,
    sampleAspectRatio: 1,
    frameRate: 29.97,
  );

  test(
    'a complete 30-second source uses the playback position and defaults',
    () {
      final plan = GifExportPlan.fromSource(
        complete,
        mimeType: 'video/mp4',
        playbackPosition: const Duration(seconds: 27),
      );

      expect(plan.start, const Duration(seconds: 27));
      expect(plan.duration, const Duration(seconds: 3));
      expect(plan.width, 270);
      expect(plan.height, 480);
      expect(plan.frameRate, 12);
      expect(plan.rotationDegrees, 90);
    },
  );

  test('default export covers the full source without an explicit trim', () {
    final plan = GifExportPlan.fromSource(complete, mimeType: 'video/mp4');
    expect(plan.start, Duration.zero);
    expect(plan.duration, complete.duration);
  });

  final rejected = [
    (
      'an unknown-duration video',
      const GifSourceMetadata(
        duration: null,
        complete: true,
        width: 100,
        height: 100,
        rotationDegrees: 0,
        sampleAspectRatio: 1,
        frameRate: 24,
      ),
      'video/mp4',
      GifConversionFailure.durationUnknown,
    ),
    (
      'an incomplete video',
      const GifSourceMetadata(
        duration: Duration(seconds: 20),
        complete: false,
        width: 100,
        height: 100,
        rotationDegrees: 0,
        sampleAspectRatio: 1,
        frameRate: 24,
      ),
      'video/mp4',
      GifConversionFailure.incomplete,
    ),
    (
      'an unsupported video container',
      complete,
      'video/quicktime',
      GifConversionFailure.unsupportedSource,
    ),
  ];
  for (final (description, source, mimeType, failure) in rejected) {
    test('$description cannot be converted', () {
      expect(
        () => GifExportPlan.fromSource(source, mimeType: mimeType),
        throwsA(
          isA<GifConversionException>().having(
            (e) => e.failure,
            'failure',
            failure,
          ),
        ),
      );
    });
  }

  test(
    'Original resolution accounts for rotation independently of fixed FPS',
    () {
      final plan = GifExportPlan.fromSource(
        complete,
        mimeType: 'video/webm',
        settings: const GifExportSettings(
          start: Duration(seconds: 2),
          duration: Duration(seconds: 4),
          resolution: GifResolution.original,
          frameRate: GifFrameRate.fps15,
        ),
      );

      expect((plan.width, plan.height, plan.frameRate), (1080, 1920, 15));
    },
  );

  test('Original FPS uses decoder metadata and rejects unknown FPS', () {
    const settings = GifExportSettings(
      start: Duration.zero,
      duration: Duration(seconds: 6),
      resolution: GifResolution.px360,
      frameRate: GifFrameRate.original,
    );
    final resolved = GifExportPlan.fromSource(
      complete,
      mimeType: 'video/mp4',
      settings: settings,
    );
    expect(resolved.frameRate, 29.97);
    expect(resolved.width, 203);
    expect(resolved.height, 360);

    expect(
      () => GifExportPlan.fromSource(
        const GifSourceMetadata(
          duration: Duration(seconds: 30),
          complete: true,
          width: 1920,
          height: 1080,
          rotationDegrees: 0,
          sampleAspectRatio: 1,
          frameRate: null,
        ),
        mimeType: 'video/mp4',
        settings: settings,
      ),
      throwsA(
        isA<GifConversionException>().having(
          (e) => e.failure,
          'failure',
          GifConversionFailure.frameRateUnknown,
        ),
      ),
    );
  });

  final unsafeFrameRates = [
    0.0,
    -1.0,
    0.5,
    double.nan,
    double.infinity,
    101.0,
    1e9,
  ];
  for (final value in unsafeFrameRates) {
    test('unsafe Original FPS $value is unavailable while fixed FPS works', () {
      final source = GifSourceMetadata(
        duration: const Duration(seconds: 30),
        complete: true,
        width: 1920,
        height: 1080,
        rotationDegrees: 0,
        sampleAspectRatio: 1,
        frameRate: value,
      );
      const original = GifExportSettings(
        start: Duration.zero,
        duration: Duration(seconds: 6),
        resolution: GifResolution.px480,
        frameRate: GifFrameRate.original,
      );
      const fixed = GifExportSettings(
        start: Duration.zero,
        duration: Duration(seconds: 6),
        resolution: GifResolution.px480,
        frameRate: GifFrameRate.fps12,
      );

      expect(
        () => GifExportPlan.fromSource(
          source,
          mimeType: 'video/mp4',
          settings: original,
        ),
        throwsA(
          isA<GifConversionException>().having(
            (e) => e.failure,
            'failure',
            GifConversionFailure.frameRateUnknown,
          ),
        ),
      );
      expect(
        GifExportPlan.fromSource(
          source,
          mimeType: 'video/mp4',
          settings: fixed,
        ).frameRate,
        12,
      );
    });
  }

  for (final value in [1.0, 100.0]) {
    test('Original FPS $value remains available at the safe boundary', () {
      final plan = GifExportPlan.fromSource(
        GifSourceMetadata(
          duration: const Duration(seconds: 30),
          complete: true,
          width: 1920,
          height: 1080,
          rotationDegrees: 0,
          sampleAspectRatio: 1,
          frameRate: value,
        ),
        mimeType: 'video/mp4',
        settings: const GifExportSettings(
          start: Duration.zero,
          duration: Duration(seconds: 6),
          resolution: GifResolution.px480,
          frameRate: GifFrameRate.original,
        ),
      );

      expect(plan.frameRate, value);
    });
  }

  test('trim cannot exceed the complete source duration', () {
    expect(
      () => GifExportPlan.fromSource(
        complete,
        mimeType: 'video/mp4',
        settings: const GifExportSettings(
          start: Duration(seconds: 29),
          duration: Duration(seconds: 2),
          resolution: GifResolution.px480,
          frameRate: GifFrameRate.fps12,
        ),
      ),
      throwsA(
        isA<GifConversionException>().having(
          (e) => e.failure,
          'failure',
          GifConversionFailure.invalidTrim,
        ),
      ),
    );
  });

  for (final duration in [
    const Duration(seconds: 6),
    const Duration(seconds: 6, microseconds: 1),
    const Duration(seconds: 30),
    const Duration(minutes: 5),
    const Duration(hours: 1),
  ]) {
    test(
      'a full $duration video has no source or selected-clip duration cap',
      () {
        final source = GifSourceMetadata(
          duration: duration,
          complete: true,
          width: 160,
          height: 90,
          rotationDegrees: 0,
          sampleAspectRatio: 1,
          frameRate: 12,
        );
        final plan = GifExportPlan.fromSource(
          source,
          mimeType: 'video/mp4',
          settings: GifExportSettings(
            start: Duration.zero,
            duration: duration,
            resolution: GifResolution.original,
            frameRate: GifFrameRate.original,
          ),
        );
        expect(plan.duration, duration);
      },
    );
  }

  test(
    'fixed output rejects an aspect ratio that would round a side to zero',
    () {
      expect(
        () => GifExportPlan.fromSource(
          const GifSourceMetadata(
            duration: Duration(seconds: 10),
            complete: true,
            width: 1,
            height: 100000,
            rotationDegrees: 0,
            sampleAspectRatio: 1,
            frameRate: 24,
          ),
          mimeType: 'video/mp4',
        ),
        throwsA(
          isA<GifConversionException>().having(
            (e) => e.failure,
            'failure',
            GifConversionFailure.invalidDimensions,
          ),
        ),
      );
    },
  );

  test('Original output rejects dimensions beyond the GIF canvas limit', () {
    expect(
      () => GifExportPlan.fromSource(
        const GifSourceMetadata(
          duration: Duration(seconds: 10),
          complete: true,
          width: 70000,
          height: 100,
          rotationDegrees: 0,
          sampleAspectRatio: 1,
          frameRate: 24,
        ),
        mimeType: 'video/mp4',
        settings: const GifExportSettings(
          start: Duration.zero,
          duration: Duration(seconds: 5),
          resolution: GifResolution.original,
          frameRate: GifFrameRate.fps12,
        ),
      ),
      throwsA(
        isA<GifConversionException>().having(
          (e) => e.failure,
          'failure',
          GifConversionFailure.invalidDimensions,
        ),
      ),
    );
  });

  test('extreme pixel aspect is rejected as invalid dimensions', () {
    expect(
      () => GifExportPlan.fromSource(
        const GifSourceMetadata(
          duration: Duration(seconds: 10),
          complete: true,
          width: 720,
          height: 480,
          rotationDegrees: 0,
          sampleAspectRatio: 1e305,
          frameRate: 24,
        ),
        mimeType: 'video/mp4',
      ),
      throwsA(
        isA<GifConversionException>().having(
          (e) => e.failure,
          'failure',
          GifConversionFailure.invalidDimensions,
        ),
      ),
    );
  });

  test('non-square pixels preserve display aspect after rotation', () {
    final plan = GifExportPlan.fromSource(
      const GifSourceMetadata(
        duration: Duration(seconds: 10),
        complete: true,
        width: 720,
        height: 480,
        rotationDegrees: 90,
        sampleAspectRatio: 2,
        frameRate: 24,
      ),
      mimeType: 'video/mp4',
    );

    expect((plan.width, plan.height, plan.rotationDegrees), (160, 480, 90));
    expect(plan.sampleAspectRatio, 2);
  });

  for (final source in [
    const GifSourceMetadata(
      duration: Duration(seconds: 10),
      complete: true,
      width: 3841,
      height: 2160,
      rotationDegrees: 0,
      sampleAspectRatio: 1,
      frameRate: 24,
    ),
    const GifSourceMetadata(
      duration: Duration(seconds: 10),
      complete: true,
      width: 65535,
      height: 65535,
      rotationDegrees: 0,
      sampleAspectRatio: 1,
      frameRate: 24,
    ),
  ]) {
    test(
      'source ${source.width}x${source.height} exceeds the decode budget',
      () {
        expect(
          () => GifExportPlan.fromSource(source, mimeType: 'video/mp4'),
          throwsA(
            isA<GifConversionException>().having(
              (e) => e.failure,
              'failure',
              GifConversionFailure.invalidDimensions,
            ),
          ),
        );
      },
    );
  }

  test('a 3840x2160 Original canvas fits the provisional frame budget', () {
    final plan = GifExportPlan.fromSource(
      const GifSourceMetadata(
        duration: Duration(seconds: 10),
        complete: true,
        width: 3840,
        height: 2160,
        rotationDegrees: 270,
        sampleAspectRatio: 1,
        frameRate: 24,
      ),
      mimeType: 'video/mp4',
      settings: const GifExportSettings(
        start: Duration.zero,
        duration: Duration(seconds: 6),
        resolution: GifResolution.original,
        frameRate: GifFrameRate.fps12,
      ),
    );

    expect((plan.width, plan.height, plan.rotationDegrees), (2160, 3840, 270));
  });

  const oneFpsSource = GifSourceMetadata(
    duration: Duration(seconds: 30),
    complete: true,
    width: 720,
    height: 480,
    rotationDegrees: 0,
    sampleAspectRatio: 1,
    frameRate: 1,
  );
  for (final duration in [
    const Duration(seconds: 1),
    const Duration(seconds: 1, microseconds: 999999),
  ]) {
    test('a 1 FPS trim of $duration cannot support two frames', () {
      expect(
        () => GifExportPlan.fromSource(
          oneFpsSource,
          mimeType: 'video/mp4',
          settings: GifExportSettings(
            start: Duration.zero,
            duration: duration,
            resolution: GifResolution.px480,
            frameRate: GifFrameRate.original,
          ),
        ),
        throwsA(
          isA<GifConversionException>().having(
            (e) => e.failure,
            'failure',
            GifConversionFailure.invalidTrim,
          ),
        ),
      );
    });
  }

  test('a two-second trim at 1 FPS is the inclusive animation boundary', () {
    final plan = GifExportPlan.fromSource(
      oneFpsSource,
      mimeType: 'video/mp4',
      settings: const GifExportSettings(
        start: Duration.zero,
        duration: Duration(seconds: 2),
        resolution: GifResolution.px480,
        frameRate: GifFrameRate.original,
      ),
    );

    expect((plan.duration, plan.frameRate), (const Duration(seconds: 2), 1));
  });
}
