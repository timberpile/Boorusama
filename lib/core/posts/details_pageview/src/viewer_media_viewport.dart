import 'dart:ui' show lerpDouble;

import 'package:kurumi/material.dart';

/// The shared frame stays full width; each native Page fits its own geometry.
class ViewerMediaViewport extends InheritedWidget {
  const ViewerMediaViewport({
    required this.viewport,
    required this.details,
    required this.progress,
    required super.child,
    super.key,
  });

  final Size viewport;
  final Size details;
  final double progress;

  static ViewerMediaViewport? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ViewerMediaViewport>();

  bool _valid(Size size) =>
      size.width.isFinite &&
      size.height.isFinite &&
      size.width > 0 &&
      size.height > 0;

  ({double scale, Offset offset}) _geometry(Size size) {
    final content = _valid(size) ? size : viewport;
    final immersiveFit = applyBoxFit(
      BoxFit.contain,
      content,
      viewport,
    ).destination;
    final detailsFit = applyBoxFit(
      BoxFit.contain,
      content,
      details,
    ).destination;
    final scale = immersiveFit.width > 0
        ? detailsFit.width / immersiveFit.width
        : 1.0;
    final offset =
        Offset(
          details.width / 2,
          content.width / content.height > 3
              ? details.height - detailsFit.height / 2
              : details.height / 2,
        ) -
        viewport.center(Offset.zero) * scale;
    return (
      scale: lerpDouble(1, scale, progress)!,
      offset: offset * progress,
    );
  }

  Widget present(Size size, Widget child) {
    final geometry = _geometry(size);
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: viewport.width,
        maxWidth: viewport.width,
        minHeight: viewport.height,
        maxHeight: viewport.height,
        child: Transform(
          alignment: Alignment.topLeft,
          transform: Matrix4.identity()
            ..translateByDouble(
              geometry.offset.dx,
              geometry.offset.dy,
              0,
              1,
            )
            ..scaleByDouble(geometry.scale, geometry.scale, 1, 1),
          child: child,
        ),
      ),
    );
  }

  @override
  bool updateShouldNotify(ViewerMediaViewport oldWidget) =>
      viewport != oldWidget.viewport ||
      details != oldWidget.details ||
      progress != oldWidget.progress;
}
