import '../../../configs/config/types.dart';
import '../../post/types.dart';
import 'preload_media.dart';

/// Optional engine capability for thumbnail-only listings. Returning a loader
/// does not start I/O; the viewer admits it through its bounded metadata queue.
abstract interface class ViewerPreloadMetadataResolver {
  Future<Post?> Function()? viewerPreloadMetadataLoader(
    Post post,
    BooruConfig config,
  );
}

/// Preload the rendition selected by the viewer. Unresolved listings may
/// supply a real thumbnail, but their guessed display URLs are ineligible.
ImageMedia? viewerPreloadMedia(
  Post post, {
  required String? displayUrl,
  String? thumbnailUrl,
}) {
  if (post.isVideo) {
    return post.videoThumbnailUrl.isEmpty
        ? null
        : ImageMedia.fromUrl(post.videoThumbnailUrl);
  }
  final target = post.requiresDetailLookup ? null : displayUrl;
  final original = post.originalImageUrl;
  final thumbnail =
      [
        if (target != null) ?thumbnailUrl,
        post.thumbnailImageUrl,
      ].where((url) => url.isNotEmpty && url != original).firstOrNull ??
      '';
  if (target == null || target.isEmpty) {
    return thumbnail.isEmpty ? null : ImageMedia.fromUrl(thumbnail);
  }
  return ImageMedia(
    thumbnailUrl: thumbnail.isEmpty ? target : thumbnail,
    originalUrl: target,
    estimatedSizeBytes: post.fileSize,
  );
}
