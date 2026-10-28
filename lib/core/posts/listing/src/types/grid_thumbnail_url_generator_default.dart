// Package imports:
import 'package:coreutils/coreutils.dart';

// Project imports:
import '../../../../images/types.dart';
import '../../../post/types.dart';
import 'animated_posts_default_state.dart';
import 'grid_size.dart';
import 'grid_thumbnail_url_generator.dart';

GridThumbnailMedia defaultGridThumbnailMedia(
  Post post,
  GridThumbnailSettings settings,
) {
  final isGif = isOriginalGridGif(post);
  final sampleUrl = isGif
      ? gridGifSampleUrl(post, post.sampleImageUrl)
      : post.sampleImageUrl;
  final sampleAspectRatio = isGif && sampleUrl == post.originalImageUrl
      ? post.effectiveOriginalAspectRatio
      : post.effectiveSampleAspectRatio;
  if (isGif && !shouldAutoplayGridGif(post, settings)) {
    return GridThumbnailMedia(
      url: post.thumbnailImageUrl,
      aspectRatio: post.effectiveThumbnailAspectRatio,
      placeholderUrl: post.thumbnailImageUrl,
      placeholderAspectRatio: post.effectiveThumbnailAspectRatio,
    );
  }
  final aspectRatio = switch (isGif) {
    true => switch (settings.imageQuality) {
      ImageQuality.automatic => switch (settings.animatedPostsDefaultState) {
        AnimatedPostsDefaultState.autoplay => sampleAspectRatio,
        AnimatedPostsDefaultState.static => post.effectiveThumbnailAspectRatio,
      },
      ImageQuality.low => post.effectiveThumbnailAspectRatio,
      ImageQuality.high => sampleAspectRatio,
      ImageQuality.highest => sampleAspectRatio,
      ImageQuality.original => post.effectiveOriginalAspectRatio,
    },
    false => switch (settings.resolvedImageQuality) {
      ImageQuality.automatic => post.effectiveThumbnailAspectRatio,
      ImageQuality.low => post.effectiveThumbnailAspectRatio,
      ImageQuality.high =>
        post.isVideo
            ? post.effectiveVideoThumbnailAspectRatio
            : switch (settings.gridSize) {
                GridSize.micro ||
                GridSize.tiny => post.effectiveThumbnailAspectRatio,
                _ => post.effectiveSampleAspectRatio,
              },
      ImageQuality.highest =>
        post.isVideo
            ? post.effectiveVideoThumbnailAspectRatio
            : switch (settings.gridSize) {
                GridSize.micro ||
                GridSize.tiny => post.effectiveThumbnailAspectRatio,
                _ => post.effectiveSampleAspectRatio,
              },
      ImageQuality.original =>
        post.isVideo
            ? post.effectiveVideoThumbnailAspectRatio
            : post.effectiveOriginalAspectRatio,
    },
  };

  return GridThumbnailMedia(
    url: switch (isGif) {
      true => switch (settings.imageQuality) {
        ImageQuality.automatic => switch (settings.animatedPostsDefaultState) {
          AnimatedPostsDefaultState.autoplay => sampleUrl,
          AnimatedPostsDefaultState.static => post.thumbnailImageUrl,
        },
        ImageQuality.low => post.thumbnailImageUrl,
        ImageQuality.high => sampleUrl,
        ImageQuality.highest => sampleUrl,
        ImageQuality.original => post.originalImageUrl,
      },
      false => switch (settings.resolvedImageQuality) {
        ImageQuality.automatic => post.thumbnailImageUrl,
        ImageQuality.low => post.thumbnailImageUrl,
        ImageQuality.high =>
          post.isVideo
              ? post.thumbnailImageUrl
              : switch (settings.gridSize) {
                  GridSize.micro || GridSize.tiny => post.thumbnailImageUrl,
                  _ => post.sampleImageUrl,
                },
        ImageQuality.highest =>
          post.isVideo
              ? post.thumbnailImageUrl
              : switch (settings.gridSize) {
                  GridSize.micro || GridSize.tiny => post.thumbnailImageUrl,
                  _ => post.sampleImageUrl,
                },
        ImageQuality.original =>
          post.isVideo ? post.thumbnailImageUrl : post.originalImageUrl,
      },
    },
    aspectRatio: aspectRatio,
    placeholderUrl: post.thumbnailImageUrl,
    placeholderAspectRatio: aspectRatio,
  );
}

const maxAutoplayGridGifBytes = 5 * 1024 * 1024;

// The viewer's isGif also inspects videoUrl, which may be a transcoded sample.
// Grid limits must instead follow the original file whose size the API reports.
bool isOriginalGridGif(Post post) => switch (post.format.toLowerCase()) {
  'gif' || '.gif' => true,
  '' => post.isGif,
  _ => false,
};

String gridGifSampleUrl(Post post, String sampleUrl) {
  final extension = urlExtension(sampleUrl).toLowerCase();
  // A static JPEG or video transcode cannot animate in an image grid.
  return sampleUrl.isEmpty ||
          extension == '.jpg' ||
          extension == '.jpeg' ||
          isFormatVideo(extension)
      ? post.originalImageUrl
      : sampleUrl;
}

bool shouldAutoplayGridGif(Post post, GridThumbnailSettings settings) =>
    isOriginalGridGif(post) &&
    settings.animatedPostsDefaultState == AnimatedPostsDefaultState.autoplay &&
    post.fileSize > 0 &&
    (post.fileSize <= maxAutoplayGridGifBytes || settings.allowLargeCachedGif);

GridThumbnailMedia _thumbnailOnlyGridThumbnailMedia(
  Post post,
  GridThumbnailSettings settings,
) {
  final aspectRatio = post.effectiveThumbnailAspectRatio;

  return GridThumbnailMedia(
    url: post.thumbnailImageUrl,
    aspectRatio: aspectRatio,
    placeholderUrl: post.thumbnailImageUrl,
    placeholderAspectRatio: aspectRatio,
  );
}

class DefaultGridThumbnailUrlGenerator
    implements
        GridThumbnailUrlGenerator,
        GridLoadingPlaceholderAspectRatioResolver {
  const DefaultGridThumbnailUrlGenerator({
    this.mediaMapper,
    this.loadingPlaceholderAspectRatioResolver,
  });

  const DefaultGridThumbnailUrlGenerator.thumbnailOnly()
    : mediaMapper = _thumbnailOnlyGridThumbnailMedia,
      loadingPlaceholderAspectRatioResolver = null;

  final GridThumbnailMediaMapper? mediaMapper;
  final double? Function(GridThumbnailSettings settings)?
  loadingPlaceholderAspectRatioResolver;

  @override
  GridThumbnailMedia resolve(
    Post post, {
    required GridThumbnailSettings settings,
  }) => (mediaMapper ?? defaultGridThumbnailMedia)(post, settings);

  @override
  double? resolveLoadingPlaceholderAspectRatio({
    required GridThumbnailSettings settings,
  }) => loadingPlaceholderAspectRatioResolver?.call(settings);
}
