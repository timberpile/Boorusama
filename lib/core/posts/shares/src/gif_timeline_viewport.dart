import 'dart:math' as math;

/// Normalized source-time viewport. Selection and playback remain in source
/// timestamps and are never mutated by navigation.
class GifTimelineViewport {
  const GifTimelineViewport({this.start = 0, this.span = 1});

  final double start;
  final double span;
  double get end => start + span;
  double fractionAt(double x) => start + x * span;
  double xFor(double fraction) => (fraction - start) / span;

  GifTimelineViewport pan(double fractionDelta) => GifTimelineViewport(
    start: (start + fractionDelta).clamp(0, 1 - span),
    span: span,
  );

  GifTimelineViewport zoom({
    required double scale,
    required double anchor,
    required double anchorX,
    required double minimumSpan,
  }) {
    final nextSpan = (span / scale)
        .clamp(math.min(1, minimumSpan), 1)
        .toDouble();
    return GifTimelineViewport(
      start: (anchor - anchorX * nextSpan).clamp(0, 1 - nextSpan),
      span: nextSpan,
    );
  }
}
