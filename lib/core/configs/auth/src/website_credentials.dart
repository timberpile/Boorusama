// Dart imports:
import 'dart:async';
import 'dart:convert';

// Package imports:
import 'package:booru_clients/gelbooru.dart';
import 'package:collection/collection.dart';
import 'package:coreutils/coreutils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../foundation/browser/cookie_conversion.dart';
import '../../../../foundation/browser/types.dart';
import '../../../boorus/booru/types.dart';
import '../../../http/client/providers.dart';
import '../../../proxy/types.dart';

enum WebsiteCredentialSite {
  gelbooru(BooruType.gelbooru, 'gelbooru.com'),
  rule34(BooruType.gelbooruV2, 'rule34.xxx', apiHost: 'api.rule34.xxx'),
  realbooru(BooruType.gelbooruV2, 'realbooru.com'),
  danbooru(BooruType.danbooru, 'danbooru.donmai.us'),
  safebooru(BooruType.danbooru, 'safebooru.donmai.us'),
  e621(BooruType.e621, 'e621.net'),
  derpibooru(BooruType.philomena, 'derpibooru.org');

  const WebsiteCredentialSite(this._type, this.host, {String? apiHost})
    : _apiHost = apiHost ?? host;

  final BooruType _type;
  final String host;
  final String _apiHost;

  static WebsiteCredentialSite? forProfile(BooruType type, String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return values.firstWhereOrNull(
      (site) => site._type == type && site.matchesOrigin(uri),
    );
  }

  bool get importsSession =>
      this == gelbooru || this == rule34 || this == realbooru;

  bool get importsKey => this != realbooru;
  bool get importsLogin => this != derpibooru;
  bool get _isDonmai => this == danbooru || this == safebooru;

  bool matchesOrigin(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == host &&
      uri.port == 443 &&
      uri.userInfo.isEmpty;

  Uri get loginUri => switch (this) {
    danbooru || safebooru => Uri.https(host, '/profile'),
    e621 || derpibooru => optionsUri,
    _ => Uri.https(host, '/index.php', {
      'page': 'account',
      's': 'login',
      'code': '00',
    }),
  };

  Uri get optionsUri => switch (this) {
    e621 => Uri.https(host, '/api_keys'),
    derpibooru => Uri.https(host, '/registrations/edit'),
    _ => Uri.https(host, '/index.php', {
      'page': 'account',
      's': this == realbooru ? 'home' : 'options',
    }),
  };

  bool isOptions(Uri uri) {
    if (!matchesOrigin(uri)) return false;
    return switch (this) {
      danbooru || safebooru => _danbooruKeyPath.hasMatch(uri.path),
      e621 => uri.path == optionsUri.path,
      derpibooru => uri.path == optionsUri.path || uri.path == '/users/edit',
      _ =>
        uri.path == optionsUri.path &&
            uri.queryParametersAll.length == 2 &&
            uri.queryParametersAll['page']?.singleOrNull == 'account' &&
            uri.queryParametersAll['s']?.singleOrNull ==
                optionsUri.queryParameters['s'],
    };
  }

  Future<Uri?> destination(EmbeddedBrowserSession browser) async {
    if (importsSession) {
      return await readSession(browser) != null ? optionsUri : null;
    }
    final script = destinationScript;
    if (script == null) return null;
    final userId = _browserString(await browser.evaluateJavaScript(script));
    if (userId == null || !_validUserId(userId)) return null;
    return Uri.https(host, '/users/$userId/api_keys');
  }

  String? get destinationScript => _isDonmai
      ? '''
(() => {
  const userId = document.body.dataset.currentUserId;
  const url = new URL(window.location.href);
  return url.origin === 'https://$host' &&
    (url.pathname === '/profile' || url.pathname === '/users/' + userId)
    ? userId : '';
})()
'''
      : null;

  Uri get _indexUri => Uri.https(host, '/index.php');
  Uri get _addFavoriteUri => Uri.https(host, '/public/addfav.php');
  String get _uidCookie =>
      this == rule34 ? Rule34WebsiteSession.userIdCookie : 'user_id';
  String get _sessionCookie =>
      this == rule34 ? Rule34WebsiteSession.sessionCookie : 'pass_hash';

  Future<({String userId, String passHash})?> readSession(
    EmbeddedBrowserSession browser, {
    bool forImport = false,
  }) async {
    final uris = [_indexUri, if (forImport) _addFavoriteUri];
    final cookiesByUri = await Future.wait([
      for (final uri in uris) browser.getCookies(uri),
    ]);
    final now = DateTime.now();
    final pairs = [
      for (final (index, uri) in uris.indexed)
        _cookiePair(
          browserCookiesForRequest(
            uri: uri,
            cookies: cookiesByUri[index],
            now: now,
          ),
        ),
    ];
    final pair = pairs.first;
    if (pair == null || pairs.any((other) => other != pair)) return null;
    final (id, token) = pair;
    return switch (this) {
      gelbooru || realbooru
          when _validUserId(id) && _cookieOctets.stringMatch(token) == token =>
        (userId: id, passHash: token),
      rule34 => _rule34Session(id, token),
      _ => null,
    };
  }

  (String, String)? _cookiePair(List<Cookie> cookies) {
    final ids = <String>{};
    final tokens = <String>{};
    for (final cookie in cookies) {
      if (cookie.name == _uidCookie) ids.add(cookie.value);
      if (cookie.name == _sessionCookie) tokens.add(cookie.value);
    }

    if (ids.length != 1 || tokens.length != 1) return null;
    return (ids.single, tokens.single);
  }

  static ({String userId, String passHash})? _rule34Session(
    String signedId,
    String token,
  ) {
    final session = Rule34WebsiteSession.fromCookies(
      signedUserId: signedId,
      token: token,
    );
    if (session == null || !_validUserId(session.userId)) return null;
    return (userId: session.userId, passHash: session.toStoredValue());
  }

  /// Both sites present the pair in a labeled options row. Only the matching
  /// document may return a pair, even if navigation races script evaluation.
  String get extractorScript => switch (this) {
    danbooru || safebooru || e621 => _namedKeysScript,
    derpibooru => _philomenaScript,
    realbooru => _realbooruAccountScript,
    _ => _dapiScript,
  };

  String get _dapiScript =>
      '''
(() => {
  const url = new URL(window.location.href);
  if (url.origin !== 'https://$host' ||
      url.pathname !== '/index.php' ||
      Array.from(url.searchParams).length !== 2 ||
      url.searchParams.get('page') !== 'account' ||
      url.searchParams.get('s') !== 'options') return '';

  const rows = Array.from(document.querySelectorAll('tr')).filter(row =>
    /^API Access Credentials\\b/i.test(row.cells[0]?.textContent.trim() ?? '')
  );
  if (rows.length !== 1) return '';
  const cells = Array.from(rows[0].cells).slice(1);
  const text = cells.map(cell => [
    cell.textContent,
    ...Array.from(cell.querySelectorAll('input[readonly], textarea[readonly]'),
      field => field.value)
  ].join(' ')).join(' ');
  const keys = new Set(Array.from(
    text.matchAll(/(?:^|[?&\\s])api_key=([A-Za-z0-9_-]{16,256})(?=\$|[&\\s])/g),
    match => match[1]));
  const ids = new Set(Array.from(
    text.matchAll(/(?:^|[?&\\s])user_id=([0-9]{1,20})(?=\$|[&\\s])/g),
    match => match[1]));
  if (keys.size !== 1 || ids.size !== 1) return '';
  return JSON.stringify({userId: [...ids][0], apiKey: [...keys][0]});
})()
''';

  String get _namedKeysScript {
    final dan = _isDonmai;
    final path = dan
        ? r'/^\/users\/[1-9][0-9]*\/api_keys\/?$/'
        : r'/^\/api_keys\/?$/';
    final rows = dan ? '#c-api-keys table tbody tr' : '.api-keys-list .row';
    final readCells = dan
        ? '''
    const name = row.cells[0]?.textContent;
    const key = row.cells[1]?.textContent;
'''
        : '''
    if (row.querySelector('.api-key-expired')) continue;
    const name = row.querySelector('[data-label="Name"]')?.textContent;
    const key = row.querySelector('[data-label="Key"] code')?.textContent;
''';
    final readOwner = dan
        ? '''
  const login = document.body.dataset.currentUserName;
  const userId = url.pathname.split('/')[2];
  if (document.body.dataset.currentUserId !== userId) return '';
'''
        : '''
  const sample = document.querySelector('.instructions code')?.textContent.trim();
  if (!sample) return '';
  const sampleUrl = new URL(sample, url);
  if (sampleUrl.origin !== url.origin) return '';
  const login = sampleUrl.searchParams.get('login');
''';
    return '''
(() => {
  const url = new URL(window.location.href);
  if (url.origin !== 'https://$host' || !$path.test(url.pathname)) return '';
  $readOwner
  if (!login) return '';
  const candidates = [];
  for (const row of document.querySelectorAll('$rows')) {
    $readCells
    if (name && key) candidates.push({login, name: name.trim(), apiKey: key.trim()});
  }
  return JSON.stringify(candidates);
})()
''';
  }

  String get _philomenaScript =>
      '''
(() => {
  const url = new URL(window.location.href);
  if (url.origin !== 'https://$host' ||
      !['/registrations/edit', '/users/edit'].includes(url.pathname)) return '';
  const apiKey = document.querySelector('#api-key code')?.textContent.trim();
  return apiKey ? JSON.stringify([{apiKey}]) : '';
})()
''';

  // Check the account page's guest notice even when session cookies exist.
  String get _realbooruAccountScript =>
      '''
(() => {
  const url = new URL(window.location.href);
  // Realbooru's Prototype.js replaces Array.from with a version that cannot
  // read URLSearchParams.
  if (url.origin !== 'https://$host' ||
      url.pathname !== '/index.php' ||
      [...url.searchParams].length !== 2 ||
      url.searchParams.get('page') !== 'account' ||
      url.searchParams.get('s') !== 'home') return '';

  const accountText = document.querySelector('#content')?.innerText?.trim();
  if (!accountText || accountText.includes('You are not logged in.')) return '';
  return 'signed-in';
})()
''';

  List<WebsiteCredentials> candidates(
    Object? raw, {
    ({String userId, String passHash})? session,
  }) {
    if (this == realbooru) {
      if (session == null || _browserString(raw) != 'signed-in') {
        return const [];
      }
      return [WebsiteCredentials._(session.userId, '', session.passHash)];
    }
    if (importsSession) {
      if (session == null) return const [];
      final imported = WebsiteCredentials.fromBrowserResult(
        raw,
        session: session,
      );
      return [?imported];
    }
    final data = _browserJson(raw);
    if (data is! List || data.length > 50) return const [];

    final keys = <String>{};
    final candidates = <WebsiteCredentials>[];
    for (final entry in data) {
      if (entry case {'apiKey': final String key}
          when _apiKeyPattern.stringMatch(key) == key && keys.add(key)) {
        final login = entry['login'];
        final name = entry['name'];
        if (importsLogin && (login is! String || !_validLogin(login))) {
          continue;
        }
        candidates.add(
          WebsiteCredentials._(
            importsLogin ? login as String : '',
            key,
            null,
            name is String && name.isNotEmpty ? name : null,
          ),
        );
      }
    }
    return candidates;
  }

  Uri probeUri(WebsiteCredentials credentials) => switch (this) {
    danbooru || safebooru => Uri.https(_apiHost, '/profile.json'),
    e621 => Uri.https(_apiHost, '/posts.json', {'limit': '1'}),
    derpibooru => Uri.https(_apiHost, '/api/v1/json/filters/user', {
      'key': credentials.apiKey,
      'per_page': '1',
    }),
    realbooru => throw StateError(
      'Realbooru uses browser session verification',
    ),
    _ => Uri.https(_apiHost, '/index.php', {
      'page': 'dapi',
      's': 'post',
      'q': 'index',
      'json': '1',
      'limit': '1',
      'user_id': credentials.login,
      'api_key': credentials.apiKey,
    }),
  };

  Map<String, String> probeHeaders(WebsiteCredentials credentials) => {
    if (_isDonmai || this == e621)
      'Authorization':
          'Basic ${base64Encode(utf8.encode('${credentials.login}:${credentials.apiKey}'))}',
  };

  bool acceptsProbe(Object? data, {WebsiteCredentials? credentials}) {
    // The production listing parsers can accept empty or unrecognized results
    // that do not establish that the credential probe succeeded.
    final Object? payload;
    try {
      payload = data is String ? jsonDecode(data) : data;
    } on FormatException {
      return false;
    }
    if (payload is Map &&
        (payload.containsKey('error') || payload['success'] == false)) {
      return false;
    }
    return switch ((this, payload)) {
      (
        gelbooru,
        {'@attributes': {'count': final int count}, 'post': [final post]},
      )
          when count > 0 =>
        _isPost(post),
      (rule34, [final post]) => _isPost(post),
      (
        danbooru || safebooru,
        {'id': final int id, 'name': final String name},
      ) =>
        id > 0 && name == credentials?.login,
      (e621, {'posts': [final post]}) => _isPost(post),
      (derpibooru, {'filters': final List filters, 'total': final int total}) =>
        total >= filters.length,
      _ => false,
    };
  }

  static bool _isPost(Object? post) =>
      post is Map && post['id'] is int && (post['id'] as int) > 0;
}

final _userIdPattern = RegExp(r'^[1-9][0-9]{0,19}$');
final _apiKeyPattern = RegExp(r'^[A-Za-z0-9_-]{16,256}$');
final _cookieOctets = RegExp(r'^[\x21\x23-\x2B\x2D-\x3A\x3C-\x5B\x5D-\x7E]+$');

bool _validUserId(String value) => _userIdPattern.stringMatch(value) == value;

final _danbooruKeyPath = RegExp(r'^/users/[1-9][0-9]*/api_keys/?$');
final _loginPattern = RegExp(r'^[^:\x00-\x20\x7f]{1,128}$');

bool _validLogin(String value) => _loginPattern.stringMatch(value) == value;

Object? _browserJson(Object? result) {
  final value = _browserString(result);
  if (value == null || value.length > 65536) return null;
  try {
    return jsonDecode(value);
  } on FormatException {
    return null;
  }
}

String? _browserString(Object? result) {
  if (result is! String) return null;
  if (!result.startsWith('"')) return result;
  try {
    // Android and WebView2 can wrap a returned JS string in JSON quotes.
    final decoded = jsonDecode(result);
    return decoded is String ? decoded : null;
  } on FormatException {
    return null;
  }
}

final class WebsiteCredentials {
  const WebsiteCredentials._(
    this.login,
    this.apiKey,
    this.passHash, [
    this.name,
  ]);

  final String login;
  final String apiKey;
  final String? passHash;
  final String? name;

  bool matches(WebsiteCredentials other) =>
      login == other.login &&
      apiKey == other.apiKey &&
      passHash == other.passHash;

  static WebsiteCredentials? fromBrowserResult(
    Object? result, {
    required ({String userId, String passHash}) session,
  }) {
    if (_browserJson(result)
        case {
          'userId': final String userId,
          'apiKey': final String key,
        }
        when userId == session.userId &&
            _apiKeyPattern.stringMatch(key) == key) {
      return WebsiteCredentials._(userId, key, session.passHash);
    }
    return null;
  }
}

typedef WebsiteCredentialValidator = Future<bool> Function(
  WebsiteCredentialSite site,
  WebsiteCredentials credentials,
  ProxySettings? proxy,
  CancelToken cancellation,
);

const websiteCredentialTimeout = Duration(seconds: 15);

/// Signs out the matching Realbooru account in the shared embedded browser.
Future<bool> signOutRealbooruBrowser(
  EmbeddedBrowserFactory factory, {
  required String userId,
}) async {
  final availability = await factory.checkAvailability().timeout(
    websiteCredentialTimeout,
  );
  if (!availability.isAvailable) return true;

  final creation = factory.createSession();
  final browser = await creation.timeout(
    websiteCredentialTimeout,
    onTimeout: () {
      creation.then((lateBrowser) => lateBrowser.dispose()).ignore();
      throw TimeoutException('Realbooru browser initialization timed out');
    },
  );
  const site = WebsiteCredentialSite.realbooru;
  Future<bool> hasMatchingSession() async =>
      (await site.readSession(browser).timeout(websiteCredentialTimeout))
          ?.userId ==
      userId;

  StreamSubscription<BrowserEvent>? subscription;
  try {
    if (!await hasMatchingSession()) return true;

    final completed = Completer<bool>();
    subscription = browser.events.listen((event) {
      if (completed.isCompleted) return;
      if (event.kind == BrowserEventKind.navigationCompleted) {
        if (event.uri case final uri? when !site.matchesOrigin(uri)) return;
        completed.complete(true);
      } else if (event.kind == BrowserEventKind.loadError &&
          (event.isForMainFrame ?? true)) {
        completed.complete(false);
      }
    });
    // Realbooru's account page uses this GET route to sign out.
    final logoutUri = Uri.https(site.host, '/index.php', {
      'page': 'account',
      's': 'login',
      'code': '01',
    });
    await browser.load(logoutUri).timeout(websiteCredentialTimeout);
    return await completed.future.timeout(websiteCredentialTimeout) &&
        !await hasMatchingSession();
  } finally {
    subscription?.cancel().ignore();
    await browser.dispose();
  }
}

final websiteCredentialValidatorProvider =
    Provider.autoDispose<WebsiteCredentialValidator>(
      (ref) {
        final userAgent = ref.watch(defaultUserAgentProvider);
        return (site, credentials, proxy, cancellation) async {
          final dio = newGenericDio(
            baseUrl: null,
            userAgent: userAgent,
            proxySettings: proxy,
          );
          dio.options
            ..connectTimeout = websiteCredentialTimeout
            ..receiveTimeout = websiteCredentialTimeout;
          try {
            final response = await dio
                .getUri<Object?>(
                  site.probeUri(credentials),
                  cancelToken: cancellation,
                  options: Options(
                    followRedirects: false,
                    headers: {
                      'Cache-Control': 'no-store',
                      ...site.probeHeaders(credentials),
                    },
                    responseType: ResponseType.plain,
                  ),
                )
                .timeout(websiteCredentialTimeout);
            return response.statusCode == 200 &&
                site.acceptsProbe(response.data, credentials: credentials);
          } finally {
            dio.close(force: true);
          }
        };
      },
    );
