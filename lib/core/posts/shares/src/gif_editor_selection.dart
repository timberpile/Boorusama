import 'dart:math' as math;

import 'gif_export_contract.dart';

class GifSpeedChoice {
  const GifSpeedChoice(this.ratio, this.frameRate);
  final double ratio;
  final int frameRate;
}

class GifEditorSelection {
  const GifEditorSelection({
    required this.source,
    required this.mimeType,
    required this.start,
    required this.end,
    required this.sourceFrameRate,
    this.resolution = GifResolution.original,
    this.speedPreset = 1,
  });

  factory GifEditorSelection.initial(
    GifSourceMetadata source,
    String mimeType,
  ) {
    final plan = GifExportPlan.fromSource(
      source,
      mimeType: mimeType,
      settings: GifExportSettings(
        start: Duration.zero,
        duration: source.duration ?? Duration.zero,
        resolution: GifResolution.original,
        frameRate: GifFrameRate.original,
      ),
    );
    return GifEditorSelection(
      source: source,
      mimeType: mimeType,
      start: Duration.zero,
      end: plan.duration,
      sourceFrameRate: plan.frameRate,
      resolution: math.max(plan.width, plan.height) > 480
          ? GifResolution.px480
          : GifResolution.original,
    );
  }

  final GifSourceMetadata source;
  final String mimeType;
  final Duration start;
  final Duration end;
  final double sourceFrameRate;
  final GifResolution resolution;
  final double speedPreset;

  static const speedRatios = [.25, .5, .75, 1.0, 1.5, 2.0, 3.0, 4.0];
  static const minimumWindow = Duration(milliseconds: 200);
  Duration get _minimumDuration => Duration(
    microseconds: math.min(
      minimumWindow.inMicroseconds,
      sourceDuration.inMicroseconds,
    ),
  );
  Duration get duration => end - start;
  Duration get sourceDuration => source.duration!;
  List<double> get sourceFrameRates => [
    for (var i = 1; i <= source.frameRate!.floor(); i++) i.toDouble(),
    if (source.frameRate! != source.frameRate!.floor()) source.frameRate!,
  ];

  List<GifSpeedChoice> get speedChoices {
    final choices = <int, GifSpeedChoice>{};
    for (final ratio in speedRatios) {
      final fps = (sourceFrameRate * ratio).round().clamp(
        1,
        (sourceFrameRate * 4).floor(),
      );
      final previous = choices[fps];
      if (previous == null ||
          (fps / sourceFrameRate - ratio).abs() <
              (fps / sourceFrameRate - previous.ratio).abs()) {
        choices[fps] = GifSpeedChoice(ratio, fps);
      }
    }
    return choices.values.toList()
      ..sort((a, b) => a.frameRate.compareTo(b.frameRate));
  }

  int get playbackFrameRate => (sourceFrameRate * speedPreset).round().clamp(
    1,
    (sourceFrameRate * 4).floor(),
  );
  double get speed => playbackFrameRate / sourceFrameRate;
  int get speedIndex => speedChoices.indexWhere(
    (choice) => choice.frameRate == playbackFrameRate,
  );
  Duration get outputDuration =>
      Duration(microseconds: (duration.inMicroseconds / speed).round());

  (double, double) get _displayDimensions {
    final rotated =
        source.rotationDegrees == 90 || source.rotationDegrees == 270;
    final w = rotated
        ? source.height!.toDouble()
        : source.width! * source.sampleAspectRatio!;
    final h = rotated
        ? source.width! * source.sampleAspectRatio!
        : source.height!.toDouble();
    return (w, h);
  }

  (int, int) get originalDimensions {
    final (w, h) = _displayDimensions;
    return (w.round(), h.round());
  }

  List<GifResolution> get resolutions {
    final (w, h) = originalDimensions;
    return [
      for (final option in [
        GifResolution.px360,
        GifResolution.px480,
        GifResolution.px640,
        GifResolution.px720,
      ])
        if (option.longestEdge! < math.max(w, h)) option,
      GifResolution.original,
    ];
  }

  (int, int) get dimensions {
    final (w, h) = _displayDimensions;
    final edge = resolution.longestEdge;
    if (edge == null) return (w.round(), h.round());
    final scale = math.min(1, edge / math.max(w, h));
    return ((w * scale).round(), (h * scale).round());
  }

  // A deliberately coarse, uncalibrated compression assumption. The estimate
  // never controls eligibility; only the measured output enforces the ceiling.
  int get estimatedBytes {
    final (w, h) = dimensions;
    final frames =
        (duration.inMicroseconds /
                Duration.microsecondsPerSecond *
                sourceFrameRate)
            .round();
    return (w * h * frames * .5).round();
  }

  GifExportSettings get settings => GifExportSettings(
    start: start,
    duration: duration,
    resolution: resolution,
    frameRate: GifFrameRate.original,
    sourceFrameRate: sourceFrameRate,
    playbackFrameRate: playbackFrameRate,
  );

  GifExportPlan get plan =>
      GifExportPlan.fromSource(source, mimeType: mimeType, settings: settings);
  bool get canCreate {
    try {
      plan;
      return true;
    } on GifConversionException {
      return false;
    }
  }

  GifEditorSelection copyWith({
    Duration? start,
    Duration? end,
    double? sourceFrameRate,
    GifResolution? resolution,
    double? speedPreset,
  }) => GifEditorSelection(
    source: source,
    mimeType: mimeType,
    start: start ?? this.start,
    end: end ?? this.end,
    sourceFrameRate: sourceFrameRate ?? this.sourceFrameRate,
    resolution: resolution ?? this.resolution,
    speedPreset: speedPreset ?? this.speedPreset,
  );

  GifEditorSelection moveWindow(Duration position) {
    final value = position.inMicroseconds.clamp(
      0,
      (sourceDuration - duration).inMicroseconds,
    );
    final next = Duration(microseconds: value);
    return copyWith(start: next, end: next + duration);
  }

  GifEditorSelection moveStart(Duration position) => copyWith(
    start: Duration(
      microseconds: position.inMicroseconds.clamp(
        0,
        (end - _minimumDuration).inMicroseconds,
      ),
    ),
  );

  GifEditorSelection moveEnd(Duration position) => copyWith(
    end: Duration(
      microseconds: position.inMicroseconds.clamp(
        (start + _minimumDuration).inMicroseconds,
        sourceDuration.inMicroseconds,
      ),
    ),
  );
}
