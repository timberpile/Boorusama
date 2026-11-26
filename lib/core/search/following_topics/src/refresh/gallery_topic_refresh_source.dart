import '../../../../configs/config/types.dart';

typedef GalleryTopicRefreshSource = Future<GalleryTopicRefreshPage> Function(
  BooruConfig config,
  String query,
);

/// A Gallery listing page carries identities even when covers are unavailable.
final class GalleryTopicRefreshPage {
  const GalleryTopicRefreshPage({
    required this.ids,
    required this.hasMore,
    this.coverUrls = const {},
  });

  static const maxResults = 25;

  final List<int> ids;
  final bool hasMore;
  final Map<int, Uri> coverUrls;
}
