import 'package:coreutils/coreutils.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

import '../gelbooru/gelbooru_client_favorites.dart';
import 'rule34_website_session.dart';

class Rule34FavoriteActions {
  const Rule34FavoriteActions(this.dio, this.session);

  static final _website = Rule34WebsiteSession.origin;
  static const _redirects = {301, 302, 303, 307, 308};

  final Dio dio;
  final Rule34WebsiteSession? session;

  bool get hasSession => session != null;
  String? get userId => session?.userId;

  Future<GelbooruFavoriteStatus> add(int postId) async {
    if (!hasSession) return GelbooruFavoriteStatus.userNotLoggedIn;

    try {
      final response = await _get(Rule34WebsiteSession.addFavoriteUri, {
        'id': postId,
      });
      if (response.statusCode != 200) return GelbooruFavoriteStatus.failed;

      final code = switch (response.data) {
        final String value => value.trim(),
        final num value => value,
        _ => null,
      };
      return switch (code) {
        '1' || 1 => GelbooruFavoriteStatus.alreadyFavorited,
        '2' || 2 => GelbooruFavoriteStatus.userNotLoggedIn,
        '3' || 3 => GelbooruFavoriteStatus.success,
        _ => GelbooruFavoriteStatus.unknown,
      };
    } on GelbooruFavoriteException catch (error) {
      return error.status;
    }
  }

  Future<void> remove(int postId) async {
    if (!hasSession) {
      throw const GelbooruFavoriteException(
        GelbooruFavoriteStatus.userNotLoggedIn,
      );
    }

    // The delete endpoint can return an ordinary page even when nothing was
    // deleted. Compare the first page of the signed-in account before and after
    // the mutation. An unrecognized or incomplete listing cannot confirm it.
    final before = await _firstFavoritesPage();
    final index = before.posts.indexOf(postId);
    if (index == -1) _unconfirmed();

    final response = await _get(Rule34WebsiteSession.indexUri, {
      'page': 'favorites',
      's': 'delete',
      'id': postId,
    });
    if (response.statusCode != 200) {
      final destination = _redirectTarget(response);
      final query = destination?.queryParameters;
      if (destination?.path != '/index.php' ||
          query?['page'] != 'favorites' ||
          query?['s'] != 'view' ||
          (query?['id'] != null && query?['id'] != userId)) {
        _unconfirmed();
      }
    }

    final after = await _firstFavoritesPage();
    // A concurrent add could push a post off a full first page. A post that
    // followed the target bounds its old position on the refreshed page.
    if (after.posts.contains(postId) ||
        (after.hasNext &&
            !before.posts.skip(index + 1).any(after.posts.contains))) {
      _unconfirmed();
    }
  }

  Future<({List<int> posts, bool hasNext})> _firstFavoritesPage() async {
    final response = await _get(Rule34WebsiteSession.indexUri, {
      'page': 'favorites',
      's': 'view',
      'id': userId,
    }, mutation: false);
    final body = response.data;
    if (response.statusCode != 200 || body is! String) _unconfirmed();
    final document = html.parse(body);
    final pagination = document.querySelector('#paginator');
    if (pagination == null ||
        !RegExp(r'var\s+posts\s*=\s*\{\}').hasMatch(body) ||
        !document
            .querySelectorAll('a[href]')
            .any(
              (link) =>
                  _isAccountAction(_target(link.attributes['href']), 'logout'),
            )) {
      _unconfirmed();
    }

    var hasNext = false;
    for (final link in pagination.querySelectorAll('a')) {
      final onclick = link.attributes['onclick'] ?? '';
      final route =
          RegExp(
            r"document\.location\s*=\s*'([^']+)'",
          ).firstMatch(onclick)?.group(1) ??
          link.attributes['href'];
      if (onclick.isEmpty && (route == null || route == '#')) continue;
      final target = _target(route);
      final query = target?.queryParameters;
      if (target?.path != '/index.php' ||
          query?['page'] != 'favorites' ||
          query?['s'] != 'view' ||
          query?['id'] != userId) {
        _unconfirmed();
      }
      final offset = int.tryParse(query?['pid'] ?? '0');
      if (offset == null || offset < 0) _unconfirmed();
      hasNext |= offset > 0;
    }

    final posts = <int>[];
    for (final row in document.querySelectorAll('span.thumb')) {
      final link = row.querySelector('a[href]');
      final target = _target(link?.attributes['href']);
      final query = target?.queryParameters;
      final id = int.tryParse(query?['id'] ?? '');
      if (target?.path != '/index.php' ||
          query?['page'] != 'post' ||
          query?['s'] != 'view' ||
          id == null ||
          id <= 0) {
        _unconfirmed();
      }
      posts.add(id);
    }
    return (posts: posts, hasNext: hasNext);
  }

  Future<Response<Object?>> _get(
    Uri uri,
    Map<String, Object?> query, {
    bool mutation = true,
  }) async {
    // Dio forces JSON for most typed requests. Keep the plain transformer even
    // when a custom interceptor resolves the response with a numeric value.
    final response = await dio.get<dynamic>(
      uri.toString(),
      queryParameters: query,
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (status) =>
            status == 200 ||
            status == 401 ||
            status == 403 ||
            _redirects.contains(status),
        headers: {
          ...session!.headers,
          'Referer': _website.toString(),
          if (!mutation) 'Cache-Control': 'no-cache',
        },
        extra: {
          // Verification reads use the same private session. Prevent challenge
          // replay outside this client for them as well as for mutations.
          ...stateChangingRequestExtra,
          privateRequestDiagnosticsKey: true,
          preferRequestCookiesKey: true,
        },
      ),
    );
    if (response.redirects.isNotEmpty ||
        response.realUri.origin != _website.origin) {
      _unconfirmed();
    }
    final data = response.data;
    if (response.statusCode == 401 ||
        _isAccountAction(_redirectTarget(response), 'login') ||
        (data is String && _isLoginPage(data))) {
      throw const GelbooruFavoriteException(
        GelbooruFavoriteStatus.userNotLoggedIn,
      );
    }
    return response;
  }

  static Uri? _redirectTarget(Response<Object?> response) =>
      _redirects.contains(response.statusCode)
      ? _target(response.headers.value('location'))
      : null;

  static Uri? _target(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null) return null;
    final target = _website.resolveUri(uri);
    return Rule34WebsiteSession.matchesOrigin(target) ? target : null;
  }

  static bool _isAccountAction(Uri? uri, String action) =>
      uri?.path == '/index.php' &&
      uri?.queryParameters['page'] == 'account' &&
      uri?.queryParameters['s'] == action;

  static bool _isLoginPage(String body) =>
      body.contains('<') &&
      html
          .parse(body)
          .querySelectorAll('form[action]')
          .any(
            (form) =>
                _isAccountAction(_target(form.attributes['action']), 'login') &&
                form.querySelector('input[type="password"]') != null,
          );

  static Never _unconfirmed() =>
      throw const GelbooruFavoriteException(GelbooruFavoriteStatus.unknown);
}
