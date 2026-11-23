import 'dart:typed_data';

import 'package:booru_clients/gelbooru.dart';
import 'package:coreutils/coreutils.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

const _login = '/index.php?page=account&s=login&code=00';
const _loginPage = '<form action="$_login"><input type="password"></form>';
const _storedSession = 'rule34-session-v1:42:42.fake-signature;fake-session';
const _ownFavorites = 'index.php?page=favorites&s=view&id=42&pid=0';

void main() {
  late _Adapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _Adapter();
    dio = Dio(BaseOptions(baseUrl: 'https://api.rule34.xxx'))
      ..httpClientAdapter = adapter;
  });
  tearDown(() => dio.close(force: true));

  GelbooruV2Client client({
    String baseUrl = 'https://RULE34.XXX/',
    String? userId = '42',
    String? passHash = _storedSession,
  }) => GelbooruV2Client(
    baseUrl: baseUrl,
    dio: dio,
    userId: userId,
    passHash: passHash,
    apiKey: 'fake-api-key',
  );

  for (final (body, expected) in [
    (' 3\n', GelbooruFavoriteStatus.success),
    ('1', GelbooruFavoriteStatus.alreadyFavorited),
    ('2\r\n', GelbooruFavoriteStatus.userNotLoggedIn),
    ('"3"', GelbooruFavoriteStatus.unknown),
    ('{"status":3}', GelbooruFavoriteStatus.unknown),
    ('<html>3</html>', GelbooruFavoriteStatus.unknown),
    (_loginPage, GelbooruFavoriteStatus.userNotLoggedIn),
  ]) {
    test('add maps fixture ${body.trim()} to ${expected.name}', () async {
      adapter.responses.add(() => ResponseBody.fromString(body, 200));
      expect(await client().addFavorite(postId: 7), expected);
      final request = adapter.requests.single;
      expect(request.uri.path, '/public/addfav.php');
      expect(request.uri.queryParameters, {'id': '7'});
      _expectPrivateMutation(request);
    });
  }

  for (final (code, expected) in [
    (1, GelbooruFavoriteStatus.alreadyFavorited),
    (2, GelbooruFavoriteStatus.userNotLoggedIn),
    (3, GelbooruFavoriteStatus.success),
    (4, GelbooruFavoriteStatus.unknown),
  ]) {
    test('add accepts a numeric status from an interceptor: $code', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.resolve(
            Response(requestOptions: request, data: code, statusCode: 200),
          ),
        ),
      );
      expect(await client().addFavorite(postId: 7), expected);
    });
  }

  for (final (status, location, expected) in [
    (302, _login, GelbooruFavoriteStatus.userNotLoggedIn),
    (302, 'https://api.rule34.xxx$_login', GelbooruFavoriteStatus.failed),
    (302, 'https://other.invalid/', GelbooruFavoriteStatus.failed),
    (401, null, GelbooruFavoriteStatus.userNotLoggedIn),
    (403, null, GelbooruFavoriteStatus.failed),
  ]) {
    test('add rejects $status to ${location ?? "no redirect"}', () async {
      adapter.responses.add(
        () => ResponseBody.fromString(
          '3',
          status,
          headers: {
            if (location != null) 'location': [location],
          },
        ),
      );
      expect(await client().addFavorite(postId: 7), expected);
      expect(adapter.requests, hasLength(1));
    });
  }

  test('Cloudflare denial remains a failure', () async {
    adapter.responses.add(
      () => ResponseBody.fromString(
        '3',
        403,
        headers: {
          'cf-mitigated': ['challenge'],
        },
      ),
    );
    expect(
      await client().addFavorite(postId: 7),
      GelbooruFavoriteStatus.failed,
    );
  });

  for (final (userId, passHash) in [
    ('42', null),
    ('42', ''),
    ('42', ' '),
    (null, 'fake-session'),
    (' ', 'fake-session'),
    ('42', 'fake-legacy-pass-hash'),
    ('43', _storedSession),
    ('42', 'rule34-session-v1:42:42.fake-signature;invalid;cookie'),
    ('42', 'rule34-session-v1:42:43.fake-signature;fake-session'),
  ]) {
    test('invalid website session prevents both mutations', () async {
      final r34 = client(userId: userId, passHash: passHash);
      expect(r34.needsWebsiteLogin, true);
      expect(r34.canFavorite, false);
      expect(
        await r34.addFavorite(postId: 7),
        GelbooruFavoriteStatus.userNotLoggedIn,
      );
      await expectLater(
        r34.removeFavorite(postId: 7),
        _favoriteError(GelbooruFavoriteStatus.userNotLoggedIn),
      );
      expect(adapter.requests, isEmpty);
    });
  }

  for (final postId in [7, 90000000]) {
    test(
      'remove dispatches once without locating post $postId in Favorites',
      () async {
        adapter.responses.add(() => ResponseBody.fromString('', 200));
        await client().removeFavorite(postId: postId);
        final request = adapter.requests.single;
        expect(request.uri.path, '/index.php');
        expect(request.uri.queryParameters, {
          'page': 'favorites',
          's': 'delete',
          'id': '$postId',
          'return_pid': '0',
        });
        _expectPrivateMutation(request);
      },
    );
  }

  for (final (status, body) in [
    (200, '2'),
    (200, '<html>Favorites</html>'),
    (204, ''),
  ]) {
    test('delete accepts a $status receipt with body "$body"', () async {
      adapter.responses.add(() => ResponseBody.fromString(body, status));
      await client().removeFavorite(postId: 7);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.uri.queryParameters['s'], 'delete');
    });
  }

  test(
    'delete accepts HTTP 302 to the signed-in account’s Favorites',
    () async {
      adapter.responses.add(
        () => ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': [_ownFavorites],
          },
        ),
      );
      await client().removeFavorite(postId: 7);
      final request = adapter.requests.single;
      expect(request.uri.queryParameters['return_pid'], '0');
      _expectPrivateMutation(request);
    },
  );

  for (final (status, location) in [
    (302, '/index.php?page=favorites&s=view&id=42'),
    (302, '/index.php?page=favorites&s=view&id=43&pid=0'),
    (302, '/index.php?page=favorites&s=view&id=42&pid=50'),
    (302, '/index.php?page=favorites&s=view&id=42&id=43&pid=0'),
    (302, 'https://api.rule34.xxx/$_ownFavorites'),
    (302, 'https://other.invalid/$_ownFavorites'),
    (303, _ownFavorites),
  ]) {
    test(
      'an unrecognized delete redirect stays unconfirmed ($status $location)',
      () async {
        adapter.responses.add(
          () => ResponseBody.fromString(
            '',
            status,
            headers: {
              'location': [location],
            },
          ),
        );
        await expectLater(
          client().removeFavorite(postId: 7),
          _favoriteError(GelbooruFavoriteStatus.unknown),
        );
        expect(adapter.requests, hasLength(1));
      },
    );
  }

  test(
    'multiple redirect locations fail closed without a header exception',
    () async {
      adapter.responses.add(
        () => ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': [_login, 'https://other.invalid/'],
          },
        ),
      );
      await expectLater(
        client().removeFavorite(postId: 7),
        _favoriteError(GelbooruFavoriteStatus.unknown),
      );
      expect(adapter.requests, hasLength(1));
    },
  );

  for (final (status, body, location, expected) in [
    (401, '', null, GelbooruFavoriteStatus.userNotLoggedIn),
    (403, '', null, GelbooruFavoriteStatus.failed),
    (200, _loginPage, null, GelbooruFavoriteStatus.userNotLoggedIn),
    (302, '', _login, GelbooruFavoriteStatus.userNotLoggedIn),
  ]) {
    test(
      'delete preserves authentication/denial outcome: $status/$expected',
      () async {
        adapter.responses.add(
          () => ResponseBody.fromString(
            body,
            status,
            headers: {
              if (location != null) 'location': [location],
            },
          ),
        );
        await expectLater(
          client().removeFavorite(postId: 7),
          _favoriteError(expected),
        );
        expect(adapter.requests, hasLength(1));
      },
    );
  }

  for (final removing in [false, true]) {
    test('HTTP errors propagate without replay (remove: $removing)', () async {
      adapter.responses.add(() => ResponseBody.fromString('3', 500));
      await expectLater(
        removing
            ? client().removeFavorite(postId: 7)
            : client().addFavorite(postId: 7),
        throwsA(
          isA<DioException>().having(
            (error) => error.response?.statusCode,
            'status',
            500,
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });
    for (final type in [
      DioExceptionType.connectionError,
      DioExceptionType.receiveTimeout,
      DioExceptionType.cancel,
    ]) {
      test(
        'transport failure never replays $type (remove: $removing)',
        () async {
          adapter.responses.add(
            () => throw DioException(
              requestOptions: adapter.requests.last,
              type: type,
            ),
          );
          await expectLater(
            removing
                ? client().removeFavorite(postId: 7)
                : client().addFavorite(postId: 7),
            throwsA(
              isA<DioException>().having((error) => error.type, 'type', type),
            ),
          );
          expect(adapter.requests, hasLength(1));
          _expectPrivateMutation(adapter.requests.single);
        },
      );
    }
  }

  for (final site in [
    'gelbooru.com',
    'realbooru.com',
    'rule34.xxx.example',
    'custom.example',
  ]) {
    test('keeps the existing Favorite protocol for $site', () async {
      dio.options.baseUrl = 'https://$site';
      final legacy = client(baseUrl: 'https://$site', passHash: '');
      expect(legacy.canFavorite, true);
      expect(legacy.needsWebsiteLogin, false);
      adapter.responses.addAll([
        () => ResponseBody.fromString('2', 200),
        () => ResponseBody.fromString('3\n', 200),
        () => ResponseBody.fromString('', 302),
      ]);
      expect(
        await legacy.addFavorite(postId: 7),
        GelbooruFavoriteStatus.failed,
      );
      expect(
        await legacy.addFavorite(postId: 7),
        GelbooruFavoriteStatus.unknown,
      );
      await legacy.removeFavorite(postId: 7);
      expect(adapter.requests, hasLength(3));
      expect(adapter.requests.every((r) => r.uri.host == site), true);
    });
  }
}

void _expectPrivateMutation(RequestOptions request) {
  expect(request.uri.origin, 'https://rule34.xxx');
  expect(request.method, 'GET');
  expect(
    request.headers['Cookie'],
    'r34_uid=42.fake-signature; __Host-session=fake-session',
  );
  expect(request.headers['Referer'], 'https://rule34.xxx');
  expect(request.headers['Cache-Control'], 'no-cache, no-store');
  expect(request.followRedirects, false);
  expect(request.responseType, ResponseType.plain);
  expect(request.extra[stateChangingRequestKey], true);
  expect(request.extra[privateRequestDiagnosticsKey], true);
  expect(request.extra[preferRequestCookiesKey], true);
  expect(request.uri.queryParameters.containsKey('api_key'), false);
  expect(request.uri.queryParameters.containsKey('pid'), false);
}

Matcher _favoriteError(GelbooruFavoriteStatus status) => throwsA(
  isA<GelbooruFavoriteException>().having(
    (error) => error.status,
    'status',
    status,
  ),
);

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final responses = <ResponseBody Function()>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responses.removeAt(0)();
  }

  @override
  void close({bool force = false}) {}
}
