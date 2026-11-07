import 'package:equatable/equatable.dart';

import '../boorus/booru/types.dart';

/// Public reads are an explicit source permission, never an engine-wide default.
/// A matching imported host, redirect or image URL cannot extend this list.
final class AnonymousSourcePolicy {
  const AnonymousSourcePolicy({this.enabled = true});

  final bool enabled;

  static const version = 1;

  /// Legacy Post origins retain a namespace rather than a transport URL. Select
  /// an explicitly registered public endpoint without rewriting that identity.
  AnonymousSource? forNamespace(BooruType engine, String namespace) {
    if (!enabled) return null;
    for (final source in _sources) {
      if (source.engine == engine && source.site.host == namespace) {
        return source;
      }
    }
    return null;
  }

  AnonymousSource? resolve(BooruType engine, Uri site) {
    if (!enabled ||
        !_safeHttps(site) ||
        !const ['', '/'].contains(site.path) ||
        site.hasQuery) {
      return null;
    }
    for (final source in _sources) {
      if (source.engine == engine && source.site.host == site.host) {
        return source;
      }
    }
    return null;
  }
}

final class AnonymousSource extends Equatable {
  const AnonymousSource._(this.engine, this._site, this._mediaHosts);

  final BooruType engine;
  final String _site;
  final Set<String> _mediaHosts;
  Uri get site => Uri.parse(_site);

  bool allowsMedia(Uri target) =>
      _safeHttps(target) &&
      !target.hasQuery &&
      _mediaHosts.contains(target.host) &&
      _safePath(target) &&
      RegExp(
        r'\.(?:jpg|jpeg|png|gif|webp|avif|bmp|webm|mp4)$',
        caseSensitive: false,
      ).hasMatch(target.path);

  bool allowsApi(Uri target) {
    if (!_safeHttps(target) ||
        target.host != site.host ||
        !_safePath(target) ||
        target.queryParametersAll.keys.any(_credentialParameter)) {
      return false;
    }
    return switch (engine) {
      BooruType.danbooru => RegExp(
        r'^/(?:posts|pools|tags|notes|comments|artists|counts/posts)(?:/[1-9][0-9]*)?\.json$',
      ).hasMatch(target.path),
      BooruType.gelbooruV2 =>
        target.path == '/index.php' &&
            target.queryParametersAll['page']?.length == 1 &&
            target.queryParameters['page'] == 'dapi' &&
            target.queryParametersAll['s']?.length == 1 &&
            const [
              'post',
              'tag',
              'pool',
            ].contains(target.queryParameters['s']) &&
            target.queryParametersAll['q']?.length == 1 &&
            const ['index', 'show'].contains(target.queryParameters['q']),
      BooruType.moebooru => RegExp(
        r'^/(?:post|tag|note|comment)(?:/show/[1-9][0-9]*)?\.json$|^/pool/(?:show/[1-9][0-9]*|index)\.json$',
      ).hasMatch(target.path),
      _ => false,
    };
  }

  @override
  List<Object?> get props => [engine, _site];
}

bool _safeHttps(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host.isNotEmpty &&
    uri.port == 443 &&
    uri.userInfo.isEmpty &&
    !uri.hasFragment;

bool _safePath(Uri uri) =>
    !uri.path.contains(r'\') &&
    !RegExp('%(?:2f|5c|2e|25)', caseSensitive: false).hasMatch(uri.path) &&
    !uri.pathSegments.any((segment) => segment == '.' || segment == '..');

bool _credentialParameter(String name) => const {
  'api_key',
  'apikey',
  'login',
  'password',
  'pass_hash',
  'token',
  'access_token',
  'auth',
  'authorization',
  'user_id',
}.contains(name.toLowerCase());

// Source sites are the exact built-in installations in boorus.yaml. CDN access
// remains separate and explicit; unknown media hosts remain unavailable.
const _sources = [
  AnonymousSource._(BooruType.danbooru, 'https://danbooru.donmai.us', {
    'danbooru.donmai.us',
    'cdn.donmai.us',
  }),
  AnonymousSource._(BooruType.danbooru, 'https://safebooru.donmai.us', {
    'safebooru.donmai.us',
    'cdn.donmai.us',
  }),
  AnonymousSource._(BooruType.danbooru, 'https://aibooru.online', {
    'aibooru.online',
    'cdn.aibooru.download',
  }),
  AnonymousSource._(BooruType.gelbooruV2, 'https://safebooru.org', {
    'safebooru.org',
    'wimg.safebooru.org',
  }),
  AnonymousSource._(BooruType.moebooru, 'https://konachan.com', {
    'konachan.com',
  }),
  AnonymousSource._(BooruType.moebooru, 'https://konachan.net', {
    'konachan.net',
  }),
  AnonymousSource._(BooruType.moebooru, 'https://yande.re', {
    'yande.re',
    'files.yande.re',
    'assets.yande.re',
  }),
  AnonymousSource._(BooruType.moebooru, 'https://www.sakugabooru.com', {
    'www.sakugabooru.com',
  }),
  AnonymousSource._(BooruType.moebooru, 'https://sakugabooru.com', {
    'sakugabooru.com',
    'www.sakugabooru.com',
  }),
];
