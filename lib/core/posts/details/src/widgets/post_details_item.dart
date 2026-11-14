// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

// Package imports:
import 'package:foundation/performance.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../foundation/platform.dart';
import '../../../../../foundation/info/package_info.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/gesture/types.dart';
import '../../../../developer_options/providers.dart';
import '../../../../widgets/widgets.dart';
import '../../../details_pageview/widgets.dart';
import '../../../listing/providers.dart';
import '../../../listing/types.dart';
import '../../../post/types.dart';
import '../providers/note_overlay_provider.dart';
import 'zoom_study_overlay.dart';
import '../../../../settings/providers.dart';
import '../../../../navigation/destination_activity.dart';
import '../../../../settings/types.dart';
import 'play_pause_animation_overlay.dart';
import 'post_details_controller.dart';
import 'post_details_page_view_scope.dart';
import 'post_media.dart';
import 'post_details_image.dart' show PostDetailsPlaceholderMediaBuilder;
import 'seek_animation_overlay.dart';
import 'post_viewer_transformation_scope.dart';
import 'zoom_edge_page_gesture.dart';

class PostDetailsItem<T extends Post> extends ConsumerStatefulWidget {
  const PostDetailsItem({
    required this.index,
    required this.posts,
    this.post,
    required this.transformController,
    required this.isInitPageListenable,
    required this.imageCacheManager,
    required this.detailsController,
    required this.authConfig,
    required this.viewerConfig,
    required this.gestureConfig,
    required this.imageUrlBuilder,
    required this.mediaAspectRatioBuilder,
    required this.videoAspectRatioBuilder,
    this.contentSize,
    this.onImageSize,
    this.onImageReady,
    this.onDisplayed,
    this.onImageUnavailable,
    this.placeholderMediaBuilder,
    this.allowOriginalImage = true,
    super.key,
  });

  final PostDetailsPlaceholderMediaBuilder<T>? placeholderMediaBuilder;
  final bool allowOriginalImage;
  final Size? contentSize;
  final ValueChanged<Size>? onImageSize;

  /// Fired after the first decoded rendition has reached the media surface.
  final VoidCallback? onImageReady;

  /// A decoded image on the settled, active full Viewer occurrence.
  final VoidCallback? onDisplayed;
  final VoidCallback? onImageUnavailable;
  final int index;
  final List<T> posts;
  final T? post;
  final TransformationController transformController;
  final ValueListenable<bool> isInitPageListenable;
  final ImageCacheManager? imageCacheManager;
  final PostDetailsController<T> detailsController;
  final BooruConfigAuth authConfig;
  final BooruConfigViewer viewerConfig;
  final PostGestureConfig? gestureConfig;
  final String Function(T post) imageUrlBuilder;
  final double? Function(T post) mediaAspectRatioBuilder;
  final double? Function(T post) videoAspectRatioBuilder;

  @override
  ConsumerState<PostDetailsItem<T>> createState() => _PostDetailsItemState<T>();
}

class _PostDetailsItemState<T extends Post>
    extends ConsumerState<PostDetailsItem<T>> {
  final _videoKey = GlobalKey();
  final _displayTransform = KurumiTransformationController();
  double _presentationProgress = 0;
  var _updatingDisplay = false;

  void _syncDisplay() {
    final immersive = _immersiveTransform;
    if (immersive == null) return;
    _updatingDisplay = true;
    final matrix = Matrix4Tween(
      begin: immersive.value,
      end: Matrix4.identity(),
    ).transform(_presentationProgress);
    if (_presentationProgress > 0) {
      _displayTransform.setPresentationValue(matrix);
    } else {
      _displayTransform.value = matrix;
    }
    _updatingDisplay = false;
    // Kurumi may constrain a programmatic transform to the actual image bounds.
    // Keep that usable matrix as the checkpoint, without recording the temporary
    // interpolated Details representation.
    if (_presentationProgress == 0 &&
        _displayTransform.value != immersive.value) {
      immersive.value = _displayTransform.value.clone();
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _syncCurrentTransform();
    } else {
      _updateCurrentTransform();
    }
  }

  void _saveGestureTransform() {
    if (!_updatingDisplay && _presentationProgress == 0) {
      _immersiveTransform?.value = _displayTransform.value.clone();
    }
  }

  TransformationController? _immersiveTransform;
  PostDetailsPageViewController? _pager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notifyDisplayed();
    final pager = PostDetailsPageViewScope.of(context);
    if (_pager != pager) {
      _pager?.sheetState.removeListener(_syncCurrentTransform);
      _pager = pager;
      pager.sheetState.addListener(_syncCurrentTransform);
    }
    _syncCurrentTransform();
  }

  void _syncCurrentTransform() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateCurrentTransform(),
    );
  }

  void _updateCurrentTransform() {
    if (!mounted || !_isPageSettled || _presentationProgress > 0) return;
    final pager = _pager;
    if (pager == null) return;
    if (pager.isExpanded) {
      pager.zoom.value = false;
      pager.enableAllSwiping();
    } else {
      final zoomed = kurumiIsZoomed(
        (_immersiveTransform ?? widget.transformController).value,
      );
      final settings = ref.read(imageViewerSettingsProvider);
      final post = widget.post ?? widget.posts[widget.index];
      if (zoomed &&
          !pager.zoom.value &&
          settings.loadOriginalOnZoom &&
          settings.postQuality != PostQuality.original &&
          post.hasFullView) {
        widget.detailsController.loadOriginalImage(post);
      }
      pager.synchronizeZoom(zoomed);
    }
  }

  final _imageController = ExtendedImageController();
  final _representationState = _MediaRepresentationState();
  late final _mediaState = Listenable.merge([
    _imageController.loadState,
    _representationState,
  ]);
  var _mediaCompatible = false;
  late bool _isPageSettled;

  @override
  void initState() {
    super.initState();
    _displayTransform.addListener(_saveGestureTransform);
    _isPageSettled =
        widget.detailsController.currentSettledPage.value == widget.index;
    widget.detailsController.currentSettledPage.addListener(_onPageSettled);
    _imageController.loadState.addListener(_onImageStateChanged);
  }

  var _active = true;

  @override
  void deactivate() {
    _active = false;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
  }

  @override
  void didUpdateWidget(covariant PostDetailsItem<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detailsController != widget.detailsController) {
      oldWidget.detailsController.currentSettledPage.removeListener(
        _onPageSettled,
      );
      widget.detailsController.currentSettledPage.addListener(_onPageSettled);
    }
    _isPageSettled =
        widget.detailsController.currentSettledPage.value == widget.index;
  }

  @override
  void dispose() {
    widget.detailsController.currentSettledPage.removeListener(_onPageSettled);
    _imageController.loadState.removeListener(_onImageStateChanged);
    _imageController.dispose();
    _pager?.sheetState.removeListener(_syncCurrentTransform);
    _immersiveTransform?.removeListener(_syncDisplay);
    _displayTransform.removeListener(_saveGestureTransform);
    _displayTransform.dispose();
    _representationState.dispose();
    super.dispose();
  }

  void _onPageSettled() {
    final isPageSettled =
        widget.detailsController.currentSettledPage.value == widget.index;
    if (isPageSettled == _isPageSettled) return;
    setState(() => _isPageSettled = isPageSettled);
    _syncCurrentTransform();
    _notifyDisplayed();
  }

  void _onRepresentationChanged(bool compatible) {
    _mediaCompatible = compatible;
    _representationState.changed();
    _onImageStateChanged();
  }

  void _notifyDisplayed() {
    if (widget.onDisplayed == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeDisplayed();
    });
  }

  void _maybeDisplayed() {
    if (widget.onDisplayed != null &&
        _active &&
        _isPageSettled &&
        _imageController.loadState.value == LoadState.completed &&
        _imageController.imageInfo.value != null &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        NavigationActivity.of(context)) {
      widget.onDisplayed!();
    }
  }

  void _onImageStateChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_imageController.loadState.value == LoadState.completed &&
          _imageController.imageInfo.value != null) {
        widget.onImageReady?.call();
        _maybeDisplayed();
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => performanceRecorder.measureSync(
    PerfOperation.viewerItemBuild,
    () => _buildItem(context),
  );

  Widget _buildItem(BuildContext context) {
    final pageViewController = PostDetailsPageViewScope.of(context);
    final post = widget.post ?? widget.posts[widget.index];

    final loadOriginalOnZoom = ref.watch(
      imageViewerSettingsProvider.select(
        (settings) =>
            settings.loadOriginalOnZoom &&
            settings.postQuality != PostQuality.original,
      ),
    );
    final snapZoomToFit = ref.watch(
      imageViewerSettingsProvider.select(
        (settings) => settings.snapZoomToFit,
      ),
    );

    final booruRepo = ref.watch(booruRepoProvider(widget.authConfig));
    final gestures = widget.gestureConfig?.fullview;
    final noteOverlayShown = ref.watch(
      noteOverlayProvider((widget.authConfig, post)),
    );
    final navigation = ZoomPageNavigationScope.maybeOf(context);
    final viewerTransform = PostViewerTransformationScope.maybeOf(context);
    final immersiveTransform =
        viewerTransform?.transformationController ?? widget.transformController;
    if (_immersiveTransform != immersiveTransform) {
      _immersiveTransform?.removeListener(_syncDisplay);
      _immersiveTransform = immersiveTransform;
      immersiveTransform.addListener(_syncDisplay);
    }
    _presentationProgress = ViewerPresentationTransition.of(context);
    _syncDisplay();
    final automaticMediaLoadingEnabled = ref.watch(
      automaticMediaLoadingEnabledProvider,
    );
    final showZoomStudy =
        ref.watch(isDevEnvironmentProvider) &&
        ref.watch(zoomStudyEnabledProvider);

    void onItemTap() {
      if (!_active || !mounted) return;
      if (pageViewController.isExpanded) {
        pageViewController.resetSheet();
        return;
      }
      final controller = widget.detailsController;

      if (ref.read(appPlatformProvider).isDesktop) {
        if (controller.currentPost.value.isVideo) {
          if (controller.isVideoPlaying.value) {
            controller.pauseCurrentVideo(showAnimation: true);
          } else {
            controller.playCurrentVideo(showAnimation: true);
          }
        } else {
          if (pageViewController.isExpanded) return;

          pageViewController.toggleOverlay();
        }
      } else {
        if (pageViewController.isExpanded) return;

        pageViewController.toggleOverlay();
      }
    }

    void onVideoDoubleTap(Offset? tapPosition) {
      final renderBox =
          _videoKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || tapPosition == null) return;

      widget.detailsController.seekFromDoubleTap(
        tapPosition,
        renderBox.size,
      );
    }

    void onTransformationChanged(KurumiTransformationDetails details) {
      if (!_isPageSettled ||
          pageViewController.isExpanded ||
          _updatingDisplay ||
          _presentationProgress > 0) {
        return;
      }
      final startedZooming = !pageViewController.zoom.value && details.isZoomed;

      pageViewController.onTransformationChanged(details);

      if (startedZooming && loadOriginalOnZoom && post.hasFullView) {
        widget.detailsController.loadOriginalImage(post);
      }
    }

    // Cropped previews must not replace the full-post layout geometry or move
    // its reading position. Decode dimensions only fill missing metadata.
    final decodedImage =
        !post.isVideo && _imageController.loadState.value == LoadState.completed
        ? _imageController.imageInfo.value?.image
        : null;
    final decodedSize =
        decodedImage != null &&
            decodedImage.width > 0 &&
            decodedImage.height > 0
        ? Size(decodedImage.width.toDouble(), decodedImage.height.toDouble())
        : null;
    final hasPostGeometry =
        post.width.isFinite &&
        post.height.isFinite &&
        post.width > 0 &&
        post.height > 0;
    final mediaSize =
        widget.contentSize ??
        (hasPostGeometry
            ? Size(post.width, post.height)
            : decodedSize ?? Size(post.width, post.height));

    final initialThumbnailUrl = widget.detailsController.initialThumbnailUrl;
    final initialPlaceholderMedia = initialThumbnailUrl != null
        ? _initialPlaceholderMedia(post, initialThumbnailUrl)
        : null;

    final viewer = ValueListenableBuilder(
      valueListenable: pageViewController.sheetState,
      builder: (_, state, _) => GestureDetector(
        // let the user tap the image to toggle overlay
        onTap: onItemTap,
        onDoubleTap: state.isExpanded ? () {} : null,
        child: InteractiveViewerExtended(
          key: _videoKey,
          contentSize: mediaSize,
          controller: _displayTransform,
          constrainPanToContent:
              _isPageSettled && !state.isExpanded && _presentationProgress == 0,
          snapZoomToFit: snapZoomToFit,
          enable: switch (noteOverlayShown) {
            // If the note overlay is shown, disable all interactions to prevent gesture conflicts
            true => false,
            false => !state.isExpanded && _presentationProgress == 0,
          },
          onTransformationChanged: onTransformationChanged,
          onTap: onItemTap,
          onDoubleTap: switch ((
            doubleTap: gestures.canDoubleTap,
            handler: booruRepo?.handlePostGesture,
          )) {
            (doubleTap: true, handler: final h?) => (_) => h(
              ref,
              gestures?.doubleTap,
              post,
            ),
            (doubleTap: false, handler: _) when post.isVideo => (
              details,
            ) => onVideoDoubleTap(details?.localPosition),
            _ => null,
          },
          onLongPress: gestures.canLongPress && booruRepo != null
              ? () => booruRepo.handlePostGesture(
                  ref,
                  gestures?.longPress,
                  post,
                )
              : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ValueListenableBuilder(
                valueListenable: widget.isInitPageListenable,
                builder: (_, isInitPage, _) {
                  return ValueListenableBuilder<Set<String>>(
                    valueListenable:
                        widget.detailsController.originalImagePostKeys,
                    builder: (_, originalImagePostKeys, _) {
                      final useOriginal =
                          widget.allowOriginalImage &&
                          originalImagePostKeys.contains(
                            postViewerIdentity(post),
                          );

                      return PostMedia<T>(
                        post: post,
                        config: widget.authConfig,
                        viewer: widget.viewerConfig,
                        imageUrlBuilder: useOriginal
                            ? (post) => post.originalImageUrl
                            : widget.imageUrlBuilder,
                        mediaAspectRatioBuilder: useOriginal
                            ? (post) => post.effectiveOriginalAspectRatio
                            : widget.mediaAspectRatioBuilder,
                        videoAspectRatioBuilder: widget.videoAspectRatioBuilder,
                        imageCacheManager: widget.imageCacheManager,
                        imageController: _imageController,
                        onRepresentationChanged: _onRepresentationChanged,
                        onTerminalFailure: widget.onImageUnavailable,
                        contentSize: widget.contentSize,
                        onImageSize: widget.onImageSize,
                        // This is used to make sure we have a thumbnail to show instead of a black placeholder
                        placeholderMediaBuilder:
                            widget.placeholderMediaBuilder ??
                            (isInitPage &&
                                    widget.index ==
                                        widget.detailsController.initialPage &&
                                    initialThumbnailUrl != null
                                ? (_) => initialPlaceholderMedia!
                                : null),
                        controller: pageViewController,
                        isPageSettled: _isPageSettled,
                      );
                    },
                  );
                },
              ),
              if (post.isVideo)
                SeekAnimationOverlay(
                  controller: widget.detailsController,
                ),
              if (post.isVideo)
                PlayPauseAnimationOverlay(
                  controller: widget.detailsController,
                ),
            ],
          ),
        ),
      ),
    );

    final content = switch ((navigation, viewerTransform)) {
      (final nav?, final transform?) => ValueListenableBuilder(
        valueListenable: widget.detailsController.originalImagePostKeys,
        builder: (_, _, _) {
          final useOriginal = widget
              .detailsController
              .originalImagePostKeys
              .value
              .contains(postViewerIdentity(post));
          final imageUrl = useOriginal
              ? post.originalImageUrl
              : widget.imageUrlBuilder(post);

          return ZoomEdgePageGesture(
            transform: transform,
            pageController: pageViewController,
            currentSettledPage: widget.detailsController.currentSettledPage,
            pageIndex: widget.index,
            contentSize: mediaSize,
            navigation: nav,
            mediaState: _mediaState,
            enabled:
                !pageViewController.isExpanded &&
                !post.isVideo &&
                !noteOverlayShown &&
                automaticMediaLoadingEnabled &&
                imageUrl.isNotEmpty &&
                _mediaCompatible &&
                _imageController.loadState.value == LoadState.completed &&
                _imageController.imageInfo.value != null,
            child: viewer,
          );
        },
      ),
      _ => viewer,
    };

    if (!showZoomStudy || !_isPageSettled || post.isVideo) return content;
    return Stack(
      children: [
        Positioned.fill(child: content),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
              right: 12,
              bottom: 88 + MediaQuery.paddingOf(context).bottom,
            ),
            child: ZoomStudyOverlay(
              post: post,
              controller: immersiveTransform,
              decodedSize: decodedSize,
            ),
          ),
        ),
      ],
    );
  }

  GridThumbnailMedia _initialPlaceholderMedia(
    T post,
    String initialThumbnailUrl,
  ) {
    final generator = ref.watch(
      gridThumbnailUrlGeneratorProvider(widget.authConfig),
    );
    final settings = ref.watch(
      gridThumbnailSettingsProvider(widget.authConfig),
    );
    final media = generator.resolve(post, settings: settings);

    return GridThumbnailMedia(
      url: initialThumbnailUrl,
      aspectRatio: media.aspectRatio,
      placeholderUrl: media.placeholderUrl,
      fallbackUrl: media.fallbackUrl,
      fallbackUrls: media.fallbackUrls,
      placeholderAspectRatio: media.placeholderAspectRatio,
      placeholderFit: media.placeholderFit,
    );
  }
}

class _MediaRepresentationState extends ChangeNotifier {
  void changed() => notifyListeners();
}
