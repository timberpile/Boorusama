// Dart imports:
import 'dart:async';
import 'dart:typed_data';

// Flutter imports:
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:coreutils/coreutils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/ddos/handler/protection_handler.dart';
import 'package:boorusama/core/ddos/solver/src/protection_detector.dart';
import 'package:boorusama/core/ddos/solver/src/protection_orchestrator.dart';
import 'package:boorusama/core/ddos/solver/src/protection_solver.dart';
import 'package:boorusama/core/ddos/solver/src/user_agent_provider.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/http/client/src/interceptors/dio_protection_interceptor.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/http/client/src/types/http_utils.dart';

const _challengePage = '''
<html><title>Just a moment...</title>
<script src="https://challenges.cloudflare.com/turnstile"></script></html>
''';
const _deniedPage = '<html><title>403 Access denied</title></html>';

void main() {
  test(
    'bulk maintenance does not launch verification or replay a challenge response',
    () async {
      final fixture = _Fixture([
        const _Response(403, _challengePage),
        const _Response(200, 'posts'),
      ]);
      await expectLater(
        runWithApiRequestContext(
          const ApiRequestContext(requestClass: ApiRequestClass.bulkTransfer),
          () => fixture.dio.get<String>('/index.php?page=dapi&s=post&q=index'),
        ),
        throwsA(isA<DioException>()),
      );
      expect(fixture.adapter.requestCount, 1);
    },
  );

  test(
    'a solved startup challenge replays the request with clearance',
    () async {
      final fixture = _Fixture([
        const _Response(403, _challengePage),
        const _Response(200, 'posts'),
      ]);

      final response = await fixture.dio.get<String>(
        '/index.php?page=dapi&s=post&q=index',
      );

      expect(response.data, 'posts');
      expect(fixture.adapter.requestCount, 2);
      expect(fixture.adapter.sawClearanceOnRequest, [false, true]);
      expect(fixture.solver.solveCount, 1);
    },
  );

  test('a transient denied replay recovers without manual refresh', () async {
    final fixture = _Fixture([
      const _Response(403, _challengePage),
      const _Response(403, _deniedPage),
      const _Response(200, 'posts'),
    ]);

    final response = await fixture.dio.get<String>(
      '/index.php?page=dapi&s=post&q=index',
    );

    expect(response.data, 'posts');
    expect(fixture.adapter.requestCount, 3);
    expect(fixture.solver.solveCount, 1);
  });

  test(
    'persistent denied replay exposes final error and manual retry works',
    () async {
      final fixture = _Fixture([
        const _Response(403, _challengePage),
        const _Response(403, _deniedPage),
        const _Response(403, '<html>Still denied</html>'),
        const _Response(200, 'posts'),
      ]);

      final result = await tryFetchRemoteData(
        fetcher: () => fixture.dio.get<String>(
          '/index.php?page=dapi&s=post&q=index',
        ),
      ).run();
      final error = result.fold((error) => error, (_) => null);

      expect(error, isA<ServerError>());
      expect((error! as ServerError).httpStatusCode, 403);
      expect(error.message, '<html>Still denied</html>');
      expect(fixture.adapter.requestCount, 3);
      expect(fixture.solver.solveCount, 1);

      final manual = await fixture.dio.get<String>(
        '/index.php?page=dapi&s=post&q=index',
      );
      expect(manual.data, 'posts');
      expect(fixture.adapter.requestCount, 4);
    },
  );

  test('another site does not receive a delayed request', () async {
    final fixture = _Fixture([
      const _Response(403, _challengePage),
      const _Response(403, _deniedPage),
    ], baseUrl: 'https://example.com');

    final result = await tryFetchRemoteData(
      fetcher: () => fixture.dio.get<String>(
        '/index.php?page=dapi&s=post&q=index',
      ),
    ).run();

    expect(result.fold((error) => error, (_) => null), isA<ServerError>());
    expect(fixture.adapter.requestCount, 2);
  });

  test('a mutation never replays after protection handling', () async {
    final fixture = _Fixture([
      const _Response(403, _challengePage),
      const _Response(403, _deniedPage),
    ]);

    final result = await tryFetchRemoteData(
      fetcher: () => fixture.dio.post<String>(
        '/index.php?page=dapi&s=post&q=index',
      ),
    ).run();

    expect(result.fold((error) => error, (_) => null), isA<ServerError>());
    expect(fixture.adapter.requestCount, 1);
  });

  test('cancellation during the delay prevents another request', () async {
    final fixture = _Fixture([
      const _Response(403, _challengePage),
      const _Response(403, _deniedPage),
      const _Response(200, 'posts'),
    ]);
    final token = CancelToken();

    final request = fixture.dio.get<String>(
      '/index.php?page=dapi&s=post&q=index',
      cancelToken: token,
    );
    await fixture.adapter.secondRequestDelivered.future;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(fixture.adapter.requestCount, 2);
    token.cancel();

    await expectLater(
      request,
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    expect(fixture.adapter.requestCount, 2);
  });
}

class _Fixture {
  _Fixture(List<_Response> responses, {String baseUrl = 'https://rule34.xxx'}) {
    dio.options.baseUrl = baseUrl;
    dio.options.responseType = ResponseType.plain;
    adapter = _SequenceAdapter(responses);
    dio.httpClientAdapter = adapter;
    solver = _ClearanceSolver(cookieJar);
    dio.interceptors.add(
      DioProtectionInterceptor(
        dio: dio,
        protectionHandler: HttpProtectionHandler(
          orchestrator: ProtectionOrchestrator(
            detectors: [CloudflareDetector()],
            solvers: [solver],
            userAgentProvider: _TestUserAgent(),
          ),
          contextProvider: _TestBuildContext.new,
          cookieJar: LazyAsync<CookieJar>(() async => cookieJar),
        ),
      ),
    );
  }

  final dio = Dio();
  final cookieJar = _MemoryCookieJar();
  late final _SequenceAdapter adapter;
  late final _ClearanceSolver solver;
}

class _Response {
  const _Response(this.status, this.body);
  final int status;
  final String body;
}

class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this.responses);

  final List<_Response> responses;
  final sawClearanceOnRequest = <bool>[];
  final secondRequestDelivered = Completer<void>();
  var requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sawClearanceOnRequest.add(
      options.headers.values.any(
        (value) => RegExp(
          r'(?:^|;)\s*cf_clearance=',
          caseSensitive: false,
        ).hasMatch(value.toString()),
      ),
    );
    final response = responses[requestCount++];
    if (requestCount == 2) secondRequestDelivered.complete();
    return ResponseBody.fromString(
      response.body,
      response.status,
      headers: {
        Headers.contentTypeHeader: ['text/plain'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ClearanceSolver implements ProtectionSolver {
  _ClearanceSolver(this.jar);
  final _MemoryCookieJar jar;
  var solveCount = 0;

  @override
  String get protectionType => 'cloudflare';
  @override
  bool get isSolving => false;
  @override
  Future<void> cancel() async {}

  @override
  Future<bool> solve({required Uri uri, String? userAgent}) async {
    solveCount++;
    await jar.saveFromResponse(uri, [Cookie('cf_clearance', 'test')]);
    return true;
  }
}

class _TestUserAgent implements UserAgentProvider {
  @override
  Future<String?> getUserAgent() async => 'TestAgent/1.0';
}

class _TestBuildContext extends Fake implements BuildContext {}

class _MemoryCookieJar implements CookieJar {
  final saved = <Uri, List<Cookie>>{};

  @override
  bool get ignoreExpires => false;

  @override
  Future<void> saveFromResponse(Uri uri, List<Cookie> cookies) async {
    saved[uri] = cookies;
  }

  @override
  Future<List<Cookie>> loadForRequest(Uri uri) async => saved[uri] ?? [];

  @override
  Future<void> delete(Uri uri, [bool withDomainSharedCookie = false]) async {
    saved.remove(uri);
  }

  @override
  Future<void> deleteAll() async => saved.clear();
}
