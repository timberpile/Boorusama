import 'post.dart';

/// A known video represented by a static poster until its media is resolved.
/// This is display metadata, not permission to play the poster as a video.
abstract interface class VideoPreviewPostData {
  bool get isVideoPreview;
}

/// A source animation whose grid image is a static poster.
abstract interface class GifPreviewPostData {
  bool get isGifPreview;
}

extension PostPreviewBadgeX on Post {
  bool get showsGifBadge =>
      isGif ||
      switch (booruData) {
        GifPreviewPostData(isGifPreview: true) => true,
        _ => false,
      };

  bool get showsAnimatedBadge =>
      isAnimated ||
      switch (booruData) {
        VideoPreviewPostData(isVideoPreview: true) => true,
        _ => false,
      };
}
