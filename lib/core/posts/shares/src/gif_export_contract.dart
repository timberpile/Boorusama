import 'dart:math' as math;

import 'package:dio/dio.dart';

enum GifResolution {
  px360(360),
  px480(480),
  px640(640),
  px720(720),
  original(null);

  const GifResolution(this.longestEdge);
  final int? longestEdge;
}

enum GifFrameRate { fps10, fps12, fps15, original }

enum GifConversionFailure {
  encoderUnavailable,
  unsupportedSource,
  incomplete,
  durationUnknown,
  invalidDimensions,
  frameRateUnknown,
  invalidTrim,
  cancelled,
  oversized,
  invalidOutput,
  network,
  authentication,
  storage,
  encoder,
}

class GifConversionException implements Exception {
  const GifConversionException(
    this.failure, {
    this.cleanupErrors = const [],
    this.cause,
    this.stage,
  });

  final GifConversionFailure failure;
  final List<Object> cleanupErrors;
  final Object? cause;
  final GifConversionStage? stage;
}

class GifSourceMetadata {
  const GifSourceMetadata({
    required this.duration,
    required this.complete,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.sampleAspectRatio,
    required this.frameRate,
  });

  final Duration? duration;
  final bool complete;
  final int? width;
  final int? height;
  final int? rotationDegrees;
  final double? sampleAspectRatio;
  final double? frameRate;
}

class GifExportSettings {
  const GifExportSettings({
    required this.start,
    required this.duration,
    required this.resolution,
    required this.frameRate,
    this.resolutionPercent,
    this.sourceFrameRate,
    this.playbackFrameRate,
  });

  final Duration start;
  final Duration duration;
  final GifResolution resolution;
  final GifFrameRate frameRate;
  final int? resolutionPercent;
  final double? sourceFrameRate;
  final int? playbackFrameRate;
}

class GifExportPlan {
  const GifExportPlan({
    required this.start,
    required this.duration,
    required this.width,
    required this.height,
    required this.frameRate,
    required this.rotationDegrees,
    required this.sampleAspectRatio,
    double? playbackFrameRate,
  }) : _playbackFrameRate = playbackFrameRate;

  factory GifExportPlan.fromSource(
    GifSourceMetadata source, {
    required String mimeType,
    GifExportSettings? settings,
    Duration? playbackPosition,
  }) {
    if (mimeType != 'video/mp4' && mimeType != 'video/webm') {
      throw const GifConversionException(
        GifConversionFailure.unsupportedSource,
      );
    }
    if (!source.complete) {
      throw const GifConversionException(GifConversionFailure.incomplete);
    }
    final sourceDuration = source.duration;
    if (sourceDuration == null || sourceDuration <= Duration.zero) {
      throw const GifConversionException(GifConversionFailure.durationUnknown);
    }
    final sourceWidth = source.width;
    final sourceHeight = source.height;
    final rotation = source.rotationDegrees;
    final sampleAspectRatio = source.sampleAspectRatio;
    if (sourceWidth == null ||
        sourceWidth <= 0 ||
        sourceHeight == null ||
        sourceHeight <= 0 ||
        sourceWidth > maxFramePixels ~/ sourceHeight ||
        sampleAspectRatio == null ||
        !sampleAspectRatio.isFinite ||
        sampleAspectRatio <= 0 ||
        rotation == null ||
        !{0, 90, 180, 270}.contains(rotation)) {
      throw const GifConversionException(
        GifConversionFailure.invalidDimensions,
      );
    }

    final defaultStart = switch (playbackPosition) {
      final position?
          when position >= Duration.zero && position < sourceDuration =>
        position,
      _ => Duration.zero,
    };
    final selected =
        settings ??
        GifExportSettings(
          start: defaultStart,
          duration: sourceDuration - defaultStart,
          resolution: GifResolution.px480,
          frameRate: GifFrameRate.fps12,
        );
    if (selected.start < Duration.zero ||
        selected.duration <= Duration.zero ||
        selected.start >= sourceDuration ||
        selected.duration > sourceDuration - selected.start) {
      throw const GifConversionException(GifConversionFailure.invalidTrim);
    }

    final displayWidth = rotation == 90 || rotation == 270
        ? sourceHeight.toDouble()
        : sourceWidth * sampleAspectRatio;
    final displayHeight = rotation == 90 || rotation == 270
        ? sourceWidth * sampleAspectRatio
        : sourceHeight.toDouble();
    if (!displayWidth.isFinite || !displayHeight.isFinite) {
      throw const GifConversionException(
        GifConversionFailure.invalidDimensions,
      );
    }
    final longestSide =
        selected.resolution.longestEdge?.toDouble() ??
        math.max(displayWidth, displayHeight);
    final originalLongestSide = math.max(displayWidth, displayHeight);
    if (selected.resolution == GifResolution.original &&
        (displayWidth > maxGifEdge || displayHeight > maxGifEdge)) {
      throw const GifConversionException(
        GifConversionFailure.invalidDimensions,
      );
    }
    final percentage = selected.resolutionPercent;
    if (percentage != null && !{25, 50, 75, 100}.contains(percentage)) {
      throw const GifConversionException(
        GifConversionFailure.invalidDimensions,
      );
    }
    final width = percentage != null
        ? (displayWidth * percentage / 100).round()
        : selected.resolution == GifResolution.original
        ? displayWidth.round()
        : (displayWidth / originalLongestSide * longestSide).round();
    final height = percentage != null
        ? (displayHeight * percentage / 100).round()
        : selected.resolution == GifResolution.original
        ? displayHeight.round()
        : (displayHeight / originalLongestSide * longestSide).round();
    if (width <= 0 ||
        height <= 0 ||
        width > maxGifEdge ||
        height > maxGifEdge ||
        width > maxFramePixels ~/ height) {
      throw const GifConversionException(
        GifConversionFailure.invalidDimensions,
      );
    }
    final frameRate =
        selected.sourceFrameRate ??
        switch (selected.frameRate) {
          GifFrameRate.fps10 => 10.0,
          GifFrameRate.fps12 => 12.0,
          GifFrameRate.fps15 => 15.0,
          GifFrameRate.original => source.frameRate,
        };
    if (frameRate == null ||
        !frameRate.isFinite ||
        frameRate < minOriginalFrameRate ||
        frameRate > maxOriginalFrameRate) {
      throw const GifConversionException(
        GifConversionFailure.frameRateUnknown,
      );
    }
    if (selected.sourceFrameRate != null &&
        (source.frameRate == null ||
            !source.frameRate!.isFinite ||
            frameRate > source.frameRate!)) {
      throw const GifConversionException(GifConversionFailure.frameRateUnknown);
    }
    final playbackRate = selected.playbackFrameRate?.toDouble() ?? frameRate;
    if (playbackRate < 1 || playbackRate > frameRate * 4) {
      throw const GifConversionException(GifConversionFailure.invalidTrim);
    }
    // Above 100 playback FPS, retain fewer images while preserving the speed:
    // GIF cannot represent a positive frame delay shorter than 10 ms.
    final encodedSamplingRate =
        math.min(playbackRate, 100) * frameRate / playbackRate;
    if (selected.duration.inMicroseconds * encodedSamplingRate <
        2 * Duration.microsecondsPerSecond) {
      throw const GifConversionException(GifConversionFailure.invalidTrim);
    }
    return GifExportPlan(
      start: selected.start,
      duration: selected.duration,
      width: width,
      height: height,
      frameRate: frameRate,
      rotationDegrees: rotation,
      sampleAspectRatio: sampleAspectRatio,
      playbackFrameRate: playbackRate,
    );
  }

  static const minOriginalFrameRate = 1.0;
  static const maxOriginalFrameRate = 100.0;
  static const maxGifEdge = 65535;
  static const maxFramePixels = 3840 * 2160;
  static const maxWorkingBytes = 160 * 1000 * 1000;
  static const targetOutputBytes = 15 * 1000 * 1000;
  static const maxOutputBytes = 100 * 1000 * 1000;

  final Duration start;
  final Duration duration;
  final int width;
  final int height;
  final double frameRate;
  final int rotationDegrees;
  final double sampleAspectRatio;
  final double? _playbackFrameRate;

  double get playbackFrameRate => _playbackFrameRate ?? frameRate;
  double get speed => playbackFrameRate / frameRate;
  double get encodedPlaybackFrameRate => math.min(100, playbackFrameRate);
  double get encodedSourceFrameRate => encodedPlaybackFrameRate / speed;
  Duration get outputDuration => Duration(
    microseconds: (duration.inMicroseconds / speed).round(),
  );
}

enum GifConversionStage { downloading, inspecting, encoding, checking }

class GifConversionProgress {
  const GifConversionProgress(this.stage, this.fraction);

  final GifConversionStage stage;
  final double? fraction;
}

class GifEncodeRequest {
  const GifEncodeRequest({
    required this.sourcePath,
    required this.outputPath,
    required this.plan,
  });

  final String sourcePath;
  final String outputPath;
  final GifExportPlan plan;
  int get maxWorkingBytes => GifExportPlan.maxWorkingBytes;
  int get maxOutputBytes => GifExportPlan.maxOutputBytes;
}

class GifOutputValidation {
  const GifOutputValidation({
    required this.fullDecodeSucceeded,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.allFramesMatchCanvas,
    required this.frameCount,
    required this.frameDelayCentiseconds,
    required this.infiniteLoop,
  });

  final bool fullDecodeSucceeded;
  final int? canvasWidth;
  final int? canvasHeight;
  final bool allFramesMatchCanvas;
  final int? frameCount;
  final List<int>? frameDelayCentiseconds;
  final bool? infiniteLoop;
}

abstract interface class GifEncoderBackend {
  Future<GifSourceMetadata> inspect(
    String sourcePath, {
    required CancelToken cancelToken,
  });

  // Completion means all writers are closed. The backend must honor the
  // request's working/output budgets and apply plan.rotationDegrees.
  Future<void> encode(
    GifEncodeRequest request, {
    required CancelToken cancelToken,
    void Function(double? fraction)? onProgress,
  });

  // Read-only. A production adapter must decode every frame of outputPath and
  // report observed canvas, frame delays, and explicit infinite-loop metadata.
  Future<GifOutputValidation> validateOutput(
    GifEncodeRequest request, {
    required CancelToken cancelToken,
  });
}

abstract interface class GifTimelineBackend {
  Future<void> createTimeline({
    required String sourcePath,
    required String outputPath,
    required Duration duration,
    required CancelToken cancelToken,
  });
}
