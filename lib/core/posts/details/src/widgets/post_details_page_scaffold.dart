import '../../../../navigation/destination_activity.dart';

// Flutter imports:
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show IntProperty;

// Package imports:
import 'package:foundation/performance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/widgets.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Project imports:
import '../../../../../foundation/performance/performance_navigation.dart';
import '../../../../../foundation/platform.dart';
import '../../../../analytics/providers.dart';
import '../../../../boorus/engine/types.dart';
import '../../../../cache/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/gesture/types.dart';
import '../../../../premiums/providers.dart';
import '../../../../settings/providers.dart';
import '../../../../videos/lock/widgets.dart';
import '../../../details_pageview/widgets.dart';
import '../../../details_parts/types.dart';
import '../../../post/routes.dart';
import '../../../post/types.dart';
import '../types/post_details.dart';
import '../types/viewer_entry.dart';
import '../types/inherited_post.dart';
import '../types/post_presentation_context.dart';
import 'post_details_controller.dart';
import 'post_details_full_info_sheet.dart';
import 'post_details_page_view_scope.dart';
import 'post_viewer_auto_comic_strip.dart';
import 'post_viewer_transformation_scope.dart';
import 'video_controls.dart';
import 'volume_key_page_navigator.dart';

const kShowInfoStateCacheKey = 'showInfoCacheStateKey';

class PostDetailsPageScaffold<T extends Post> extends ConsumerStatefulWidget {
  const PostDetailsPageScaffold({
    required this.posts,
    required this.controller,
    required this.gestureConfig,
    required this.layoutConfig,
    required this.itemBuilder,
    required this.transformController,
    required this.isInitPage,
    required this.actions,
    required this.postGestureHandlerBuilder,
    required this.uiBuilder,
    this.sequence,
    this.hasMediaPager,
    this.mediaNavigationBuilder,
    this.pagePostBuilder,
    this.pageIndicatorBuilder,
    this.pageWrapperBuilder,
    super.key,
    this.onExpanded,
    this.preferredParts,
    this.preferredPreviewParts,
    this.enableViewerTransformations = true,
    this.viewerWarning,
    this.nextLoading = false,
    this.nextFailed = false,
    this.nextCanLoad = false,
    this.onRetryNext,
    this.onLoadMoreNext,
    this.onPageChanged,
  });

  final List<T> posts;
  final void Function()? onExpanded;
  final PostDetailsController<T>? controller;
  final ViewerEntrySequence? sequence;
  final bool Function(int)? hasMediaPager;
  final MediaPageNavigation? Function(int)? mediaNavigationBuilder;

  /// The selected real Post in a media-pager entry; never a synthetic Group Post.
  final Post? Function(int)? pagePostBuilder;
  final Widget? Function(int)? pageIndicatorBuilder;
  final Widget Function(BuildContext, int, Widget)? pageWrapperBuilder;
  final PostDetailsUIBuilder? uiBuilder;
  final Set<DetailsPart>? preferredParts;
  final Set<DetailsPart>? preferredPreviewParts;
  final LayoutConfigs? layoutConfig;
  final PostGestureConfig? gestureConfig;
  final IndexedWidgetBuilder itemBuilder;
  final TransformationController transformController;
  final ValueNotifier<bool> isInitPage;
  final List<Widget> actions;
  final PostGestureHandlerBuilder? postGestureHandlerBuilder;
  final bool enableViewerTransformations;
  final Widget? viewerWarning;
  final bool nextLoading;
  final bool nextFailed;
  final bool nextCanLoad;
  final VoidCallback? onRetryNext;
  final VoidCallback? onLoadMoreNext;
  final ValueChanged<int>? onPageChanged;

  @override
  ConsumerState<PostDetailsPageScaffold<T>> createState() =>
      _PostDetailPageScaffoldState<T>();
}

class _PostDetailPageScaffoldState<T extends Post>
    extends ConsumerState<PostDetailsPageScaffold<T>> {
  List<T> get _posts => widget.posts;
  int get _pageCount => widget.sequence?.entries.length ?? _posts.length;
  Post? _directPostAt(int page) => widget.sequence == null
      ? _posts.elementAtOrNull(page)
      : widget.sequence!.postAt(page);
  Post? _postAt(int page) =>
      _directPostAt(page) ?? widget.pagePostBuilder?.call(page);
  bool get _isPostPage => _postAt(_controller.page) != null;
  final _transformCheckpoints = <Object, Matrix4>{};

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      IntProperty('transformCheckpoints', _transformCheckpoints.length),
    );
  }

  Object _occurrenceKey(int index) =>
      widget.sequence?.entries[index].occurrenceId ??
      (postViewerIdentity(_postAt(index)!), index);

  PostDetailsPageViewController? _pageViewController;
  PostDetailsPageViewController get _controller => _pageViewController!;

  VolumeKeyPageNavigator? _volumeKeyPageNavigator;

  ValueNotifier<bool> visibilityNotifier = ValueNotifier(false);
  late final _isInitPage = widget.isInitPage;

  List<T> get posts => _posts;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!mounted) return;
      widget.controller?.setPage(_controller.page);
      _onPageSettled(_controller.page);
    });

    widget.controller?.isVideoPlaying.addListener(_isVideoPlayingChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    visibilityNotifier.value = NavigationActivity.of(context);
    final controller = PostDetailsPageViewScope.of(context);
    if (identical(_pageViewController, controller)) return;

    _pageViewController?.precisePage.removeListener(_onPrecisePageChanged);
    _pageViewController?.currentPage.removeListener(_pruneTransformCheckpoints);
    _volumeKeyPageNavigator?.dispose();
    _pageViewController = controller;
    controller.precisePage.addListener(_onPrecisePageChanged);
    controller.currentPage.addListener(_pruneTransformCheckpoints);

    _volumeKeyPageNavigator = VolumeKeyPageNavigator(
      pageViewController: controller,
      totalPosts: () => _pageCount,
      visibilityNotifier: visibilityNotifier,
      enableVolumeKeyViewerNavigation: () => ref.read(
        settingsProvider.select((value) => value.volumeKeyViewerNavigation),
      ),
    )..initialize();
  }

  @override
  void didUpdateWidget(covariant PostDetailsPageScaffold<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.isVideoPlaying.removeListener(
        _isVideoPlayingChanged,
      );
      widget.controller?.isVideoPlaying.addListener(_isVideoPlayingChanged);
      final controller = widget.controller;
      // A media Page and an ordinary Post share this frame but have separate
      // controllers. A settled outer pager will not emit another page event.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(widget.controller, controller)) return;
        final page = _controller.page;
        controller?.setPage(page);
        controller?.updateCurrentPost(page);
        if (_controller.precisePage.value == page.toDouble()) {
          controller?.onPageSettled(page);
        }
        controller?.setNavigationActive(visibilityNotifier.value);
      });
    }
  }

  @override
  void dispose() {
    _volumeKeyPageNavigator?.dispose();
    widget.controller?.isVideoPlaying.removeListener(_isVideoPlayingChanged);
    _pageViewController?.precisePage.removeListener(_onPrecisePageChanged);
    _pageViewController?.currentPage.removeListener(_pruneTransformCheckpoints);
    visibilityNotifier.dispose();

    super.dispose();
  }

  void _pruneTransformCheckpoints() {
    final retained = _controller.retainedStatePages.map(_occurrenceKey).toSet();
    _transformCheckpoints.removeWhere((key, _) => !retained.contains(key));
  }

  void _handleMediaKey(VoidCallback action) {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    final editing =
        focusedContext?.widget is EditableText ||
        focusedContext?.findAncestorWidgetOfExactType<EditableText>() != null;
    if (!_controller.keyboardShortcutsEnabled.value ||
        !visibilityNotifier.value ||
        !(_postAt(_controller.page)?.isVideo ?? false) ||
        editing) {
      return;
    }
    action();
  }

  var _previouslyPlaying = false;

  void _isVideoPlayingChanged() {
    if (context.isLargeScreen && ref.read(appPlatformProvider).isDesktop) {
      // force overlay to be on when video is not playing
      if (!(widget.controller?.isVideoPlaying.value ?? false)) {
        _controller.disableHoverToControlOverlay();
      } else {
        if (_postAt(_controller.page)?.isVideo ?? false) {
          _controller.enableHoverToControlOverlay();
        }
      }
    }
  }

  void _onPrecisePageChanged() {
    performanceRecorder.measureSync(
      PerfOperation.viewerPrecisePageCallback,
      () {
        final precisePage = _controller.precisePage.value;

        if (precisePage != null) {
          final page = precisePage.round();
          final distance = (page - precisePage).abs();

          // The selected presentation changes only when the outer pager has
          // committed this page. A precise-position notification can otherwise
          // update the Post controller before the rest of the Viewer tree.
          final scrolling =
              _controller.pageController.hasClients &&
              _controller.pageController.position.isScrollingNotifier.value;
          if (!scrolling && distance == 0 && page == _controller.page) {
            widget.controller?.updateCurrentPost(page);
            _onPageSettled(page);
          }
        }
      },
    );
  }

  void _onPageSettled(int page) {
    performanceRecorder.measureSync(PerfOperation.viewerSettlement, () {
      widget.controller?.onPageSettled(page);
    });
  }

  void _onHover({
    required bool value,
    required bool disableAnimation,
  }) {
    if (!_controller.hoverToControlOverlay.value) {
      return;
    }

    if (disableAnimation) {
      return;
    }

    if (value) {
      _controller.showOverlay(
        includeSystemStatus: false,
      );
    } else {
      _controller.hideOverlay(
        includeSystemStatus: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) => PerformanceScreenScope(
    screen: PerfScreen.postViewer,
    child: performanceRecorder.measureSync(
      PerfOperation.viewerScaffoldBuild,
      () => _buildViewer(context),
    ),
  );

  Widget _buildViewer(BuildContext context) {
    // Sync slideshow options with settings
    ref.listen(
      imageViewerSettingsProvider.select(
        toSlideShowOptions,
      ),
      (prev, next) {
        if (prev != next) {
          _controller.slideshowOptions = next;
        }
      },
    );

    final child = CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.keyF,
          control: true,
        ): () {
          final post = _postAt(_controller.page);
          if (_isPostPage && visibilityNotifier.value && post != null) {
            goToOriginalImagePage(ref, post);
          }
        },
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () =>
            _handleMediaKey(
              () => widget.controller?.toggleCurrentVideo(showAnimation: true),
            ),
        const SingleActivator(LogicalKeyboardKey.mediaPlay): () =>
            _handleMediaKey(
              () => widget.controller?.setCurrentVideoPlaying(
                true,
                showAnimation: true,
              ),
            ),
        const SingleActivator(LogicalKeyboardKey.mediaPause): () =>
            _handleMediaKey(
              () => widget.controller?.setCurrentVideoPlaying(
                false,
                showAnimation: true,
              ),
            ),
      },
      child: VisibilityDetector(
        key: const Key('post_details_page_scaffold'),
        onVisibilityChanged: (info) {
          if (!mounted) return;

          if (info.visibleFraction == 0) {
            visibilityNotifier.value = false;
            _previouslyPlaying =
                widget.controller?.isVideoPlaying.value ?? false;
            if (_previouslyPlaying) {
              widget.controller?.pauseCurrentVideo();
            }
          } else if (info.visibleFraction == 1 &&
              NavigationActivity.of(context)) {
            visibilityNotifier.value = true;
            if (_previouslyPlaying) {
              widget.controller?.playCurrentVideo();
            }
          }
        },
        child: VideoScreenLocker(
          onLockChanged: (isLocked) {
            if (isLocked) {
              _controller.hideAllUI();
              _controller.disableKeyboardShortcuts();
            } else {
              _controller.showAllUI();
              _controller.enableKeyboardShortcuts();
            }
          },
          child: _build(),
        ),
      ),
    );

    return child;
  }

  Widget _build() {
    final postGesturesHandler = widget.postGestureHandlerBuilder;
    final gestures = widget.gestureConfig?.fullview;
    final hasPremiumLayout = ref.watch(hasPremiumLayoutProvider);
    final canCustomize = ref.watch(showPremiumFeatsProvider);

    final reduceAnimations = ref.watch(
      settingsProvider.select((value) => value.reduceAnimations),
    );
    final autoAdjustComicStrips = ref.watch(
      imageViewerSettingsProvider.select(
        (value) => value.autoAdjustComicStrips,
      ),
    );

    return Scaffold(
      body: PostDetailsPageView(
        nextLoading: widget.nextLoading,
        nextFailed: widget.nextFailed,
        nextCanLoad: widget.nextCanLoad,
        onRetryNext: widget.onRetryNext,
        onLoadMoreNext: widget.onLoadMoreNext,
        disableAnimation: reduceAnimations,
        onPageChanged: (page) {
          final post = _postAt(page);

          widget.controller?.setPage(page);
          widget.controller?.updateCurrentPost(page);
          widget.controller?.onPageSettled(page);

          _isInitPage.value = false;
          widget.onPageChanged?.call(page);

          if (_controller.overlay.value) {
            if (post?.isVideo ?? false) {
              _controller.enableHoverToControlOverlay();
            } else {
              _controller.disableHoverToControlOverlay();
            }
          }
        },
        sheetStateStorage: SheetStateStorageBuilder(
          save: (expanded) => ref
              .read(miscDataProvider(kShowInfoStateCacheKey).notifier)
              .put(expanded.toString()),
          load: () =>
              ref.read(miscDataProvider(kShowInfoStateCacheKey)) == 'true',
        ),
        checkIfLargeScreen: () => context.isLargeScreen,
        controller: _controller,
        onExit: () {
          widget.controller?.onExit();
        },
        itemCount: _pageCount,
        mediaNavigationBuilder: widget.mediaNavigationBuilder,
        detailsEnabled:
            _isPostPage ||
            (widget.hasMediaPager?.call(_controller.page) ?? false),
        overlayEnabled:
            (widget.hasMediaPager?.call(_controller.page) ?? false) ||
            !(widget
                    .sequence
                    ?.entries[_controller.page]
                    .usesContentNavigationHeader ??
                false),
        isPostPage: (index) =>
            _postAt(index) != null ||
            (widget.hasMediaPager?.call(index) ?? false),
        leftActions: [
          if (widget.controller?.dislclaimer != null)
            KurumiCircularIconButton(
              icon: const Icon(
                Symbols.warning,
                fill: 1,
              ),
              onPressed: () => Kurumi.showAppModalBarBottomSheet(
                context: context,
                builder: (_) => DisclaimerDialog(
                  disclaimer: widget.controller!.dislclaimer!,
                ),
              ),
            ),
        ],
        onSwipeDownThresholdReached:
            _isPostPage && gestures.canSwipeDown && postGesturesHandler != null
            ? () {
                _controller.resetSheet();

                postGesturesHandler(
                  ref,
                  gestures?.swipeDown,
                  _postAt(_controller.page)!,
                );
              }
            : null,
        occurrenceKeyBuilder: _occurrenceKey,
        mediaSizeBuilder: (index) {
          final post = _postAt(index);
          return post == null ? null : Size(post.width, post.height);
        },
        pageWrapperBuilder: (context, index, content) {
          Widget child = LayoutBuilder(
            builder: (context, constraints) => PostDetailsSheetConstraints(
              maxWidth: constraints.maxWidth,
              child: content,
            ),
          );
          final post = _postAt(index);
          if (_directPostAt(index) != null &&
              widget.enableViewerTransformations) {
            child = PostViewerOccurrence(
              key: ValueKey(_occurrenceKey(index)),
              checkpoints: _transformCheckpoints,
              retainCheckpoint: () => _controller.retainsStateFor(index),
              occurrence: _occurrenceKey(index),
              child: child,
            );
          }
          if (widget.pageWrapperBuilder case final wrapper?) {
            return wrapper(context, index, child);
          }
          if (post == null) return child;
          final presentation = context
              .dependOnInheritedWidgetOfExactType<InheritedPost>()
              ?.presentationContext;
          return InheritedPost(
            presentationContext: PostPresentationContext.resolve(
              post: post,
              presentation:
                  presentation?.presentation ?? const GenericPostPresentation(),
              resolvedConfig: presentation?.resolvedConfig,
            ),
            child: child,
          );
        },
        detailsSliversBuilder: (context, index) {
          final page = PostDetailsPageConfiguration.maybeOf(context);
          final ui = page == null ? widget.uiBuilder : page.uiBuilder;
          return [
            if (_postAt(index)?.isVideo ?? false)
              SliverToBoxAdapter(
                child: PostDetailsVideoControlsMobile(
                  pageIndex: index,
                  controller: PostDetails.of<Post>(context).controller,
                ),
              ),
            ...buildPostDetailsInfoSlivers(
              context,
              uiBuilder: ui,
              preferredParts:
                  page?.preferredParts ??
                  widget.preferredParts ??
                  getLayoutParsedParts(
                    details: (page == null ? widget.layoutConfig : page.layout)
                        ?.details,
                    hasPremium: hasPremiumLayout,
                  ) ??
                  ui?.buildableFullParts ??
                  <DetailsPart>{},
              canCustomize:
                  ui != null && canCustomize && _postAt(index) != null,
            ),
          ];
        },
        mainContentBuilder: (context, child) => MouseRegion(
          onEnter: (_) => _onHover(
            value: true,
            disableAnimation: reduceAnimations,
          ),
          onExit: (_) => _onHover(
            value: false,
            disableAnimation: reduceAnimations,
          ),
          child: Stack(
            children: [
              child,
              if (widget.pageIndicatorBuilder?.call(_controller.page)
                  case final indicator?)
                Positioned.fill(child: indicator),
              if (widget.viewerWarning case final warning?)
                Align(
                  alignment: Alignment.topCenter,
                  child: warning,
                ),
            ],
          ),
        ),
        itemBuilder: (context, index) {
          final child = widget.itemBuilder(context, index);
          if (!widget.enableViewerTransformations ||
              _directPostAt(index) == null) {
            return child;
          }

          final post = _postAt(index)!;
          return PostViewerTransformationViewport(
            child: PostViewerAutoComicStrip(
              index: index,
              postId: post.id,
              contentSize: Size(post.width, post.height),
              currentSettledPage: widget.controller!.currentSettledPage,
              enabled: autoAdjustComicStrips && !post.isVideo,
              child: child,
            ),
          );
        },
        bottomPreviewBuilder: (context, index) {
          final post = _postAt(index);
          if (post == null) return const SizedBox.shrink();
          final page = PostDetailsPageConfiguration.maybeOf(context);
          final ui = page == null ? widget.uiBuilder : page.uiBuilder;
          return switch (ui) {
            null => _buildFallbackPreview(context, index, post),
            final ui when ui.preview.isNotEmpty => _buildCustomPreview(
              pageIndex: index,
              context: context,
              post: post,
              layout: page == null ? widget.layoutConfig : page.layout,
              uiBuilder: ui,
              hasPremium: hasPremiumLayout,
            ),
            _ => const SizedBox.shrink(),
          };
        },
        actions: widget.actions,
        onExpanded: () {
          widget.onExpanded?.call();
          ref
              .read(analyticsProvider)
              .whenData(
                (analytics) => analytics?.logScreenView('/details/info'),
              );
        },
        onShrink: () {
          final routeName = ModalRoute.of(context)?.settings.name;
          if (routeName != null) {
            ref
                .read(analyticsProvider)
                .whenData(
                  (analytics) => analytics?.logScreenView(routeName),
                );
          }
        },
      ),
    );
  }

  Widget _buildCustomPreview({
    required int pageIndex,
    required BuildContext context,
    required Post post,
    required LayoutConfigs? layout,
    required bool hasPremium,
    required PostDetailsUIBuilder uiBuilder,
  }) {
    final preferredPreviewParts =
        widget.preferredPreviewParts ??
        getLayoutPreviewParsedParts(
          previewDetails: layout?.previewDetails,
          hasPremium: hasPremium,
        ) ??
        uiBuilder.preview.keys.toSet();

    final colorScheme = Kurumi.themeOf(context).colorScheme;
    final decoration = BoxDecoration(
      color: colorScheme.surface,
      border: Border(
        top: BorderSide(
          color: colorScheme.hintColor,
          width: 0.2,
        ),
      ),
    );

    return CustomScrollView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        if (post.isVideo)
          SliverToBoxAdapter(
            child: DecoratedBox(
              decoration: decoration,
              child: context.isLargeScreen
                  ? PostDetailsVideoControlsDesktop(
                      pageIndex: pageIndex,
                      controller: PostDetails.of<Post>(context).controller,
                      pageViewController: _controller,
                    )
                  : PostDetailsVideoControlsMobile(
                      pageIndex: pageIndex,
                      controller: PostDetails.of<Post>(context).controller,
                    ),
            ),
          ),
        DecoratedSliver(
          decoration: decoration,
          sliver: SliverPadding(
            padding: EdgeInsets.only(top: post.isVideo ? 0 : 8),
            sliver: MultiSliver(
              children: preferredPreviewParts
                  .map((part) => uiBuilder.buildPart(context, part))
                  .nonNulls
                  .toList(),
            ),
          ),
        ),
        const _SliverBottomPadding(),
      ],
    );
  }

  Widget _buildFallbackPreview(BuildContext context, int pageIndex, Post post) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (post.isVideo)
          PostDetailsVideoControlsMobile(
            controller: widget.controller!,
            pageIndex: pageIndex,
          ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

class DisclaimerDialog extends StatelessWidget {
  const DisclaimerDialog({
    required this.disclaimer,
    super.key,
  });

  final String disclaimer;

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.paddingOf(context);

    return ColoredBox(
      color: Kurumi.themeOf(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(
            disclaimer,
            style: Kurumi.themeOf(context).textTheme.bodyMedium,
          ),
          SizedBox(
            height: viewPadding.bottom + 8,
          ),
        ],
      ),
    );
  }
}

class _SliverBottomPadding extends StatelessWidget {
  const _SliverBottomPadding();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Kurumi.themeOf(context).colorScheme;

    return DecoratedSliver(
      decoration: BoxDecoration(
        color: colorScheme.surface,
      ),
      sliver: SliverSizedBox(
        height: MediaQuery.paddingOf(context).bottom,
      ),
    );
  }
}

/// Per-occurrence source presentation for the shared pager's content and footer.
class PostDetailsPageConfiguration extends InheritedWidget {
  const PostDetailsPageConfiguration({
    required this.uiBuilder,
    required this.layout,
    required super.child,
    this.preferredParts,
    super.key,
  });
  final PostDetailsUIBuilder? uiBuilder;
  final LayoutConfigs? layout;
  final Set<DetailsPart>? preferredParts;
  static PostDetailsPageConfiguration? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PostDetailsPageConfiguration>();
  @override
  bool updateShouldNotify(PostDetailsPageConfiguration oldWidget) =>
      uiBuilder != oldWidget.uiBuilder ||
      layout != oldWidget.layout ||
      preferredParts != oldWidget.preferredParts;
}
