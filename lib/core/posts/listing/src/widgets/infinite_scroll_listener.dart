// Package imports:
import 'package:kurumi/material.dart';

class InfiniteScrollListener extends StatefulWidget {
  const InfiniteScrollListener({
    required this.scrollController,
    required this.onBottomReached,
    super.key,
    this.prefetchExtentFactor = 2,
    this.child,
  });

  final ScrollController scrollController;
  final VoidCallback? onBottomReached;
  final double prefetchExtentFactor;
  final Widget? child;

  @override
  State<InfiniteScrollListener> createState() => _InfiniteScrollListenerState();
}

class _InfiniteScrollListenerState extends State<InfiniteScrollListener> {
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  @override
  void didUpdateWidget(InfiniteScrollListener oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  void _onScroll() {
    final callback = widget.onBottomReached;
    if (callback == null) return;

    if (!widget.scrollController.hasClients) return;

    final position = widget.scrollController.position;
    final prefetchExtent =
        position.viewportDimension * widget.prefetchExtentFactor;

    if (position.extentAfter <= prefetchExtent) {
      callback();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child ?? const SizedBox.shrink();
  }
}
