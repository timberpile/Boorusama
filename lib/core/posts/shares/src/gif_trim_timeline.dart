import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import 'gif_conversion_service.dart';
import 'gif_editor_selection.dart';
import 'gif_export_contract.dart';
import 'gif_timeline_thumbnails.dart';
import 'gif_timeline_viewport.dart';

class GifTrimTimeline extends StatefulWidget {
  const GifTrimTimeline({
    required this.selection,
    required this.source,
    required this.position,
    required this.onChanged,
    this.backend,
    super.key,
  });

  final GifEditorSelection selection;
  final GifPreparedSource source;
  final GifEncoderBackend? backend;
  final ValueListenable<Duration> position;
  final ValueChanged<GifEditorSelection> onChanged;

  @override
  State<GifTrimTimeline> createState() => _GifTrimTimelineState();
}

class _GifTrimTimelineState extends State<GifTrimTimeline> {
  var _viewport = const GifTimelineViewport();
  GifTimelineThumbnails? _thumbnails;
  late GifTimelineViewport _gestureViewport;
  late GifEditorSelection _gestureSelection;
  late Offset _gesturePoint;
  var _edge = 2; // -1/1: trim edges, 0: move selection, 2: pan viewport.
  var _pinching = false;
  var _baseScale = 1.0;
  var _anchor = 0.0;
  var _anchorX = .5;
  var _centerFirstZoom = false;
  final _pointers = <int>{};
  Offset? _downPoint;
  var _rulerHeight = 20.0;

  @override
  void initState() {
    super.initState();
    if (widget.backend case final GifTimelineRegionBackend backend) {
      _thumbnails = GifTimelineThumbnails(widget.source, backend)
        ..addListener(_imagesChanged);
    }
  }

  void _imagesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _thumbnails?.removeListener(_imagesChanged);
    _thumbnails?.dispose();
    super.dispose();
  }

  double _fraction(Duration time) =>
      time.inMicroseconds / widget.selection.sourceDuration.inMicroseconds;
  Duration _time(double fraction) => Duration(
    microseconds: (fraction * widget.selection.sourceDuration.inMicroseconds)
        .round(),
  );
  String _seconds(Duration time) =>
      (time.inMicroseconds / 1000000).toStringAsFixed(1);

  void _requestImages() {
    if (_viewport.span < .95) {
      _thumbnails?.request(_time(_viewport.start), _time(_viewport.end));
    }
  }

  void _start(ScaleStartDetails details, double width) {
    _gestureViewport = _viewport;
    _gestureSelection = widget.selection;
    _gesturePoint = _downPoint ?? details.localFocalPoint;
    _pinching = false;
    _edge = 2;
    if (details.pointerCount < 2 && _gesturePoint.dy >= _rulerHeight) {
      final x = _gesturePoint.dx - 22;
      final left = _viewport.xFor(_fraction(widget.selection.start)) * width;
      final right = _viewport.xFor(_fraction(widget.selection.end)) * width;
      if ((x - left).abs() <= 22 || (x - right).abs() <= 22) {
        _edge = (x - left).abs() <= (x - right).abs() ? -1 : 1;
      } else if (x > left && x < right) {
        _edge = 0;
      }
    }
  }

  void _update(ScaleUpdateDetails details, double width) {
    if (details.pointerCount >= 2) {
      if (!_pinching) {
        _pinching = true;
        _gestureViewport = _viewport;
        _baseScale = details.scale;
        _centerFirstZoom = _viewport.span >= .999999;
        _anchorX = _centerFirstZoom
            ? .5
            : ((details.localFocalPoint.dx - 22) / width).clamp(0, 1);
        _anchor = _centerFirstZoom
            ? (_fraction(widget.selection.start) +
                      _fraction(widget.selection.end)) /
                  2
            : _viewport.fractionAt(_anchorX);
      }
      final minimumSpan = math.min<double>(
        1,
        math.max(250000, 10000000 / widget.selection.source.frameRate!) /
            widget.selection.sourceDuration.inMicroseconds,
      );
      setState(() {
        _viewport = _gestureViewport.zoom(
          scale: details.scale / _baseScale,
          anchor: _anchor,
          anchorX: _centerFirstZoom
              ? .5
              : ((details.localFocalPoint.dx - 22) / width).clamp(0, 1),
          minimumSpan: minimumSpan,
        );
      });
      _requestImages();
      return;
    }
    // Lifting one finger after a pinch must not turn navigation into a trim.
    if (_pinching) return;
    final delta =
        (details.localFocalPoint.dx - _gesturePoint.dx) /
        width *
        _gestureViewport.span;
    if (_edge == 2) {
      setState(() => _viewport = _gestureViewport.pan(-delta));
      _requestImages();
    } else {
      final timeDelta = _time(delta);
      widget.onChanged(_next(_gestureSelection, timeDelta, _edge));
    }
  }

  GifEditorSelection _next(
    GifEditorSelection selected,
    Duration delta,
    int edge,
  ) => switch (edge) {
    -1 => selected.moveStart(selected.start + delta),
    1 => selected.moveEnd(selected.end + delta),
    _ => selected.moveWindow(selected.start + delta),
  };

  Widget _semantics(Widget child, int edge, String label) {
    final selected = widget.selection;
    return Semantics(
      label: label,
      value: '${_seconds(edge == 1 ? selected.end : selected.start)} s',
      increasedValue:
          '${_seconds(edge == 1 ? _next(selected, const Duration(milliseconds: 100), edge).end : _next(selected, const Duration(milliseconds: 100), edge).start)} s',
      decreasedValue:
          '${_seconds(edge == 1 ? _next(selected, const Duration(milliseconds: -100), edge).end : _next(selected, const Duration(milliseconds: -100), edge).start)} s',
      onIncrease: () => widget.onChanged(
        _next(selected, const Duration(milliseconds: 100), edge),
      ),
      onDecrease: () => widget.onChanged(
        _next(selected, const Duration(milliseconds: -100), edge),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.max<double>(1, constraints.maxWidth - 44);
      _rulerHeight = (MediaQuery.textScalerOf(context).scale(11) + 8).clamp(
        20,
        48,
      );
      final selected = widget.selection;
      final left = _viewport.xFor(_fraction(selected.start)) * width + 22;
      final right = _viewport.xFor(_fraction(selected.end)) * width + 22;
      final color = Theme.of(context).colorScheme.primary;
      final t = context.t.post.gif_editor;
      final strip = _thumbnails?.strip;
      final hasDetail = strip != null && _viewport.span < .95;
      final imageStart = hasDetail
          ? _fraction(strip.start)
          : _fraction(Duration.zero);
      final imageSpan = hasDetail ? _fraction(strip.end - strip.start) : 1.0;
      final imageLeft = _viewport.xFor(imageStart) * width;
      final imageWidth = imageSpan / _viewport.span * width;
      return Semantics(
        hint: t.timeline_zoom_hint,
        child: GestureDetector(
          key: const ValueKey('gif-timeline'),
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) => _start(details, width),
          onScaleUpdate: (details) => _update(details, width),
          child: Listener(
            onPointerDown: (event) {
              if (_pointers.isEmpty) _downPoint = event.localPosition;
              _pointers.add(event.pointer);
            },
            onPointerUp: (event) => _pointers.remove(event.pointer),
            onPointerCancel: (event) => _pointers.remove(event.pointer),
            child: SizedBox(
              height: _rulerHeight + 72,
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      left: 22,
                      right: 22,
                      top: 0,
                      height: _rulerHeight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${_seconds(_time(_viewport.start))} s',
                              style: Theme.of(context).textTheme.labelSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${_seconds(_time(_viewport.end))} s',
                              style: Theme.of(context).textTheme.labelSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 22,
                      right: 22,
                      top: _rulerHeight + 6,
                      bottom: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ColoredBox(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                              ),
                            ),
                            if (hasDetail || widget.source.timeline != null)
                              Positioned(
                                left: imageLeft,
                                width: imageWidth,
                                top: 0,
                                bottom: 0,
                                child: hasDetail
                                    ? Image.memory(
                                        strip.bytes,
                                        fit: BoxFit.fill,
                                        gaplessPlayback: true,
                                      )
                                    : Image.file(
                                        File(widget.source.timeline!.path),
                                        fit: BoxFit.fill,
                                        errorBuilder: (_, _, _) =>
                                            const SizedBox.shrink(),
                                      ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (right > 22 && left < width + 22)
                      Positioned(
                        left: math.max(22, left),
                        width: math.min(width + 22, right) - math.max(22, left),
                        top: _rulerHeight + 4,
                        bottom: 4,
                        child: _semantics(
                          Container(
                            key: const ValueKey('gif-trim-window'),
                            decoration: BoxDecoration(
                              border: Border.all(color: color, width: 3),
                              color: color.withValues(alpha: .12),
                            ),
                          ),
                          0,
                          t.move_window,
                        ),
                      ),
                    for (final edge in [-1, 1])
                      if ((edge == -1 ? left : right) >= 0 &&
                          (edge == -1 ? left : right) <= width + 44)
                        Positioned(
                          left: (edge == -1 ? left : right) - 22,
                          width: 44,
                          top: _rulerHeight,
                          bottom: 0,
                          child: _semantics(
                            Center(
                              child: Container(
                                key: ValueKey('gif-trim-$edge'),
                                width: 12,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.drag_indicator,
                                  size: 12,
                                ),
                              ),
                            ),
                            edge,
                            edge == -1 ? t.clip_start : t.clip_end,
                          ),
                        ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ValueListenableBuilder<Duration>(
                          valueListenable: widget.position,
                          builder: (context, position, _) {
                            final x =
                                _viewport.xFor(_fraction(position)) * width +
                                22;
                            if (x < 22 || x > width + 22) {
                              return const SizedBox.shrink();
                            }
                            return Stack(
                              children: [
                                Positioned(
                                  left: x - 1,
                                  width: 2,
                                  top: _rulerHeight,
                                  bottom: 0,
                                  child: Semantics(
                                    label: t.timeline_position,
                                    value: '${_seconds(position)} s',
                                    child: ColoredBox(
                                      key: const ValueKey('gif-playhead'),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
