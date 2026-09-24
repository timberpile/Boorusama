// Project imports:
import '../../../core/images/types.dart';
import '../../../core/posts/listing/types.dart';
import '../../../core/posts/post/types.dart';

GridThumbnailMedia gelbooruGridThumbnailMedia(
  Post post,
  GridThumbnailSettings settings, {
  bool isVideoPreview = false,
}) {
  if (!post.isVideo && !isVideoPreview) {
    return defaultGridThumbnailMedia(post, settings);
  }

  if (settings.imageQuality == ImageQuality.low) {
    return defaultGridThumbnailMedia(post, settings);
  }

  final posterUrl = post.videoThumbnailUrl;
  final thumbnailUrl = post.thumbnailImageUrl;

  return GridThumbnailMedia(
    url: posterUrl,
    aspectRatio: post.effectiveVideoThumbnailAspectRatio,
    placeholderUrl: thumbnailUrl,
    fallbackUrl: posterUrl == thumbnailUrl ? null : thumbnailUrl,
    placeholderAspectRatio: post.effectiveThumbnailAspectRatio,
  );
}
