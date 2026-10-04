enum SharePayloadId {
  image,
  original,
  video,
  booruLink,
  sourceLink,
  imageLink,
  postId,
}

final class SharePayload {
  const SharePayload({
    required this.id,
    required this.value,
    required this.canCopy,
    required this.canShare,
    this.deferred = false,
  });

  final SharePayloadId id;
  final String? value;
  final bool canCopy;
  final bool canShare;
  final bool deferred;

  bool get available => value != null || deferred;
  bool get isMedia => switch (id) {
    SharePayloadId.image ||
    SharePayloadId.original ||
    SharePayloadId.video => true,
    _ => false,
  };
}

final class PostSharePayloads {
  const PostSharePayloads({required this.media, required this.links});

  factory PostSharePayloads.build({
    required bool isVideo,
    bool canResolveExactOriginal = false,
    bool canResolveExactVideo = false,
    required String viewerImageUrl,
    required String originalUrl,
    required String booruLink,
    required String? sourceLink,
    required int postId,
  }) {
    final image = _validWebUrl(viewerImageUrl);
    final original = _validWebUrl(originalUrl);
    final video = isVideo && canResolveExactVideo ? original : null;

    return PostSharePayloads(
      media: [
        if (isVideo)
          SharePayload(
            id: SharePayloadId.video,
            value: video,
            deferred: canResolveExactVideo,
            canCopy: true,
            canShare: true,
          )
        else ...[
          SharePayload(
            id: SharePayloadId.image,
            value: image,
            canCopy: true,
            canShare: true,
          ),
          SharePayload(
            id: SharePayloadId.original,
            value: original,
            deferred: canResolveExactOriginal,
            canCopy: true,
            canShare: true,
          ),
        ],
      ],
      links: [
        SharePayload(
          id: SharePayloadId.booruLink,
          value: _validWebUrl(booruLink),
          canCopy: true,
          canShare: true,
        ),
        SharePayload(
          id: SharePayloadId.sourceLink,
          value: _validWebUrl(sourceLink),
          canCopy: true,
          canShare: true,
        ),
        SharePayload(
          id: SharePayloadId.imageLink,
          value: image,
          canCopy: true,
          canShare: true,
        ),
        SharePayload(
          id: SharePayloadId.postId,
          value: postId.toString(),
          canCopy: true,
          canShare: true,
        ),
      ],
    );
  }

  final List<SharePayload> media;
  final List<SharePayload> links;
}

String? _validWebUrl(String? value) {
  final uri = value == null ? null : Uri.tryParse(value.trim());
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return null;
  }
  return uri.toString();
}
