// Project imports:
import '../../../core/images/types.dart';
import '../../../core/posts/listing/types.dart';
import '../../../core/posts/post/types.dart';
import '../../gelbooru/common/grid_thumbnail_url.dart';
import 'types.dart';

GridThumbnailMedia gelbooruV2ThumbnailOnlyGridThumbnailMedia(
  Post post,
  GridThumbnailSettings settings,
) {
  final isVideoPreview = switch (post.booruData) {
    GelbooruV2PostData(isVideoPreview: true) => true,
    _ => false,
  };
  if (post.isVideo || isVideoPreview) {
    return gelbooruGridThumbnailMedia(
      post,
      settings,
      isVideoPreview: true,
    );
  }
  if (post.isGif) {
    return defaultGridThumbnailMedia(post, settings);
  }

  final thumbnail = post.thumbnailImageUrl;
  final uri = Uri.tryParse(thumbnail);
  final match = uri == null
      ? null
      : RegExp(
          r'^/+thumbnails/([a-f0-9]{2}/[a-f0-9]{2})/thumbnail_([a-f0-9]{32})\.jpg$',
        ).firstMatch(uri.path);
  if (settings.resolvedImageQuality == ImageQuality.low || match == null) {
    return const DefaultGridThumbnailUrlGenerator.thumbnailOnly().resolve(
      post,
      settings: settings,
    );
  }

  // Realbooru lists only the small JPEG thumbnail, without the original
  // extension. Try static image formats lazily; never fetch detail HTML or video
  // files just to improve the grid. A resolved URL avoids guessing altogether.
  const extensions = ['jpg', 'jpeg', 'png', 'webp', 'avif'];
  final sample = Uri.tryParse(post.sampleImageUrl);
  final knownImage =
      post.sampleImageUrl != thumbnail &&
      sample != null &&
      extensions.any(
        (extension) => sample.path.toLowerCase().endsWith('.$extension'),
      );
  final candidates = knownImage
      ? [post.sampleImageUrl]
      : [
          for (final extension in extensions)
            uri!
                .replace(
                  path: '/images/${match[1]}/${match[2]}.$extension',
                )
                .toString(),
        ];
  return GridThumbnailMedia(
    url: candidates.first,
    fallbackUrls: candidates.skip(1).toList(),
    fallbackUrl: thumbnail,
    aspectRatio: post.effectiveSampleAspectRatio,
    placeholderUrl: thumbnail,
    placeholderAspectRatio: post.effectiveThumbnailAspectRatio,
  );
}
