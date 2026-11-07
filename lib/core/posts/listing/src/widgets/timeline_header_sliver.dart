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
    this.backgroundColor,
    super.key,
  });

  final Widget child;
  final bool keepVisible;
  final bool reduceMotion;
  final Color? backgroundColor;

  static Color backgroundColorOf(BuildContext context) =>
      (Theme.of(context).extension<KurumiExtendedColorScheme>() ??
              const KurumiExtendedColorScheme())
          .surfaceContainerOverlay;

  @override
  Widget build(BuildContext context) {
    // Keep a stable measured render child across empty/error header changes.
    Widget surface({double topInset = 0}) => ColoredBox(
      color: backgroundColor ?? backgroundColorOf(context),
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
              return _MeasuredPinnedHeader(child: surface(topInset: inset));
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

class _MeasuredPinnedHeader extends SingleChildRenderObjectWidget {
  const _MeasuredPinnedHeader({required super.child});

  @override
  RenderSliverToBoxAdapter createRenderObject(BuildContext context) =>
      _RenderMeasuredPinnedHeader();
}

/// A header taller than its viewport must scroll so its bottom actions remain
/// reachable. Measure on every layout to handle chip wrapping, IME and rotation
/// without replacing the child or waiting for another frame.
class _RenderMeasuredPinnedHeader extends RenderSliverToBoxAdapter {
  bool _pinned = false;

  @override
  void performLayout() {
    super.performLayout();
    final current = geometry!;
    final overlap = math.max(0.0, constraints.overlap);
    final available = math.max(
      0.0,
      constraints.viewportMainAxisExtent - overlap,
    );
    _pinned = child != null && current.scrollExtent <= available;
    if (!_pinned) return;

    final extent = current.scrollExtent;
    final remaining = math.max(
      0.0,
      constraints.remainingPaintExtent - overlap,
    );
    geometry = SliverGeometry(
      scrollExtent: extent,
      paintOrigin: overlap,
      paintExtent: math.min(extent, remaining),
      layoutExtent: (extent - constraints.scrollOffset).clamp(
        0.0,
        remaining,
      ),
      maxPaintExtent: extent,
      maxScrollObstructionExtent: extent,
      cacheExtent: calculateCacheOffset(constraints, from: 0, to: extent),
      hasVisualOverflow: true,
    );
    // The scrolling adapter's parent data includes the scroll translation.
    // A pinned child stays at the sliver's painted leading edge instead.
    (child!.parentData! as SliverPhysicalParentData).paintOffset = Offset.zero;
  }

  @override
  double childMainAxisPosition(covariant RenderBox child) =>
      _pinned ? 0 : super.childMainAxisPosition(child);

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (_pinned && geometry!.layoutExtent < geometry!.scrollExtent) {
      config.addTagForChildren(RenderViewport.excludeFromScrolling);
    }
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
