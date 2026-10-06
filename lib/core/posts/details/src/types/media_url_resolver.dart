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

class DefaultMediaUrlResolver implements MediaUrlResolver {
  const DefaultMediaUrlResolver({required this.postQuality});

  final PostQuality postQuality;

  @override
  String resolveMediaUrl(Post post, BooruConfigViewer config) => post.isGif
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
      post.isGif
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
  const SampleMediaUrlResolver();

  @override
  String resolveMediaUrl(
    Post post,
    BooruConfigViewer config,
  ) => post.sampleImageUrl;

  @override
  double? resolveMediaAspectRatio(
    Post post,
    BooruConfigViewer config,
  ) => post.effectiveSampleAspectRatio;

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
