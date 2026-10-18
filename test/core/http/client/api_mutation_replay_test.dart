import 'dart:typed_data';

import 'package:booru_clients/core.dart';
import 'package:booru_clients/gelbooru.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/http/client/src/interceptors/dio_protection_interceptor.dart';
import 'package:coreutils/coreutils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Physical exchanges terminate in controlled adapters; no test contacts a site.
void main() {
  group('mutation classification takes precedence over read hints', () {
    final cases = <String, Map<String, dynamic>>{
      'coreutils marker': {...stateChangingRequestExtra},
      'legacy marker': {apiMutationRequestKey: true},
      'explicit mutation context': {
        apiRequestContextKey: const ApiRequestContext(
          replaySafety: ApiReplaySafety.mutation,
        ),
      },
      'coreutils marker with safe context': {
        ...stateChangingRequestExtra,
        apiRequestContextKey: const ApiRequestContext(
          replaySafety: ApiReplaySafety.safeRead,
        ),
      },
    };
    for (final entry in cases.entries) {
      for (final method in ['GET', 'HEAD']) {
        test('${entry.key} overrides $method and explicit safe-read hint', () {
          final options = RequestOptions(
            baseUrl: 'https://review.invalid/booru/',
            path: 'https://review.invalid/index.php?page=favorites&s=delete&id=17',
            method: method,
            extra: {...entry.value, apiSafeReadRequestKey: true},
          );
          expect(isApiSafeRead(options), isFalse);
          expect(
            challengeUriFor(options).toString(),
            'https://review.invalid/booru/',
          );
        });
      }
    }
  });

  for (final type in [
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  ]) {
    for (final remove in [false, true]) {
      test(
        'actual Gelbooru ${remove ? 'remove' : 'add'} favorite is dispatched '
        'once when its response fails with ${type.name}',
        () async {
          final coordinator = ApiRequestCoordinator();
          addTearDown(coordinator.dispose);
          final transport = _FirstExchangeFails(type);
          final dio = Dio(BaseOptions(baseUrl: 'https://review.invalid'))
            ..httpClientAdapter = transport;
          coordinateApiDio(dio, coordinator);
          addTearDown(() => dio.close(force: true));
          final client = GelbooruClient.custom(
            baseUrl: 'https://review.invalid',
            dio: dio,
            login: 'fixture-user',
            passHash: 'fixture-session',
          );

          Object? failure;
          try {
            if (remove) {
              await client.removeFavorite(postId: 17);
            } else {
              await client.addFavorite(postId: 17);
            }
          } catch (error) {
            failure = error;
          }

          expect(
            transport.requests,
            hasLength(1),
            reason:
                'An ambiguous mutation response must reach its caller '
                'without an automatic second physical mutation.',
          );
          expect(
            failure,
            isA<DioException>().having((error) => error.type, 'type', type),
          );
          final request = transport.requests.single;
          expect(request.method, 'GET');
          expect(
            request.uri.path,
            remove ? '/index.php' : '/public/addfav.php',
          );
          expect(request.uri.queryParameters['id'], '17');
          expect(
            coordinator.snapshot(ApiQuotaKey.fromUri(request.uri)).inFlight,
            0,
          );
        },
      );
    }
  }
  for (final type in [
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  ]) {
    test('Rule34 upvote never replays after ${type.name}', () async {
      final coordinator = ApiRequestCoordinator();
      addTearDown(coordinator.dispose);
      final transport = _FirstExchangeFails(type);
      final dio = Dio(BaseOptions(baseUrl: 'https://rule34.xxx'))
        ..httpClientAdapter = transport;
      addTearDown(() => dio.close(force: true));
      coordinateApiDio(dio, coordinator);
      final client = _rule34Client(dio);
      await expectLater(
        client.upvote(postId: 17, commentId: 23),
        throwsA(
          isA<GelbooruCommentActionException>().having(
            (e) => e.cause,
            'transport failure',
            isA<DioException>().having((e) => e.type, 'type', type),
          ),
        ),
      );
      expect(transport.requests, hasLength(1));
      final request = transport.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.queryParameters, {
        'page': 'comment',
        's': 'vote',
        'vote': 'up',
        'id': '17',
        'cid': '23',
      });
      expect(request.headers['Cookie'], contains('user_id=fixture-user'));
    });
  }

  test(
    'authentication rejection returns to the favorite caller without replay',
    () async {
      final coordinator = ApiRequestCoordinator();
      addTearDown(coordinator.dispose);
      final transport = _Unauthorized();
      final dio = Dio(BaseOptions(baseUrl: 'https://review.invalid'))
        ..httpClientAdapter = transport;
      addTearDown(() => dio.close(force: true));
      coordinateApiDio(dio, coordinator);
      final client = GelbooruClient.custom(
        baseUrl: 'https://review.invalid',
        dio: dio,
        login: 'fixture-user',
        passHash: 'fixture-session',
      );
      await expectLater(
        client.addFavorite(postId: 17),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            401,
          ),
        ),
      );
      expect(transport.requests, hasLength(1));
    },
  );
}

GelbooruCommentActionClient _rule34Client(Dio dio) =>
    GelbooruCommentActionClient(
      dio: dio,
      baseUrl: 'https://rule34.xxx',
      userId: 'fixture-user',
      passHash: 'fixture-session',
      actions: {
        'upvote': FeatureActionEndpoint(
          name: 'upvote',
          method: ActionRequestMethod.get,
          path: '/index.php',
          auth: ActionAuthMode.sessionCookie,
          responseType: ActionResponseType.integer,
          fixedParams: const {'page': 'comment', 's': 'vote', 'vote': 'up'},
          paramMappings: const {P.postId: 'id', P.commentId: 'cid'},
        ),
      },
    );

final class _Unauthorized implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString('Authentication required', 401);
  }

  @override
  void close({bool force = false}) {}
}

final class _FirstExchangeFails implements HttpClientAdapter {
  _FirstExchangeFails(this.failureType);

  final DioExceptionType failureType;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requests.length == 1) {
      // The server may already have committed the mutation. A response failure
      // does not prove that repeating it is safe.
      throw DioException(
        requestOptions: options,
        type: failureType,
        message: 'Controlled response failure after physical dispatch',
      );
    }
    // Bound the failure fixture: a mistaken retry succeeds rather than looping.
    return ResponseBody.fromString(
      options.uri.path == '/public/addfav.php' ? '3' : '',
      200,
      headers: {
        Headers.contentTypeHeader: ['text/plain'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
