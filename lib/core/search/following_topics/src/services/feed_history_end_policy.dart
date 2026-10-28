import '../../../../boorus/booru/types.dart';
import '../../../../posts/post/types.dart';

/// Only raw source results reach this policy. Local filters and session stops
/// are not evidence of exhaustion. Unknown pagination contracts stay retryable.
bool confirmsFeedHistoryEnd(
  PostResult<Post> result, {
  required BooruType booruType,
  required String siteUrl,
  required int page,
  required int limit,
}) {
  if (page < 1 ||
      limit < 1 ||
      result.posts.length > limit ||
      result.hasMore == true ||
      (result.maxPage != null && page >= result.maxPage!))
    return false;
  final uri = Uri.tryParse(siteUrl);
  final official =
      uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      !uri.hasPort &&
      (uri.path.isEmpty || uri.path == '/');
  final host = official ? uri.host.toLowerCase() : '';
  // These raw endpoints report an empty successful page at the actual end;
  // account/search-depth limits fail requests. Stay below the basic limits.
  final emptyPageContract = switch ((booruType, host)) {
    (BooruType.danbooru, 'danbooru.donmai.us' || 'safebooru.donmai.us') =>
      page < 1000,
    (BooruType.e621, 'e621.net' || 'e926.net') => page < 750,
    _ => false,
  };
  if (emptyPageContract && result.posts.isEmpty) return true;
  // These repositories retain the API's exact total. Realbooru's estimated
  // HTML count and arbitrary Gelbooru V2 installations cannot prove an end.
  final exactTotalContract = switch (booruType) {
    BooruType.gelbooru ||
    BooruType.philomena ||
    BooruType.szurubooru ||
    BooruType.hybooru => true,
    _ => false,
  };
  return exactTotalContract &&
      result.total != null &&
      result.total! >= 0 &&
      (page - 1) * limit + result.posts.length == result.total;
}
