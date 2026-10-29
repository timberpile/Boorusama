// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

// Project imports:
import '../../../../../foundation/display.dart';
import '../../../../settings/providers.dart';
import '../../../../navigation/destination_activity.dart';
import '../../../../navigation/destination_profile_scope.dart';
import '../../../../navigation/navigation_chrome_controller.dart';
import '../../../details_pageview/widgets.dart';
import '../../../post/types.dart';
import '../types/inherited_post.dart';
import '../types/post_details.dart';
import '../types/post_details_swipe_mode.dart';
import '../types/post_presentation_context.dart';
import 'post_details_controller.dart';
import 'post_details_page_view_scope.dart';

class PostDetailsScope<T extends Post> extends ConsumerStatefulWidget {
  const PostDetailsScope({
    required this.initialIndex,
    required this.initialThumbnailUrl,
    required this.posts,
    required this.dislclaimer,
    required this.child,
    required this.scrollController,
    super.key,
  });

  final int initialIndex;
  final String? initialThumbnailUrl;
  final List<T> posts;
  final String? dislclaimer;
  final AutoScrollController? scrollController;
  final Widget child;

  @override
  ConsumerState<PostDetailsScope<T>> createState() =>
      _PostDetailsLayoutSwitcherState<T>();
}

class _PostDetailsLayoutSwitcherState<T extends Post>
    extends ConsumerState<PostDetailsScope<T>> {
  late final PostDetailsController<T> _controller;
  late final PostDetailsPageViewController _pageViewController;
  NavigationChromeController? _navigationChrome;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();

    final initialPage = widget.initialIndex;
    final settings = ref.read(settingsProvider);
    final viewerSettings = ref.read(imageViewerSettingsProvider);

    final reduceAnimations = settings.reduceAnimations;
    final hideOverlay = viewerSettings.postDetailsOverlayInitialState.isHide;
    final slideshowOptions = toSlideShowOptions(viewerSettings);
    final hoverToControlOverlay = widget.posts[initialPage].isVideo;

    _controller = PostDetailsController<T>(
      scrollController: widget.scrollController,
      initialPage: initialPage,
      initialThumbnailUrl: widget.initialThumbnailUrl,
      posts: widget.posts,
      reduceAnimations: reduceAnimations,
      dislclaimer: widget.dislclaimer,
      doubleTapSeekDuration: viewerSettings.doubleTapSeekDuration,
    );

    _pageViewController = PostDetailsPageViewController(
      initialPage: initialPage,
      initialHideOverlay: hideOverlay,
      slideshowOptions: slideshowOptions,
      hoverToControlOverlay: hoverToControlOverlay,
      checkIfLargeScreen: () => context.isLargeScreen,
      totalPage: widget.posts.length,
      disableAnimation: reduceAnimations,
      viewMode: switch (viewerSettings.swipeMode) {
        PostDetailsSwipeMode.horizontal => ViewMode.horizontal,
        PostDetailsSwipeMode.vertical => ViewMode.vertical,
      },
      onBeforeSlideshowAdvance: (currentPage, nextPage) async {
        if (viewerSettings.slideshowVideoBehavior.isWaitForCompletion) {
          final currentPost = widget.posts[currentPage];

          if (currentPost.isVideo) {
            await _controller.waitForVideoCompletion(currentPost);
          }
        }
      },
    );
  }

  void _syncNavigationChrome() {
    if (_navigationChrome == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigationChrome?.setViewerFor(
        this,
        active: DestinationScope.maybeOf(context)?.active ?? false,
        immersive: !_pageViewController.overlay.value,
        closing: _routeAnimation?.status == AnimationStatus.reverse,
        bottomObstruction: _pageViewController.bottomObstruction.value,
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _onRouteAnimationStatus(AnimationStatus _) => _syncNavigationChrome();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (_routeAnimation != animation) {
      _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
      _routeAnimation = animation;
      animation?.addStatusListener(_onRouteAnimationStatus);
    }
    if (DestinationScope.maybeOf(context) != null &&
        _navigationChrome == null) {
      _navigationChrome = ref.read(navigationChromeProvider.notifier);
      _pageViewController.overlay.addListener(_syncNavigationChrome);
      _pageViewController.bottomObstruction.addListener(_syncNavigationChrome);
    }
    _syncNavigationChrome();
    final active = NavigationActivity.of(context);
    _controller.setNavigationActive(active);
    if (!active) _pageViewController.stopSlideshow();
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    final chrome = _navigationChrome;
    if (chrome != null)
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => chrome.setViewerFor(this, active: false, immersive: false),
      );
    _pageViewController.overlay.removeListener(_syncNavigationChrome);
    _pageViewController.bottomObstruction.removeListener(_syncNavigationChrome);
    _controller.dispose();
    _pageViewController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _pageViewController.totalPage = widget.posts.length;
    return PostDetailsPageViewScope(
      controller: _pageViewController,
      child: PostDetails(
        data: PostDetailsData(
          posts: widget.posts,
          controller: _controller,
        ),
        child: CurrentPostScope(
          post: _controller.currentPost,
          child: widget.child,
        ),
      ),
    );
  }
}

class CurrentPostScope<T extends Post> extends StatelessWidget {
  const CurrentPostScope({
    required this.post,
    required this.child,
    super.key,
  });

  final ValueNotifier<T> post;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: post,
      builder: (context, post, _) => InheritedPost(
        presentationContext: PostPresentationContext.generic(post),
        child: child,
      ),
    );
  }
}
