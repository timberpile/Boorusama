import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import 'gif_editor_selection.dart';
import 'gif_trim_navigation.dart';

String gifTrimTime(Duration time) =>
    '${(time.inMicroseconds / 1000000).toStringAsFixed(3)} s';

/// Variant A: permanent source overview plus a separate, stable detail viewport.
/// No thumbnail generation and no multi-touch gesture is needed for navigation.
class GifTrimNavigator extends StatelessWidget {
  const GifTrimNavigator({
    required this.selection,
    required this.navigation,
    required this.position,
    required this.onChanged,
    required this.onSeek,
    super.key,
  });
  final GifEditorSelection selection;
  final GifTrimNavigation navigation;
  final ValueListenable<Duration> position;
  final ValueChanged<GifEditorSelection> onChanged;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: navigation,
    builder: (context, _) {
      final t = context.t.gif_trim;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.overview,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              IconButton(
                key: const ValueKey('gif-trim-zoom-out'),
                tooltip: t.zoom_out,
                onPressed: () => navigation.zoom(.5, position.value),
                icon: const Icon(Icons.remove),
              ),
              IconButton(
                key: const ValueKey('gif-trim-zoom-in'),
                tooltip: t.zoom_in,
                onPressed: () => navigation.zoom(2, position.value),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                key: const ValueKey('gif-trim-focus'),
                tooltip: t.focus_selection,
                onPressed: () =>
                    navigation.focus(selection.start, selection.end),
                icon: const Icon(Icons.center_focus_strong),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              void browse(Offset point) {
                final fraction = (point.dx / math.max(1, constraints.maxWidth))
                    .clamp(0, 1);
                final time = Duration(
                  microseconds:
                      (fraction * selection.sourceDuration.inMicroseconds)
                          .round(),
                );
                navigation.browse(time);
                onSeek(time);
              }

              return Semantics(
                label: t.overview,
                hint: t.overview_hint,
                child: GestureDetector(
                  key: const ValueKey('gif-trim-overview'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (event) => browse(event.localPosition),
                  onHorizontalDragStart: (event) => browse(event.localPosition),
                  onHorizontalDragUpdate: (event) =>
                      browse(event.localPosition),
                  child: SizedBox(
                    height: 48,
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: position,
                      builder: (context, value, _) => CustomPaint(
                        painter: _OverviewPainter(
                          selection,
                          navigation,
                          value,
                          Theme.of(context).colorScheme,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  gifTrimTime(navigation.visibleStart),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Text(
                  gifTrimTime(navigation.visibleEnd),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Tooltip(
            message: t.detail_hint,
            child: _DetailTrack(
              selection: selection,
              navigation: navigation,
              position: position,
              onChanged: onChanged,
              onSeek: onSeek,
            ),
          ),
        ],
      );
    },
  );
}

class _DetailTrack extends StatefulWidget {
  const _DetailTrack({
    required this.selection,
    required this.navigation,
    required this.position,
    required this.onChanged,
    required this.onSeek,
  });
  final GifEditorSelection selection;
  final GifTrimNavigation navigation;
  final ValueListenable<Duration> position;
  final ValueChanged<GifEditorSelection> onChanged;
  final ValueChanged<Duration> onSeek;
  @override
  State<_DetailTrack> createState() => _DetailTrackState();
}

class _DetailTrackState extends State<_DetailTrack> {
  late GifEditorSelection _dragSelection;
  late double _dragSpan;
  var _distance = 0.0;

  GifEditorSelection _move(
    GifEditorSelection selected,
    Duration delta,
    int edge,
  ) => switch (edge) {
    -1 => selected.moveStart(selected.start + delta),
    1 => selected.moveEnd(selected.end + delta),
    _ => selected.moveWindow(selected.start + delta),
  };

  String _value(GifEditorSelection selected, int edge) =>
      gifTrimTime(edge == 1 ? selected.end : selected.start);

  Widget _handle(int edge, String label, Widget child, double width) =>
      Semantics(
        label: label,
        value: _value(widget.selection, edge),
        increasedValue: _value(
          _move(widget.selection, const Duration(milliseconds: 20), edge),
          edge,
        ),
        decreasedValue: _value(
          _move(widget.selection, const Duration(milliseconds: -20), edge),
          edge,
        ),
        onIncrease: () => widget.onChanged(
          _move(widget.selection, const Duration(milliseconds: 20), edge),
        ),
        onDecrease: () => widget.onChanged(
          _move(widget.selection, const Duration(milliseconds: -20), edge),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            _dragSelection = widget.selection;
            _distance = 0;
            _dragSpan = widget.navigation.viewport.span;
          },
          onHorizontalDragUpdate: (event) {
            _distance += event.delta.dx;
            final delta = Duration(
              microseconds:
                  (_distance /
                          width *
                          _dragSpan *
                          widget.selection.sourceDuration.inMicroseconds)
                      .round(),
            );
            widget.onChanged(_move(_dragSelection, delta, edge));
          },
          child: child,
        ),
      );

  Widget _selectionFill(ColorScheme colors) => Container(
    key: const ValueKey('gif-trim-window'),
    decoration: BoxDecoration(
      color: colors.primary.withValues(alpha: .15),
      border: Border.all(color: colors.primary, width: 2),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.max<double>(1, constraints.maxWidth - 48);
      final selected = widget.selection;
      final duration = selected.sourceDuration.inMicroseconds;
      final viewport = widget.navigation.viewport;
      double x(Duration time) =>
          24 + width * viewport.xFor(time.inMicroseconds / duration);
      final left = x(selected.start);
      final right = x(selected.end);
      final colors = Theme.of(context).colorScheme;
      final t = context.t.post.gif_editor;
      return SizedBox(
        height: 64,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (event) => widget.onSeek(
            Duration(
              microseconds:
                  (viewport.fractionAt(
                            ((event.localPosition.dx - 24) / width).clamp(0, 1),
                          ) *
                          duration)
                      .round(),
            ),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    key: const ValueKey('gif-trim-detail'),
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (event) => widget.navigation.pan(
                      -event.delta.dx / width * viewport.span,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                if (right > 24 && left < width + 24)
                  Positioned(
                    left: math.max(24, left),
                    width: math.min(width + 24, right) - math.max(24, left),
                    top: 8,
                    bottom: 8,
                    child: left >= 24 && right <= width + 24
                        ? _handle(
                            0,
                            t.move_window,
                            _selectionFill(colors),
                            width,
                          )
                        : IgnorePointer(child: _selectionFill(colors)),
                  ),
                for (final edge in [-1, 1])
                  if ((edge == -1 ? left : right) >= 24 &&
                      (edge == -1 ? left : right) <= width + 24)
                    Positioned(
                      left: (edge == -1 ? left : right) - 24,
                      width: 48,
                      top: 0,
                      bottom: 0,
                      child: _handle(
                        edge,
                        edge == -1 ? t.clip_start : t.clip_end,
                        Center(
                          child: Container(
                            key: ValueKey('gif-trim-$edge'),
                            width: 14,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Icon(
                              Icons.drag_indicator,
                              size: 12,
                              color: colors.onPrimary,
                            ),
                          ),
                        ),
                        width,
                      ),
                    ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: widget.position,
                      builder: (context, time, _) => Stack(
                        children: [
                          if (x(time) >= 24 && x(time) <= width + 24)
                            Positioned(
                              left: x(time) - 1,
                              width: 2,
                              top: 6,
                              bottom: 6,
                              child: ColoredBox(
                                key: const ValueKey('gif-playhead'),
                                color: colors.onSurface,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _OverviewPainter extends CustomPainter {
  _OverviewPainter(this.selection, this.navigation, this.position, this.colors);
  final GifEditorSelection selection;
  final GifTrimNavigation navigation;
  final Duration position;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    final duration = selection.sourceDuration.inMicroseconds;
    double x(Duration time) => time.inMicroseconds / duration * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 12, size.width, 24),
        const Radius.circular(5),
      ),
      Paint()..color = colors.surfaceContainerHighest,
    );
    canvas.drawRect(
      Rect.fromLTRB(x(selection.start), 17, x(selection.end), 31),
      Paint()..color = colors.primary.withValues(alpha: .45),
    );
    canvas.drawRect(
      Rect.fromLTRB(
        navigation.viewport.start * size.width,
        10,
        navigation.viewport.end * size.width,
        38,
      ),
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final playhead = x(position).clamp(0, size.width).toDouble();
    canvas.drawLine(
      Offset(playhead, 8),
      Offset(playhead, 40),
      Paint()
        ..color = colors.onSurface
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _OverviewPainter oldDelegate) => true;
}
