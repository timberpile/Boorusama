// Dart imports:
import 'dart:async';

// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../foundation/mobile.dart';
import '../../../../foundation/platform.dart';
import '../../slideshow/widgets.dart';
import 'constants.dart';
import 'drag_sheet.dart';
import 'page_nav_button.dart';
import 'pointer_count_on_screen.dart';
import 'post_details_overlay.dart';
import 'post_details_page_view_controller.dart';
import 'post_details_shortcuts.dart';
import 'sheet_state_storage.dart';
import 'side_sheet.dart';
import 'zoom_page_navigation_scope.dart';

// Dart imports:
// ignore_for_file: prefer_int_literals

enum ViewMode {
  horizontal,
  vertical,
}

const _kBottomPreviewSwipeThreshold = 32.0;
const _kBottomPreviewVerticalDominance = 1.5;
const _kExpandedMediaSwipeThreshold = 32.0;
const _kExpandedMediaVerticalDominance = 1.5;

class PostDetailsPageView extends StatefulWidget {
  const PostDetailsPageView({
    required this.sheetBuilder,
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
    this.sheetStateStorage,
    this.disableAnimation = false,
    this.viewMode = ViewMode.horizontal,
    this.mainContentBuilder,
    this.nextLoading = false,
    this.nextFailed = false,
    this.nextCanLoad = false,
    this.onRetryNext,
    this.onLoadMoreNext,
  });

  final Widget Function(BuildContext, ScrollController? scrollController)
  sheetBuilder;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double maxSize;
  final double swipeDownThreshold;

  final List<Widget> actions;
  final List<Widget> leftActions;
  final Widget? bottomSheet;

  final void Function()? onSwipeDownThresholdReached;
  final void Function()? onExit;
  final void Function()? onExpanded;
  final void Function()? onShrink;
  final void Function(int page)? onPageChanged;

  final PostDetailsPageViewController? controller;
  final SheetStateStorage? sheetStateStorage;

  final bool disableAnimation;
  final bool Function() checkIfLargeScreen;
  final ViewMode viewMode;
  final bool nextLoading;
  final bool nextFailed;
  final bool nextCanLoad;
  final VoidCallback? onRetryNext;
  final VoidCallback? onLoadMoreNext;

  // Terrible hack to allow wrapping main content with MouseRegion from outside
  final Widget Function(BuildContext context, Widget child)? mainContentBuilder;

  @override
  State<PostDetailsPageView> createState() => _PostDetailsPageViewState();
}

class _PostDetailsPageViewState extends State<PostDetailsPageView>
    with TickerProviderStateMixin {
  final _pointerCount = ValueNotifier(0);
  final _interacting = ValueNotifier(false);
  var _freestyleMoveStartOffset = Offset.zero;
  var _freestyleMoveScale = 1.0;
  var _handledExpandedMediaSwipe = false;

  static const _edgeSlideDistance = 24.0;
  static const _edgeSlideHalfDuration = Duration(milliseconds: 100);
  late final _edgeSlideController = AnimationController(vsync: this);
  int? _edgeExpectedPage;
  double? _edgeDragDirection;
  var _edgeSlideSerial = 0;

  late final PostDetailsPageViewController _controller;

  late final _overlayAnimController = !widget.disableAnimation
      ? AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 150),
        )
      : null;

  late final _overlayCurvedAnimation = _overlayAnimController != null
      ? CurvedAnimation(
          parent: _overlayAnimController,
          curve: Curves.easeOutCirc,
        )
      : null;

  late final _bottomInfoAnimController = !widget.disableAnimation
      ? AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 150),
        )
      : null;

  late final _bottomInfoCurvedAnimation = _bottomInfoAnimController != null
      ? CurvedAnimation(
          parent: _bottomInfoAnimController,
          curve: Curves.easeOutCirc,
        )
      : null;

  final _isSheetAnimating = ValueNotifier(false);

  late AnimationController _sheetAnimController;
  late Animation<double> _displacementAnim;
  late Animation<Offset> _sideSheetSlideAnim;

  bool get isLargeScreen => widget.checkIfLargeScreen();
  bool get isVerticalMode => widget.viewMode == ViewMode.vertical;
  bool get useVerticalLayout => isVerticalMode && !isLargeScreen;

  @override
  void initState() {
    super.initState();

    // Single animation controller to sync displacement and side sheet slide
    _sheetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Animate the displacement box width
    _displacementAnim =
        Tween<double>(
          begin: 0.0,
          end: kSideSheetWidth,
        ).animate(
          CurvedAnimation(
            parent: _sheetAnimController,
            curve: Curves.easeInOut,
          ),
        );

    // Animate the side sheet's position from offscreen to onscreen
    _sideSheetSlideAnim =
        Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _sheetAnimController,
            curve: Curves.easeInOut,
          ),
        );

    _controller =
        widget.controller ??
        PostDetailsPageViewController(
          initialPage: 0,
          checkIfLargeScreen: widget.checkIfLargeScreen,
          totalPage: widget.itemCount,
          viewMode: widget.viewMode,
        );

    _controller.pageController.addListener(_onPageChanged);
    _controller.sheetController.addListener(_onSheetChanged);
    _controller.verticalPosition.addListener(_onVerticalPositionChanged);
    _controller.sheetState.addListener(_onSheetStateChanged);
    _controller
      ..attachOverlayAnimController(_overlayAnimController)
      ..attachBottomSheetAnimController(_bottomInfoAnimController);

    _isSheetAnimating.addListener(_onSheetAnimatingChanged);

    final currentExpanded = _controller.sheetState.value.isExpanded;

    // auto expand side sheet if it was expanded before
    if (isLargeScreen && !currentExpanded && !isVerticalMode) {
      final expanded = widget.sheetStateStorage?.loadExpandedState();

      if (expanded ?? false) {
        _controller.sheetState.value = SheetState.expanded;
        // Set the controller value immediately to skip the opening animation
        _sheetAnimController.value = 1;
      }
    }

    if (_controller.initialHideOverlay) {
      Future.delayed(
        const Duration(milliseconds: 250),
        () {
          if (!mounted) return;
          hideSystemStatus();
        },
      );
    }
  }

  @override
  void didUpdateWidget(PostDetailsPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount ||
        oldWidget.viewMode != widget.viewMode ||
        oldWidget.disableAnimation != widget.disableAnimation) {
      _cancelEdgeSlide();
    }
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

  void _onSheetAnimatingChanged() {
    // Only control overlay when in expanded state
    if (!_controller.sheetState.value.isExpanded) return;
  }

  void _onPageChanged() {
    final page = _controller.pageController.page;
    if (_edgeExpectedPage case final expected?) {
      if (page == null || (page - expected).abs() > 0.001) {
        _cancelEdgeSlide();
      }
    }

    _controller.precisePage.value = page;

    final pageNum = page?.round();

    if (pageNum == null) return;

    if (pageNum != _controller.page) {
      _controller.currentPage.value = pageNum;

      _controller.sheetState.value = switch (_controller.sheetState.value) {
        SheetState.expanded => SheetState.expanded,
        SheetState.collapsed => SheetState.collapsed,
        SheetState.hidden => SheetState.collapsed,
      };

      widget.onPageChanged?.call(pageNum);

      // Hide UI elements when page changes
      if (_controller.initialHideOverlay && !isLargeScreen) {
        _controller.hideAllUI();
      }
    }
  }

  void _onVerticalPositionChanged() {
    if (_controller.animating.value || _controller.isExpanded) return;

    final dy = _controller.verticalPosition.value;

    if (dy > 0) return;

    final size = _controller.sheetController.pixelsToSize(dy.abs());

    _controller.sheetController.jumpTo(size);
  }

  void _onSheetChanged() {
    final size = _controller.sheetController.size;

    if (size > widget.maxSize) {
      return;
    }

    final dis = _clampToZero(_controller.sheetController.sizeToPixels(size));

    _controller.setDisplacement(dis);

    // Handle case when sheet is closed by dragging down, this is not handled by the controller
    if (dis <= 0 && _controller.isExpanded) {
      _controller.sheetState.value = SheetState.hidden;
    }

    if (dis <= 200 && _controller.isExpanded) {
      if (!_controller.previouslyForcedShowUIByDrag) {
        // Delay to next frame to wait for the sheet state to change before showing the overlay
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _controller.showBottomSheet();
        });
      } else {
        // UI was previously forced to show by drag, so we don't want to show it again here
      }
    }
  }

  void _onSheetStateChanged() {
    if (_controller.isExpanded) {
      widget.onExpanded?.call();
    } else {
      if (_controller.sheetState.value == SheetState.hidden) {
        widget.onShrink?.call();
      }

      // Hide UI elements when sheet is collapsed if it was previously forced to show by drag
      if (_controller.previouslyForcedShowUIByDrag) {
        _controller
          ..hideOverlay()
          ..previouslyForcedShowUIByDrag = false;
      }
    }

    if (isLargeScreen && !isVerticalMode) {
      widget.sheetStateStorage?.persistExpandedState(_controller.isExpanded);
    }

    // sync the side sheet slide animation with the sheet state
    _sheetAnimController.value = _controller.isExpanded ? 1 : 0;
  }

  @override
  void dispose() {
    _controller.sheetState.removeListener(_onSheetStateChanged);
    _controller.pageController.removeListener(_onPageChanged);
    _controller.sheetController.removeListener(_onSheetChanged);

    _controller
      ..detachOverlayAnimController()
      ..detachBottomSheetAnimController();

    _isSheetAnimating.removeListener(_onSheetAnimatingChanged);

    _pointerCount.dispose();
    _interacting.dispose();
    _isSheetAnimating.dispose();
    _edgeSlideController.dispose();

    _overlayCurvedAnimation?.dispose();
    _overlayAnimController?.dispose();
    _sheetAnimController.dispose();
    _bottomInfoAnimController?.dispose();
    _bottomInfoCurvedAnimation?.dispose();

    if (widget.controller == null) {
      _controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PostDetailsShortcuts(
      controller: _controller,
      useVerticalLayout: useVerticalLayout,
      isLargeScreen: isLargeScreen,
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: SlideshowOverlay(
                  controller: _controller.slideshowController,
                  onStop: _controller.stopSlideshow,
                  child: switch (widget.mainContentBuilder) {
                    null => _buildMain(),
                    final builder => builder(
                      context,
                      _buildMain(),
                    ),
                  },
                ),
              ),
              if (!isLargeScreen)
                const SizedBox.shrink()
              else if (!widget.disableAnimation)
                AnimatedBuilder(
                  animation: _displacementAnim,
                  builder: (context, child) {
                    return SizedBox(width: _displacementAnim.value);
                  },
                )
              else
                _buildSideSheet(),
              ValueListenableBuilder(
                valueListenable: _controller.sheetState,
                builder: (_, state, _) => PopScope(
                  canPop: switch (isLargeScreen) {
                    true => true,
                    false => !state.isExpanded,
                  },
                  onPopInvokedWithResult: (didPop, _) {
                    if (didPop) {
                      _onPop();
                    } else {
                      if (_controller.isExpanded) {
                        _controller.resetSheet();
                        return;
                      }
                    }
                  },
                  child: const SizedBox.shrink(),
                ),
              ),
            ],
          ),
          if (isLargeScreen && !widget.disableAnimation)
            Align(
              alignment: Alignment.centerRight,
              child: SlideTransition(
                position: _sideSheetSlideAnim,
                child: _buildSideSheet(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSideSheet() {
    return ValueListenableBuilder(
      valueListenable: _controller.forceHideOverlay,
      builder: (_, hide, child) => hide ? const SizedBox.shrink() : child!,
      child: SideSheet(
        controller: _controller,
        sheetBuilder: widget.sheetBuilder,
        animationController: _sheetAnimController,
      ),
    );
  }

  Widget _buildMain() {
    final bottomSheet = widget.bottomSheet;

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: _interacting,
                  builder: (_, interacting, _) => ValueListenableBuilder(
                    valueListenable: _controller.swipe,
                    builder: (_, swipe, _) => _buildPageView(
                      swipe,
                      interacting,
                    ),
                  ),
                ),
              ),
              _buildBottomDisplacement(),
            ],
          ),
        ),
        if (bottomSheet != null && !isLargeScreen)
          Align(
            alignment: Alignment.bottomCenter,
            child: ValueListenableBuilder(
              valueListenable: _controller.forceHideBottomSheet,
              builder: (_, hide, _) => hide
                  ? const SizedBox.shrink()
                  : _BottomPreviewSwipeDetector(
                      onSwipeUp: _expandFromBottomPreview,
                      child: _bottomInfoAnimController != null
                          ? SlideTransition(
                              position: Tween(
                                begin: const Offset(0, 1),
                                end: Offset.zero,
                              ).animate(_bottomInfoAnimController),
                              child: ColoredBox(
                                color: Kurumi.themeOf(
                                  context,
                                ).colorScheme.surface,
                                child: FadeTransition(
                                  opacity:
                                      Tween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: _bottomInfoAnimController,
                                          curve: Curves.easeInCubic,
                                        ),
                                      ),
                                  child: bottomSheet,
                                ),
                              ),
                            )
                          : bottomSheet,
                    ),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: !isLargeScreen
              ? DragSheet(
                  sheetBuilder: widget.sheetBuilder,
                  pageViewController: _controller,
                  isSheetAnimating: _isSheetAnimating,
                )
              : const SizedBox.shrink(),
        ),
        PostDetailsOverlay(
          controller: _controller,
          leftActions: widget.leftActions,
          actions: widget.actions,
          useVerticalLayout: useVerticalLayout,
          isLargeScreen: isLargeScreen,
          sheetAnimController: _sheetAnimController,
          overlayCurvedAnimation: _overlayCurvedAnimation,
          disableAnimation: widget.disableAnimation,
        ),
      ],
    );
  }

  void _expandFromBottomPreview() {
    if (_controller.isExpanded || _controller.animating.value) return;

    _controller
      ..hideBottomSheet()
      ..expandToSnapPoint();
  }

  Widget _buildBottomDisplacement() {
    return !isLargeScreen
        ? ValueListenableBuilder(
            valueListenable: _controller.sheetMaxSize,
            builder: (_, maxSize, _) => ValueListenableBuilder(
              valueListenable: _controller.sheetState,
              builder: (_, state, _) => ValueListenableBuilder(
                valueListenable: _controller.displacement,
                builder: (context, dis, child) {
                  final maxSheetSize =
                      maxSize * MediaQuery.sizeOf(context).longestSide;

                  return state.isExpanded &&
                          dis >
                              maxSheetSize -
                                  0.01 // 0.01 is for rounding error e.g: 419.99999999999
                      ? SizedBox(
                          height: maxSheetSize,
                        )
                      : ValueListenableBuilder(
                          valueListenable: _pointerCount,
                          builder: (_, count, _) => SizedBox(
                            height: dis,
                          ),
                        );
                },
              ),
            ),
          )
        : const SizedBox.shrink();
  }

  Widget _buildPageView(
    bool swipe,
    bool interacting,
  ) {
    final isPortrait = !context.isLargeScreen;

    return ValueListenableBuilder(
      valueListenable: _controller.sheetState,
      builder: (_, state, _) {
        final blockSwipe = !swipe || state.isExpanded || interacting;

        return AnimatedBuilder(
          animation: _edgeSlideController,
          builder: (context, child) {
            final dragDirection = _edgeDragDirection;
            final isSliding = dragDirection != null;

            final value = _edgeSlideController.value;
            final outgoing = value <= 0.5;
            final progress = outgoing ? value * 2 : (value - 0.5) * 2;
            final offset = outgoing
                ? _edgeSlideDistance * progress * (dragDirection ?? 0)
                : -_edgeSlideDistance * (1 - progress) * (dragDirection ?? 0);
            final opacity = isSliding
                ? (outgoing ? 1 - progress : progress)
                : 1.0;

            return ClipRect(
              child: IgnorePointer(
                ignoring: isSliding,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: PageView.builder(
            scrollDirection: useVerticalLayout
                ? Axis.vertical
                : Axis.horizontal,
            onPageChanged: blockSwipe && !isPortrait
                ? (_) => _controller.startCooldownTimer()
                : null,
            controller: _controller.pageController,
            physics: blockSwipe || widget.itemCount < 2
                ? const NeverScrollableScrollPhysics()
                : const _PostDetailsPagePhysics(),
            itemCount: widget.itemCount,
            itemBuilder: (context, index) => _buildItem(index, blockSwipe),
          ),
        );
      },
    );
  }

  final _dummyAlwaysFalse = ValueNotifier(false);

  Widget _buildItem(int index, bool blockSwipe) {
    List<Widget> buildNavButtons() {
      final isVertical = useVerticalLayout;

      return [
        PageNavButton(
          alignment: isVertical
              ? Alignment.bottomCenter
              : Alignment.centerRight,
          controller: _controller,
          visibleWhen: (page) => page < widget.itemCount - 1,
          icon: Icon(
            isVertical ? Symbols.keyboard_arrow_down : Symbols.arrow_forward,
          ),
          onPressed: () => _controller.nextPage(duration: Duration.zero),
        ),
        PageNavButton(
          alignment: isVertical ? Alignment.topCenter : Alignment.centerLeft,
          controller: _controller,
          visibleWhen: (page) => page > 0,
          icon: Icon(
            isVertical ? Symbols.keyboard_arrow_up : Symbols.arrow_back,
          ),
          onPressed: () => _controller.previousPage(duration: Duration.zero),
        ),
      ];
    }

    final isSmall = !isLargeScreen;

    final lastKnownPage = widget.itemCount - 1;
    final loadingNext = widget.nextLoading && index == lastKnownPage;
    final failedNext =
        !loadingNext && widget.nextFailed && index == lastKnownPage;
    final loadMoreNext =
        !loadingNext &&
        !failedNext &&
        widget.nextCanLoad &&
        index == lastKnownPage;

    final navigation = ZoomPageNavigationScope(
      previousLabel: context.t.infinite_scroll.previous_page,
      nextLabel: failedNext
          ? context.t.generic.action.retry
          : loadMoreNext
          ? context.t.infinite_scroll.load_more
          : context.t.infinite_scroll.next_page,
      onPrevious: index > 0
          ? () => _controller.previousPage(duration: Duration.zero)
          : null,
      onEdgePrevious: index > 0
          ? () => _navigateFromEdge(index, index - 1)
          : null,
      previousActionId: index > 0 ? (index - 1, widget.itemCount) : null,
      nextEdgeAction: failedNext
          ? ZoomPageEdgeAction.retry
          : loadMoreNext
          ? ZoomPageEdgeAction.loadMore
          : ZoomPageEdgeAction.page,
      nextActionId: failedNext
          ? ('retry', widget.onRetryNext)
          : loadMoreNext
          ? ('load-more', widget.onLoadMoreNext)
          : loadingNext || index >= lastKnownPage
          ? null
          : (index + 1, widget.itemCount),
      onNext: failedNext
          ? widget.onRetryNext
          : loadMoreNext
          ? widget.onLoadMoreNext
          : loadingNext || index >= lastKnownPage
          ? null
          : () => _controller.nextPage(duration: Duration.zero),
      onEdgeNext: index < lastKnownPage
          ? () => _navigateFromEdge(index, index + 1)
          : null,
      child: widget.itemBuilder(context, index),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: ValueListenableBuilder(
            valueListenable: !isSmall || useVerticalLayout
                ? _dummyAlwaysFalse
                : _controller.canPull,
            builder: (_, canPull, _) => PointerCountOnScreen(
              enable: isSmall,
              onCountChanged: (count) {
                _pointerCount.value = count;
                _interacting.value = count > 1;
              },
              child: ValueListenableBuilder(
                valueListenable: !isSmall || useVerticalLayout
                    ? _dummyAlwaysFalse
                    : _controller.pulling,
                builder: (_, pulling, _) => GestureDetector(
                  onVerticalDragStart:
                      canPull && !_interacting.value && !useVerticalLayout
                      ? _onVerticalDragStart
                      : null,
                  onVerticalDragUpdate: pulling && !useVerticalLayout
                      ? _onVerticalDragUpdate
                      : null,
                  onVerticalDragEnd: pulling && !useVerticalLayout
                      ? _onVerticalDragEnd
                      : null,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _controller.freestyleMoveOffset,
                      _controller.sheetState,
                    ]),
                    builder: (context, childAb) => Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..translateByDouble(
                          _controller.freestyleMoveOffset.value.dx,
                          _controller.freestyleMoveOffset.value.dy,
                          0,
                          1,
                        )
                        ..scaledByDouble(
                          _freestyleMoveScale,
                          _freestyleMoveScale,
                          _freestyleMoveScale,
                          1,
                        ),
                      child: childAb,
                    ),
                    child: isSmall
                        ? _ExpandedMediaSwipeDetector(
                            controller: _controller,
                            onSwipeDown: () {
                              _handledExpandedMediaSwipe = true;
                              _controller.resetSheet();
                            },
                            onSwipeEnded: () =>
                                _handledExpandedMediaSwipe = false,
                            child: navigation,
                          )
                        : navigation,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isDesktopPlatform())
          ...buildNavButtons()
        else if (!isSmall)
          if (blockSwipe) ...buildNavButtons(),
      ],
    );
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _controller.pulling.value = true;

    if (!_controller.isExpanded) {
      _freestyleMoveStartOffset = details.globalPosition;
      _freestyleMoveScale = 1.0;
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_handledExpandedMediaSwipe) return;
    _controller.dragUpdate(details);

    if (_controller.freestyleMoving.value) {
      if (_controller.verticalPosition.value <= 0) return;

      // Calculate scale first
      final movePercent =
          details.globalPosition.dy - _freestyleMoveStartOffset.dy;
      final normalizedPercent = movePercent / widget.swipeDownThreshold;
      _freestyleMoveScale =
          1.0 -
          (normalizedPercent * _kSwipeDownScaleFactor).clamp(
            0.0,
            _kSwipeDownScaleFactor,
          );

      // Adjust translation based on scale
      final scaledOffset = details.globalPosition - _freestyleMoveStartOffset;
      // Apply scale compensation to keep the image centered
      final scaleCompensation =
          (1 - _freestyleMoveScale) *
          (_freestyleMoveStartOffset.dy - details.globalPosition.dy) /
          2;

      _controller.freestyleMoveOffset.value = Offset(
        scaledOffset.dx,
        scaledOffset.dy + scaleCompensation,
      );
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _controller.pulling.value = false;
    if (_handledExpandedMediaSwipe) {
      _handledExpandedMediaSwipe = false;
      return;
    }

    // Check if drag distance exceeds threshold for dismissal
    if (_controller.freestyleMoveOffset.value.dy.abs() >
        widget.swipeDownThreshold) {
      if (widget.onSwipeDownThresholdReached != null) {
        widget.onSwipeDownThresholdReached?.call();
      } else {
        Navigator.of(context).maybePop();
        return;
      }
      // scale back to 1.0
      _freestyleMoveScale = 1.0;
    } else {
      // Animate back to original position
      _animateBackToPosition();
      _freestyleMoveScale = 1.0;
    }

    _controller.freestyleMoveOffset.value = Offset.zero;

    _controller.dragEnd();
  }

  void _animateBackToPosition() {
    final startOffset = _controller.freestyleMoveOffset.value;

    final animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    final animation =
        Tween(
          begin: startOffset,
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animController,
            curve: Curves.easeOut,
          ),
        );

    animation.addListener(() {
      if (mounted) {
        _controller.freestyleMoveOffset.value = animation.value;
      }
    });

    // Start animation
    animController.forward().then((_) {
      animController.dispose();
    });
  }
}

class _ExpandedMediaSwipeDetector extends StatefulWidget {
  const _ExpandedMediaSwipeDetector({
    required this.controller,
    required this.onSwipeDown,
    required this.onSwipeEnded,
    required this.child,
  });

  final PostDetailsPageViewController controller;
  final VoidCallback onSwipeDown;
  final VoidCallback onSwipeEnded;
  final Widget child;

  @override
  State<_ExpandedMediaSwipeDetector> createState() =>
      _ExpandedMediaSwipeDetectorState();
}

class _ExpandedMediaSwipeDetectorState
    extends State<_ExpandedMediaSwipeDetector> {
  final _pointers = <int>{};
  int? _activePointer;
  Offset? _startPosition;
  var _cancelled = false;
  var _swipeHandled = false;

  bool get _canSwipe =>
      widget.controller.isExpanded &&
      !widget.controller.zoom.value &&
      !widget.controller.animating.value;

  @override
  void initState() {
    super.initState();
    widget.controller.sheetState.addListener(_onEligibilityChanged);
    widget.controller.zoom.addListener(_onEligibilityChanged);
  }

  @override
  void dispose() {
    widget.controller.sheetState.removeListener(_onEligibilityChanged);
    widget.controller.zoom.removeListener(_onEligibilityChanged);
    super.dispose();
  }

  void _onEligibilityChanged() {
    if (_pointers.isNotEmpty && !_canSwipe) {
      _cancelled = true;
      _activePointer = null;
      _startPosition = null;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onPointerDown,
    onPointerMove: _onPointerMove,
    onPointerUp: _onPointerEnd,
    onPointerCancel: _onPointerEnd,
    child: widget.child,
  );

  void _onPointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_pointers.length > 1 || !_canSwipe) {
      _cancelled = true;
      _activePointer = null;
      _startPosition = null;
      return;
    }

    _activePointer = event.pointer;
    _startPosition = event.position;
    _cancelled = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_cancelled || event.pointer != _activePointer) return;
    if (!_canSwipe) {
      _onEligibilityChanged();
      return;
    }

    final startPosition = _startPosition;
    if (startPosition == null) return;

    final offset = event.position - startPosition;
    if (offset.dy < _kExpandedMediaSwipeThreshold ||
        offset.dy < offset.dx.abs() * _kExpandedMediaVerticalDominance) {
      return;
    }

    _cancelled = true;
    _swipeHandled = true;
    _activePointer = null;
    _startPosition = null;
    widget.onSwipeDown();
  }

  void _onPointerEnd(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.isEmpty) {
      _activePointer = null;
      _startPosition = null;
      _cancelled = false;
      if (_swipeHandled) {
        _swipeHandled = false;
        scheduleMicrotask(widget.onSwipeEnded);
      }
    }
  }
}

class _BottomPreviewSwipeDetector extends StatefulWidget {
  const _BottomPreviewSwipeDetector({
    required this.onSwipeUp,
    required this.child,
  });

  final VoidCallback onSwipeUp;
  final Widget child;

  @override
  State<_BottomPreviewSwipeDetector> createState() =>
      _BottomPreviewSwipeDetectorState();
}

class _BottomPreviewSwipeDetectorState
    extends State<_BottomPreviewSwipeDetector> {
  final _pointers = <int>{};
  int? _activePointer;
  Offset? _startPosition;
  Offset? _currentPosition;
  var _cancelled = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);

    if (_pointers.length > 1) {
      _cancelled = true;
      return;
    }

    _activePointer = event.pointer;
    _startPosition = event.position;
    _currentPosition = event.position;
    _cancelled = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _cancelled) return;

    _currentPosition = event.position;
    if (_isQualifyingSwipe()) {
      _clearCandidate();
      widget.onSwipeUp();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    if (event.pointer != _activePointer) {
      if (_pointers.isEmpty) _resetGesture();
      return;
    }

    final cancelled = _cancelled;
    final isQualifyingSwipe = _isQualifyingSwipe();
    _clearCandidate();
    if (_pointers.isEmpty) _cancelled = false;

    if (!cancelled && isQualifyingSwipe) widget.onSwipeUp();
  }

  bool _isQualifyingSwipe() {
    final startPosition = _startPosition;
    final currentPosition = _currentPosition;
    if (_cancelled || startPosition == null || currentPosition == null) {
      return false;
    }

    final offset = currentPosition - startPosition;
    final upwardDistance = -offset.dy;
    final isUpward = upwardDistance >= _kBottomPreviewSwipeThreshold;
    final isVertical =
        upwardDistance >= offset.dx.abs() * _kBottomPreviewVerticalDominance;

    return isUpward && isVertical;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    if (event.pointer == _activePointer) {
      _clearCandidate();
    }

    if (_pointers.isEmpty) {
      _resetGesture();
    }
  }

  void _clearCandidate() {
    _activePointer = null;
    _startPosition = null;
    _currentPosition = null;
  }

  void _resetGesture() {
    _pointers.clear();
    _clearCandidate();
    _cancelled = false;
  }
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

const _kSwipeDownScaleFactor = 0.2;

double _clampToZero(
  double value, {
  double threshold = 0.01,
}) {
  if (value.isNaN) return 0.0;
  return value.abs() < threshold ? 0.0 : value;
}
