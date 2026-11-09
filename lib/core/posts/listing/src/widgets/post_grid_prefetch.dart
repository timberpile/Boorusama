import 'dart:async';

import 'package:kurumi/material.dart';

import '../../../../navigation/destination_activity.dart';
import '../types/page_mode.dart';
import '../types/timeline_continuation_controller.dart';

/// Owns automatic continuation for one post timeline. Short and empty pages
/// share a bounded fill cycle; scrolling or refresh starts a new cycle.
class PostGridPrefetch extends StatefulWidget {
  const PostGridPrefetch({
    required this.controller,
    required this.scrollController,
    required this.child,
    super.key,
  });
  final TimelineContinuationController controller;
  final ScrollController scrollController;
  final Widget child;
  @override
  State<PostGridPrefetch> createState() => _PostGridPrefetchState();
}

class _PostGridPrefetchState extends State<PostGridPrefetch>
    with WidgetsBindingObserver {
  var _scheduled = false;
  var _layoutRequests = 0;
  var _attached = true;
  var _navigationActive = false;
  late bool _foreground;
  ModalRoute<dynamic>? _route;
  static const _layoutBudget = 3;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _attach();
  }

  void _attach() {
    widget.controller.addListener(_changed);
    widget.scrollController.addListener(_scrolled);
  }

  void _detach(PostGridPrefetch host) {
    host.controller.removeListener(_changed);
    host.scrollController.removeListener(_scrolled);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigationActive = NavigationActivity.of(context);
    _route = ModalRoute.of(context);
    _schedule();
  }

  @override
  void didUpdateWidget(PostGridPrefetch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.scrollController != oldWidget.scrollController) {
      _detach(oldWidget);
      _layoutRequests = 0;
      _attach();
      _schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _schedule();
  }

  @override
  void deactivate() {
    _attached = false;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _attached = true;
    _schedule();
  }

  void _changed() {
    if (widget.controller.refreshing) _layoutRequests = 0;
    _schedule();
  }

  void _schedule() {
    if (!mounted) return;
    if (!_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (mounted && _attached) _prefetch();
      });
    }
    // Completions need not coincide with a scheduled layout frame.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _scrolled() {
    if (widget.scrollController.positions.length != 1) return;
    // Include keyboard, wheel and programmatic scrolling. Layout corrections
    // do not notify ScrollController; metrics changes retain the fill budget.
    _layoutRequests = 0;
    _schedule();
  }

  bool _canStart() {
    if (!mounted ||
        !_attached ||
        !_foreground ||
        !_navigationActive ||
        !(_route?.isCurrent ?? true) ||
        widget.controller.refreshing ||
        !widget.controller.hasMore ||
        widget.controller.errors.value != null ||
        widget.controller.pageMode != PageMode.infinite ||
        widget.scrollController.positions.length != 1) {
      return false;
    }
    final position = widget.scrollController.position;
    return position.hasContentDimensions &&
        position.viewportDimension > 0 &&
        position.extentAfter <= position.viewportDimension * 2;
  }

  void _prefetch() {
    final controller = widget.controller;
    if (!_canStart() ||
        controller.loadingMore ||
        _layoutRequests >= _layoutBudget) {
      return;
    }
    _layoutRequests++;
    final scrollController = widget.scrollController;
    unawaited(
      controller.fetchMore(
        // Check again at dispatch, not only before the debounce interval.
        canStart: () =>
            mounted &&
            identical(controller, widget.controller) &&
            identical(scrollController, widget.scrollController) &&
            _canStart(),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detach(widget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 &&
              widget.scrollController.positions.length == 1 &&
              notification.metrics.axis ==
                  widget.scrollController.position.axis) {
            _schedule();
          }
          return false;
        },
        child: widget.child,
      );
}
