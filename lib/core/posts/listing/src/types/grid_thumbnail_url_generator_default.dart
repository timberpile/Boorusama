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
      false => defaultStaticGridThumbnailUrl(
        thumbnail: post.thumbnailImageUrl,
        sample: post.sampleImageUrl,
        original: post.originalImageUrl,
        isVideo: post.isVideo,
        settings: settings,
      ),
    },
    aspectRatio: aspectRatio,
    placeholderUrl: post.thumbnailImageUrl,
    placeholderAspectRatio: aspectRatio,
  );
}

const maxAutoplayGridGifBytes = 5 * 1024 * 1024;

String defaultStaticGridThumbnailUrl({
  required String thumbnail,
  required String sample,
  required String original,
  required bool isVideo,
  required GridThumbnailSettings settings,
}) => switch (settings.resolvedImageQuality) {
  ImageQuality.automatic || ImageQuality.low => thumbnail,
  ImageQuality.high || ImageQuality.highest =>
    isVideo
        ? thumbnail
        : switch (settings.gridSize) {
            GridSize.micro || GridSize.tiny => thumbnail,
            _ => sample,
          },
  ImageQuality.original => isVideo ? thumbnail : original,
};

GridThumbnailMedia defaultStaticCoverGridThumbnailMedia(
  GridThumbnailStaticMedia cover,
  GridThumbnailSettings settings,
) => GridThumbnailMedia(
  url: defaultStaticGridThumbnailUrl(
    thumbnail: cover.thumbnail,
    sample: cover.sample,
    original: cover.original,
    isVideo: false,
    settings: settings,
  ),
  aspectRatio: null,
  placeholderUrl: cover.thumbnail,
  placeholderAspectRatio: null,
);

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
        GridThumbnailStaticCoverResolver,
        GridLoadingPlaceholderAspectRatioResolver {
  const DefaultGridThumbnailUrlGenerator({
    this.mediaMapper,
    this.loadingPlaceholderAspectRatioResolver,
  }) : _thumbnailOnly = false;

  const DefaultGridThumbnailUrlGenerator.thumbnailOnly()
    : mediaMapper = _thumbnailOnlyGridThumbnailMedia,
      loadingPlaceholderAspectRatioResolver = null,
      _thumbnailOnly = true;

  final GridThumbnailMediaMapper? mediaMapper;
  final double? Function(GridThumbnailSettings settings)?
  loadingPlaceholderAspectRatioResolver;
  final bool _thumbnailOnly;

  @override
  GridThumbnailMedia resolve(
    Post post, {
    required GridThumbnailSettings settings,
  }) => (mediaMapper ?? defaultGridThumbnailMedia)(post, settings);

  @override
  GridThumbnailMedia resolveStaticCover(
    GridThumbnailStaticMedia cover, {
    required GridThumbnailSettings settings,
  }) => _thumbnailOnly
      ? GridThumbnailMedia(
          url: cover.thumbnail,
          aspectRatio: null,
          placeholderUrl: cover.thumbnail,
          placeholderAspectRatio: null,
        )
      : defaultStaticCoverGridThumbnailMedia(cover, settings);

  @override
  double? resolveLoadingPlaceholderAspectRatio({
    required GridThumbnailSettings settings,
  }) => loadingPlaceholderAspectRatioResolver?.call(settings);
}

extension GridThumbnailStaticCoverResolverX on GridThumbnailUrlGenerator {
  GridThumbnailMedia resolveStaticCover(
    GridThumbnailStaticMedia cover, {
    required GridThumbnailSettings settings,
  }) {
    final generator = this;
    if (generator is GridThumbnailStaticCoverResolver) {
      return generator.resolveStaticCover(cover, settings: settings);
    }
    return defaultStaticCoverGridThumbnailMedia(cover, settings);
  }
}
