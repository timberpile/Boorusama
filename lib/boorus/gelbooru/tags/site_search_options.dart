/// Shared website-specific sorting rules for Gelbooru's search UI and parser.
class GelbooruSiteSearchOptions {
  const GelbooruSiteSearchOptions({
    required this.sortFields,
    this.randomSort = false,
    this.seededRandomSort = false,
    this.extraMetatags = const {},
  });

  final List<String> sortFields;
  final bool randomSort;
  final bool seededRandomSort;
  final Set<String> extraMetatags;
}

const _standardSortFields = [
  'id',
  'score',
  'rating',
  'user',
  'height',
  'width',
  'source',
  'updated',
];

const _legacySortFields = [
  'id',
  'score',
  'rating',
  'user',
  'height',
  'width',
  'parent',
  'source',
  'updated',
];

const _rule34SortFields = [
  'id',
  'score',
  'user',
  'height',
  'width',
  'parent',
  'source',
  'updated',
];

String? gelbooruSiteHost(String url) =>
    Uri.tryParse(url)?.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');

GelbooruSiteSearchOptions gelbooruSiteSearchOptions(
  String url, {
  required bool legacy,
}) {
  final host = gelbooruSiteHost(url);
  if (legacy && host == 'rule34.xxx') {
    return const GelbooruSiteSearchOptions(
      sortFields: _rule34SortFields,
      randomSort: true,
      // Live API checks reject the website's ratio/domain predicates even
      // for known matching posts. Native source URL patterns do work.
      extraMetatags: {'source'},
    );
  }
  if (!legacy && host == 'gelbooru.com') {
    return const GelbooruSiteSearchOptions(
      sortFields: _standardSortFields,
      randomSort: true,
      seededRandomSort: true,
    );
  }
  return GelbooruSiteSearchOptions(
    sortFields: legacy ? _legacySortFields : _standardSortFields,
  );
}
