import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:kurumi/material.dart';

/// A naturally sized floating header using Flutter's persistent-header renderer.
/// Cache the measured extent: scroll activity can change while an ancestor is
/// laying out, when SliverFloatingHeader's direct child-size read is invalid.
class MeasuredFloatingHeader extends StatefulWidget {
  const MeasuredFloatingHeader({
    required this.child,
    required this.reduceMotion,
    super.key,
  });

  final Widget child;
  final bool reduceMotion;

  @override
  State<MeasuredFloatingHeader> createState() => _MeasuredFloatingHeaderState();
}

class _MeasuredFloatingHeaderState extends State<MeasuredFloatingHeader>
    with SingleTickerProviderStateMixin {
  ScrollPosition? _position;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.isScrollingNotifier.removeListener(_scrollingChanged);
    _position = Scrollable.maybeOf(context)?.position;
    _position?.isScrollingNotifier.addListener(_scrollingChanged);
  }

  void _scrollingChanged() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_scheduled) return;
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (mounted) _syncAnimation();
      });
    } else {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final renderer = context.findRenderObject();
    final position = _position;
    if (renderer is! _RenderMeasuredFloatingHeader ||
        !renderer.hasLayout ||
        position == null) {
      return;
    }
    if (position.isScrollingNotifier.value) {
      renderer
        ..updateScrollStartDirection(position.userScrollDirection)
        ..maybeStopSnapAnimation(position.userScrollDirection);
    } else {
      renderer.maybeStartSnapAnimation(position.userScrollDirection);
    }
  }

  @override
  void dispose() {
    _position?.isScrollingNotifier.removeListener(_scrollingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _MeasuredHeaderRenderWidget(
    vsync: this,
    reduceMotion: widget.reduceMotion,
    child: widget.child,
  );
}

class _MeasuredHeaderRenderWidget extends SingleChildRenderObjectWidget {
  const _MeasuredHeaderRenderWidget({
    required this.vsync,
    required this.reduceMotion,
    required super.child,
  });

  final TickerProvider vsync;
  final bool reduceMotion;

  FloatingHeaderSnapConfiguration get _snap => FloatingHeaderSnapConfiguration(
    duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasuredFloatingHeader(vsync: vsync, snapConfiguration: _snap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasuredFloatingHeader renderObject,
  ) {
    renderObject
      ..vsync = vsync
      ..snapConfiguration = _snap;
  }
}

class _RenderMeasuredFloatingHeader
    extends RenderSliverFloatingPersistentHeader {
  _RenderMeasuredFloatingHeader({required super.vsync, super.snapConfiguration})
    : super(
        showOnScreenConfiguration:
            const PersistentHeaderShowOnScreenConfiguration(),
      );

  double _extent = 0;
  bool hasLayout = false;

  @override
  double get minExtent => _extent;
  @override
  double get maxExtent => _extent;

  @override
  void updateChild(double shrinkOffset, bool overlapsContent) {}

  @override
  void layoutChild(
    double scrollOffset,
    double maxExtent, {
    bool overlapsContent = false,
  }) {
    // A tight cached height would make an empty child a relayout boundary:
    // later error recovery or text resizing could never update its extent.
    child?.layout(constraints.asBoxConstraints(), parentUsesSize: true);
  }

  @override
  void performLayout() {
    layoutChild(0, 0);
    _extent = switch (constraints.axis) {
      Axis.vertical => child?.size.height ?? 0,
      Axis.horizontal => child?.size.width ?? 0,
    };
    super.performLayout();
    hasLayout = true;
  }
}
