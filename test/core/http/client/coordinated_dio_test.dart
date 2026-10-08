import 'dart:async';
import 'dart:typed_data';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'counts actual transport starts and retains permits until stream completion',
    () {
      fakeAsync((time) {
        final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
        final a = _Adapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
          ..httpClientAdapter = a;
        coordinateApiDio(dio, c);
        for (var i = 0; i < 5; i++) {
          dio.get('/data');
        }
        _pump(time);
        expect(a.starts, 4);
        time.elapse(const Duration(seconds: 1));
        _pump(time);
        expect(a.starts, 4);
        a.bodies.first.close();
        _pump(time);
        expect(a.starts, 5);
        for (final b in a.bodies.skip(1)) {
          b.close();
        }
        _pump(time);
        expect(
          c
              .snapshot(ApiQuotaKey.fromUri(Uri.parse('https://site.test')))
              .inFlight,
          0,
        );
        c.dispose();
      });
    },
  );

  test(
    'shares cooldown across clients while extensionless media bypasses admission',
    () async {
      final c = ApiRequestCoordinator();
      final a = _Adapter(status: 429, retryAfter: '120', immediate: true);
      final mediaAdapter = _Adapter(immediate: true);
      final first = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = a;
      final second = Dio(BaseOptions(baseUrl: 'https://site.test'))
        ..httpClientAdapter = mediaAdapter;
      coordinateApiDio(first, c);
      coordinateApiDio(second, c);
      await expectLater(
        first.get('/api'),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'cooldown',
            isA<ApiCooldownException>(),
          ),
        ),
      );
      await expectLater(
        second.get('/api'),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'cooldown',
            isA<ApiCooldownException>(),
          ),
        ),
      );
      await second.get(
        '/signed-media',
        options: Options(extra: {apiMediaRequestKey: true}),
      );
      expect(mediaAdapter.starts, 1);
      expect(
        c
            .snapshot(ApiQuotaKey.fromUri(Uri.parse('https://site.test')))
            .inFlight,
        0,
      );
      first.close(force: true);
      second.close(force: true);
      c.dispose();
    },
  );
}

final class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 200, this.retryAfter, this.immediate = false});
  final bool immediate;
  final int status;
  final String? retryAfter;
  var starts = 0;
  final bodies = <StreamController<Uint8List>>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    starts++;
    if (immediate) {
      return ResponseBody.fromString(
        '',
        status,
        headers: {
          if (retryAfter != null) 'retry-after': [retryAfter!],
        },
      );
    }
    final body = StreamController<Uint8List>();
    bodies.add(body);
    return ResponseBody(
      body.stream,
      status,
      headers: {
        if (retryAfter != null) 'retry-after': [retryAfter!],
      },
    );
  }

  @override
  void close({bool force = false}) {
    for (final b in bodies) {
      if (!b.isClosed) b.close();
    }
  }
}

void _pump(FakeAsync time) {
  for (var i = 0; i < 10; i++) {
    time.flushMicrotasks();
    time.elapse(Duration.zero);
  }
}
