// Package imports:
import 'package:cache_manager/cache_manager.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../foundation/loggers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/network/providers.dart';
import '../../../../content/content_media_access.dart';
import '../../../../content/content_media_dio.dart';
import '../../../../content/content_access_provider.dart';
import '../../../../ddos/handler/providers.dart';
import '../../../../developer_options/blocked_media_placeholder.dart';
import '../../../../developer_options/providers.dart';
import '../../../../http/client/providers.dart';
import '../../../../images/booru_image.dart' show ErrorPlaceholder;
import '../../../../navigation/destination_activity.dart';
import '../../../../local_media/local_media_providers.dart';
import '../../../../local_media/local_media_reference.dart';
import '../../../../local_media/local_media_thumbnail.dart';
import '../../../../videos/engines/types.dart';
import '../../../../settings/providers.dart';
import '../../../../settings/routes.dart';
import '../../../../videos/cache/providers.dart';
import '../../../../videos/cache/prepare_bound_video.dart';
import '../../../../videos/player/providers.dart';
import '../../../../videos/player/widgets.dart';
import '../../../details_pageview/widgets.dart';
import '../../../post/types.dart';
import '../providers/video_url_provider.dart';
import '../types/post_details.dart';
import '../types/post_presentation_fallback_reason.dart';
import '../types/utils.dart';
import 'post_details_image.dart';

class PostMedia<T extends Post> extends ConsumerWidget {
  const PostMedia({
    required this.post,
    required this.config,
    required this.viewer,
    required this.imageUrlBuilder,
    required this.mediaAspectRatioBuilder,
    required this.videoAspectRatioBuilder,
    required this.placeholderMediaBuilder,
    required this.controller,
    required this.imageCacheManager,
    this.imageController,
    this.onRepresentationChanged,
    this.onTerminalFailure,
    this.onVideoFrameChanged,
    this.contentSize,
    this.onImageSize,
    super.key,
    this.isPageSettled = false,
    this.detailsImageBuilder,
    this.presentationConfig,
  });

  final T post;
  final BooruConfigAuth config;
  final BooruConfigViewer viewer;
  final PostDetailsPageViewController controller;
  final String Function(T post)? imageUrlBuilder;
  final double? Function(T post)? mediaAspectRatioBuilder;
  final double? Function(T post)? videoAspectRatioBuilder;
  final PostDetailsPlaceholderMediaBuilder<T>? placeholderMediaBuilder;
  final ImageCacheManager? imageCacheManager;
  final ExtendedImageController? imageController;
  final ValueChanged<bool>? onRepresentationChanged;
  final VoidCallback? onTerminalFailure;
  final ValueChanged<bool>? onVideoFrameChanged;
  final Size? contentSize;
  final ValueChanged<Size>? onImageSize;
  final bool isPageSettled;
  final PostDetailsImageBuilder? detailsImageBuilder;
  final BooruConfig? presentationConfig;

  void _openSettings(WidgetRef ref) {
    openImageViewerSettingsPage(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (post.booruData case LocalMediaPostData(:final reference)) {
      return _buildLocalMedia(context, ref, reference);
    }
    final access = watchContentMediaAccess(ref, config, post: post);
    if (!access.allowed) {
      return const BlockedMediaPlaceholder(borderRadius: BorderRadius.zero);
    }
    final details = PostDetails.of(context);
    final heroTag = postHeroTag(post);
    final automaticMediaLoadingEnabled = ref.watch(
      automaticMediaLoadingEnabledProvider,
    );

    if (!automaticMediaLoadingEnabled) {
      return BlockedMediaPlaceholder(
        aspectRatio: post.isVideo
            ? videoAspectRatioBuilder?.call(post) ??
                  post.effectiveVideoAspectRatio
            : mediaAspectRatioBuilder?.call(post) ??
                  post.effectiveSampleAspectRatio,
        isVideo: post.isVideo,
      );
    }

    final headers = ref.watch(httpHeadersProvider(config));

    return post.isVideo
        ? Stack(
            children: [
              Positioned.fill(
                child: Builder(
                  builder: (context) {
                    final videoUrl = ref.watch(
                      postDetailsVideoUrlProvider(
                        VideoUrlParam(
                          viewer: viewer,
                          post: post,
                          auth: config,
                        ),
                      ),
                    );

                    final request = ref
                        .watch(networkSettingsProvider(config))
                        .resolveMedia(
                          videoUrl,
                          headers: headers,
                          sourceUrl: config.url,
                        );
                    final publicScope = config.anonymousReadScope;
                    if (publicScope != null) {
                      final uri = Uri.tryParse(request.url);
                      if (uri == null || !publicScope.source.allowsMedia(uri)) {
                        return const ErrorPlaceholder(
                          borderRadius: BorderRadius.zero,
                          video: true,
                          reason:
                              PostPresentationFallbackReason.unavailableEngine,
                        );
                      }
                    }
                    final mediaDio = access.key == null
                        ? null
                        : ref.watch(contentMediaDioProvider(access.key!));
                    final mediaHeaders = {
                      ...request.headers,
                      if (publicScope == null && request.overridden)
                        ...ref.watch(
                          cachedBypassDdosHeadersProvider(request.url),
                        ),
                    };
                    return BooruVideo(
                      key: ValueKey((access.key, request.url)),
                      sourceLoader: access.key == null
                          ? null
                          : (cancellation) => Future.sync(() {
                              bool current() =>
                                  (publicScope?.isCurrent ?? true) &&
                                  ref.context.mounted &&
                                  ref
                                          .read(
                                            contentAccessContextProvider(
                                              access.key!,
                                            ),
                                          )
                                          ?.key ==
                                      access.key;
                              return prepareBoundVideo(
                                url: request.url,
                                namespace: 'content-media',
                                transport: mediaDio!,
                                headers: mediaHeaders,
                                isCurrent: current,
                                cancellation: cancellation,
                                fileSize: post.fileSize > 0
                                    ? post.fileSize
                                    : null,
                                cache: ref.read(videoCacheManagerProvider),
                              );
                            }),
                      heroTag: heroTag,
                      url: request.url,
                      aspectRatio:
                          videoAspectRatioBuilder?.call(post) ??
                          post.effectiveVideoAspectRatio,
                      onCurrentPositionChanged: (current, total) =>
                          details.controller.onCurrentPositionChanged(
                            current,
                            total,
                            post,
                          ),
                      onVideoPlayerCreated: (player) {
                        onVideoFrameChanged?.call(false);
                        details.controller.onBooruVideoPlayerCreated(
                          player,
                          post,
                        );
                      },
                      onVideoPlayerDisposed: () {
                        onVideoFrameChanged?.call(false);
                        details.controller.onBooruVideoPlayerDisposed(post);
                      },
                      onFrameRendered: () => onVideoFrameChanged?.call(true),
                      sound: ref.watch(globalSoundStateProvider),
                      speed: ref.watch(playbackSpeedProvider(videoUrl)),
                      thumbnailUrl: post.videoThumbnailUrl,
                      onOpenSettings: () => _openSettings(ref),
                      headers: mediaHeaders,
                      videoPlayerEngine: ref.watch(
                        imageViewerSettingsProvider.select(
                          (value) => value.videoPlayerEngine,
                        ),
                      ),
                      userAgent: ref.watch(
                        userAgentProvider(config),
                      ),
                      logger: ref.watch(loggerProvider),
                      cacheManager: ref.watch(videoCacheManagerProvider),
                      cacheDelay: createVideoCacheDelayCallback(post),
                      fileSize: post.fileSize > 0 ? post.fileSize : null,
                      shouldInitialize: isPageSettled,
                    );
                  },
                ),
              ),
            ],
          )
        : _buildImage(context, heroTag);
  }

  Widget _buildLocalMedia(
    BuildContext context,
    WidgetRef ref,
    LocalMediaReference reference,
  ) {
    final state = ref.watch(localMediaPresentationProvider(reference));
    if (state.isLoading && state.valueOrNull == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final media = state.valueOrNull;
    final file = media?.file;
    if (file == null || media == null) {
      return const LocalMediaUnavailable(showLabel: true);
    }
    final current = media.item.toPost();
    if (current.isVideo) {
      final details = PostDetails.of(context);
      final engine = ref.watch(
        imageViewerSettingsProvider.select((value) => value.videoPlayerEngine),
      );
      return BooruVideo(
        key: ValueKey(reference),
        url: file.uri.toString(),
        aspectRatio: current.effectiveVideoAspectRatio,
        sourceLoader: (_) async => (
          source: LocalFileVideoSource(file),
          release: null,
        ),
        videoPlayerEngine: engine == VideoPlayerEngine.webview
            ? VideoPlayerEngine.videoPlayerPlugin
            : engine,
        heroTag: postHeroTag(current),
        onCurrentPositionChanged: (position, total) => details.controller
            .onCurrentPositionChanged(position, total, current),
        onVideoPlayerCreated: (player) {
          onVideoFrameChanged?.call(false);
          details.controller.onBooruVideoPlayerCreated(player, current);
        },
        onVideoPlayerDisposed: () {
          onVideoFrameChanged?.call(false);
          details.controller.onBooruVideoPlayerDisposed(current);
        },
        onFrameRendered: () => onVideoFrameChanged?.call(true),
        sound: ref.watch(globalSoundStateProvider),
        speed: ref.watch(playbackSpeedProvider(reference.sha256)),
        shouldInitialize: isPageSettled,
        onOpenSettings: () => _openSettings(ref),
      );
    }

    final image = _LocalMediaImage(
      key: ValueKey((reference, imageController)),
      image: FileImage(file),
      controller: imageController,
      onDecoded: (size) {
        onRepresentationChanged?.call(true);
        onImageSize?.call(size);
      },
    );
    final aspectRatio = current.effectiveOriginalAspectRatio;
    return Center(
      child: aspectRatio == null
          ? image
          : AspectRatio(aspectRatio: aspectRatio, child: image),
    );
  }

  Widget _buildImage(BuildContext context, String heroTag) {
    final poster = PostDetailsImage(
      heroTag: heroTag,
      imageUrlBuilder: imageUrlBuilder,
      mediaAspectRatioBuilder: mediaAspectRatioBuilder,
      placeholderMediaBuilder: placeholderMediaBuilder,
      imageCacheManager: imageCacheManager,
      imageController: imageController,
      onRepresentationChanged: onRepresentationChanged,
      onTerminalFailure: onTerminalFailure,
      contentSize: contentSize,
      onImageSize: onImageSize,
      post: post,
      config: config,
    );
    final builder = detailsImageBuilder;
    final source = presentationConfig;
    if (builder == null || source == null) return poster;
    return builder(
      post: post,
      config: source,
      active:
          isPageSettled &&
          NavigationActivity.of(context) &&
          (ModalRoute.of(context)?.isCurrent ?? true),
      poster: poster,
    );
  }
}

class _LocalMediaImage extends StatefulWidget {
  const _LocalMediaImage({
    required this.image,
    required this.controller,
    required this.onDecoded,
    super.key,
  });

  final FileImage image;
  final ExtendedImageController? controller;
  final ValueChanged<Size> onDecoded;

  @override
  State<_LocalMediaImage> createState() => _LocalMediaImageState();
}

class _LocalMediaImageState extends State<_LocalMediaImage> {
  var _reported = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.loadState.addListener(_reportDecoded);
  }

  @override
  void didUpdateWidget(_LocalMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _reported = false;
  }

  @override
  void dispose() {
    widget.controller?.loadState.removeListener(_reportDecoded);
    super.dispose();
  }

  void _reportDecoded() {
    final controller = widget.controller;
    final info = controller?.imageInfo.value;
    if (_reported ||
        controller?.loadState.value != LoadState.completed ||
        info == null) {
      return;
    }
    _reported = true;
    final image = widget.image;
    final size = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    // FileImage can decode synchronously from the cache while its widget mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.image == image && widget.controller == controller) {
        widget.onDecoded(size);
      }
    });
  }

  @override
  Widget build(BuildContext context) => ExtendedImage(
    image: widget.image,
    controller: widget.controller,
    fit: BoxFit.contain,
    errorWidget: const LocalMediaUnavailable(showLabel: true),
  );
}
