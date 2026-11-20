import 'dart:typed_data';

import 'package:booru_clients/gelbooru.dart';
import 'package:coreutils/coreutils.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

const _login = '/index.php?page=account&s=login&code=00';
const _loginPage = '<form action="$_login"><input type="password"></form>';

const _storedSession = 'rule34-session-v1:42:42.fake-signature;fake-session';

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
      expect(request.uri.origin, 'https://rule34.xxx');
      expect(request.uri.path, '/public/addfav.php');
      expect(request.uri.queryParameters, {'id': '7'});
      expect(
        request.headers['Cookie'],
        'r34_uid=42.fake-signature; __Host-session=fake-session',
      );
      expect(request.headers['Referer'], 'https://rule34.xxx');
      expect(request.followRedirects, false);
      expect(request.responseType, ResponseType.plain);
      expect(request.extra[stateChangingRequestKey], true);
      expect(request.extra[privateRequestDiagnosticsKey], true);
      expect(request.extra[preferRequestCookiesKey], true);
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

  test('HTTP failure and transport errors never acknowledge an add', () async {
    adapter.responses.add(() => ResponseBody.fromString('3', 500));
    await expectLater(
      client().addFavorite(postId: 7),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'status',
          500,
        ),
      ),
    );

    for (final type in [
      DioExceptionType.connectionError,
      DioExceptionType.cancel,
    ]) {
      adapter.responses.add(
        () => throw DioException(
          requestOptions: adapter.requests.last,
          type: type,
        ),
      );
      await expectLater(
        client().addFavorite(postId: 7),
        throwsA(
          isA<DioException>().having((error) => error.type, 'type', type),
        ),
      );
    }
    expect(adapter.requests, hasLength(3));
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

  test(
    'remove checks membership before and after an authenticated delete',
    () async {
      adapter.responses.addAll([
        () => _favorites([7, 8], hasNext: true),
        () => ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': ['/index.php?page=favorites&s=view&id=42'],
          },
        ),
        () => _favorites([8, 9], hasNext: true),
      ]);
      await client().removeFavorite(postId: 7);
      expect(adapter.requests.map((r) => r.uri.queryParameters['s']), [
        'view',
        'delete',
        'view',
      ]);
      for (final request in adapter.requests) {
        expect(request.uri.origin, 'https://rule34.xxx');
        expect(
          request.headers['Cookie'],
          'r34_uid=42.fake-signature; __Host-session=fake-session',
        );
        expect(request.followRedirects, false);
        expect(request.uri.queryParameters.containsKey('api_key'), false);
        expect(request.extra[privateRequestDiagnosticsKey], true);
      }
    },
  );

  test(
    'remove of the last favorite accepts a recognized empty listing',
    () async {
      adapter.responses.addAll([
        () => _favorites([7]),
        () => ResponseBody.fromString('', 200),
        () => _favorites([]),
      ]);
      await client().removeFavorite(postId: 7);
    },
  );

  test(
    'a target absent from the bounded listing leaves the site untouched',
    () async {
      adapter.responses.add(() => _favorites([8], hasNext: true));
      await expectLater(
        client().removeFavorite(postId: 7),
        _favoriteError(GelbooruFavoriteStatus.unknown),
      );
      expect(adapter.requests, hasLength(1));
    },
  );

  for (final (description, after) in <(String, ResponseBody Function())>[
    ('the post is still there', () => _favorites([7])),
    (
      'the post may have moved to another page',
      () => _favorites([8], hasNext: true),
    ),
    (
      'the verification body is unrecognized',
      () => ResponseBody.fromString('<html>Access denied</html>', 200),
    ),
    ('the page is public', () => _favorites([], signedIn: false)),
  ]) {
    test('a 200 delete is unconfirmed when $description', () async {
      adapter.responses.addAll([
        () => _favorites([7, 8, 9], hasNext: true),
        () => ResponseBody.fromString('200 OK', 200),
        // For the pagination case, 8 precedes the target in the initial page.
        after,
      ]);
      if (description.contains('another page')) {
        adapter.responses[0] = () => _favorites([8, 7, 9], hasNext: true);
      }
      await expectLater(
        client().removeFavorite(postId: 7),
        _favoriteError(GelbooruFavoriteStatus.unknown),
      );
      expect(adapter.requests, hasLength(3));
    });
  }

  for (final (response, error)
      in <(ResponseBody Function(), GelbooruFavoriteStatus)>[
        (
          () => ResponseBody.fromString(_loginPage, 200),
          GelbooruFavoriteStatus.userNotLoggedIn,
        ),
        (
          () => ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': [_login],
            },
          ),
          GelbooruFavoriteStatus.userNotLoggedIn,
        ),
        (
          () => ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': ['https://other.invalid/'],
            },
          ),
          GelbooruFavoriteStatus.unknown,
        ),
      ]) {
    test('remove does not follow a rejected or untrusted response', () async {
      adapter.responses.addAll([
        () => _favorites([7]),
        response,
      ]);
      await expectLater(
        client().removeFavorite(postId: 7),
        _favoriteError(error),
      );
      expect(adapter.requests, hasLength(2));
    });
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

Matcher _favoriteError(GelbooruFavoriteStatus status) => throwsA(
  isA<GelbooruFavoriteException>().having(
    (error) => error.status,
    'status',
    status,
  ),
);

ResponseBody _favorites(
  List<int> posts, {
  bool hasNext = false,
  bool signedIn = true,
}) => ResponseBody.fromString('''
<!doctype html>
<html><body>
${signedIn ? '<a href="/index.php?page=account&s=logout">Logout</a>' : ''}
<script>var posts = {};</script>
${posts.map((id) => '<span class="thumb"><a href="/index.php?page=post&s=view&id=$id">Post</a></span>').join()}
<div id="paginator">
${hasNext ? '<a href="/index.php?page=favorites&s=view&id=42&pid=50">Next</a>' : ''}
</div>
</body></html>
''', 200);

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
