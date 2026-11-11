import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/scheduler.dart' show SchedulerPhase, SchedulerBinding;
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../foundation/mobile.dart';
import '../../../../foundation/platform.dart';
import '../../slideshow/widgets.dart';
import 'page_nav_button.dart';
import 'pointer_count_on_screen.dart';
import 'post_details_overlay.dart';
import 'post_details_page_view_controller.dart';
import 'post_details_shortcuts.dart';
import 'sheet_state_storage.dart';
import 'zoom_page_navigation_scope.dart';

/// One outer pager owns media, its overlay and its scrolling Details content.
class PostDetailsPageView extends StatefulWidget {
  const PostDetailsPageView({
    required this.detailsSliversBuilder,
    required this.itemCount,
    required this.itemBuilder,
    required this.checkIfLargeScreen,
    super.key,
    this.maxSize = 0.7,
    this.controller,
    this.onSwipeDownThresholdReached,
    this.onExit,
    this.onExpanded,
    this.onShrink,
    this.onPageChanged,
    this.swipeDownThreshold = 20,
    this.actions = const [],
    this.leftActions = const [],
    this.bottomSheet,
    this.bottomPreviewBuilder,
    this.pageWrapperBuilder,
    this.mediaSizeBuilder,
    this.occurrenceKeyBuilder,
    this.sheetStateStorage,
    this.disableAnimation = false,
    this.mainContentBuilder,
    this.nextLoading = false,
    this.nextFailed = false,
    this.nextCanLoad = false,
    this.onRetryNext,
    this.onLoadMoreNext,
    this.detailsEnabled = true,
    this.overlayEnabled = true,
    this.isPostPage,
  });

  final List<Widget> Function(BuildContext, int) detailsSliversBuilder;
  final int itemCount;
  final bool detailsEnabled;
  final bool overlayEnabled;
  final bool Function(int)? isPostPage;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder? bottomPreviewBuilder;
  final Widget Function(BuildContext, int, Widget)? pageWrapperBuilder;
  final Size? Function(int)? mediaSizeBuilder;
  final Object Function(int)? occurrenceKeyBuilder;
  final double maxSize;
  final double swipeDownThreshold;
  final List<Widget> actions;
  final List<Widget> leftActions;
  final Widget? bottomSheet;
  final VoidCallback? onSwipeDownThresholdReached;
  final VoidCallback? onExit;
  final VoidCallback? onExpanded;
  final VoidCallback? onShrink;
  final ValueChanged<int>? onPageChanged;
  final PostDetailsPageViewController? controller;
  final SheetStateStorage? sheetStateStorage;
  final bool disableAnimation;
  final bool Function() checkIfLargeScreen;
  final bool nextLoading;
  final bool nextFailed;
  final bool nextCanLoad;
  final VoidCallback? onRetryNext;
  final VoidCallback? onLoadMoreNext;
  final Widget Function(BuildContext, Widget)? mainContentBuilder;

  @override
  State<PostDetailsPageView> createState() => _PostDetailsPageViewState();
}

class _PostDetailsPageViewState extends State<PostDetailsPageView>
    with TickerProviderStateMixin {
  final _interacting = ValueNotifier(false);
  final _scrollOffsets = <Object, double>{};
  EdgeInsets _safeInsets = EdgeInsets.zero;
  Size? _viewportSize;
  static const _edgeSlideDistance = 24.0;
  static const _edgeSlideHalfDuration = Duration(milliseconds: 100);
  late final _edgeSlideController = AnimationController(vsync: this);
  int? _edgeExpectedPage;
  double? _edgeDragDirection;
  var _edgeSlideSerial = 0;
  late final PostDetailsPageViewController _controller;
  late final _overlayAnimController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  late final _bottomInfoAnimController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  late final _overlayAnimation = CurvedAnimation(
    parent: _overlayAnimController,
    curve: Curves.easeOutCirc,
  );
  late final _previewAnimation = CurvedAnimation(
    parent: _bottomInfoAnimController,
    curve: Curves.easeOutCirc,
  );
  bool get isLargeScreen => widget.checkIfLargeScreen();

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        PostDetailsPageViewController(
          initialPage: 0,
          totalPage: widget.itemCount,
          checkIfLargeScreen: widget.checkIfLargeScreen,
          disableAnimation: widget.disableAnimation,
        );
    _controller.pageController.addListener(_onPageChanged);
    _controller.sheetState.addListener(_onModeChanged);
    _controller.attachOverlayAnimController(_overlayAnimController);
    _controller.attachBottomSheetAnimController(_bottomInfoAnimController);
    if (!widget.detailsEnabled) _controller.showOverlay();
    if (widget.detailsEnabled &&
        isLargeScreen &&
        (widget.sheetStateStorage?.loadExpandedState() ?? false)) {
      _controller.expandToSnapPoint();
    }
    _controller.presentationProgress.value = _controller.isExpanded ? 1 : 0;
    if (_controller.initialHideOverlay && widget.detailsEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_controller.overlay.value) hideSystemStatus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant PostDetailsPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detailsEnabled && !widget.detailsEnabled) {
      _controller.sheetState.value = SheetState.collapsed;
      _controller.stopSlideshow();
      _controller.disableHoverToControlOverlay();
      _controller.showOverlay();
    }
    if (oldWidget.itemCount != widget.itemCount ||
        oldWidget.disableAnimation != widget.disableAnimation) {
      _cancelEdgeSlide();
    }
  }

  void _onModeChanged() {
    _controller.bottomObstruction.value = 0;
    if (_controller.isExpanded) {
      widget.onExpanded?.call();
    } else {
      widget.onShrink?.call();
    }
    if (isLargeScreen) {
      widget.sheetStateStorage?.persistExpandedState(_controller.isExpanded);
    }
  }

  void _onPageChanged() {
    final page = _controller.pageController.page;
    if (_edgeExpectedPage case final expected?) {
      if (page == null || (page - expected).abs() > 0.001) _cancelEdgeSlide();
    }
    _controller.precisePage.value = page;
    final number = page?.round();
    if (number == null || number == _controller.page) return;
    _controller.currentPage.value = number;
    widget.onPageChanged?.call(number);
    // Transform ownership belongs to the settled occurrence, not its neighbor.
    _controller.zoom.value = false;
    _controller.enableAllSwiping();
    if (!(widget.isPostPage?.call(number) ?? true)) {
      _controller.bottomObstruction.value = 0;
      _controller.showOverlay();
    } else if (!_controller.isExpanded && _controller.initialHideOverlay) {
      _controller.hideAllUI();
    }
  }

  void _onPop() {
    if (Kurumi.enableHeroTransition && !widget.disableAnimation) {
      _controller.forceHideOverlay.value = true;
      _controller.forceHideBottomSheet.value = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.restoreSystemStatus();
      widget.onExit?.call();
    });
  }

  void _cancelEdgeSlide() {
    if (_edgeExpectedPage == null) return;
    _edgeSlideSerial++;
    _edgeSlideController.stop();
    _edgeExpectedPage = null;
    _edgeDragDirection = null;
    _edgeSlideController.value = 0;
  }

  void _navigateFromEdge(int source, int target) {
    if (!mounted ||
        _edgeExpectedPage != null ||
        (target - source).abs() != 1 ||
        target < 0 ||
        target >= widget.itemCount ||
        _controller.page != source ||
        !_controller.pageController.hasClients) {
      return;
    }

    final precisePage = _controller.pageController.page;
    if (precisePage == null || (precisePage - source).abs() > 0.001) {
      return;
    }

    if (widget.disableAnimation) {
      _controller.jumpToPage(target);
      return;
    }

    final isRtl = Directionality.of(context) == TextDirection.rtl;
    _edgeDragDirection = (target > source ? -1.0 : 1.0) * (isRtl ? -1 : 1);
    _edgeExpectedPage = source;
    _edgeSlideController.value = 0;
    final serial = ++_edgeSlideSerial;
    unawaited(_animateEdgeSlide(source, target, serial));
  }

  Future<void> _animateEdgeSlide(int source, int target, int serial) async {
    try {
      await _edgeSlideController
          .animateTo(
            0.5,
            duration: _edgeSlideHalfDuration,
            curve: Curves.easeOut,
          )
          .orCancel;
      if (!mounted ||
          serial != _edgeSlideSerial ||
          _controller.page != source ||
          target >= widget.itemCount) {
        return;
      }

      _edgeExpectedPage = target;
      _controller.jumpToPage(target);
      await _edgeSlideController
          .animateTo(
            1,
            duration: _edgeSlideHalfDuration,
            curve: Curves.easeOut,
          )
          .orCancel;
    } on TickerCanceled {
      // The route or page changed while the slide was running.
    } finally {
      if (mounted && serial == _edgeSlideSerial) _cancelEdgeSlide();
    }
  }

  @override
  void dispose() {
    _controller.pageController.removeListener(_onPageChanged);
    _controller.sheetState.removeListener(_onModeChanged);
    _controller.detachOverlayAnimController();
    _controller.detachBottomSheetAnimController();
    _controller.scrollDetailsToTop = null;
    _controller.bottomObstruction.value = 0;
    _interacting.dispose();
    _overlayAnimation.dispose();
    _previewAnimation.dispose();
    _overlayAnimController.dispose();
    _bottomInfoAnimController.dispose();
    _edgeSlideController.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = MediaQuery.of(context);
    final physicalInsets = MediaQueryData.fromView(View.of(context))
        .viewPadding;
    if (_viewportSize != query.size) {
      _viewportSize = query.size;
      _safeInsets = EdgeInsets.zero;
    }
    // The navigation shell can briefly supply its app-bar obstruction here.
    // Bound it to actual system insets, respecting any already consumed edges.
    // Keep the last physical inset only while Android's bars are hidden.
    double inset(double physical, double inherited, double previous) =>
        physical > 0 ? math.min(physical, inherited) : previous;
    _safeInsets = EdgeInsets.fromLTRB(
      inset(physicalInsets.left, query.viewPadding.left, _safeInsets.left),
      inset(physicalInsets.top, query.viewPadding.top, _safeInsets.top),
      inset(physicalInsets.right, query.viewPadding.right, _safeInsets.right),
      inset(
        physicalInsets.bottom,
        query.viewPadding.bottom,
        _safeInsets.bottom,
      ),
    );
    final pager = SlideshowOverlay(
      controller: _controller.slideshowController,
      onStop: _controller.stopSlideshow,
      child: _buildPager(),
    );
    return MediaQuery(
      data: query.copyWith(padding: _safeInsets, viewPadding: _safeInsets),
      child: PostDetailsShortcuts(
        controller: _controller,
        isLargeScreen: isLargeScreen,
        child: PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) _onPop();
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: widget.mainContentBuilder?.call(context, pager) ?? pager,
              ),
              if (widget.overlayEnabled)
                PostDetailsOverlay(
                  controller: _controller,
                  leftActions: widget.leftActions,
                  actions: widget.actions,
                  detailsEnabled: widget.detailsEnabled,
                  isLargeScreen: isLargeScreen,
                  overlayCurvedAnimation: widget.disableAnimation
                      ? null
                      : _overlayAnimation,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPager() => PointerCountOnScreen(
    enable: true,
    onCountChanged: (count) => _interacting.value = count > 1,
    child: ListenableBuilder(
      listenable: Listenable.merge([
        _controller.swipe,
        _controller.zoom,
        _controller.sheetState,
        _controller.animating,
        _interacting,
      ]),
      builder: (context, _) {
        final blocked =
            _interacting.value ||
            !_controller.swipe.value ||
            _controller.zoom.value ||
            _controller.animating.value;
        return AnimatedBuilder(
          animation: _edgeSlideController,
          builder: (context, child) {
            final direction = _edgeDragDirection;
            final value = _edgeSlideController.value;
            final outgoing = value <= 0.5;
            final progress = outgoing ? value * 2 : (value - 0.5) * 2;
            return ClipRect(
              child: IgnorePointer(
                ignoring: direction != null,
                child: Opacity(
                  opacity: direction == null
                      ? 1
                      : outgoing
                      ? 1 - progress
                      : progress,
                  child: Transform.translate(
                    offset: Offset(
                      direction == null
                          ? 0
                          : outgoing
                          ? _edgeSlideDistance * progress * direction
                          : -_edgeSlideDistance * (1 - progress) * direction,
                      0,
                    ),
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: PageView.builder(
            controller: _controller.pageController,
            allowImplicitScrolling: true,
            physics: blocked || widget.itemCount < 2
                ? const NeverScrollableScrollPhysics()
                : const _PostDetailsPagePhysics(),
            itemCount: widget.itemCount,
            itemBuilder: (context, index) {
              final key = widget.occurrenceKeyBuilder?.call(index) ?? index;
              final page = _ViewerPage(
                key: ValueKey(key),
                index: index,
                interacting: _interacting,
                controller: _controller,
                previewAnimation: _previewAnimation,
                isPost: widget.isPostPage?.call(index) ?? widget.detailsEnabled,
                disableAnimation: widget.disableAnimation,
                mediaSize: widget.mediaSizeBuilder?.call(index),
                itemBuilder: (context) => _buildMedia(context, index),
                detailsBuilder: (context) =>
                    widget.detailsSliversBuilder(context, index),
                previewBuilder: (context) =>
                    widget.bottomPreviewBuilder?.call(context, index) ??
                    widget.bottomSheet,
                savedOffset: () => _scrollOffsets[key] ?? 0,
                saveOffset: (value) => _scrollOffsets[key] = value,
                onSwipeDown: widget.onSwipeDownThresholdReached,
                swipeDownThreshold: widget.swipeDownThreshold,
              );
              return widget.pageWrapperBuilder?.call(context, index, page) ??
                  page;
            },
          ),
        );
      },
    ),
  );

  Widget _buildMedia(BuildContext context, int index) {
    final last = widget.itemCount - 1;
    final loading = widget.nextLoading && index == last;
    final failed = !loading && widget.nextFailed && index == last;
    final more = !loading && !failed && widget.nextCanLoad && index == last;
    final navigation = ZoomPageNavigationScope(
      previousLabel: context.t.infinite_scroll.previous_page,
      nextLabel: failed
          ? context.t.generic.action.retry
          : more
          ? context.t.infinite_scroll.load_more
          : context.t.infinite_scroll.next_page,
      onPrevious: index > 0
          ? () => _controller.previousPage(duration: Duration.zero)
          : null,
      onEdgePrevious: index > 0
          ? () => _navigateFromEdge(index, index - 1)
          : null,
      previousActionId: index > 0 ? (index - 1, widget.itemCount) : null,
      nextEdgeAction: failed
          ? ZoomPageEdgeAction.retry
          : more
          ? ZoomPageEdgeAction.loadMore
          : ZoomPageEdgeAction.page,
      nextActionId: failed
          ? ('retry', widget.onRetryNext)
          : more
          ? ('load-more', widget.onLoadMoreNext)
          : loading || index == last
          ? null
          : (index + 1, widget.itemCount),
      onNext: failed
          ? widget.onRetryNext
          : more
          ? widget.onLoadMoreNext
          : loading || index == last
          ? null
          : () => _controller.nextPage(duration: Duration.zero),
      onEdgeNext: index < last
          ? () => _navigateFromEdge(index, index + 1)
          : null,
      child: widget.itemBuilder(context, index),
    );
    return Stack(
      children: [
        Positioned.fill(child: navigation),
        if (isDesktopPlatform()) ...[
          PageNavButton(
            alignment: Alignment.centerRight,
            controller: _controller,
            visibleWhen: (page) => page < widget.itemCount - 1,
            icon: const Icon(Symbols.arrow_forward),
            onPressed: () => _controller.nextPage(duration: Duration.zero),
          ),
          PageNavButton(
            alignment: Alignment.centerLeft,
            controller: _controller,
            visibleWhen: (page) => page > 0,
            icon: const Icon(Symbols.arrow_back),
            onPressed: () => _controller.previousPage(duration: Duration.zero),
          ),
        ],
      ],
    );
  }
}

class _ViewerPage extends StatefulWidget {
  const _ViewerPage({
    required this.index,
    required this.interacting,
    required this.controller,
    required this.previewAnimation,
    required this.isPost,
    required this.disableAnimation,
    required this.mediaSize,
    required this.itemBuilder,
    required this.detailsBuilder,
    required this.previewBuilder,
    required this.savedOffset,
    required this.saveOffset,
    required this.onSwipeDown,
    required this.swipeDownThreshold,
    super.key,
  });
  final int index;
  final ValueListenable<bool> interacting;
  final PostDetailsPageViewController controller;
  final Animation<double> previewAnimation;
  final bool isPost;
  final bool disableAnimation;
  final Size? mediaSize;
  final WidgetBuilder itemBuilder;
  final List<Widget> Function(BuildContext) detailsBuilder;
  final Widget? Function(BuildContext) previewBuilder;
  final double Function() savedOffset;
  final ValueChanged<double> saveOffset;
  final VoidCallback? onSwipeDown;
  final double swipeDownThreshold;
  @override
  State<_ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<_ViewerPage>
    with SingleTickerProviderStateMixin {
  late var _current = widget.controller.page == widget.index;
  late final _mode = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 165),
    value: _details ? 1 : 0,
  );
  late final _scroll = ScrollController(
    initialScrollOffset: _details ? widget.savedOffset() : 0,
  );
  late bool _mountedDetails = _details;
  final _pointers = <int>{};
  Offset? _dragOrigin;
  Offset? _pointerPosition;
  Offset _dismissOffset = Offset.zero;
  var _dragging = false;
  var _cancelledMediaDrag = false;
  var _overlayWasVisible = false;
  var _startedInDetails = false;
  var _fromOverlay = false;
  var _scrubbing = false;
  var _rootScrollOwnsDrag = false;
  var _startedAtTop = false;
  double _transitionDistance = 1;
  double _dragStartProgress = 0;

  void _onInteractionChanged() {
    if (widget.interacting.value) _cancelPointerGesture();
  }

  void _pointerDown(PointerDownEvent event, {bool fromOverlay = false}) {
    _pointers.add(event.pointer);
    if (_pointers.length != 1) {
      _cancelPointerGesture();
      return;
    }
    _dragOrigin = _pointerPosition = event.position;
    _cancelledMediaDrag = widget.interacting.value || !_current;
    _overlayWasVisible = widget.controller.overlay.value;
    _startedInDetails = _details;
    _dragStartProgress = _mode.value;
    _startedAtTop = _scroll.hasClients && _scroll.offset <= 0;
    _rootScrollOwnsDrag = false;
    _fromOverlay = fromOverlay;
  }

  void _pointerMove(PointerMoveEvent event) =>
      _updateVerticalDrag(event.position);

  void _updateVerticalDrag(Offset position) {
    _pointerPosition = position;
    final origin = _dragOrigin;
    if (_cancelledMediaDrag || origin == null || _pointers.length != 1) {
      return;
    }
    final delta = position - origin;
    if (!_scrubbing && !_dragging) {
      if (delta.distance < kTouchSlop) return;
      if (delta.dy.abs() <= delta.dx.abs() * 1.5 ||
          (!_fromOverlay && widget.controller.zoom.value)) {
        _cancelledMediaDrag = true;
        return;
      }
      if (_startedInDetails) {
        // Only the root scrollable may authorize a top-edge pull. Nested text,
        // sliders and scrollables keep their own gesture arena ownership.
        if (!_rootScrollOwnsDrag ||
            delta.dy <= 0 ||
            (_scroll.hasClients && _scroll.offset > 0)) {
          return;
        }
      } else if (delta.dy > 0) {
        if (_fromOverlay) return;
        _dragging = true;
      }
      if (!_dragging) {
        _mode.stop();
        _scrubbing = true;
        _mountedDetails = true;
        if (_current) widget.controller.animating.value = true;
      }
    }
    if (_scrubbing) {
      _mode.value = (_dragStartProgress - delta.dy / _transitionDistance).clamp(
        0.0,
        1.0,
      );
      // Starting the gesture must rebuild even if it is already at an endpoint.
      setState(() {});
    } else if (_dragging) {
      widget.controller.freestyleMoving.value = true;
      widget.controller.hideOverlay(includeSystemStatus: false);
      widget.controller.hideBottomSheet();
      setState(() => _dismissOffset = delta);
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (!_startedInDetails || !_startedAtTop || notification.depth != 0) {
      return false;
    }
    final started =
        notification is ScrollStartNotification &&
        notification.dragDetails != null;
    final overscrolled =
        notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.overscroll < 0;
    if ((started || overscrolled) && !_cancelledMediaDrag) {
      _rootScrollOwnsDrag = true;
      final position = _pointerPosition;
      if (position != null) {
        _updateVerticalDrag(position);
      }
    }
    return false;
  }

  void _cancelPointerGesture() {
    _cancelledMediaDrag = true;
    if (_scrubbing) {
      _scrubbing = false;
      // Restore synchronously before the scale recognizer handles a second
      // pointer. No competing vertical recognizer has claimed the image.
      _mode.value = _startedInDetails ? 1 : 0;
      if (_current) widget.controller.animating.value = false;
    }
    _resetDismiss();
  }

  void _resetDismiss() {
    widget.controller.freestyleMoving.value = false;
    if (_dragging && mounted) {
      setState(() {
        _dragging = false;
        _dismissOffset = Offset.zero;
      });
      if (!_details && _overlayWasVisible) widget.controller.showAllUI();
    }
  }

  void _pointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.isNotEmpty) return;
    if (_scrubbing) {
      _scrubbing = false;
      final threshold = math.min(80, _transitionDistance * 0.25);
      final travelled =
          (_mode.value - (_startedInDetails ? 1 : 0)).abs() *
          _transitionDistance;
      final expand = travelled >= threshold
          ? !_startedInDetails
          : _startedInDetails;
      if (expand != _details) {
        if (expand) {
          widget.controller.expandToSnapPoint();
        } else {
          widget.controller.resetSheet();
        }
      } else {
        _settleMode();
      }
    } else if (!_cancelledMediaDrag &&
        _dragging &&
        _dismissOffset.dy > widget.swipeDownThreshold) {
      _resetDismiss();
      if (widget.onSwipeDown != null) {
        widget.onSwipeDown!();
      } else {
        Navigator.of(context).maybePop();
      }
    } else {
      _resetDismiss();
    }
    _dragOrigin = _pointerPosition = null;
  }

  void _pointerCancel(PointerCancelEvent event) {
    _cancelPointerGesture();
    _pointerUp(event);
  }

  double _previewHeight = 0;
  void _reportObstruction(double visibility) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller.page == widget.index && !_details) {
        widget.controller.bottomObstruction.value = _previewHeight * visibility;
      }
    });
  }

  bool get _details => widget.isPost && widget.controller.isExpanded;
  bool get _reduceMotion =>
      widget.disableAnimation || MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _mode.addListener(_publishProgress);
    widget.controller.sheetState.addListener(_modeChanged);
    widget.controller.zoom.addListener(_zoomChanged);
    widget.interacting.addListener(_onInteractionChanged);
    widget.controller.currentPage.addListener(_pageChanged);
    _scroll.addListener(_saveScroll);
    _pageChanged();
  }

  void _publishProgress() {
    void publish() {
      if (mounted && _current) {
        widget.controller.presentationProgress.value = _mode.value;
      }
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => publish());
    } else {
      publish();
    }
  }

  void _saveScroll() {
    if (_details && !_scrubbing && !_mode.isAnimating && _scroll.hasClients) {
      widget.saveOffset(_scroll.offset);
    }
  }

  void _zoomChanged() {
    if (widget.controller.zoom.value && !_fromOverlay) _cancelPointerGesture();
  }

  void _pageChanged() {
    final current = widget.controller.page == widget.index;
    if (current != _current) setState(() => _current = current);
    if (widget.controller.page == widget.index) {
      _publishProgress();
      widget.controller.scrollDetailsToTop = _scrollToTop;
      _reportObstruction(
        _details || !widget.controller.bottomSheet.value
            ? 0
            : widget.disableAnimation
            ? 1
            : widget.previewAnimation.value,
      );
    }
  }

  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    if (_reduceMotion) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 165),
        curve: Curves.easeOut,
      );
    }
  }

  void _modeChanged() {
    if (!mounted || !widget.isPost) return;
    if (_pointers.isNotEmpty) _cancelPointerGesture();
    if (_details) {
      _mountedDetails = true;
    } else if (_scroll.hasClients) {
      widget.saveOffset(_scroll.offset);
      _scroll.jumpTo(0);
    }
    setState(() {});
    _settleMode();
  }

  void _settleMode() {
    if (_current) widget.controller.animating.value = true;
    if (_reduceMotion) {
      _mode.value = _details ? 1 : 0;
      _restoreOffset();
      if (_current) widget.controller.animating.value = false;
    } else {
      _mode
          .animateTo(
            _details ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          )
          .orCancel
          .then(
            (_) {
              if (!mounted) return;
              _restoreOffset();
              if (_current) widget.controller.animating.value = false;
            },
            onError: (Object error) {
              if (error is! TickerCanceled) {
                Error.throwWithStackTrace(error, StackTrace.current);
              }
            },
          );
    }
  }

  void _restoreOffset() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_details || !_scroll.hasClients) return;
      _scroll.jumpTo(
        widget.savedOffset().clamp(0, _scroll.position.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    widget.controller.sheetState.removeListener(_modeChanged);
    widget.controller.zoom.removeListener(_zoomChanged);
    widget.interacting.removeListener(_onInteractionChanged);
    widget.controller.currentPage.removeListener(_pageChanged);
    _saveScroll();
    _scroll.removeListener(_saveScroll);
    _scroll.dispose();
    _mode.removeListener(_publishProgress);
    _mode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(excluding: !_current, child: _buildPage(context));
  }

  Widget _buildPage(BuildContext context) {
    if (!widget.isPost) return widget.itemBuilder(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.viewPaddingOf(context);
        final safeWidth = constraints.maxWidth - padding.horizontal;
        final usable = math.max(0, constraints.maxHeight - padding.vertical);
        final ceiling = usable * 0.6;
        final size = widget.mediaSize;
        final ratio = size != null && size.width > 0 && size.height > 0
            ? size.width / size.height
            : double.nan;
        final natural = ratio.isFinite && ratio > 0
            ? safeWidth / ratio
            : ceiling;
        final minimum = math.min(
          ceiling,
          (usable * 0.2).clamp(158.0, 188.0),
        );
        final detailsHeight = natural.clamp(minimum, ceiling);
        final contentSize = size != null && ratio.isFinite && ratio > 0
            ? size
            : constraints.biggest;
        final immersiveFit = applyBoxFit(
          BoxFit.contain,
          contentSize,
          constraints.biggest,
        ).destination;
        final detailsFit = applyBoxFit(
          BoxFit.contain,
          contentSize,
          Size(safeWidth, math.max(1, detailsHeight)),
        ).destination;
        final targetScale = immersiveFit.width > 0
            ? detailsFit.width / immersiveFit.width
            : 1.0;
        final targetOffset =
            Offset(
              safeWidth / 2,
              ratio > 3
                  ? detailsHeight - detailsFit.height / 2
                  : detailsHeight / 2,
            ) -
            Offset(constraints.maxWidth / 2, constraints.maxHeight / 2) *
                targetScale;
        _transitionDistance = math.max(
          1,
          constraints.maxHeight - padding.top - detailsHeight,
        );
        final media = widget.itemBuilder(context);
        final preview = widget.previewBuilder(context);
        return AnimatedBuilder(
          animation: _mode,
          builder: (context, _) {
            final progress = _mode.value;
            return Stack(
              children: [
                Positioned(
                  left: padding.left * progress,
                  top: padding.top * progress,
                  right: padding.right * progress,
                  bottom: padding.bottom * progress,
                  child: ClipRect(
                    key: ValueKey(('viewer-safe-viewport', widget.index)),
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _pointerDown,
                      onPointerMove: _pointerMove,
                      onPointerUp: _pointerUp,
                      onPointerCancel: _pointerCancel,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _onScrollNotification,
                        child: CustomScrollView(
                          key: ValueKey((
                            'viewer-details-scroll',
                            widget.index,
                          )),
                          controller: _scroll,
                          // Stretching overscroll would add a second transform
                          // to the same finger-driven top-edge transition.
                          scrollBehavior: ScrollConfiguration.of(context)
                              .copyWith(overscroll: false),
                          physics: _details
                              ? _ViewerDetailsPhysics(hold: () => _scrubbing)
                              : const NeverScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: SizedBox(
                                key: ValueKey(('viewer-media', widget.index)),
                                height: lerpDouble(
                                  constraints.maxHeight,
                                  detailsHeight,
                                  progress,
                                ),
                                child: ClipRect(
                                  child: OverflowBox(
                                    alignment: Alignment.topLeft,
                                    minWidth: constraints.maxWidth,
                                    maxWidth: constraints.maxWidth,
                                    minHeight: constraints.maxHeight,
                                    maxHeight: constraints.maxHeight,
                                    child: Transform(
                                      alignment: Alignment.topLeft,
                                      transform: Matrix4.identity()
                                        ..translateByDouble(
                                          targetOffset.dx * progress,
                                          targetOffset.dy * progress,
                                          0,
                                          1,
                                        )
                                        ..scaleByDouble(
                                          lerpDouble(1, targetScale, progress)!,
                                          lerpDouble(1, targetScale, progress)!,
                                          1,
                                          1,
                                        ),
                                      child: TweenAnimationBuilder<Offset>(
                                        tween: Tween(
                                          begin: Offset.zero,
                                          end: _dismissOffset,
                                        ),
                                        duration: _dragging || _reduceMotion
                                            ? Duration.zero
                                            : const Duration(milliseconds: 165),
                                        builder: (context, offset, child) =>
                                            Transform.translate(
                                              offset: offset,
                                              child: Transform.scale(
                                                scale:
                                                    1 -
                                                    (offset.dy.abs() /
                                                            widget
                                                                .swipeDownThreshold *
                                                            0.2)
                                                        .clamp(0.0, 0.2),
                                                child: child,
                                              ),
                                            ),
                                        child: ViewerPresentationTransition(
                                          progress: progress,
                                          child: media,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_mountedDetails)
                              SliverOffstage(
                                offstage: progress == 0,
                                sliver: ExcludeFocus(
                                  excluding: !_details || progress == 0,
                                  child: SliverOpacity(
                                    opacity: progress,
                                    sliver: SliverMainAxisGroup(
                                      slivers: [
                                        ...widget.detailsBuilder(context),
                                        const SliverToBoxAdapter(
                                          child: SizedBox(
                                            height: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (preview != null && progress < 1)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        widget.controller.bottomSheet,
                        widget.controller.forceHideBottomSheet,
                        widget.previewAnimation,
                      ]),
                      builder: (context, _) {
                        final visible =
                            !widget.controller.forceHideBottomSheet.value &&
                            widget.controller.bottomSheet.value;
                        final visibility =
                            (widget.disableAnimation
                                ? (visible ? 1.0 : 0.0)
                                : widget.previewAnimation.value) *
                            (1 - progress * 2).clamp(0.0, 1.0);
                        _reportObstruction(visibility);
                        return IgnorePointer(
                          ignoring: !visible || _details || visibility == 0,
                          child: ExcludeFocus(
                            excluding: !visible || _details || visibility == 0,
                            child: FractionalTranslation(
                              translation: Offset(0, 1 - visibility),
                              child: Listener(
                                onPointerDown: (event) =>
                                    _pointerDown(event, fromOverlay: true),
                                onPointerMove: _pointerMove,
                                onPointerUp: _pointerUp,
                                onPointerCancel: _pointerCancel,
                                child: _OverlayDragSurface(
                                  controller: widget.controller,
                                  child: KurumiMeasureSize(
                                    onChange: (size) {
                                      _previewHeight = size.height;
                                      if (mounted &&
                                          widget.controller.page ==
                                              widget.index &&
                                          !_details) {
                                        widget
                                                .controller
                                                .bottomObstruction
                                                .value =
                                            size.height * visibility;
                                      }
                                    },
                                    child: SafeArea(
                                      top: false,
                                      bottom: false,
                                      child: preview,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The same progress drives the media's zoom return and its outer layout.
class ViewerPresentationTransition extends InheritedWidget {
  const ViewerPresentationTransition({
    required this.progress,
    required super.child,
    super.key,
  });
  final double progress;
  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ViewerPresentationTransition>()
          ?.progress ??
      0;
  @override
  bool updateShouldNotify(ViewerPresentationTransition oldWidget) =>
      progress != oldWidget.progress;
}

/// A toolbar drag participates in the arena, cancelling button taps, and drives
/// the same outer ScrollPosition even when zoom owns drags on the image itself.
class _OverlayDragSurface extends StatefulWidget {
  const _OverlayDragSurface({required this.controller, required this.child});
  final PostDetailsPageViewController controller;
  final Widget child;
  @override
  State<_OverlayDragSurface> createState() => _OverlayDragSurfaceState();
}

class _OverlayDragSurfaceState extends State<_OverlayDragSurface> {
  Drag? _drag;
  final _pointers = <int>{};
  var _cancelled = false;
  int? _startPage;

  void _cancelDrag() {
    final drag = _drag;
    _drag = null;
    drag?.cancel();
    if (drag != null && _startPage != null) {
      final page = _startPage!;
      widget.controller.animateToPage(page);
    }
  }

  @override
  void dispose() {
    _drag?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      _pointers.add(event.pointer);
      if (_pointers.length > 1) {
        _cancelled = true;
        _cancelDrag();
      }
    },
    onPointerUp: _endPointer,
    onPointerCancel: (event) {
      _cancelDrag();
      _endPointer(event);
    },
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (details) {
        if (_cancelled) return;
        _startPage = widget.controller.page;
        _drag = widget.controller.pageController.position.drag(
          details,
          () => _drag = null,
        );
      },
      onHorizontalDragUpdate: (details) {
        if (!_cancelled) _drag?.update(details);
      },
      onHorizontalDragEnd: (details) {
        final drag = _drag;
        _drag = null;
        if (!_cancelled) drag?.end(details);
      },
      onHorizontalDragCancel: _cancelDrag,
      // Claim a vertical toolbar drag so its buttons do not tap/hold. The page's
      // pointer observer drives presentation directly, without claiming media.
      onVerticalDragUpdate: (_) {},
      child: widget.child,
    ),
  );

  void _endPointer(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.isEmpty) {
      // Up is delivered to the recognizer after this Listener.
      scheduleMicrotask(() {
        if (mounted && _pointers.isEmpty) _cancelled = false;
      });
    }
  }
}

class _ViewerDetailsPhysics extends ClampingScrollPhysics {
  const _ViewerDetailsPhysics({required this.hold, super.parent});
  final bool Function() hold;

  @override
  _ViewerDetailsPhysics applyTo(ScrollPhysics? ancestor) =>
      _ViewerDetailsPhysics(hold: hold, parent: buildParent(ancestor));

  // A top-edge mode pull is available even when the metadata fit on screen.
  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      hold() ? 0 : super.applyPhysicsToUserOffset(position, offset);
}

// Disables deferred image loading during page transitions.
// Flutter's ScrollAwareImageProvider defers image loading when scroll velocity
// is high, which can cause images (especially GIFs) to silently never load
// if the widget is disposed before the deferred retry fires.
// See https://github.com/flutter/flutter/pull/48536
class _PostDetailsPagePhysics extends ScrollPhysics {
  const _PostDetailsPagePhysics({super.parent});

  @override
  _PostDetailsPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _PostDetailsPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 40,
  );

  @override
  bool recommendDeferredLoading(
    double velocity,
    ScrollMetrics metrics,
    BuildContext context,
  ) => false;
}
