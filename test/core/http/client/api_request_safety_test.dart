import 'dart:async';
import 'dart:typed_data';
import 'package:booru_clients/shimmie2.dart';
import 'package:booru_clients/nozomi.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/http/client/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

void main() {
  test(
    'manual auth owner promotes the original queued exchange while active work remains',
    () async {
      final c = ApiRequestCoordinator();
      final registry = ApiAuthRefreshRegistry();
      final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
      final active = await c.acquire(key);
      final passive = [
        for (var i = 0; i < 2; i++)
          await c.acquire(
            key,
            context: const ApiRequestContext(
              requestClass: ApiRequestClass.automatic,
            ),
          ),
      ];
      var starts = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = _Responses((_) async {
          starts++;
          return ResponseBody.fromString('', 200);
        });
      coordinateApiDio(dio, c);
      final automatic = runWithApiRequestContext(
        const ApiRequestContext(requestClass: ApiRequestClass.automatic),
        () => registry.run('account', () => dio.post('/refresh')),
      );
      while (c.snapshot(key).queued == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final manual = runWithApiRequestContext(
        const ApiRequestContext(requestClass: ApiRequestClass.userInitiated),
        () => registry.run('account', () => dio.post('/duplicate')),
      );
      await Future.wait([
        automatic,
        manual,
      ]).timeout(const Duration(seconds: 2));
      expect(starts, 1);
      active.release();
      for (final permit in passive) {
        permit.release();
      }
      c.dispose();
    },
  );

  test(
    'a late manual owner interrupts a pending brief cooldown without replay',
    () async {
      final c = ApiRequestCoordinator();
      final changes = StreamController<void>.broadcast(sync: true);
      var manual = false;
      var starts = 0;
      final response = Completer<void>();
      final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = _Responses((_) async {
          starts++;
          response.complete();
          return ResponseBody.fromString(
            '',
            429,
            headers: {
              'retry-after': ['1'],
            },
          );
        });
      coordinateApiDio(dio, c);
      final request = runWithApiRequestContext(
        ApiRequestContext(
          allowCooldownRetryResolver: () => !manual,
          changes: changes.stream,
        ),
        () => dio.get('/read'),
      );
      final assertion = expectLater(
        request,
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'typed cooldown',
            isA<ApiCooldownException>(),
          ),
        ),
      );
      await response.future;
      while (c
              .snapshot(ApiQuotaKey.fromUri(Uri.parse('https://site.test')))
              .retryAt ==
          null) {
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      manual = true;
      changes.add(null);
      await assertion.timeout(const Duration(milliseconds: 250));
      expect(starts, 1);
      await changes.close();
      c.dispose();
    },
  );

  test('all waiters receive a typed auth cooldown without hanging', () async {
    final gate = Completer<void>();
    final joined = Completer<void>();
    var callers = 0;
    final c = ApiRequestCoordinator();
    final retryAt = DateTime.now().toUtc().add(const Duration(minutes: 2));
    final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
    final auth = AutoRefreshAuthInterceptor(
      config: const AutoRefreshAuthConfig(cookieName: 'token'),
      baseUrl: 'https://site.test',
      refreshToken: 'old',
      onRefresh: (_) async {
        await gate.future;
        throw DioException(
          requestOptions: RequestOptions(path: '/refresh'),
          error: ApiCooldownException(key, retryAt),
        );
      },
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
      ..httpClientAdapter = _Responses(
        (_) async => ResponseBody.fromString('', 200),
      );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          if (++callers == 2) joined.complete();
          h.next(o);
        },
      ),
    );
    dio.interceptors.add(auth);
    auth.attach(dio);
    coordinateApiDio(dio, c);
    Future<Object?> request() async {
      try {
        await dio.get('/data');
        return null;
      } catch (e) {
        return e;
      }
    }

    final first = request();
    final second = request();
    await joined.future;
    gate.complete();
    final results = await Future.wait([
      first,
      second,
    ]).timeout(const Duration(seconds: 2));
    expect(
      results.every(
        (e) => e is DioException && e.error is ApiCooldownException,
      ),
      true,
    );
    c.dispose();
  });

  test(
    'shared auth failures reach callers in distinct interceptor error zones',
    () async {
      final registry = ApiAuthRefreshRegistry();
      late Completer<int> refresh;
      final first = Completer<Object>();
      final second = Completer<Object>();
      runZonedGuarded(() {
        registry
            .run<int>('account', () => (refresh = Completer<int>()).future)
            .then(
              (_) {},
              onError: (Object e) {
                first.complete(e);
              },
            );
      }, (e, _) {});
      runZonedGuarded(() {
        registry
            .run<int>('account', () => Future.value(99))
            .then(
              (_) {},
              onError: (Object e) {
                second.complete(e);
              },
            );
      }, (e, _) {});
      refresh.completeError(StateError('refresh failed'));
      final errors = await Future.wait([
        first.future,
        second.future,
      ]).timeout(const Duration(seconds: 2));
      expect(errors.every((e) => e is StateError), true);
    },
  );

  test(
    'queued passive auth cannot start after all lifecycle guards become invalid',
    () async {
      final c = ApiRequestCoordinator();
      final registry = ApiAuthRefreshRegistry();
      final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
      final held = await Future.wait(List.generate(4, (_) => c.acquire(key)));
      var foreground = true;
      var starts = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = _Responses((_) async {
          starts++;
          return ResponseBody.fromString('', 200);
        });
      coordinateApiDio(dio, c);
      final operation = runWithApiRequestContext(
        ApiRequestContext(
          requestClass: ApiRequestClass.automatic,
          canStart: () => foreground,
        ),
        () => registry.run('account', () => dio.post('/refresh')),
      );
      final assertion = expectLater(operation, throwsA(isA<DioException>()));
      while (c.snapshot(key).queued == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      foreground = false;
      for (final p in held) {
        p.abandon();
      }
      await assertion.timeout(const Duration(seconds: 2));
      expect(starts, 0);
      expect(c.snapshot(key).queued, 0);
      c.dispose();
    },
  );

  test(
    'explicit Dio cancellation removes all owners of a queued auth exchange',
    () async {
      final c = ApiRequestCoordinator();
      final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
      final held = await Future.wait(List.generate(4, (_) => c.acquire(key)));
      var starts = 0;
      var failedCredentials = 0;
      var waiters = 0;
      final joined = Completer<void>();
      final tokenDio = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = _Responses((_) async {
          starts++;
          return ResponseBody.fromString('', 200);
        });
      coordinateApiDio(tokenDio, c);
      final auth = AutoRefreshAuthInterceptor(
        config: const AutoRefreshAuthConfig(cookieName: 'token'),
        baseUrl: 'https://site.test',
        refreshToken: 'old',
        onAuthFailed: () => failedCredentials++,
        onRefresh: (_) async {
          await tokenDio.post('/refresh');
          return const AuthTokenPair(accessToken: 'new', refreshToken: 'next');
        },
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = _Responses(
          (_) async => ResponseBody.fromString('', 200),
        );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            if (++waiters == 2) joined.complete();
            h.next(o);
          },
        ),
      );
      dio.interceptors.add(auth);
      auth.attach(dio);
      coordinateApiDio(dio, c);
      final first = CancelToken();
      final second = CancelToken();
      final assertions = [
        expectLater(
          dio.get('/one', cancelToken: first),
          throwsA(isA<DioException>()),
        ),
        expectLater(
          dio.get('/two', cancelToken: second),
          throwsA(isA<DioException>()),
        ),
      ];
      await joined.future;
      await Future<void>.delayed(Duration.zero);
      first.cancel();
      second.cancel();
      await Future.wait(assertions);
      for (final p in held) {
        p.release();
      }
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(starts, 0);
      expect(failedCredentials, 0);
      expect(c.snapshot(key).queued, 0);
      c.dispose();
    },
  );

  test(
    'last owner cancels queued auth while dispatched rotation finishes',
    () async {
      final registry = ApiAuthRefreshRegistry();
      final c = ApiRequestCoordinator();
      final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
      final held = await Future.wait(List.generate(4, (_) => c.acquire(key)));
      final entered = Completer<void>();
      var starts = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = _Responses((_) async {
          starts++;
          return ResponseBody.fromString('', 200);
        });
      coordinateApiDio(dio, c);
      final tokens = [CancelToken(), CancelToken()];
      Future<int> owner(CancelToken token) => runWithApiRequestContext(
        ApiRequestContext(
          requestClass: ApiRequestClass.automatic,
          cancelToken: token,
        ),
        () => registry.run('account', () async {
          entered.complete();
          await dio.post('/refresh');
          return 1;
        }),
      );
      final first = owner(tokens.first);
      final second = owner(tokens.last);
      final assertions = [
        expectLater(first, throwsA(isA<DioException>())),
        expectLater(second, throwsA(isA<DioException>())),
      ];
      await entered.future;
      await Future<void>.delayed(Duration.zero);
      tokens.first.cancel();
      expect(starts, 0);
      tokens.last.cancel();
      await Future.wait(assertions);
      for (final p in held) {
        p.release();
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(starts, 0);
      expect(c.snapshot(key).queued, 0);
      c.dispose();
    },
  );

  test(
    'cancelling one auth waiter leaves the shared token transport alive',
    () async {
      final registry = ApiAuthRefreshRegistry();
      final c = ApiRequestCoordinator(
        policy: (_) => ApiQuotaPolicy.buffered(
          sourceWindows: const [
            ApiStartWindow(capacity: 100, duration: Duration(minutes: 1)),
          ],
        ),
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      final joined = Completer<void>();
      var waiters = 0;
      var tokenStarts = 0;
      final tokenDio = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = _Responses((o) async {
          tokenStarts++;
          expect(o.cancelToken, isNotNull);
          entered.complete();
          await release.future;
          return ResponseBody.fromString('', 200);
        });
      coordinateApiDio(tokenDio, c);
      Dio client() {
        final auth = AutoRefreshAuthInterceptor(
          config: const AutoRefreshAuthConfig(cookieName: 'token'),
          baseUrl: 'https://site.test',
          refreshToken: 'old',
          onRefresh: (_) {
            if (++waiters == 2) joined.complete();
            return registry.run('account', () async {
              await tokenDio.post('/refresh');
              return const AuthTokenPair(
                accessToken: 'new',
                refreshToken: 'next',
              );
            });
          },
        );
        final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
          ..httpClientAdapter = _Responses(
            (_) async => ResponseBody.fromString('', 200),
          );
        dio.interceptors.add(auth);
        auth.attach(dio);
        coordinateApiDio(dio, c);
        return dio;
      }

      final token = CancelToken();
      final first = runWithApiRequestContext(
        ApiRequestContext(cancelToken: token),
        () => client().get('/first'),
      );
      final failed = expectLater(first, throwsA(isA<DioException>()));
      await entered.future;
      final second = client().get('/second');
      await joined.future;
      token.cancel();
      await failed;
      expect(tokenStarts, 1);
      release.complete();
      await second.timeout(const Duration(seconds: 2));
      expect(tokenStarts, 1);
      c.dispose();
    },
  );

  test(
    'Shimmie favorite mutations never replay after token rejection',
    () async {
      var mutations = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = _Responses((o) async {
          if (o.method == 'GET') {
            return ResponseBody.fromString(
              "<input name='auth_token' value='token'>",
              200,
            );
          }
          mutations++;
          return ResponseBody.fromString('', mutations == 1 ? 403 : 200);
        });
      final success = await Shimmie2Client(
        dio: dio,
        baseUrl: 'https://site.test',
        username: 'user',
      ).addFavorite(postId: 1);
      expect(mutations, 1);
      expect(success, false);
    },
  );

  test(
    'repeated Pixiv rate envelopes escalate instead of counting as success',
    () async {
      var elapsed = Duration.zero;
      final wall = DateTime.now().toUtc();
      final c = ApiRequestCoordinator(
        elapsed: () => elapsed,
        now: () => wall.add(elapsed),
        jitter: () => 0,
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://app-api.pixiv.net'))
        ..httpClientAdapter = _Responses(
          (_) async => ResponseBody.fromString(
            '{"error":{"message":"Rate Limit"}}',
            200,
            headers: {
              'content-type': ['application/json'],
            },
          ),
        );
      coordinateApiDio(dio, c);
      final key = ApiQuotaKey.fromUri(Uri.parse('https://app-api.pixiv.net'));
      await expectLater(dio.get('/read'), throwsA(isA<DioException>()));
      expect(c.snapshot(key).retryAt, wall.add(const Duration(seconds: 30)));
      elapsed = const Duration(seconds: 31);
      await expectLater(dio.get('/read'), throwsA(isA<DioException>()));
      expect(c.snapshot(key).retryAt, wall.add(const Duration(seconds: 151)));
      c.dispose();
    },
  );

  test(
    'redirects count target origin and strip original query and credentials',
    () async {
      final requests = <RequestOptions>[];
      final c = ApiRequestCoordinator();
      final dio =
          Dio(
              BaseOptions(
                baseUrl: 'https://site.test',
                headers: {'Authorization': 'secret', 'Cookie': 'secret'},
              ),
            )
            ..httpClientAdapter = _Responses((o) async {
              requests.add(o);
              return requests.length == 1
                  ? ResponseBody.fromString(
                      '',
                      302,
                      headers: {
                        'location': ['https://other.test/final?public=yes'],
                      },
                    )
                  : ResponseBody.fromString('ok', 200);
            });
      coordinateApiDio(dio, c);
      await dio.get(
        '/first',
        queryParameters: {'api_key': 'secret', 'tags': 'private'},
      );
      expect(requests.length, 2);
      expect(
        requests.last.uri.toString(),
        'https://other.test/final?public=yes',
      );
      expect(
        requests.last.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(
        requests.last.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('cookie')),
      );
      expect(requests.every((o) => !o.followRedirects), true);
      expect(
        c
            .snapshot(ApiQuotaKey.fromUri(Uri.parse('https://other.test')))
            .inFlight,
        0,
      );
      c.dispose();
    },
  );

  test('safe POST redirects do not reuse a consumed request stream', () async {
    var starts = 0;
    final c = ApiRequestCoordinator();
    final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
      ..httpClientAdapter = _Responses((_) async {
        starts++;
        return ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': ['/other'],
          },
        );
      });
    coordinateApiDio(dio, c);
    await expectLater(
      dio.post(
        '/graphql',
        data: {'query': 'query'},
        options: Options(extra: {apiSafeReadRequestKey: true}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(starts, 1);
    c.dispose();
  });

  test(
    'lazy tasks keep isolated request classes across concurrent scopes',
    () async {
      final seen = <String, ApiRequestClass>{};
      final c = ApiRequestCoordinator();
      final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = _Responses((o) async {
          seen[o.path] =
              (o.extra[apiRequestContextKey] as ApiRequestContext).requestClass;
          return ResponseBody.fromString('ok', 200);
        });
      coordinateApiDio(dio, c);
      final task = TaskEither<Object, Response>.tryCatch(
        () => dio.get('/lazy'),
        (e, _) => e,
      );
      await Future.wait([
        runWithApiRequestContext(
          const ApiRequestContext(requestClass: ApiRequestClass.automatic),
          task.run,
        ),
        runWithApiRequestContext(
          const ApiRequestContext(requestClass: ApiRequestClass.userInitiated),
          () => dio.get('/manual'),
        ),
      ]);
      expect(seen['/lazy'], ApiRequestClass.automatic);
      expect(seen['/manual'], ApiRequestClass.userInitiated);
      c.dispose();
    },
  );

  test(
    'cancelled transport retains its permit until cancellation is acknowledged',
    () async {
      final entered = Completer<void>();
      final ack = Completer<void>();
      final c = ApiRequestCoordinator();
      final token = CancelToken();
      final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = _Responses((o) async {
          entered.complete();
          await ack.future;
          throw token.cancelError!;
        });
      coordinateApiDio(dio, c);
      final request = dio.get('/read', cancelToken: token);
      final assertion = expectLater(request, throwsA(isA<DioException>()));
      await entered.future;
      token.cancel();
      await assertion;
      final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
      expect(c.snapshot(key).inFlight, 1);
      ack.complete();
      await Future<void>.delayed(Duration.zero);
      expect(c.snapshot(key).inFlight, 0);
      c.dispose();
    },
  );

  test(
    'Nozomi binary indexes and absolute JSON use their actual data origins',
    () async {
      final c = ApiRequestCoordinator();
      final seen = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://bookmark-alias.test'))
        ..httpClientAdapter = _Responses((o) async {
          seen.add(o);
          expect(c.snapshot(ApiQuotaKey.fromUri(o.uri)).inFlight, 1);
          if (o.responseType == ResponseType.bytes) {
            final data = ByteData(4)..setUint32(0, 17);
            return ResponseBody.fromBytes(
              data.buffer.asUint8List(),
              206,
              headers: {
                'content-range': ['bytes 0-3/4'],
              },
            );
          }
          return ResponseBody.fromString(
            '{}',
            200,
            headers: {
              'content-type': ['application/json'],
            },
          );
        });
      coordinateApiDio(dio, c);
      final client = NozomiClient(dio: dio);
      expect(await client.getPostIds(limit: 1), [17]);
      await client.getPost(id: 17);
      expect(seen.map((o) => o.uri.host), [
        'n.nozomi.la',
        'j.gold-usergeneratedcontent.net',
      ]);
      for (final o in seen) {
        expect(o.extra[apiMediaRequestKey], isNot(true));
      }
      expect(
        c
            .snapshot(
              ApiQuotaKey.fromUri(Uri.parse('https://bookmark-alias.test')),
            )
            .inFlight,
        0,
      );
      c.dispose();
    },
  );

  test(
    'four simultaneous 401 responses release permits before nested auth retry',
    () async {
      var refreshes = 0;
      var initial = 0;
      final allInitial = Completer<void>();
      final c = ApiRequestCoordinator(
        policy: (_) => ApiQuotaPolicy.buffered(
          sourceWindows: const [
            ApiStartWindow(capacity: 100, duration: Duration(minutes: 1)),
          ],
        ),
      );
      final tokenDio = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = _Responses((_) async {
          expect(
            c
                .snapshot(ApiQuotaKey.fromUri(Uri.parse('https://site.test')))
                .inFlight,
            lessThanOrEqualTo(4),
          );
          return ResponseBody.fromString('', 200);
        });
      coordinateApiDio(tokenDio, c);
      final auth = AutoRefreshAuthInterceptor(
        config: const AutoRefreshAuthConfig(cookieName: 'token'),
        baseUrl: 'https://site.test',
        refreshToken: 'old',
        onRefresh: (_) async {
          refreshes++;
          await tokenDio.post('/refresh');
          return const AuthTokenPair(accessToken: 'new', refreshToken: 'next');
        },
      )..setAccessToken('old');
      final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = _Responses((o) async {
          if (o.extra[apiNegotiatedKey] == true) {
            return ResponseBody.fromString('', 200);
          }
          if (++initial == 4) allInitial.complete();
          await allInitial.future;
          return ResponseBody.fromString('', 401);
        });
      dio.interceptors.add(auth);
      auth.attach(dio);
      coordinateApiDio(dio, c);
      await Future.wait(
        List.generate(4, (_) => dio.get('/data')),
      ).timeout(const Duration(seconds: 3));
      expect(refreshes, 1);
      expect(
        c
            .snapshot(ApiQuotaKey.fromUri(Uri.parse('https://site.test')))
            .inFlight,
        0,
      );
      c.dispose();
    },
  );

  test(
    'four same-origin requests refresh auth without occupying data permits',
    () async {
      var refreshes = 0;
      final c = ApiRequestCoordinator(
        policy: (_) => ApiQuotaPolicy.buffered(
          sourceWindows: const [
            ApiStartWindow(capacity: 100, duration: Duration(minutes: 1)),
          ],
        ),
      );
      final tokenDio = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = _Responses(
          (_) async => ResponseBody.fromString('', 200),
        );
      coordinateApiDio(tokenDio, c);
      final auth = AutoRefreshAuthInterceptor(
        config: const AutoRefreshAuthConfig(cookieName: 'token'),
        baseUrl: 'https://site.test',
        refreshToken: 'old',
        onRefresh: (_) async {
          refreshes++;
          await tokenDio.post('/refresh');
          return const AuthTokenPair(accessToken: 'new', refreshToken: 'next');
        },
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = _Responses(
          (_) async => ResponseBody.fromString('', 200),
        );
      dio.interceptors.add(auth);
      auth.attach(dio);
      coordinateApiDio(dio, c);
      await Future.wait(
        List.generate(4, (_) => dio.get('/data')),
      ).timeout(const Duration(seconds: 3));
      expect(refreshes, 1);
      expect(
        c
            .snapshot(ApiQuotaKey.fromUri(Uri.parse('https://site.test')))
            .inFlight,
        0,
      );
      c.dispose();
    },
  );
  for (final mutation in [false, true]) {
    test(
      'transient failure ${mutation ? 'does not replay a GET mutation' : 'retries a safe read once'}',
      () async {
        final c = ApiRequestCoordinator();
        var attempts = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
          ..httpClientAdapter = _Responses((o) async {
            if (++attempts == 1) {
              throw DioException(
                requestOptions: o,
                type: DioExceptionType.connectionError,
              );
            }
            return ResponseBody.fromString('', 200);
          });
        coordinateApiDio(dio, c);
        final request = dio.get(
          '/favorite-or-read',
          options: Options(extra: {apiMutationRequestKey: mutation}),
        );
        if (mutation) {
          await expectLater(request, throwsA(isA<DioException>()));
        } else {
          await request;
        }
        expect(attempts, mutation ? 1 : 2);
        c.dispose();
      },
    );
  }
  for (final manual in [false, true]) {
    test(
      '${manual ? 'manual' : 'safe read'} brief cooldown ${manual ? 'returns without delayed replay' : 'retries once'}',
      () async {
        final c = ApiRequestCoordinator();
        var attempts = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
          ..httpClientAdapter = _Responses(
            (_) async => ++attempts == 1
                ? ResponseBody.fromString(
                    '',
                    429,
                    headers: {
                      'retry-after': ['1'],
                    },
                  )
                : ResponseBody.fromString('', 200),
          );
        coordinateApiDio(dio, c);
        final request = runWithApiRequestContext(
          ApiRequestContext(allowCooldownRetry: !manual),
          () => dio.get('/data'),
        );
        if (manual) {
          await expectLater(request, throwsA(isA<DioException>()));
          await Future<void>.delayed(const Duration(milliseconds: 1100));
        } else {
          await request;
        }
        expect(attempts, manual ? 1 : 2);
        c.dispose();
      },
    );
  }

  test(
    'a fresh auth owner replaces an abandoned queued exchange before it settles',
    () async {
      final registry = ApiAuthRefreshRegistry();
      final entered = Completer<void>();
      final release = Completer<void>();
      final token = CancelToken();
      var calls = 0;
      final first = runWithApiRequestContext(
        ApiRequestContext(cancelToken: token),
        () => registry.run('account', () async {
          calls++;
          entered.complete();
          await release.future;
          return 1;
        }),
      );
      final assertion = expectLater(first, throwsA(isA<DioException>()));
      await entered.future;
      token.cancel();
      await assertion;
      expect(
        await registry.run('account', () async {
          calls++;
          return 2;
        }),
        2,
      );
      expect(calls, 2);
      release.complete();
    },
  );
  test(
    'opaque fallback coalesces identical credentials and keeps distinct credentials independent',
    () async {
      final registry = ApiAuthRefreshRegistry();
      final gate = Completer<void>();
      var refreshes = 0;
      Future<int> request(String credential) => registry.run(
        ('unknown-account', registry.opaqueCredentialIdentity(credential)),
        () async {
          final sequence = ++refreshes;
          await gate.future;
          return sequence;
        },
      );
      final first = request('same-credential');
      final second = request('same-credential');
      final other = request('other-credential');
      expect(refreshes, 2);
      gate.complete();
      expect(await Future.wait([first, second, other]), [1, 1, 2]);
      expect(
        registry.opaqueCredentialIdentity('same-credential').toString(),
        isNot(contains('same-credential')),
      );
    },
  );
}

final class _Responses implements HttpClientAdapter {
  _Responses(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}
