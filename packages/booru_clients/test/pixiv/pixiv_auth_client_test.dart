import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'mock_pixiv_server.dart';

void main() {
  group('PixivAuthClient', () {
    late MockPixivServer server;
    late String baseUrl;
    late Dio dio;

    setUp(() async {
      server = MockPixivServer();
      baseUrl = await server.start();
      dio = Dio(BaseOptions(baseUrl: baseUrl));
    });

    tearDown(() async {
      await server.stop();
    });

    // Dio always carries its own built-in ImplyContentTypeInterceptor; the
    // requirement (FIX 1a) is that PixivAuthClient adds nothing on top of
    // that — in particular no logging interceptor, which would print the
    // access/refresh token from a token response into a user-exportable log.
    test('adds no interceptor of its own when it builds its own Dio', () {
      final client = PixivAuthClient();

      expect(client.debugDio.interceptors, hasLength(1));
    });

    test('adds no interceptor of its own to an injected Dio either', () {
      final client = PixivAuthClient(dio: dio);

      expect(client.debugDio.interceptors, hasLength(1));
    });

    test('parses a token response given at the top level', () async {
      server.responseBody = '''
      {
        "access_token": "top-level-access",
        "refresh_token": "top-level-refresh",
        "expires_in": 3600,
        "token_type": "bearer",
        "user": {"id": "42", "name": "Someone", "account": "someone"}
      }
      ''';
      final client = PixivAuthClient(dio: dio);

      final tokens = await client.exchangeCode(
        code: 'code',
        codeVerifier: 'verifier',
      );

      expect(tokens.accessToken, 'top-level-access');
      expect(tokens.refreshToken, 'top-level-refresh');
      expect(tokens.expiresIn, 3600);
      expect(tokens.user?.id, '42');
    });

    test('parses a token response nested under "response"', () async {
      server.responseBody = '''
      {
        "response": {
          "access_token": "nested-access",
          "refresh_token": "nested-refresh",
          "expires_in": 3600,
          "token_type": "bearer",
          "user": {"id": 42, "name": "Someone", "account": "someone"}
        }
      }
      ''';
      final client = PixivAuthClient(dio: dio);

      final tokens = await client.refresh(refreshToken: 'old-refresh');

      expect(tokens.accessToken, 'nested-access');
      expect(tokens.refreshToken, 'nested-refresh');
      // Accepts a numeric user id (nested shape used one here) leniently,
      // even though the API normally returns a string.
      expect(tokens.user?.id, '42');
    });

    test(
      'raises a distinct auth exception for an invalid/expired refresh token',
      () async {
        server.statusCode = 400;
        server.responseBody = '''
      {
        "has_error": true,
        "errors": {"system": {"message": "Invalid refresh token", "code": 1508}},
        "error": "invalid_grant"
      }
      ''';
        final client = PixivAuthClient(dio: dio);

        await expectLater(
          client.refresh(refreshToken: 'stale-refresh'),
          throwsA(isA<PixivAuthException>()),
        );
      },
    );
  });
}
