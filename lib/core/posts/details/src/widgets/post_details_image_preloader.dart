import 'dart:async';

import '../../../../navigation/destination_activity.dart';

// Package imports:
import 'package:foundation/performance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../developer_options/providers.dart';
import '../../../../http/client/providers.dart';
import '../../../../settings/providers.dart';
import '../../../../settings/types.dart';
import '../../../details_pageview/widgets.dart';
import '../../../listing/providers.dart';
import '../../../media_preload/providers.dart';
import '../../../media_preload/types.dart';
import '../../../media_preload/src/preload_metadata_queue.dart';
import '../../../media_preload/src/viewer_preload_metadata.dart';
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
  late final _metadata = PreloadMetadataQueue<(Post, BooruConfig), Post>(
    onResolved: () {
      if (mounted && _pageViewController != null) {
        _dispatchImages(_controller.page);
      }
    },
  );
  final _directionHistory = DirectionHistory();
  PostDetailsPageViewController? _pageViewController;
  int? _lastPage;
  bool _wasActive = false;
  bool _refreshScheduled = false;

  PostDetailsPageViewController get _controller => _pageViewController!;

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted && _pageViewController != null) {
        _preloadAdjacentPages(_controller.page);
      }
    });
  }

  @override
  void didUpdateWidget(MixedPostDetailsImagePreloader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.posts, widget.posts)) _scheduleRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = NavigationActivity.of(context);
    final resumed = active && !_wasActive;
    _wasActive = active;
    if (!active) {
      _metadata.cancel();
      _preloadManager.cancelAll();
    }
    final controller = PostDetailsPageViewScope.of(context);
    if (identical(_pageViewController, controller)) {
      if (resumed) _scheduleRefresh();
      return;
    }

    _pageViewController?.currentPage.removeListener(_onPageChanged);
    _metadata.cancel();
    _preloadManager.cancelAll();
    _pageViewController = controller;
    _directionHistory.clear();
    _lastPage = controller.page;
    controller.currentPage.addListener(_onPageChanged);
    _scheduleRefresh();
  }

  void _onPageChanged() {
    if (!mounted) return;
    final currentPage = _controller.page;
    _directionHistory.addDirection(currentPage, _lastPage);
    _lastPage = currentPage;
    _preloadAdjacentPages(currentPage);
  }

  void _preloadAdjacentPages(int currentPage) {
    if (!mounted ||
        !NavigationActivity.of(context) ||
        !ref.read(automaticMediaLoadingEnabledProvider)) {
      _metadata.cancel();
      _preloadManager.cancelAll();
      return;
    }
    final configs = ref.read(booruConfigProvider);
    // Ordinary engines need no metadata admission scan. Preserve the existing
    // bounded collection reads when none of the profiles offers this capability.
    if (!configs.any(
      (config) =>
          ref.read(booruRepoProvider(config.auth))
              is ViewerPreloadMetadataResolver,
    )) {
      _metadata.cancel();
      _dispatchImages(currentPage);
      return;
    }
    final strategy = DirectionBasedPreloadStrategy(
      directionHistory: _directionHistory,
    );
    final nearby = strategy
        .getResolutionIndices(
          currentPage: currentPage,
          itemCount: widget.posts.length,
        )
        .where((index) => index != currentPage)
        .toList();
    int priority(int index) {
      final delta = index - currentPage;
      final opposite = switch (_directionHistory.scrollDirection) {
        ScrollDirection.forward => delta < 0,
        ScrollDirection.backward => delta > 0,
        _ => false,
      };
      return delta.abs() * 2 + (opposite ? 1 : 0);
    }

    nearby.sort((a, b) => priority(a).compareTo(priority(b)));
    final indices = [
      if (currentPage >= 0 && currentPage < widget.posts.length) currentPage,
      if (_directionHistory.entryPattern != EntryPattern.direct)
        ...nearby.take(4),
    ];
    final requests = <PreloadMetadataRequest<(Post, BooruConfig), Post>>[];
    for (final index in indices) {
      final post = widget.posts[index];
      final resolution = const PostOriginResolver().resolve(
        post.origin,
        configs,
      );
      if (resolution case ResolvedPostOrigin(:final config)) {
        final repository = ref.read(booruRepoProvider(config.auth));
        if (repository case final ViewerPreloadMetadataResolver resolver) {
          final load = resolver.viewerPreloadMetadataLoader(post, config);
          if (load != null) {
            requests.add((
              key: (post, config),
              load: () async {
                final result = await load();
                if (result == null ||
                    result.id != post.id ||
                    result.origin.booruType != post.origin.booruType ||
                    result.origin.sourceHost != post.origin.sourceHost)
                  return null;
                return result;
              },
            ));
          }
        }
      }
    }
    unawaited(_metadata.replace(requests));
    _dispatchImages(currentPage);
  }

  void _dispatchImages(int currentPage) {
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
          final input = widget.posts[index];
          final resolution = const PostOriginResolver().resolve(
            input.origin,
            configs,
          );
          final config = switch (resolution) {
            ResolvedPostOrigin(:final config) => config,
            _ => null,
          };
          if (config == null) return null;
          final repository = ref.read(booruRepoProvider(config.auth));
          final needsMetadata = switch (repository) {
            final ViewerPreloadMetadataResolver resolver =>
              resolver.viewerPreloadMetadataLoader(input, config) != null,
            _ => false,
          };
          final resolved = _metadata.peek((input, config));
          final post = resolved ?? input;
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
          if (needsMetadata) {
            final media = thumbnailOnlyViewerPreloadMedia(
              post,
              displayUrl: resolved == null ? null : imageUrl,
            );
            return media == null ? null : (group: auth, media: media);
          }
          final thumbnail = ref
              .read(gridThumbnailUrlGeneratorProvider(auth))
              .resolve(
                post,
                settings: ref.read(gridThumbnailSettingsProvider(auth)),
              )
              .url;
          final media = thumbnailOnlyViewerPreloadMedia(
            post,
            thumbnailUrl: thumbnail,
            displayUrl: imageUrl == post.originalImageUrl
                ? ref.read(postQualityProvider(auth)) == PostQuality.original
                      ? post.sampleImageUrl
                      : null
                : imageUrl,
          );
          return media == null ? null : (group: auth, media: media);
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
    _metadata.dispose();
    _preloadManager.cancelAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(booruConfigProvider, (_, _) => _scheduleRefresh());
    ref.listen(automaticMediaLoadingEnabledProvider, (_, enabled) {
      if (!enabled) {
        _metadata.cancel();
        _preloadManager.cancelAll();
      } else {
        _scheduleRefresh();
      }
    });
    return widget.child;
  }
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
          final post => thumbnailOnlyViewerPreloadMedia(
            post,
            thumbnailUrl: gridThumbnailUrlBuilder
                .resolve(post, settings: settings)
                .url,
            displayUrl: widget.imageUrlBuilder(post) == post.originalImageUrl
                ? ref.read(postQualityProvider(widget.authConfig)) ==
                          PostQuality.original
                      ? post.sampleImageUrl
                      : null
                : widget.imageUrlBuilder(post),
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
