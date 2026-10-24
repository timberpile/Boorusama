import '../../../../navigation/destination_activity.dart';

// Package imports:
import 'package:foundation/performance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../developer_options/providers.dart';
import '../../../../http/client/providers.dart';
import '../../../details_pageview/widgets.dart';
import '../../../listing/providers.dart';
import '../../../media_preload/providers.dart';
import '../../../media_preload/types.dart';
import '../../../post/types.dart';
import '../providers/providers.dart';
import 'post_details_page_view_scope.dart';

class MixedPostDetailsImagePreloader extends ConsumerStatefulWidget {
  const MixedPostDetailsImagePreloader({
    required this.child,
    required this.posts,
    super.key,
  });

  final List<Post> posts;
  final Widget child;

  @override
  ConsumerState<MixedPostDetailsImagePreloader> createState() =>
      _MixedPostDetailsImagePreloaderState();
}

class _MixedPostDetailsImagePreloaderState
    extends ConsumerState<MixedPostDetailsImagePreloader> {
  late final _preloadManager = GroupedPreloadManager<BooruConfigAuth>(
    managerBuilder: (auth) {
      final dio = ref.read(dioForWidgetProvider(auth));
      return ref.read(
        preloadManagerProvider((dio: dio, authConfig: auth)),
      );
    },
  );
  final _directionHistory = DirectionHistory();
  PostDetailsPageViewController? _pageViewController;
  int? _lastPage;
  bool _wasActive = false;

  PostDetailsPageViewController get _controller => _pageViewController!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = NavigationActivity.of(context);
    final resumed = active && !_wasActive;
    _wasActive = active;
    if (!active) _preloadManager.cancelAll();
    final controller = PostDetailsPageViewScope.of(context);
    if (identical(_pageViewController, controller)) {
      if (resumed)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _preloadAdjacentPages(controller.page);
        });
      return;
    }

    _pageViewController?.currentPage.removeListener(_onPageChanged);
    _preloadManager.cancelAll();
    _pageViewController = controller;
    _directionHistory.clear();
    _lastPage = controller.page;
    controller.currentPage.addListener(_onPageChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_pageViewController, controller)) return;
      _preloadAdjacentPages(controller.page);
    });
  }

  void _onPageChanged() {
    if (!mounted) return;
    final currentPage = _controller.page;
    _directionHistory.addDirection(currentPage, _lastPage);
    _lastPage = currentPage;
    _preloadAdjacentPages(currentPage);
  }

  void _preloadAdjacentPages(int currentPage) {
    if (!mounted || !NavigationActivity.of(context)) {
      _preloadManager.cancelAll();
      return;
    }
    final diagnosticRecording = performanceRecorder.enabled;
    var diagnosticResolved = 0;
    performanceRecorder.measureSync(PerfOperation.mixedPreloadResolve, () {
      if (!ref.read(automaticMediaLoadingEnabledProvider)) {
        _preloadManager.cancelAll();
        return;
      }

      final configs = ref.read(booruConfigProvider);
      _preloadManager.preloadWithStrategy(
        strategy: DirectionBasedPreloadStrategy(
          directionHistory: _directionHistory,
        ),
        currentPage: currentPage,
        itemCount: widget.posts.length,
        mediaBuilder: (index) {
          if (diagnosticRecording) diagnosticResolved++;
          final post = widget.posts[index];
          final resolution = const PostOriginResolver().resolve(
            post.origin,
            configs,
          );
          final config = switch (resolution) {
            ResolvedPostOrigin(:final config) => config,
            _ => null,
          };
          if (config == null) return null;

          final auth = config.auth;
          if (post.isVideo) {
            return (
              group: auth,
              media: ImageMedia.fromUrl(
                post.videoThumbnailUrl,
                estimatedSizeBytes: post.fileSize,
              ),
            );
          }

          final resolver = ref.read(mediaUrlResolverProvider(auth));
          final imageUrl = resolver.resolveMediaUrl(post, config.viewer);
          final thumbnail = ref
              .read(gridThumbnailUrlGeneratorProvider(auth))
              .resolve(
                post,
                settings: ref.read(gridThumbnailSettingsProvider(auth)),
              )
              .url;
          return (
            group: auth,
            media: post.originalImageUrl == imageUrl
                ? ImageMedia.fromUrl(
                    thumbnail,
                    estimatedSizeBytes: post.fileSize,
                  )
                : ImageMedia(
                    thumbnailUrl: thumbnail,
                    originalUrl: imageUrl,
                    estimatedSizeBytes: post.fileSize,
                  ),
          );
        },
      );
    });
    performanceRecorder.count(
      PerfCounter.mixedCollectionSize,
      widget.posts.length,
    );
    performanceRecorder.count(
      PerfCounter.mixedResolvedPosts,
      diagnosticResolved,
    );
  }

  @override
  void dispose() {
    _pageViewController?.currentPage.removeListener(_onPageChanged);
    _preloadManager.cancelAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class PostDetailsImagePreloader<T extends Post> extends ConsumerStatefulWidget {
  const PostDetailsImagePreloader({
    required this.child,
    required this.authConfig,
    required this.posts,
    required this.imageUrlBuilder,
    super.key,
  });

  final BooruConfigAuth authConfig;
  final List<T> posts;
  final Widget child;
  final String Function(T post) imageUrlBuilder;

  @override
  ConsumerState<PostDetailsImagePreloader<T>> createState() =>
      _PostDetailsImagePreloaderState<T>();
}

class _PostDetailsImagePreloaderState<T extends Post>
    extends ConsumerState<PostDetailsImagePreloader<T>> {
  PreloadManager? _preloadManager;

  PostDetailsPageViewController? _pageViewController;

  // Direction tracking
  int? _lastPage;
  bool _wasActive = false;
  final _directionHistory = DirectionHistory();

  PostDetailsPageViewController get _controller => _pageViewController!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final active = NavigationActivity.of(context);
    final resumed = active && !_wasActive;
    _wasActive = active;
    if (!active) _preloadManager?.cancelAll();
    final controller = PostDetailsPageViewScope.of(context);
    if (identical(_pageViewController, controller)) {
      if (resumed)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _preloadAdjacentPages(controller.page);
        });
      return;
    }

    _pageViewController?.currentPage.removeListener(_onPageChanged);
    _preloadManager?.cancelAll();
    _pageViewController = controller;
    _directionHistory.clear();
    _lastPage = controller.page;
    final dio = ref.read(dioForWidgetProvider(widget.authConfig));
    _preloadManager = ref.read(
      preloadManagerProvider((dio: dio, authConfig: widget.authConfig)),
    );
    controller.currentPage.addListener(_onPageChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_pageViewController, controller)) return;
      _preloadAdjacentPages(controller.page);
    });
  }

  void _onPageChanged() {
    if (!mounted) return;
    final currentPage = _controller.page;
    _updateDirectionHistory(currentPage);
    _preloadAdjacentPages(currentPage);
  }

  void _updateDirectionHistory(int currentPage) {
    _directionHistory.addDirection(currentPage, _lastPage);
    _lastPage = currentPage;
  }

  Future<void> _preloadAdjacentPages(int currentPage) async {
    if (!mounted || !NavigationActivity.of(context)) {
      _preloadManager?.cancelAll();
      return;
    }
    performanceRecorder.measureSync(PerfOperation.viewerPreloadDispatch, () {
      if (!mounted) return;

      final gridThumbnailUrlBuilder = ref.read(
        gridThumbnailUrlGeneratorProvider(widget.authConfig),
      );

      final settings = ref.read(
        gridThumbnailSettingsProvider(widget.authConfig),
      );

      _preloadManager?.preloadWithStrategy(
        strategy: DirectionBasedPreloadStrategy(
          directionHistory: _directionHistory,
        ),
        currentPage: currentPage,
        itemCount: widget.posts.length,
        mediaBuilder: (index) => switch (widget.posts[index]) {
          // Treat video as image for now, it will be changed when video preload is implemented
          final post when post.isVideo => ImageMedia.fromUrl(
            post.videoThumbnailUrl,
            estimatedSizeBytes: post.fileSize,
          ),
          final post
              when post.originalImageUrl == widget.imageUrlBuilder(post) =>
            ImageMedia.fromUrl(
              gridThumbnailUrlBuilder.resolve(post, settings: settings).url,
              estimatedSizeBytes: post.fileSize,
            ),
          final post => ImageMedia(
            thumbnailUrl: gridThumbnailUrlBuilder
                .resolve(post, settings: settings)
                .url,
            originalUrl: widget.imageUrlBuilder(post),
            estimatedSizeBytes: post.fileSize,
          ),
        },
      );
    });
  }

  @override
  void dispose() {
    _pageViewController?.currentPage.removeListener(_onPageChanged);
    _preloadManager?.cancelAll();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
