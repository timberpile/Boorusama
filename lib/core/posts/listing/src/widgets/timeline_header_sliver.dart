import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';

import 'measured_floating_header.dart';

/// Uses the child's measured extent, including enlarged text and custom headers.
class TimelineHeaderSliver extends StatelessWidget {
  const TimelineHeaderSliver({
    required this.child,
    this.keepVisible = false,
    this.reduceMotion = false,
    super.key,
  });

  final Widget child;
  final bool keepVisible;
  final bool reduceMotion;

  static Color backgroundColorOf(BuildContext context) =>
      (Theme.of(context).extension<KurumiExtendedColorScheme>() ??
              const KurumiExtendedColorScheme())
          .surfaceContainerOverlay;

  @override
  Widget build(BuildContext context) {
    // Keep a stable measured render child across empty/error header changes.
    Widget surface({double topInset = 0}) => ColoredBox(
      color: backgroundColorOf(context),
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
    return keepVisible
        ? SliverLayoutBuilder(
            builder: (context, constraints) {
              // The viewport may extend behind the system bar. Only reserve
              // its uncovered part as the header reaches the leading edge;
              // a visible AppBar or an ancestor SafeArea already covers it.
              final leading =
                  constraints.viewportMainAxisExtent -
                  constraints.remainingPaintExtent +
                  math.max(0, constraints.overlap);
              final inset = math.max(
                0.0,
                MediaQuery.paddingOf(context).top - leading,
              );
              return PinnedHeaderSliver(child: surface(topInset: inset));
            },
          )
        : _AvoidHeaderOverlap(
            child: MeasuredFloatingHeader(
              reduceMotion: reduceMotion,
              child: surface(),
            ),
          );
  }
}

/// Floating headers paint at the viewport's leading edge by default. A preceding
/// pinned or snapping AppBar would cover them there, even after a successful
/// reveal. Reserve its painted overlap without changing the raw scroll extent.
class _AvoidHeaderOverlap extends SingleChildRenderObjectWidget {
  const _AvoidHeaderOverlap({required super.child});

  @override
  RenderProxySliver createRenderObject(BuildContext context) =>
      _RenderAvoidHeaderOverlap();
}

class _RenderAvoidHeaderOverlap extends RenderProxySliver {
  @override
  void performLayout() {
    final overlap = math.max(0.0, constraints.overlap);
    child!.layout(
      constraints.copyWith(
        overlap: math.min(0.0, constraints.overlap),
        remainingPaintExtent: math.max(
          0.0,
          constraints.remainingPaintExtent - overlap,
        ),
      ),
      parentUsesSize: true,
    );
    geometry = child!.geometry!.copyWith(
      paintOrigin: child!.geometry!.paintOrigin + overlap,
    );
  }
}
