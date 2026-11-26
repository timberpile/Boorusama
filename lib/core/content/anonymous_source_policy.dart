import 'package:equatable/equatable.dart';

import '../boorus/booru/types.dart';

/// Public reads are an explicit source permission, never an engine-wide default.
/// A matching imported host, redirect or image URL cannot extend this list.
final class AnonymousSourcePolicy {
  const AnonymousSourcePolicy({
    this.enabled = true,
    this.nhentaiEnabled = false,
  });

  final bool enabled;
  final bool nhentaiEnabled;

  static const version = 1;

  bool _enabledFor(BooruType engine) =>
      enabled && (engine != BooruType.nhentai || nhentaiEnabled);

  /// Legacy Post origins retain a namespace rather than a transport URL. Select
  /// an explicitly registered public endpoint without rewriting that identity.
  AnonymousSource? forNamespace(BooruType engine, String namespace) {
    if (!_enabledFor(engine)) return null;
    for (final source in _sources) {
      if (source.engine == engine &&
          source.site.host == namespace &&
          _catalogPermits(source)) {
        return source;
      }
    }
    return null;
  }

  AnonymousSource? resolve(BooruType engine, Uri site) {
    if (!_enabledFor(engine) ||
        !_safeHttps(site) ||
        !const ['', '/'].contains(site.path) ||
        site.hasQuery) {
      return null;
    }
    for (final source in _sources) {
      if (source.engine == engine &&
          source.site.host == site.host &&
          _catalogPermits(source)) {
        return source;
      }
    }
    return null;
  }
}

final class AnonymousSource extends Equatable {
  const AnonymousSource._(
    this.engine,
    this._site,
    this._mediaHosts, {
    Set<String> apiHosts = const {},
  }) : _apiHosts = apiHosts;

  final BooruType engine;
  final String _site;
  final Set<String> _mediaHosts;
  final Set<String> _apiHosts;
  bool get isNhentai => engine == BooruType.nhentai;
  Uri get site => Uri.parse(_site);

  bool allowsMedia(Uri target) =>
      _safeHttps(target) &&
      (!target.hasQuery ||
          (_site == 'https://realbooru.com' && _realbooruMediaQuery(target))) &&
      (_site != 'https://realbooru.com' ||
          RegExp('^/{1,2}(?:images|thumbnails|samples)/')
              .hasMatch(target.path)) &&
      (_mediaHosts.contains(target.host) ||
          (engine == BooruType.nhentai &&
              RegExp(r'^[it][1-9][0-9]*\.nhentai\.net$')
                  .hasMatch(target.host) &&
              RegExp(
                r'^/galleries/[1-9][0-9]*/[A-Za-z0-9_-]+(?:\.(?:jpg|jpeg|png|gif|webp|avif))+$',
              ).hasMatch(target.path))) &&
      _safePath(target) &&
      RegExp(
        r'\.(?:jpg|jpeg|png|gif|webp|avif|bmp|webm|mp4)$',
        caseSensitive: false,
      ).hasMatch(target.path);

  bool allowsApi(Uri target) {
    if (!_safeHttps(target) ||
        (target.host != site.host && !_apiHosts.contains(target.host)) ||
        !_safePath(target) ||
        target.queryParametersAll.keys.any(_credentialParameter)) {
      return false;
    }
    if (engine == BooruType.nhentai) return _nhentaiApi(target);
    if (_site == 'https://realbooru.com') return _realbooruApi(target);
    if (_site == 'https://hypnohub.net' && _postHtmlRead(target)) return true;
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
      BooruType.eshuushuu => RegExp(
        r'^/api/v1/(?:images(?:/[1-9][0-9]*)?|users/[1-9][0-9]*|comments|tags/?)$',
      ).hasMatch(target.path),
      BooruType.moebooru => RegExp(
        r'^/(?:post|tag|note|comment)(?:/show/[1-9][0-9]*)?\.json$|^/pool/(?:show/[1-9][0-9]*|index)\.json$',
      ).hasMatch(target.path),
      _ => false,
    };
  }

  @override
  List<Object?> get props => [engine, _site];
}

// Catalog metadata can revoke a grant from the explicit source list. It never
// adds a source or transport permission by itself.
bool _catalogPermits(AnonymousSource source) {
  final config = BooruYamlConfigs.byId[source.engine.id];
  if (config == null || config.auth?['required'] == true) return false;
  final site = config.sites
      .where(
        (site) =>
            Uri.parse(site.url).host == source.site.host ||
            (site.metadata['post-request-url'] is String &&
                Uri.tryParse(site.metadata['post-request-url'] as String)
                        ?.host ==
                    source.site.host),
      )
      .firstOrNull;
  if (site == null) return false;
  if (site.metadata['auth'] case {'required': true}) return false;
  if (site.metadata['quick-profile'] case {'authentication': 'required'}) {
    return false;
  }
  return true;
}

bool _nhentaiApi(Uri target) {
  if (target.queryParametersAll.values.any((values) => values.length != 1)) {
    return false;
  }
  final query = target.queryParameters;
  bool positive(String? value, {int maximum = 9007199254740991}) {
    if (value == null || !RegExp(r'^[1-9][0-9]*$').hasMatch(value)) {
      return false;
    }
    final number = int.tryParse(value);
    return number != null && number <= maximum;
  }

  if (target.path == '/api/v2/config') return query.isEmpty;
  if (const {
    '/api/v2/galleries/random',
    '/api/v2/galleries/popular',
  }.contains(target.path)) {
    return query.isEmpty;
  }
  if (RegExp(r'^/api/v2/galleries/[1-9][0-9]*/related$')
      .hasMatch(target.path)) {
    return query.isEmpty && positive(target.pathSegments[3]);
  }
  if (RegExp(r'^/api/v2/galleries/[1-9][0-9]*$').hasMatch(target.path)) {
    return query.isEmpty && positive(target.pathSegments.last);
  }
  if (target.path == '/api/v2/tags/ids') {
    final ids = query['ids']?.split(',');
    return query.length == 1 &&
        ids != null &&
        ids.length <= 100 &&
        ids.every(positive);
  }
  if (target.path == '/api/v2/search') {
    return positive(query['page']) &&
        (query['query']?.isNotEmpty ?? false) &&
        (query.length == 2 ||
            (query.length == 3 &&
                const {
                  'popular-today',
                  'popular-week',
                  'popular',
                }.contains(query['sort'])));
  }
  if (target.path == '/api/v2/tags/search') return query.isEmpty;
  final catalog =
      RegExp(r'^/api/v2/tags/[a-z][a-z0-9_-]*$').hasMatch(target.path) &&
      target.pathSegments.last != 'general';
  return positive(query['page']) &&
      positive(query['per_page'], maximum: 100) &&
      (switch (target.path) {
        '/api/v2/galleries' => query.length == 2,
        _ =>
          catalog &&
              query.length == 3 &&
              const ['popular', 'name'].contains(query['sort']),
      });
}

bool _postHtmlRead(Uri target) =>
    target.path == '/index.php' &&
    target.queryParametersAll.values.every((values) => values.length == 1) &&
    target.queryParameters.keys.every(const {'page', 's', 'id'}.contains) &&
    target.queryParameters['page'] == 'post' &&
    target.queryParameters['s'] == 'view' &&
    (int.tryParse(target.queryParameters['id'] ?? '') ?? 0) > 0;

bool _realbooruMediaQuery(Uri target) =>
    target.queryParametersAll.entries.every(
      (entry) =>
          const {'v', 'version'}.contains(entry.key) &&
          entry.value.length == 1 &&
          RegExp(r'^[0-9]+$').hasMatch(entry.value.single),
    );

bool _realbooruApi(Uri target) {
  if (target.path != '/index.php') return false;
  final query = target.queryParameters;
  if (target.queryParametersAll.values.any((values) => values.length != 1)) {
    return false;
  }
  bool number(String name, {int minimum = 0, int? maximum}) {
    final value = query[name];
    if (value == null) return true;
    final parsed = int.tryParse(value);
    return parsed != null &&
        parsed >= minimum &&
        (maximum == null || parsed <= maximum);
  }

  if (query['page'] == 'dapi') {
    return query.keys.every(
          const {
            'page',
            's',
            'q',
            'id',
            'limit',
            'pid',
            'tags',
            'json',
          }.contains,
        ) &&
        query['s'] == 'post' &&
        query['q'] == 'index' &&
        number('id', minimum: 1) &&
        number('limit', minimum: 1, maximum: 100) &&
        number('pid') &&
        (query['json'] == null || const {'0', '1'}.contains(query['json']));
  }
  // Existing Realbooru engine overrides use the native HTML listing/detail
  // parser while its documented DAPI endpoint is unavailable.
  if (query['page'] != 'post') return false;
  return switch (query['s']) {
    'list' =>
      query.keys.every(const {'page', 's', 'tags', 'pid'}.contains) &&
          number('pid'),
    'view' =>
      query.keys.every(const {'page', 's', 'id'}.contains) &&
          query['id'] != null &&
          number('id', minimum: 1),
    _ => false,
  };
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
  AnonymousSource._(BooruType.nhentai, 'https://nhentai.net', {}),
  AnonymousSource._(BooruType.eshuushuu, 'https://e-shuushuu.net', {
    'e-shuushuu.net',
    'cdn.e-shuushuu.net',
  }),
  AnonymousSource._(BooruType.gelbooruV2, 'https://hypnohub.net', {
    'hypnohub.net',
  }),
  AnonymousSource._(BooruType.gelbooruV2, 'https://realbooru.com', {
    'realbooru.com',
  }),
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
  AnonymousSource._(
    BooruType.moebooru,
    'https://sakugabooru.com',
    {
      'sakugabooru.com',
      'www.sakugabooru.com',
    },
    apiHosts: {'www.sakugabooru.com'},
  ),
];
