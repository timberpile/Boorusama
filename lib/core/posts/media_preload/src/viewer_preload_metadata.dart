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

/// Only a known non-original rendition can be fetched speculatively. Do not
/// use guessed larger listing URLs as if they were known static thumbnails.
/// A null display URL means metadata is unresolved: only a safe thumbnail is used.
ImageMedia? thumbnailOnlyViewerPreloadMedia(
  Post post, {
  required String? displayUrl,
}) {
  final original = post.originalImageUrl;
  final thumbnail = post.thumbnailImageUrl == original
      ? ''
      : post.thumbnailImageUrl;
  if (displayUrl == null) {
    return thumbnail.isEmpty ? null : ImageMedia.fromUrl(thumbnail);
  }
  final candidate = displayUrl == original ? post.sampleImageUrl : displayUrl;
  final safe = original.isNotEmpty &&
      candidate.isNotEmpty &&
      candidate != original;
  if (!safe) {
    return thumbnail.isEmpty ? null : ImageMedia.fromUrl(thumbnail);
  }
  return ImageMedia(
    thumbnailUrl: thumbnail.isEmpty ? candidate : thumbnail,
    originalUrl: candidate,
    estimatedSizeBytes: post.fileSize,
  );
}
