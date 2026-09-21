// Package imports:
// Project imports:
import '../../../../../core/images/types.dart';
import '../../../../../core/posts/listing/types.dart';
import '../../../../../core/posts/post/types.dart';
import '../../post/types.dart';

class DanbooruGridThumbnailUrlGenerator implements GridThumbnailUrlGenerator {
  const DanbooruGridThumbnailUrlGenerator();

  @override
  GridThumbnailMedia resolve(
    Post post, {
    required GridThumbnailSettings settings,
  }) {
    final hasDanbooruVariants = switch (post) {
      DanbooruPost() => true,
      PostMediaVariants(:final mediaVariants) => mediaVariants.isNotEmpty,
      _ => false,
    };
    if (!hasDanbooruVariants) {
      return const DefaultGridThumbnailUrlGenerator().resolve(
        post,
        settings: settings,
      );
    }

    final media = defaultGridThumbnailMedia(post, settings);

    return GridThumbnailMedia(
      url: _danbooruGridThumbnailUrl(post, settings),
      aspectRatio: media.aspectRatio,
      placeholderUrl: media.placeholderUrl,
      placeholderAspectRatio: media.placeholderAspectRatio,
      placeholderFit: media.placeholderFit,
    );
  }
}

String _danbooruGridThumbnailUrl(
  Post post,
  GridThumbnailSettings settings,
) => switch (settings.imageQuality) {
  ImageQuality.automatic => switch (settings.gridSize) {
    GridSize.micro => _variantUrl(post, PostQualityType.v180x180),
    GridSize.tiny => _variantUrl(post, PostQualityType.v360x360),
    _ => _variantUrl(post, PostQualityType.v720x720),
  },
  ImageQuality.low => switch (settings.gridSize) {
    GridSize.micro ||
    GridSize.tiny => _variantUrl(post, PostQualityType.v180x180),
    _ => _variantUrl(post, PostQualityType.v360x360),
  },
  ImageQuality.high => switch (settings.gridSize) {
    GridSize.micro => _variantUrl(post, PostQualityType.v180x180),
    GridSize.tiny => _variantUrl(post, PostQualityType.v360x360),
    _ => _variantUrl(post, PostQualityType.v720x720),
  },
  ImageQuality.highest =>
    post.isVideo
        ? _variantUrl(post, PostQualityType.v720x720)
        : switch (settings.gridSize) {
            GridSize.micro => _variantUrl(post, PostQualityType.v360x360),
            GridSize.tiny => _variantUrl(post, PostQualityType.v720x720),
            _ => _variantUrl(post, PostQualityType.sample),
          },
  ImageQuality.original => _variantUrl(post, PostQualityType.original),
};

String _variantUrl(Post post, PostQualityType type) {
  final url = switch (post) {
    DanbooruPost(:final variants) => variants.getUrl(type),
    PostMediaVariants(:final mediaVariants) => mediaVariants[type.value] ?? '',
    _ => '',
  };
  if (url.isNotEmpty) return url;

  return switch (type) {
    PostQualityType.v180x180 ||
    PostQualityType.v360x360 ||
    PostQualityType.v720x720 => post.thumbnailImageUrl,
    PostQualityType.sample => post.sampleImageUrl,
    PostQualityType.original => post.originalImageUrl,
  };
}
