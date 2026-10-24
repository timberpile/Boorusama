import 'post.dart';

/// A known video represented by a static poster until its media is resolved.
/// This is display metadata, not permission to play the poster as a video.
abstract interface class VideoPreviewPostData {
  bool get isVideoPreview;
}

extension PostPreviewBadgeX on Post {
  bool get showsAnimatedBadge =>
      isAnimated ||
      switch (booruData) {
        VideoPreviewPostData(isVideoPreview: true) => true,
        _ => false,
      };
}
