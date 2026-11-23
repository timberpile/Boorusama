import 'package:equatable/equatable.dart';

import '../../boorus/booru/types.dart';
import '../../configs/config/types.dart';

/// Portable artist identity, not an arbitrary route or account configuration.
final class BoorusamaArtistLink extends Equatable {
  const BoorusamaArtistLink._({required this.site, required this.artistName});

  factory BoorusamaArtistLink.parse(String value) {
    if (value.isEmpty ||
        value.length > 4096 ||
        value.trim() != value ||
        _unsafeUri.hasMatch(value) ||
        _invalidEscape.hasMatch(value)) {
      throw const FormatException('Invalid Boorusama artist link');
    }
    final uri = Uri.parse(value);
    if (uri.scheme != 'boorusama' ||
        uri.host != 'artist' ||
        uri.path != '/open' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment) {
      throw const FormatException('Invalid Boorusama artist link');
    }
    final fields = uri.queryParametersAll;
    if (fields.length != 4 ||
        !fields.keys.every({'v', 'engine', 'site', 'name'}.contains) ||
        fields.values.any((values) => values.length != 1) ||
        fields['v']?.single != '1' ||
        fields['engine']?.single != 'danbooru') {
      throw const FormatException('Unsupported artist link');
    }
    final name = fields['name']!.single;
    // Danbooru artist names are individual canonical tag names, not queries.
    if (name.isEmpty ||
        name.length > 256 ||
        RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(name)) {
      throw const FormatException('Invalid artist name');
    }
    final source = fields['site']!.single;
    if (source.length > 2048 ||
        _unsafeUri.hasMatch(source) ||
        _invalidEscape.hasMatch(source)) {
      throw const FormatException('Invalid artist site');
    }
    final site = Uri.parse(source);
    if ((site.scheme != 'http' && site.scheme != 'https') ||
        !site.hasAuthority ||
        site.host.isEmpty ||
        site.userInfo.isNotEmpty ||
        site.hasQuery ||
        site.hasFragment ||
        site.port <= 0 ||
        site.port > 65535 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(Uri.decodeComponent(site.path))) {
      throw const FormatException('Invalid artist site');
    }
    return BoorusamaArtistLink._(
      site: Uri.parse(normalizeBooruSiteUrl(source)),
      artistName: name,
    );
  }

  static final _unsafeUri = RegExp(r'[\x00-\x20\x7f\\]');
  static final _invalidEscape = RegExp('%(?![0-9a-fA-F]{2})');
  final Uri site;
  final String artistName;

  Uri get uri => Uri(
    scheme: 'boorusama',
    host: 'artist',
    path: '/open',
    queryParameters: {
      'v': '1',
      'engine': 'danbooru',
      'site': site.toString(),
      'name': artistName,
    },
  );

  static BoorusamaArtistLink? tryParse(String value) {
    try {
      return BoorusamaArtistLink.parse(value);
    } on FormatException {
      return null;
    }
  }

  static BoorusamaArtistLink? fromArtist({
    required BooruConfigAuth auth,
    required String artistName,
  }) {
    if (auth.booruType != BooruType.danbooru) return null;
    return tryParse(
      Uri(
        scheme: 'boorusama',
        host: 'artist',
        path: '/open',
        queryParameters: {
          'v': '1',
          'engine': 'danbooru',
          'site': auth.url,
          'name': artistName,
        },
      ).toString(),
    );
  }

  List<BooruConfig> matchingProfiles(Iterable<BooruConfig> profiles) => profiles
      .where(
        (profile) =>
            profile.auth.booruType == BooruType.danbooru &&
            normalizeBooruSiteUrl(profile.url) == site.toString(),
      )
      .toList(growable: false);

  @override
  List<Object?> get props => [site, artistName];
}
