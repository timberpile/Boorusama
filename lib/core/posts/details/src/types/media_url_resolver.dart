// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../settings/types.dart';
import '../../../post/types.dart';

abstract class MediaUrlResolver {
  String resolveMediaUrl(
    Post post,
    BooruConfigViewer config,
  );

  String resolveVideoUrl(
    Post post,
    BooruConfigViewer config,
  );

  double? resolveMediaAspectRatio(
    Post post,
    BooruConfigViewer config,
  );

  double? resolveVideoAspectRatio(
    Post post,
    BooruConfigViewer config,
  );
}

String originalViewerImageUrl(Post post) =>
    [
      post.originalImageUrl,
      post.sampleImageUrl,
      post.thumbnailImageUrl,
    ].where((url) => url.isNotEmpty).firstOrNull ??
    '';

double? originalViewerImageAspectRatio(Post post) =>
    post.originalImageUrl.isNotEmpty
    ? post.effectiveOriginalAspectRatio
    : post.sampleImageUrl.isNotEmpty
    ? post.effectiveSampleAspectRatio
    : post.effectiveThumbnailAspectRatio;

class DefaultMediaUrlResolver implements MediaUrlResolver {
  const DefaultMediaUrlResolver({required this.postQuality});

  final PostQuality postQuality;

  bool _usesOriginal(Post post, BooruConfigViewer config) =>
      !post.isVideo &&
      config.imageDetaisQuality == null &&
      postQuality == PostQuality.original;

  @override
  String resolveMediaUrl(Post post, BooruConfigViewer config) =>
      _usesOriginal(post, config)
      ? originalViewerImageUrl(post)
      : post.isGif
      ? post.sampleImageUrl
      : switch (stringToGeneralPostQualityType(config.imageDetaisQuality)) {
          GeneralPostQualityType.preview => post.thumbnailImageUrl,
          GeneralPostQualityType.sample =>
            post.isVideo ? post.videoThumbnailUrl : post.sampleImageUrl,
          GeneralPostQualityType.original =>
            post.isVideo ? post.videoThumbnailUrl : post.originalImageUrl,
        };

  @override
  double? resolveMediaAspectRatio(Post post, BooruConfigViewer config) =>
      _usesOriginal(post, config)
      ? originalViewerImageAspectRatio(post)
      : post.isGif
      ? post.effectiveSampleAspectRatio
      : (switch (stringToGeneralPostQualityType(config.imageDetaisQuality)) {
              GeneralPostQualityType.preview =>
                post.effectiveThumbnailAspectRatio,
              GeneralPostQualityType.sample =>
                post.isVideo
                    ? post.effectiveVideoThumbnailAspectRatio
                    : post.effectiveSampleAspectRatio,
              GeneralPostQualityType.original =>
                post.isVideo
                    ? post.effectiveVideoThumbnailAspectRatio
                    : post.effectiveOriginalAspectRatio,
            }) ??
            (post.isVideo
                ? post.effectiveVideoThumbnailAspectRatio
                : post.effectiveSampleAspectRatio);

  @override
  String resolveVideoUrl(Post post, BooruConfigViewer config) => post.videoUrl;

  @override
  double? resolveVideoAspectRatio(Post post, BooruConfigViewer config) =>
      post.effectiveVideoAspectRatio;
}

class SampleMediaUrlResolver implements MediaUrlResolver {
  const SampleMediaUrlResolver({this.postQuality = PostQuality.high});

  final PostQuality postQuality;

  @override
  String resolveMediaUrl(
    Post post,
    BooruConfigViewer config,
  ) => !post.isVideo && postQuality == PostQuality.original
      ? originalViewerImageUrl(post)
      : post.sampleImageUrl;

  @override
  double? resolveMediaAspectRatio(
    Post post,
    BooruConfigViewer config,
  ) => !post.isVideo && postQuality == PostQuality.original
      ? originalViewerImageAspectRatio(post)
      : post.effectiveSampleAspectRatio;

  @override
  String resolveVideoUrl(
    Post post,
    BooruConfigViewer config,
  ) => post.videoUrl;

  @override
  double? resolveVideoAspectRatio(
    Post post,
    BooruConfigViewer config,
  ) => post.effectiveVideoAspectRatio;
}
