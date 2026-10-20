import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../boorus/booru/types.dart';
import '../../configs/config/types.dart';
import '../post/types.dart';
import '../../search/search/src/routes/params.dart';
import '../../search/selected_tags/types.dart';

/// A portable search request. It refers to a site and query, not a locally
/// saved search, profile, search history entry or cached result.
final class BoorusamaSearchLink extends Equatable {
  const BoorusamaSearchLink._({
    required this.booruType,
    required this.site,
    required this.query,
    required this.typedTags,
  });

  /// V1: boorusama://search/open?v=1&engine=...&site=...&mode=...&q=...
  /// The engine is necessary for unknown/self-hosted sites and for offering
  /// correct profile creation when the recipient has no matching profile.
  factory BoorusamaSearchLink.parse(String value) {
    if (value.isEmpty ||
        value.length > maxLength ||
        value.trim() != value ||
        _unsafeUri.hasMatch(value) ||
        _invalidEscape.hasMatch(value)) {
      throw const FormatException('Invalid Boorusama search link');
    }
    final uri = Uri.parse(value);
    if (uri.scheme != 'boorusama' ||
        uri.host != 'search' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.path != routePath ||
        uri.hasFragment) {
      throw const FormatException('Invalid Boorusama search link');
    }
    final params = uri.queryParametersAll;
    if (params.length != _fields.length ||
        !params.keys.every(_fields.contains) ||
        params.values.any((values) => values.length != 1) ||
        params['v']?.single != '1') {
      throw const FormatException('Unsupported Boorusama search link');
    }
    final engine = params['engine']!.single;
    final type = BooruYamlConfigs.values
        .where((config) => config.type.yamlName == engine)
        .map((config) => config.type)
        .firstOrNull;
    if (type == null || type == BooruType.unknown) {
      throw const FormatException('Unsupported search engine');
    }
    final site = _parseSite(params['site']!.single);
    final query = params['q']!.single;
    if (query.isEmpty ||
        query.length > maxQueryLength ||
        query.trim() != query ||
        _unsafeQuery.hasMatch(query)) {
      throw const FormatException('Invalid search query');
    }
    final mode = params['mode']!.single;
    final List<String>? tags;
    switch (mode) {
      case 'raw':
        tags = null;
      case 'tags':
        tags = _decodeTags(query);
      default:
        throw const FormatException('Unsupported search query mode');
    }
    return BoorusamaSearchLink._(
      booruType: type,
      site: site,
      query: query,
      typedTags: tags,
    );
  }

  static const routePath = '/open';
  static const maxLength = 4096;
  static const maxQueryLength = 2048;
  static const _fields = {'v', 'engine', 'site', 'mode', 'q'};
  static final _unsafeUri = RegExp(r'[\x00-\x20\x7f\\]');
  static final _unsafeQuery = RegExp(r'[\x00-\x1f\x7f]');
  static final _invalidEscape = RegExp('%(?![0-9a-fA-F]{2})');

  final BooruType booruType;
  final Uri site;
  final String query;

  /// Null means a single raw booru query. Non-null is a typed tag list.
  final List<String>? typedTags;

  bool get isRaw => typedTags == null;

  Uri get uri => Uri(
    scheme: 'boorusama',
    host: 'search',
    path: routePath,
    queryParameters: {
      'v': '1',
      'engine': booruType.yamlName,
      'site': site.toString(),
      'mode': isRaw ? 'raw' : 'tags',
      'q': query,
    },
  );

  SearchParams get searchParams => isRaw
      ? SearchParams(query: query, queryType: QueryType.simple)
      : SearchParams(
          tags: SearchTagSet.fromList(typedTags),
          queryType: QueryType.list,
        );

  static BoorusamaSearchLink? tryParse(String value) {
    try {
      return BoorusamaSearchLink.parse(value);
    } on FormatException {
      return null;
    }
  }

  static BoorusamaSearchLink? fromRaw({
    required BooruConfigAuth auth,
    required String query,
  }) => _build(auth: auth, mode: 'raw', query: query);

  static BoorusamaSearchLink? fromTags({
    required BooruConfigAuth auth,
    required Iterable<String> tags,
  }) => _build(auth: auth, mode: 'tags', query: jsonEncode(tags.toList()));

  static BoorusamaSearchLink? _build({
    required BooruConfigAuth auth,
    required String mode,
    required String query,
  }) => tryParse(
    Uri(
      scheme: 'boorusama',
      host: 'search',
      path: routePath,
      queryParameters: {
        'v': '1',
        'engine': auth.booruType.yamlName,
        'site': normalizeBooruSiteUrl(auth.url),
        'mode': mode,
        'q': query,
      },
    ).toString(),
  );

  List<BooruConfig> matchingProfiles(Iterable<BooruConfig> profiles) => profiles
      .where(
        (profile) =>
            profile.auth.booruType == booruType &&
            normalizePostSourceHost(profile.url) ==
                normalizePostSourceHost(site.toString()),
      )
      .toList(growable: false);

  static Uri _parseSite(String value) {
    if (value.length > 2048 ||
        _unsafeUri.hasMatch(value) ||
        _invalidEscape.hasMatch(value)) {
      throw const FormatException('Invalid search site');
    }
    final uri = Uri.parse(value);
    if ((uri.scheme != 'https' && uri.scheme != 'http') ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port <= 0 ||
        uri.port > 65535 ||
        _unsafeQuery.hasMatch(Uri.decodeComponent(uri.path))) {
      throw const FormatException('Invalid search site');
    }
    return Uri.parse(normalizeBooruSiteUrl(value));
  }

  static List<String> _decodeTags(String query) {
    final Object? data;
    try {
      data = jsonDecode(query);
    } on FormatException {
      throw const FormatException('Invalid search tag list');
    }
    if (data is! List ||
        data.isEmpty ||
        data.length > 64 ||
        data.any(
          (tag) =>
              tag is! String ||
              tag.isEmpty ||
              tag.length > 160 ||
              tag.trim() != tag ||
              _unsafeQuery.hasMatch(tag),
        )) {
      throw const FormatException('Invalid search tag list');
    }
    return List.unmodifiable(data.cast<String>());
  }

  @override
  List<Object?> get props => [booruType, site, query, typedTags];
}
