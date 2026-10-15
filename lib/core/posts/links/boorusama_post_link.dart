import 'package:equatable/equatable.dart';

import '../../boorus/booru/types.dart';
import '../../configs/config/types.dart';
import '../post/types.dart';

/// A portable post address, deliberately independent of accounts and snapshots.
///
/// V1: boorusama://post/open?v=1&engine=...&site=...&key=...
/// Only a matching locally configured repository may resolve this address.
final class BoorusamaPostLink extends Equatable {
  const BoorusamaPostLink._({
    required this.booruType,
    required this.site,
    required this.key,
    required this.postId,
  });

  static const routePath = '/open';
  static const maxLength = 4096;
  static const _fields = {'v', 'engine', 'site', 'key'};
  // Also safe on Dart's JavaScript targets; do not silently round a post ID.
  static const _maxId = 9007199254740991;

  final BooruType booruType;
  final Uri site;
  final String key;
  final PostId postId;

  Uri get uri => Uri(
    scheme: 'boorusama',
    host: 'post',
    path: routePath,
    queryParameters: {
      'v': '1',
      'engine': booruType.yamlName,
      'site': site.toString(),
      'key': key,
    },
  );

  factory BoorusamaPostLink.parse(String value) {
    if (value.length > maxLength ||
        value.isEmpty ||
        value.trim() != value ||
        _unsafeText.hasMatch(value) ||
        _invalidEscape.hasMatch(value)) {
      throw const FormatException('Invalid Boorusama link');
    }
    final uri = Uri.parse(value);
    if (uri.scheme != 'boorusama' ||
        uri.host != 'post' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.path != routePath ||
        uri.hasFragment) {
      throw const FormatException('Invalid Boorusama link');
    }
    final parameters = uri.queryParametersAll;
    if (parameters.length != _fields.length ||
        !parameters.keys.every(_fields.contains) ||
        parameters.values.any((values) => values.length != 1) ||
        parameters['v']?.single != '1') {
      throw const FormatException('Unsupported Boorusama link');
    }
    final engineName = parameters['engine']!.single;
    final type = BooruYamlConfigs.values
        .where((config) => config.type.yamlName == engineName)
        .map((config) => config.type)
        .firstOrNull;
    if (type == null || type == BooruType.unknown) {
      throw const FormatException('Unsupported post engine');
    }
    final site = _parseSite(parameters['site']!.single);
    final key = parameters['key']!.single;
    final postId = _parsePostId(type, key);
    return BoorusamaPostLink._(
      booruType: type,
      site: site,
      key: key,
      postId: postId,
    );
  }

  static BoorusamaPostLink? tryParse(String value) {
    try {
      return BoorusamaPostLink.parse(value);
    } on FormatException {
      return null;
    }
  }

  static BoorusamaPostLink? fromPost(Post post, {BooruConfigAuth? auth}) {
    final origin = post.origin;
    final key = _stableKey(post);
    if (key == null || origin.sourceHost.isEmpty) return null;
    // The active profile may only be a fallback in a mixed/cached viewer. It
    // must never change the source address of the post being shared.
    final source =
        auth != null &&
            auth.booruType == origin.booruType &&
            normalizePostSourceHost(auth.url) == origin.sourceHost
        ? normalizeBooruSiteUrl(auth.url)
        : 'https://${origin.sourceHost}';
    return tryParse(
      Uri(
        scheme: 'boorusama',
        host: 'post',
        path: routePath,
        queryParameters: {
          'v': '1',
          'engine': origin.booruType.yamlName,
          'site': source,
          'key': key,
        },
      ).toString(),
    );
  }

  List<BooruConfig> matchingProfiles(Iterable<BooruConfig> profiles) => profiles
      .where(
        (profile) =>
            profile.auth.booruType == booruType &&
            normalizePostSourceHost(profile.url) ==
                normalizePostSourceHost(site.toString()),
      )
      .toList(growable: false);

  bool matches(Post post) =>
      post.origin.booruType == booruType &&
      post.origin.sourceHost == normalizePostSourceHost(site.toString()) &&
      _stableKey(post) == key;

  static String? _stableKey(Post post) =>
      switch ((post.origin.booruType, post.booruData)) {
        (_, final StableBookmarkPostKeyData data) => data.stableBookmarkPostKey,
        (BooruType.sankaku || BooruType.pixiv || BooruType.unknown, _) => null,
        (_, _) when post.id > 0 => 'id:${post.id}',
        _ => null,
      };

  static final _unsafeText = RegExp(r'[\x00-\x20\x7f\\]');
  static final _invalidEscape = RegExp(r'%(?![0-9a-fA-F]{2})');
  static final _positiveInteger = RegExp(r'^[1-9][0-9]*$');
  static final _sankakuId = RegExp(r'^[a-zA-Z0-9_-]{1,128}$');

  static Uri _parseSite(String value) {
    if (value.length > 2048 ||
        _unsafeText.hasMatch(value) ||
        _invalidEscape.hasMatch(value)) {
      throw const FormatException('Invalid site');
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
        _unsafeText.hasMatch(Uri.decodeComponent(uri.path))) {
      throw const FormatException('Invalid site');
    }
    return Uri.parse(normalizeBooruSiteUrl(value));
  }

  static int _numericId(String value) {
    final id = _positiveInteger.hasMatch(value) ? int.tryParse(value) : null;
    if (id == null || id > _maxId) {
      throw const FormatException('Invalid post ID');
    }
    return id;
  }

  static PostId _parsePostId(BooruType type, String key) {
    if (key.length > 160 || _unsafeText.hasMatch(key)) {
      throw const FormatException('Invalid post reference');
    }
    if (type == BooruType.pixiv) {
      final parts = key.split(':');
      if (parts.length != 3 || parts[0] != 'work-page') {
        throw const FormatException('Invalid Pixiv reference');
      }
      final work = _numericId(parts[1]);
      final page = int.tryParse(parts[2]);
      if (page == null ||
          page < 0 ||
          page >= 1000 ||
          page.toString() != parts[2] ||
          work > (_maxId - page) ~/ 1000) {
        throw const FormatException('Invalid Pixiv page');
      }
      return NumericPostId(work * 1000 + page);
    }
    if (!key.startsWith('id:')) {
      throw const FormatException('Invalid post reference');
    }
    final value = key.substring(3);
    if (type == BooruType.sankaku) {
      if (!_sankakuId.hasMatch(value)) {
        throw const FormatException('Invalid Sankaku reference');
      }
      if (RegExp(r'^[0-9]+$').hasMatch(value)) _numericId(value);
      // Sankaku's single-post repository expects StringPostId even for digits.
      return StringPostId(value);
    }
    return NumericPostId(_numericId(value));
  }

  @override
  List<Object?> get props => [booruType, site, key];
}
