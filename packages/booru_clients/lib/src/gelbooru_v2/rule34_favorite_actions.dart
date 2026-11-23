import 'package:coreutils/coreutils.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

import '../gelbooru/gelbooru_client_favorites.dart';
import 'rule34_website_session.dart';

class Rule34FavoriteActions {
  const Rule34FavoriteActions(this.dio, this.session);

  static final _website = Rule34WebsiteSession.origin;
  static const _redirects = {301, 302, 303, 307, 308};
  static const _favoritesReturnOffset = 0;

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

    // A mutation must not depend on the size or layout of the Favorites page.
    // Dispatch once, without a preflight scan, verification crawl or replay.
    final response = await _get(Rule34WebsiteSession.indexUri, {
      'page': 'favorites',
      's': 'delete',
      'id': postId,
      'return_pid': _favoritesReturnOffset,
    });
    if (response.statusCode == 403) {
      throw const GelbooruFavoriteException(GelbooruFavoriteStatus.failed);
    }
    final confirmed = switch (response.statusCode) {
      200 => true,
      204 => response.data == null || response.data == '',
      // The browser receives this redirect after deleting a Favorite.
      302 => _returnsToOwnFavorites(_redirectTarget(response)),
      _ => false,
    };
    if (!confirmed) _unconfirmed();
  }

  Future<Response<Object?>> _get(
    Uri uri,
    Map<String, Object?> query,
  ) async {
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
            status == 204 ||
            status == 401 ||
            status == 403 ||
            _redirects.contains(status),
        headers: {
          ...session!.headers,
          'Referer': _website.toString(),
          'Cache-Control': 'no-cache, no-store',
        },
        extra: {
          ...stateChangingRequestExtra,
          privateRequestDiagnosticsKey: true,
          preferRequestCookiesKey: true,
        },
      ),
    );
    if (response.redirects.isNotEmpty ||
        !Rule34WebsiteSession.matchesOrigin(response.realUri)) {
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

  static Uri? _redirectTarget(Response<Object?> response) {
    if (!_redirects.contains(response.statusCode)) return null;
    final locations = response.headers['location'];
    return locations?.length == 1 ? _target(locations!.single) : null;
  }

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

  bool _returnsToOwnFavorites(Uri? target) {
    if (target == null || target.path != '/index.php' || target.hasFragment) {
      return false;
    }
    final query = target.queryParametersAll;
    return switch (query) {
      {
        'page': ['favorites'],
        's': ['view'],
        'id': [final account],
        'pid': [final offset],
      }
          when query.length == 4 &&
              account == userId &&
              offset == '$_favoritesReturnOffset' =>
        true,
      _ => false,
    };
  }

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
