// Refresh transport bounds are site-specific. Unsupported installations keep
// the original conservative 50-post limit until their API is verified.
import '../../../../boorus/booru/types.dart';

final class SearchRefreshFetchPlan {
  const SearchRefreshFetchPlan({
    required this.query,
    required this.limit,
    required this.delta,
  });

  final String query;
  final int limit;
  final bool delta;
}

SearchRefreshFetchPlan planSearchRefreshFetch({
  required BooruType booruType,
  required String siteUrl,
  required String query,
  int? afterPostId,
  bool requireFullSnapshot = false,
}) {
  final uri = Uri.tryParse(siteUrl);
  final officialEndpoint =
      uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasPort;
  final host = officialEndpoint ? uri.host.toLowerCase() : '';
  final donmai =
      booruType == BooruType.danbooru &&
      (host == 'danbooru.donmai.us' || host == 'safebooru.donmai.us');
  final gelbooru = booruType == BooruType.gelbooru && host == 'gelbooru.com';
  final rule34 =
      booruType == BooruType.gelbooruV2 &&
      (host == 'rule34.xxx' || host == 'api.rule34.xxx');
  final e621 =
      booruType == BooruType.e621 && (host == 'e621.net' || host == 'e926.net');

  final limit = donmai
      ? 200
      : gelbooru
      ? 100
      : rule34
      ? 1000
      : e621
      ? 320
      : 50;

  // Only official Donmai hosts have a verified ascending-ID contract. Its
  // date/age and ordered collection metatags can override ID ordering. Keep
  // unfamiliar metatags and Boolean expressions on the bounded snapshot path.
  final terms = query.trim().split(RegExp(r'\s+'));
  final safeQuery = terms.every((term) {
    if (RegExp(r'[(){}~]').hasMatch(term)) return false;
    if (!term.contains(':') && !term.contains('=')) return true;
    return RegExp(r'^-?rating:[a-z]+$', caseSensitive: false).hasMatch(term) ||
        term.toLowerCase() == 'order:id_desc';
  });
  // Donmai exempts id/rating, but order consumes a search term. Reserve room
  // for ascending order within the basic two-term allowance; higher account
  // limits are not available here. Never make a valid topic query too expensive.
  final countedTerms = terms
      .where((term) => term.isNotEmpty && !term.contains(':'))
      .toSet()
      .length;
  final hasOrder = terms.any((term) => term.toLowerCase() == 'order:id_desc');
  final hasOrderingBudget = countedTerms < 2 || hasOrder;
  final useDelta =
      !requireFullSnapshot &&
      afterPostId != null &&
      afterPostId > 0 &&
      donmai &&
      safeQuery &&
      hasOrderingBudget;
  final filters = terms.where((term) => term.toLowerCase() != 'order:id_desc');

  return SearchRefreshFetchPlan(
    query: useDelta
        ? [...filters, 'id:>$afterPostId', 'order:id_asc'].join(' ').trim()
        : query,
    limit: limit,
    delta: useDelta,
  );
}
