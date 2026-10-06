import 'dart:typed_data';

import 'package:boorusama/core/http/client/coordination.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two passive streams leave two physical slots for active work', () {
    fakeAsync((time) {
      final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
      final key = ApiQuotaKey.fromUri(Uri.parse('https://unknown.test'));
      final passive = <ApiRequestPermit>[];
      final active = <ApiRequestPermit>[];
      for (var i = 0; i < 3; i++) {
        c
            .acquire(
              key,
              context: const ApiRequestContext(
                requestClass: ApiRequestClass.preload,
              ),
            )
            .then(passive.add);
      }
      time.flushMicrotasks();
      expect(passive, hasLength(2));
      for (var i = 0; i < 2; i++) {
        c.acquire(key).then(active.add);
      }
      time.flushMicrotasks();
      expect(active, hasLength(2));
      expect(c.snapshot(key).inFlight, 4);
      passive.first.release();
      time.flushMicrotasks();
      expect(passive, hasLength(3));
      c.dispose();
    });
  });

  test(
    'manual owner wakes a queued shared auth exchange behind exhausted passive budget',
    () async {
      var elapsed = Duration.zero;
      final c = ApiRequestCoordinator(elapsed: () => elapsed);
      addTearDown(c.dispose);
      final key = ApiQuotaKey.fromUri(Uri.parse('https://unknown.test'));
      for (var i = 0; i < 12; i++) {
        (await c.acquire(
          key,
          context: const ApiRequestContext(
            requestClass: ApiRequestClass.automatic,
          ),
        )).release();
        elapsed += const Duration(seconds: 1);
      }
      var starts = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://unknown.test'))
        ..httpClientAdapter = _AuthTransport(() => starts++);
      coordinateApiDio(dio, c);
      final registry = ApiAuthRefreshRegistry();
      final passive = runWithApiRequestContext(
        const ApiRequestContext(requestClass: ApiRequestClass.automatic),
        () => registry.run('account', () => dio.post('/refresh')),
      );
      for (var i = 0; i < 20 && c.snapshot(key).queued == 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(starts, 0);
      expect(c.snapshot(key).queued, 1);
      final manual = runWithApiRequestContext(
        const ApiRequestContext(requestClass: ApiRequestClass.userInitiated),
        () => registry.run(
          'account',
          () => throw StateError('duplicate rotation'),
        ),
      );
      await Future.wait([passive, manual]).timeout(const Duration(seconds: 1));
      expect(starts, 1);
      expect(c.snapshot(key).queued, 0);
      expect(c.snapshot(key).inFlight, 0);
      expect(elapsed, const Duration(seconds: 12));
    },
  );

  test(
    'cancelled manual owner returns queued auth to passive policy until another live owner joins',
    () async {
      final c = ApiRequestCoordinator();
      addTearDown(c.dispose);
      final key = ApiQuotaKey.fromUri(Uri.parse('https://unknown.test'));
      for (var i = 0; i < 12; i++) {
        (await c.acquire(
          key,
          context: const ApiRequestContext(
            requestClass: ApiRequestClass.automatic,
          ),
        )).release();
      }
      final held = await Future.wait(List.generate(4, (_) => c.acquire(key)));
      var starts = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://unknown.test'))
        ..httpClientAdapter = _AuthTransport(() => starts++);
      coordinateApiDio(dio, c);
      final registry = ApiAuthRefreshRegistry();
      final passive = runWithApiRequestContext(
        const ApiRequestContext(requestClass: ApiRequestClass.automatic),
        () => registry.run('account', () => dio.post('/refresh')),
      );
      await _settle();
      final token = CancelToken();
      final manual = runWithApiRequestContext(
        ApiRequestContext(
          requestClass: ApiRequestClass.userInitiated,
          cancelToken: token,
        ),
        () => registry.run('account', () => throw StateError('duplicate')),
      );
      final cancelled = expectLater(manual, throwsA(isA<DioException>()));
      token.cancel();
      await cancelled;
      for (final p in held) {
        p.release();
      }
      await _settle();
      expect(starts, 0);
      expect(c.snapshot(key).waiting[ApiWaitReason.passiveBudget], 1);
      final replacement = runWithApiRequestContext(
        const ApiRequestContext(requestClass: ApiRequestClass.userInitiated),
        () => registry.run('account', () => throw StateError('duplicate')),
      );
      await Future.wait([
        passive,
        replacement,
      ]).timeout(const Duration(seconds: 1));
      expect(starts, 1);
      expect(c.snapshot(key).passiveInFlight, 0);
    },
  );

  test(
    'manual cancellation between admission and dispatch cannot bypass the passive budget',
    () async {
      final c = ApiRequestCoordinator();
      addTearDown(c.dispose);
      final key = ApiQuotaKey.fromUri(Uri.parse('https://unknown.test'));
      for (var i = 0; i < 12; i++) {
        (await c.acquire(
          key,
          context: const ApiRequestContext(
            requestClass: ApiRequestClass.automatic,
          ),
        )).release();
      }
      var starts = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://unknown.test'))
        ..httpClientAdapter = _AuthTransport(() => starts++);
      coordinateApiDio(dio, c);
      final registry = ApiAuthRefreshRegistry();
      final passive = runWithApiRequestContext(
        const ApiRequestContext(requestClass: ApiRequestClass.automatic),
        () => registry.run('account', () => dio.post('/refresh')),
      );
      await _settle();
      expect(c.snapshot(key).queued, 1);
      final token = CancelToken();
      final manual = runWithApiRequestContext(
        ApiRequestContext(
          requestClass: ApiRequestClass.userInitiated,
          cancelToken: token,
        ),
        () => registry.run('account', () => throw StateError('duplicate')),
      );
      final cancelled = expectLater(manual, throwsA(isA<DioException>()));
      token.cancel();
      await cancelled;
      await _settle();
      expect(
        starts,
        0,
        reason:
            'reservation promoted by an owner that left before physical dispatch must be reconsidered',
      );
      final replacement = runWithApiRequestContext(
        const ApiRequestContext(requestClass: ApiRequestClass.userInitiated),
        () => registry.run('account', () => throw StateError('duplicate')),
      );
      await Future.wait([
        passive,
        replacement,
      ]).timeout(const Duration(seconds: 1));
      expect(starts, 1);
    },
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _AuthTransport implements HttpClientAdapter {
  _AuthTransport(this.start);
  final void Function() start;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    start();
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}
