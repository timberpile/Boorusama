import '../../post/types.dart';
import 'share_payloads.dart';

/// Uses the same image preparation as Image sharing. A movie's URL is not an
/// image fallback: absent previews must leave Copy usable without sharing video.
SharePayload boorusamaLinkImagePayload(Post post, String viewerImageUrl) {
  final candidates = post.isVideo
      ? [post.videoThumbnailUrl, post.thumbnailImageUrl, post.sampleImageUrl]
      : [viewerImageUrl];
  final image = candidates.where((value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https'))
      return false;
    final path = uri.path.toLowerCase();
    if (RegExp(r'\.(mp4|webm|mov|m4v|zip)$').hasMatch(path)) return false;
    // Even extensionless video URLs cannot become thumbnail payloads.
    return !post.isVideo || value != post.videoUrl;
  }).firstOrNull;
  return SharePayload(
    id: SharePayloadId.image,
    value: image,
    canCopy: false,
    canShare: true,
  );
}
