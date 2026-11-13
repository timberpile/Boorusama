// Package imports:
import 'package:kurumi/material.dart';

enum ZoomPageEdgeAction { page, retry, loadMore }

class ZoomPageNavigationScope extends InheritedWidget {
  const ZoomPageNavigationScope({
    required this.previousLabel,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
    required this.previousActionId,
    required this.nextActionId,
    this.onEdgePrevious,
    this.onEdgeNext,
    this.nextEdgeAction = ZoomPageEdgeAction.page,
    required super.child,
    super.key,
  });

  final String previousLabel;
  final String nextLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onEdgePrevious;
  final VoidCallback? onEdgeNext;
  final ZoomPageEdgeAction nextEdgeAction;
  final Object? previousActionId;
  final Object? nextActionId;

  static ZoomPageNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZoomPageNavigationScope>();

  @override
  bool updateShouldNotify(ZoomPageNavigationScope oldWidget) =>
      previousLabel != oldWidget.previousLabel ||
      nextLabel != oldWidget.nextLabel ||
      previousActionId != oldWidget.previousActionId ||
      nextActionId != oldWidget.nextActionId ||
      onPrevious != oldWidget.onPrevious ||
      onNext != oldWidget.onNext ||
      onEdgePrevious != oldWidget.onEdgePrevious ||
      onEdgeNext != oldWidget.onEdgeNext ||
      nextEdgeAction != oldWidget.nextEdgeAction;
}

/// Overrides only media navigation; Details keeps the outer occurrence pager.
class MediaPageNavigation {
  const MediaPageNavigation({
    this.onPrevious,
    this.onNext,
    this.previousId,
    this.nextId,
    this.pageController,
    this.atStart = false,
    this.atEnd = false,
  });
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final Object? previousId;
  final Object? nextId;
  // Resolve after the media region mounts, rather than capturing a null pager
  // during the surrounding frame's first build.
  final PageController? Function()? pageController;
  final bool atStart;
  final bool atEnd;
}
