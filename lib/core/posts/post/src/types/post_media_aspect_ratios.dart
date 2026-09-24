// Project imports:
import 'post.dart';

abstract interface class PostMediaAspectRatios {
  double? get thumbnailAspectRatio;
  double? get sampleAspectRatio;
  double? get originalAspectRatio;
  double? get videoThumbnailAspectRatio;
  double? get videoAspectRatio;
}

extension PostMediaAspectRatioX on Post {
  double? get effectiveThumbnailAspectRatio =>
      thumbnailAspectRatio ?? aspectRatio;

  double? get effectiveSampleAspectRatio => sampleAspectRatio ?? aspectRatio;

  double? get effectiveOriginalAspectRatio =>
      originalAspectRatio ?? aspectRatio;

  double? get effectiveVideoThumbnailAspectRatio =>
      videoThumbnailAspectRatio ?? aspectRatio;

  double? get effectiveVideoAspectRatio => videoAspectRatio ?? aspectRatio;
}
