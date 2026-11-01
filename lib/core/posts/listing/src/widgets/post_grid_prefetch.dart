import 'dart:async';

import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:kurumi/material.dart';

import '../types/page_mode.dart';
import 'post_grid_controller.dart';

/// Starts sequential pages before the viewport reaches the end, including
/// short pages which do not produce a scroll event. Layout-only continuation
/// is bounded; explicit scrolling or refresh starts another fill cycle.
class PostGridPrefetch extends StatefulWidget {
  const PostGridPrefetch({
    required this.controller,
    required this.scrollController,
    required this.child,
    super.key,
  });
  final PostGridController controller;
  final ScrollController scrollController;
  final Widget child;
  @override
  State<PostGridPrefetch> createState() => _PostGridPrefetchState();
}

class _PostGridPrefetchState extends State<PostGridPrefetch> {
  var _scheduled = false;
  var _layoutRequests = 0;
  static const _layoutBudget = 3;

  @override
  void initState() {
    super.initState();
    _attach();
    _changed();
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
  void didUpdateWidget(PostGridPrefetch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.scrollController != oldWidget.scrollController) {
      _detach(oldWidget);
      _layoutRequests = 0;
      _attach();
      _changed();
    }
  }

  void _changed() {
    if (widget.controller.refreshing) _layoutRequests = 0;
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _prefetch(fromLayout: true);
    });
  }

  void _scrolled() {
    if (widget.scrollController.positions.length != 1) return;
    if (widget.scrollController.position.userScrollDirection !=
        ScrollDirection.idle) {
      _layoutRequests = 0;
    }
    _prefetch(fromLayout: false);
  }

  void _prefetch({required bool fromLayout}) {
    final controller = widget.controller;
    if (controller.refreshing ||
        controller.loadingMore ||
        !controller.hasMore ||
        controller.errors.value != null ||
        controller.items.isEmpty ||
        controller.pageMode != PageMode.infinite ||
        widget.scrollController.positions.length != 1 ||
        (fromLayout && _layoutRequests >= _layoutBudget))
      return;
    final position = widget.scrollController.position;
    if (!position.hasContentDimensions ||
        position.extentAfter > position.viewportDimension * 2)
      return;
    if (fromLayout) _layoutRequests++;
    unawaited(controller.fetchMore());
  }

  @override
  void dispose() {
    _detach(widget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
