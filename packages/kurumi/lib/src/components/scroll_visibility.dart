import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class KurumiScrollToTop extends StatefulWidget {
  const KurumiScrollToTop({
    required this.child,
    super.key,
    this.scrollController,
    this.layoutChanges,
  });

  final ScrollController? scrollController;

  /// Content changes can correct the position during layout without notifying
  /// the scroll controller or rebuilding this floating control.
  final Listenable? layoutChanges;
  final Widget child;

  @override
  State<KurumiScrollToTop> createState() => _KurumiScrollToTopState();
}

class _KurumiScrollToTopState extends State<KurumiScrollToTop>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late bool _ownsScrollController;
  late final _animationController = AnimationController(
    vsync: this,
    duration: kThemeAnimationDuration,
    reverseDuration: kThemeAnimationDuration,
  );

  ScrollDirection? _lastDirection;
  bool _visible = false;
  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    _attachController();
    widget.layoutChanges?.addListener(_syncAfterLayout);
  }

  void _attachController() {
    _ownsScrollController = widget.scrollController == null;
    _scrollController = widget.scrollController ?? AutoScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _detachController() {
    _scrollController.removeListener(_onScroll);
    if (_ownsScrollController) _scrollController.dispose();
  }

  @override
  void didUpdateWidget(KurumiScrollToTop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layoutChanges != widget.layoutChanges) {
      oldWidget.layoutChanges?.removeListener(_syncAfterLayout);
      widget.layoutChanges?.addListener(_syncAfterLayout);
    }
    if (oldWidget.scrollController != widget.scrollController) {
      _detachController();
      _lastDirection = null;
      _visible = false;
      _animationController.value = 0;
      _attachController();
    }
  }

  @override
  void dispose() {
    widget.layoutChanges?.removeListener(_syncAfterLayout);
    _detachController();
    _animationController.dispose();
    super.dispose();
  }

  void _setVisible(bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    if (visible) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _onScroll() {
    // A controller can briefly have no position during replacement, or more
    // than one during a transition. Never read its singular position then.
    final positions = _scrollController.positions;
    if (positions.length != 1) {
      _lastDirection = null;
      _setVisible(false);
      return;
    }
    final position = positions.single;
    if (!position.hasPixels || !position.hasContentDimensions) return;

    // Check the boundary on every update: a continuous drag, a ballistic
    // scroll, or jumpTo need not change userScrollDirection at the top.
    if (position.pixels <= position.minScrollExtent + 0.5) {
      _lastDirection = null;
      _setVisible(false);
      return;
    }

    final direction = position.userScrollDirection;
    if (direction == _lastDirection) return;
    _lastDirection = direction;
    switch (direction) {
      case ScrollDirection.forward:
        _setVisible(true);
      case ScrollDirection.reverse:
        _setVisible(false);
      case ScrollDirection.idle:
        break;
    }
  }

  void _syncAfterLayout() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _onScroll();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Initial attachment and layout/content changes can happen without a
    // user scroll. Inspect the current position after the new layout settles.
    _syncAfterLayout();
    return _HideWhenDismissed(
      animation: _animationController,
      child: widget.child,
    );
  }
}

class KurumiScrollToBottom extends StatefulWidget {
  const KurumiScrollToBottom({
    required this.child,
    super.key,
    this.scrollController,
  });

  final ScrollController? scrollController;
  final Widget child;

  @override
  State<KurumiScrollToBottom> createState() => _KurumiScrollToBottomState();
}

class _KurumiScrollToBottomState extends State<KurumiScrollToBottom>
    with TickerProviderStateMixin {
  late final _scrollController =
      widget.scrollController ?? AutoScrollController();
  late final _animationController = AnimationController(
    vsync: this,
    duration: kThemeAnimationDuration,
    reverseDuration: kThemeAnimationDuration,
  );

  final ValueNotifier<bool> _isOnBottom = ValueNotifier(false);

  ScrollDirection? _lastDirection;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);
    _isOnBottom.addListener(_onBottomReached);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);

    if (widget.scrollController == null) {
      _scrollController.dispose();
    }

    _isOnBottom
      ..removeListener(_onBottomReached)
      ..dispose();

    _animationController.dispose();
    super.dispose();
  }

  void _onBottomReached() {
    if (_isOnBottom.value) {
      _animationController.reverse();
    }
  }

  void _onScroll() {
    final position = _scrollController.position;

    // Avoid redundant animation calls based on scroll direction
    final currentDirection = position.userScrollDirection;
    if (currentDirection != _lastDirection) {
      _lastDirection = currentDirection;

      switch (currentDirection) {
        case ScrollDirection.forward:
          _animationController.reverse();
        case ScrollDirection.reverse:
          _animationController.forward();
        case ScrollDirection.idle:
          break;
      }
      _isOnBottom.value = _scrollController.isBottom;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _HideWhenDismissed(
      animation: _animationController,
      child: widget.child,
    );
  }
}

class _HideWhenDismissed extends StatelessWidget {
  const _HideWhenDismissed({
    required this.animation,
    required this.child,
  });

  final AnimationController animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: animation,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) => ExcludeFocus(
            excluding: animation.isDismissed,
            child: child!,
          ),
          child: child,
        ),
      ),
    );
  }
}

extension KurumiScrollControllerPositionX on ScrollController {
  bool get isTop {
    if (!hasClients) return false;

    return offset == 0;
  }

  bool get isBottom {
    if (!hasClients) return false;

    final maxScroll = position.maxScrollExtent;
    final currentScroll = offset;

    return currentScroll >= (maxScroll * 0.95);
  }
}
