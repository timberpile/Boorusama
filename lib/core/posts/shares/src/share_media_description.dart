import 'package:foundation/foundation.dart';

import '../../post/types.dart';
import 'share_payloads.dart';

String? shareMediaDescription({
  required Post post,
  required SharePayload payload,
  required String viewerImageUrl,
}) {
  if (!payload.available) return null;

  final describesOriginal = switch (payload.id) {
    SharePayloadId.original => true,
    SharePayloadId.image =>
      viewerImageUrl.isNotEmpty &&
          viewerImageUrl == post.originalImageUrl &&
          !{
            post.thumbnailImageUrl,
            post.sampleImageUrl,
            post.videoThumbnailUrl,
          }.contains(viewerImageUrl),
    _ => false,
  };
  if (!describesOriginal) return null;

  final details = <String>[];
  if (post.width.isFinite &&
      post.height.isFinite &&
      post.width > 0 &&
      post.height > 0 &&
      post.width == post.width.truncateToDouble() &&
      post.height == post.height.truncateToDouble()) {
    details.add('${post.width.toInt()} × ${post.height.toInt()}');
  }
  if (post.fileSize > 0) {
    details.add(Filesize.parse(post.fileSize, round: 1));
  }
  final format = post.format
      .trim()
      .replaceFirst(RegExp(r'^\.'), '')
      .toLowerCase();
  final originalPath = Uri.tryParse(post.originalImageUrl)?.path;
  final extension = originalPath == null
      ? null
      : RegExp(
          r'\.([a-zA-Z0-9]+)$',
        ).firstMatch(originalPath)?.group(1)?.toLowerCase();
  if (extension != null &&
      const {
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'avif',
        'bmp',
        'heic',
      }.contains(extension) &&
      (extension == format ||
          (extension == 'jpeg' && format == 'jpg') ||
          (extension == 'jpg' && format == 'jpeg'))) {
    details.add(extension.toUpperCase());
  }

  return details.isEmpty ? null : details.join(' · ');
}
