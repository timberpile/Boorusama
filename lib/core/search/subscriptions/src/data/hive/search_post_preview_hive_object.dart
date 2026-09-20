class SearchPostPreviewHiveObject {
  SearchPostPreviewHiveObject({
    required this.postId,
    required this.postCreatedAt,
    required this.thumbnailUrl,
    required this.sampleUrl,
    required this.discoveredAt,
  });

  int postId;
  DateTime? postCreatedAt;
  String thumbnailUrl;
  String? sampleUrl;
  DateTime discoveredAt;
}
