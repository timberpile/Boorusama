import 'dart:ui' show lerpDouble;

import 'package:kurumi/material.dart';

/// Supplies a route-level vertical displacement to the viewer's media drag.
/// Translating the entire route reveals the underlying timeline and keeps
/// controls and media on the same coordinate system.
class ViewerDismissalScope extends InheritedWidget {
  const ViewerDismissalScope({
    required this.offset,
    required this.restore,
    required super.child,
    super.key,
  });

  final ValueNotifier<double> offset;
  final Future<void> Function(bool immediate) restore;

  static ViewerDismissalScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ViewerDismissalScope>();

  @override
  bool updateShouldNotify(ViewerDismissalScope oldWidget) =>
      !identical(offset, oldWidget.offset);
}

/// Keep entry and exit direction stable through the first and final frames.
class ViewerRouteTransition extends StatefulWidget {
  const ViewerRouteTransition({
    required this.animation,
    required this.child,
    super.key,
  });
  final Animation<double> animation;
  final Widget child;
  @override
  State<ViewerRouteTransition> createState() => _ViewerRouteTransitionState();
}

class _ViewerRouteTransitionState extends State<ViewerRouteTransition>
    with SingleTickerProviderStateMixin {
  final _dragOffset = ValueNotifier<double>(0);
  late final _returnController =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 165),
      )..addListener(() {
        _dragOffset.value = _returnOffset.value;
      });
  Animation<double> _returnOffset = const AlwaysStoppedAnimation(0);

  Future<void> _restoreDrag(bool immediate) async {
    _returnController.stop();
    if (immediate || _dragOffset.value == 0) {
      _dragOffset.value = 0;
      return;
    }
    _returnOffset = Tween<double>(
      begin: _dragOffset.value,
      end: 0,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_returnController);
    try {
      await _returnController.forward(from: 0).orCancel;
    } on TickerCanceled {
      // A new route action or unmount can interrupt the return.
    }
  }

  var _readyToPaint = false;
  var _closing = false;
  var _closeFrom = 0.0;
  var _closeAnimationValue = 1.0;

  @override
  void initState() {
    super.initState();
    // Prepare layout/media on the first frame, but never flash an untransformed
    // Viewer over the timeline while Navigator installs the route animation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _readyToPaint = true);
    });
  }

  @override
  void dispose() {
    _returnController.dispose();
    _dragOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => AnimatedBuilder(
      animation: Listenable.merge([widget.animation, _dragOffset]),
      child: ViewerDismissalScope(
        offset: _dragOffset,
        restore: _restoreDrag,
        child: widget.child,
      ),
      builder: (context, child) {
        if (!_closing && widget.animation.status == AnimationStatus.reverse) {
          _closing = true;
          // A release continues exactly where the finger left the route,
          // instead of jumping back to the top before reverse animation.
          _closeFrom = _dragOffset.value;
          _closeAnimationValue = widget.animation.value.clamp(0.001, 1.0);
        }
        final value = widget.animation.value;
        final offset = _closing
            ? Offset(
                0,
                lerpDouble(
                  _closeFrom,
                  constraints.maxHeight,
                  Curves.easeOutCubic.transform(
                    (1 - value / _closeAnimationValue)
                        .clamp(0.0, 1.0)
                        .toDouble(),
                  ),
                )!,
              )
            : widget.animation.status == AnimationStatus.completed
            ? Offset(0, _dragOffset.value)
            : Offset(
                constraints.maxWidth *
                    (1 - Curves.easeOutCubic.transform(value)),
                _dragOffset.value,
              );
        return ClipRect(
          child: Transform.translate(
            offset: offset,
            child: Opacity(opacity: _readyToPaint ? 1 : 0, child: child),
          ),
        );
      },
    ),
  );
}
