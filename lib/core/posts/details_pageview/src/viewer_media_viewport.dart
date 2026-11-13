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

  Widget present(Size size, Widget child) {
    final content =
        size.width.isFinite &&
            size.height.isFinite &&
            size.width > 0 &&
            size.height > 0
        ? size
        : viewport;
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
    final currentScale = lerpDouble(1, scale, progress)!;
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
              offset.dx * progress,
              offset.dy * progress,
              0,
              1,
            )
            ..scaleByDouble(currentScale, currentScale, 1, 1),
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
