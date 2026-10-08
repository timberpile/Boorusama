import 'dart:typed_data';

import 'package:boorusama/core/http/client/coordination.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'physical Danbooru GET mutations and safe POST reads use explicit replay safety',
    () async {
      final c = ApiRequestCoordinator();
      addTearDown(c.dispose);
      final transport = _Transport();
      final dio = Dio(BaseOptions(baseUrl: 'https://danbooru.donmai.us'))
        ..httpClientAdapter = transport;
      coordinateApiDio(dio, c);
      await dio.get(
        '/favorite',
        options: Options(extra: {apiMutationRequestKey: true}),
      );
      final token = CancelToken();
      final write = dio.get(
        '/favorite',
        cancelToken: token,
        options: Options(extra: {apiMutationRequestKey: true}),
      );
      final cancelled = expectLater(write, throwsA(isA<DioException>()));
      await _settle();
      expect(transport.calls, ['GET /favorite']);
      await dio.post(
        '/read',
        options: Options(extra: {apiSafeReadRequestKey: true}),
      );
      expect(transport.calls, ['GET /favorite', 'POST /read']);
      token.cancel();
      await cancelled;
      expect(
        c
            .snapshot(
              ApiQuotaKey.fromUri(Uri.parse('https://danbooru.donmai.us')),
            )
            .inFlight,
        0,
      );
    },
  );

  test(
    'redirected Zerochan reads share the www sixty-start budget and isolate cancelled waiters',
    () async {
      final c = ApiRequestCoordinator();
      addTearDown(c.dispose);
      final transport = _Transport(redirect: true);
      final dio = Dio(BaseOptions(baseUrl: 'https://zerochan.net'))
        ..httpClientAdapter = transport;
      coordinateApiDio(dio, c);
      for (var i = 0; i < 60; i++) {
        await dio.get('/data');
      }
      expect(transport.calls.where((s) => s == 'GET /result'), hasLength(60));
      final token = CancelToken();
      final wait = dio.get('/data', cancelToken: token);
      final cancelled = expectLater(wait, throwsA(isA<DioException>()));
      await _settle();
      final target = ApiQuotaKey.fromUri(Uri.parse('https://www.zerochan.net'));
      expect(c.snapshot(target).queued, 1);
      expect(c.snapshot(target).waiting[ApiWaitReason.serverWindow], 1);
      expect(
        c
            .snapshot(ApiQuotaKey.fromUri(Uri.parse('https://zerochan.net')))
            .inFlight,
        0,
      );
      token.cancel();
      await cancelled;
      expect(c.snapshot(target).queued, 0);
      expect(transport.calls.where((s) => s == 'GET /result'), hasLength(60));
    },
  );

  test(
    'unavailable speculative status drops immediately while explicit status can wait and recover',
    () async {
      final c = ApiRequestCoordinator();
      addTearDown(c.dispose);
      final key = ApiQuotaKey.fromUri(Uri.parse('https://unknown.test'));
      final held = await Future.wait(List.generate(4, (_) => c.acquire(key)));
      final transport = _Transport();
      final dio = Dio(BaseOptions(baseUrl: 'https://unknown.test'))
        ..httpClientAdapter = transport;
      coordinateApiDio(dio, c);
      await expectLater(
        runWithApiRequestContext(
          const ApiRequestContext(
            requestClass: ApiRequestClass.preload,
            admissionBehavior: ApiAdmissionBehavior.dropIfUnavailable,
          ),
          () => dio.get('/status'),
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'typed deferral',
            isA<ApiRequestDeferredException>(),
          ),
        ),
      );
      expect(c.snapshot(key).queued, 0);
      expect(transport.calls, isEmpty);
      final explicit = dio.get('/status');
      await _settle();
      expect(c.snapshot(key).queued, 1);
      held.first.release();
      await explicit;
      expect(transport.calls, ['GET /status']);
      for (final p in held.skip(1)) {
        p.release();
      }
      expect(c.snapshot(key).inFlight, 0);
    },
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Transport implements HttpClientAdapter {
  _Transport({this.redirect = false});
  final bool redirect;
  final calls = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add('${options.method} ${options.uri.path}');
    if (redirect && options.uri.host == 'zerochan.net') {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['https://www.zerochan.net/result'],
        },
      );
    }
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}
