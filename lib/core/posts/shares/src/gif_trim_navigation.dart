import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'gif_timeline_viewport.dart';

/// View-only state owned by the export route, not the disposable Trim dialog.
/// Navigating, zooming and preview speed never mutate export settings.
class GifTrimNavigation extends ChangeNotifier {
  GifTrimNavigation(this.sourceDuration) {
    if (sourceDuration <= Duration.zero) {
      throw ArgumentError.value(sourceDuration, 'sourceDuration');
    }
  }

  final Duration sourceDuration;
  var viewport = const GifTimelineViewport();
  var sourceMode = true;
  double previewSpeed = 1;
  var _initialized = false;

  int get _duration => sourceDuration.inMicroseconds;
  Duration get visibleStart => _time(viewport.start);
  Duration get visibleEnd => _time(viewport.end);
  Duration get visibleDuration => _time(viewport.span);
  Duration _time(double value) =>
      Duration(microseconds: (value * _duration).round());
  double _fraction(Duration value) => value.inMicroseconds / _duration;

  void initialize(Duration start, Duration end) {
    if (_initialized) return;
    _initialized = true;
    if (start > Duration.zero || end < sourceDuration) {
      focus(start, end);
    } else {
      _center(start, math.min(1, 8000000 / _duration));
    }
  }

  void _center(Duration position, double span) {
    final safeSpan = span.clamp(math.min(1, 200000 / _duration), 1).toDouble();
    viewport = GifTimelineViewport(
      start: (_fraction(position) - safeSpan / 2).clamp(0, 1 - safeSpan),
      span: safeSpan,
    );
    notifyListeners();
  }

  void browse(Duration position) {
    sourceMode = true;
    _center(
      position,
      viewport.span >= 1 ? math.min(1, 8000000 / _duration) : viewport.span,
    );
  }

  /// Selection occupies 50% of the view, except where the source is shorter.
  void focus(Duration start, Duration end) {
    _initialized = true;
    _center(
      start + (end - start) ~/ 2,
      2 * (end - start).inMicroseconds / _duration,
    );
  }

  void pan(double sourceFractionDelta) {
    viewport = viewport.pan(sourceFractionDelta);
    notifyListeners();
  }

  void zoom(double factor, Duration position) {
    final fraction = _fraction(position);
    final anchor = fraction >= viewport.start && fraction <= viewport.end
        ? fraction
        : viewport.start + viewport.span / 2;
    viewport = viewport.zoom(
      scale: factor,
      anchor: anchor,
      anchorX: viewport.xFor(anchor),
      minimumSpan: math.min(1, 200000 / _duration),
    );
    notifyListeners();
  }

  void setSourceMode(bool value) {
    if (sourceMode == value) return;
    sourceMode = value;
    notifyListeners();
  }

  void setPreviewSpeed(double value) {
    if (!const [.25, .5, .75, 1.0].contains(value) || value == previewSpeed) {
      return;
    }
    previewSpeed = value;
    notifyListeners();
  }
}
