// Package imports:
// Project imports:
import '../../../../../core/images/types.dart';
import '../../../../../core/posts/listing/types.dart';
import '../../post/types.dart';

class DanbooruGridThumbnailUrlGenerator
    implements GridThumbnailUrlGenerator, GridThumbnailStaticCoverResolver {
  const DanbooruGridThumbnailUrlGenerator();

  @override
  GridThumbnailMedia resolve(
    Post post, {
    required GridThumbnailSettings settings,
  }) {
    final hasDanbooruVariants =
        post.danbooruData != null || post.mediaVariants.isNotEmpty;
    if (!hasDanbooruVariants) {
      return const DefaultGridThumbnailUrlGenerator().resolve(
        post,
        settings: settings,
      );
    }

    final media = defaultGridThumbnailMedia(post, settings);

    return GridThumbnailMedia(
      url: _danbooruGridThumbnailUrl(
        post: post,
        isGif: isOriginalGridGif(post),
        isVideo: post.isVideo,
        variantUrl: (type) => _variantUrl(post, type),
        settings: settings,
      ),
      aspectRatio: media.aspectRatio,
      placeholderUrl: media.placeholderUrl,
      placeholderAspectRatio: media.placeholderAspectRatio,
      placeholderFit: media.placeholderFit,
    );
  }

  @override
  GridThumbnailMedia resolveStaticCover(
    GridThumbnailStaticMedia cover, {
    required GridThumbnailSettings settings,
  }) {
    if (cover.variants.isEmpty) {
      return defaultStaticCoverGridThumbnailMedia(cover, settings);
    }
    return GridThumbnailMedia(
      url: _danbooruGridThumbnailUrl(
        post: null,
        isGif: false,
        isVideo: false,
        variantUrl: (type) => _staticCoverVariantUrl(cover, type),
        settings: settings,
      ),
      aspectRatio: null,
      placeholderUrl: cover.thumbnail,
      placeholderAspectRatio: null,
    );
  }
}

String _danbooruGridThumbnailUrl({
  required Post? post,
  required bool isGif,
  required bool isVideo,
  required String Function(PostQualityType type) variantUrl,
  required GridThumbnailSettings settings,
}) {
  if (isGif && post != null && !shouldAutoplayGridGif(post, settings)) {
    final tier = switch (settings.imageQuality) {
      ImageQuality.low => switch (settings.gridSize) {
        GridSize.micro || GridSize.tiny => PostQualityType.v180x180,
        _ => PostQualityType.v360x360,
      },
      ImageQuality.automatic ||
      ImageQuality.high => switch (settings.gridSize) {
        GridSize.micro => PostQualityType.v180x180,
        GridSize.tiny => PostQualityType.v360x360,
        _ => PostQualityType.v720x720,
      },
      ImageQuality.highest when settings.gridSize == GridSize.micro =>
        PostQualityType.v360x360,
      ImageQuality.highest || ImageQuality.original => PostQualityType.v720x720,
    };
    return variantUrl(tier);
  }

  return switch (isGif
      ? settings.imageQuality
      : settings.resolvedImageQuality) {
    ImageQuality.automatic when isGif => gridGifSampleUrl(
      post!,
      variantUrl(PostQualityType.sample),
    ),
    ImageQuality.automatic => switch (settings.gridSize) {
      GridSize.micro => variantUrl(PostQualityType.v180x180),
      GridSize.tiny => variantUrl(PostQualityType.v360x360),
      _ => variantUrl(PostQualityType.v720x720),
    },
    ImageQuality.low => switch (settings.gridSize) {
      GridSize.micro || GridSize.tiny => variantUrl(PostQualityType.v180x180),
      _ => variantUrl(PostQualityType.v360x360),
    },
    ImageQuality.high => switch (settings.gridSize) {
      GridSize.micro => variantUrl(PostQualityType.v180x180),
      GridSize.tiny => variantUrl(PostQualityType.v360x360),
      _ => variantUrl(PostQualityType.v720x720),
    },
    ImageQuality.highest
        when isGif &&
            settings.gridSize != GridSize.micro &&
            settings.gridSize != GridSize.tiny =>
      gridGifSampleUrl(post!, variantUrl(PostQualityType.sample)),
    ImageQuality.highest =>
      isVideo
          ? variantUrl(PostQualityType.v720x720)
          : switch (settings.gridSize) {
              GridSize.micro => variantUrl(PostQualityType.v360x360),
              GridSize.tiny => variantUrl(PostQualityType.v720x720),
              _ => variantUrl(PostQualityType.sample),
            },
    ImageQuality.original => variantUrl(PostQualityType.original),
  };
}

String _variantUrl(Post post, PostQualityType type) {
  final url = post.variants.getUrl(type);
  if (url.isNotEmpty) return url;

  return switch (type) {
    PostQualityType.v180x180 ||
    PostQualityType.v360x360 ||
    PostQualityType.v720x720 => post.thumbnailImageUrl,
    PostQualityType.sample => post.sampleImageUrl,
    PostQualityType.original => post.originalImageUrl,
  };
}

String _staticCoverVariantUrl(
  GridThumbnailStaticMedia cover,
  PostQualityType type,
) {
  final url = cover.variants[type.value];
  if (url != null && url.isNotEmpty) return url;
  return switch (type) {
    PostQualityType.v180x180 ||
    PostQualityType.v360x360 ||
    PostQualityType.v720x720 => cover.thumbnail,
    PostQualityType.sample => cover.sample,
    PostQualityType.original => cover.original,
  };
}
