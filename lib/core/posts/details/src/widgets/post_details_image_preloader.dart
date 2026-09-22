// Package imports:
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
  final _managers = <BooruConfigAuth, PreloadManager>{};
  final _directionHistory = DirectionHistory();
  PostDetailsPageViewController? _pageViewController;
  int? _lastPage;

  PostDetailsPageViewController get _controller =>
      _pageViewController ??= PostDetailsPageViewScope.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pageViewController != null) return;

    final controller = _controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lastPage = controller.initialPage;
      _preloadAdjacentPages(controller.initialPage);
    });
    controller.currentPage.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    if (!mounted) return;
    final currentPage = _controller.page;
    _directionHistory.addDirection(currentPage, _lastPage);
    _lastPage = currentPage;
    _preloadAdjacentPages(currentPage);
  }

  void _preloadAdjacentPages(int currentPage) {
    if (!ref.read(automaticMediaLoadingEnabledProvider)) return;

    final resolved = <int, _ResolvedPreloadPost>{};
    for (var index = 0; index < widget.posts.length; index++) {
      if (_resolve(widget.posts[index]) case final value?) {
        resolved[index] = value;
      }
    }

    for (final auth in resolved.values.map((e) => e.auth).toSet()) {
      final manager = _managers.putIfAbsent(auth, () {
        final dio = ref.read(dioForWidgetProvider(auth));
        return ref.read(
          preloadManagerProvider((dio: dio, authConfig: auth)),
        );
      });
      final gridThumbnailUrlBuilder = ref.read(
        gridThumbnailUrlGeneratorProvider(auth),
      );
      final settings = ref.read(gridThumbnailSettingsProvider(auth));

      manager.preloadWithStrategy(
        strategy: DirectionBasedPreloadStrategy(
          directionHistory: _directionHistory,
        ),
        currentPage: currentPage,
        itemCount: widget.posts.length,
        mediaBuilder: (index) {
          final value = resolved[index];
          if (value == null || value.auth != auth) return null;

          final post = value.post;
          if (post.isVideo) {
            return ImageMedia.fromUrl(
              post.videoThumbnailUrl,
              estimatedSizeBytes: post.fileSize,
            );
          }

          final thumbnail = gridThumbnailUrlBuilder
              .resolve(
                post,
                settings: settings,
              )
              .url;
          return post.originalImageUrl == value.imageUrl
              ? ImageMedia.fromUrl(
                  thumbnail,
                  estimatedSizeBytes: post.fileSize,
                )
              : ImageMedia(
                  thumbnailUrl: thumbnail,
                  originalUrl: value.imageUrl,
                  estimatedSizeBytes: post.fileSize,
                );
        },
      );
    }
  }

  _ResolvedPreloadPost? _resolve(Post post) {
    if (post is! UnifiedPost) return null;
    final resolution = const PostOriginResolver().resolve(
      post.origin,
      ref.read(booruConfigProvider),
    );
    final config = switch (resolution) {
      ResolvedPostOrigin(:final config) => config,
      _ => null,
    };
    if (config == null) return null;

    final resolver = ref.read(mediaUrlResolverProvider(config.auth));
    return (
      post: post,
      auth: config.auth,
      imageUrl: resolver.resolveMediaUrl(post, config.viewer),
    );
  }

  @override
  void dispose() {
    _controller.currentPage.removeListener(_onPageChanged);
    for (final manager in _managers.values) {
      manager.cancelAll();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

typedef _ResolvedPreloadPost = ({
  Post post,
  BooruConfigAuth auth,
  String imageUrl,
});

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
  final _directionHistory = DirectionHistory();

  PostDetailsPageViewController get _controller {
    return _pageViewController ??= PostDetailsPageViewScope.of(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_pageViewController == null) {
      final controller = _controller;
      final dio = ref.read(dioForWidgetProvider(widget.authConfig));

      _preloadManager = ref.read(
        preloadManagerProvider((
          dio: dio,
          authConfig: widget.authConfig,
        )),
      );

      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _lastPage = controller.initialPage;
        _preloadAdjacentPages(controller.initialPage);
      });

      controller.currentPage.addListener(_onPageChanged);
    }
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
        final post when post.originalImageUrl == widget.imageUrlBuilder(post) =>
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
  }

  @override
  void dispose() {
    _controller.currentPage.removeListener(_onPageChanged);
    _preloadManager?.cancelAll();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
