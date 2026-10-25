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
  final facts = post.detailFacts;
  final width = facts.originalWidth;
  final height = facts.originalHeight;
  if (width != null &&
      height != null &&
      width == width.truncateToDouble() &&
      height == height.truncateToDouble()) {
    details.add('${width.toInt()} × ${height.toInt()}');
  }
  if (facts.originalByteSize case final size?) {
    details.add(Filesize.parse(size, round: 1));
  }
  final format = facts.originalFormat;
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
