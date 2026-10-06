import 'dart:async';
import 'dart:typed_data';

import 'package:boorusama/core/http/client/src/providers/dio.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final failure in ['404', 'timeout']) {
    test(
      'production single image $failure has no orphaned completer error',
      () async {
        final zoneErrors = <Object>[];
        DioException? received;
        var requests = 0;
        await runZonedGuarded<Future<void>>(() async {
          final dio = newGenericDio(baseUrl: null);
          dio.httpClientAdapter = _FailureAdapter((options) {
            requests++;
            if (failure == 'timeout') {
              throw DioException.receiveTimeout(
                timeout: const Duration(seconds: 30),
                requestOptions: options,
              );
            }
            return ResponseBody.fromBytes(Uint8List(0), 404);
          });
          try {
            await dio.get<void>('https://fixture.test/target.png');
          } on DioException catch (error) {
            received = error;
          } finally {
            dio.close(force: true);
          }
          await Future<void>.delayed(Duration.zero);
        }, (error, stack) => zoneErrors.add(error));
        expect(
          received?.type,
          failure == '404'
              ? DioExceptionType.badResponse
              : DioExceptionType.receiveTimeout,
        );
        expect(requests, 1);
        expect(
          zoneErrors,
          isEmpty,
          reason:
              'the caller handled its error; the single request must not leave a second unobserved future',
        );
      },
    );
  }
  for (final failure in ['404', 'timeout']) {
    test(
      'concurrent image $failure reaches both callers and releases the pending key',
      () async {
        final zoneErrors = <Object>[];
        final received = <DioException>[];
        var requests = 0;
        await runZonedGuarded<Future<void>>(() async {
          try {
            var response = Completer<Object>();
            var started = Completer<void>();
            final duplicateEntered = Completer<void>();
            var entered = 0;
            final dio = newGenericDio(baseUrl: null);
            dio.interceptors.insert(
              0,
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  entered++;
                  handler.next(options);
                  if (entered == 2) duplicateEntered.complete();
                },
              ),
            );
            dio.httpClientAdapter = _DeferredAdapter((options) {
              requests++;
              started.complete();
              return response.future;
            });
            Future<void> request() => dio
                .get<void>('https://fixture.test/target.png')
                .then<void>(
                  (_) => fail('expected controlled failure'),
                  onError: (Object error, StackTrace stack) {
                    received.add(error as DioException);
                  },
                );
            final first = request();
            await started.future.timeout(
              const Duration(seconds: 3),
              onTimeout: () => throw StateError(
                'adapter did not start; zone errors: $zoneErrors',
              ),
            );
            final duplicate = request();
            await duplicateEntered.future.timeout(
              const Duration(seconds: 3),
              onTimeout: () => throw StateError(
                'duplicate did not enter; zone errors: $zoneErrors',
              ),
            );
            await Future<void>.delayed(Duration.zero);
            expect(requests, 1);
            if (failure == '404') {
              response.complete(ResponseBody.fromBytes(Uint8List(0), 404));
            } else {
              response.complete(
                DioException.receiveTimeout(
                  timeout: const Duration(seconds: 30),
                  requestOptions: RequestOptions(
                    path: 'https://fixture.test/target.png',
                  ),
                ),
              );
            }
            await Future.wait([first, duplicate]).timeout(
              const Duration(seconds: 3),
              onTimeout: () => throw StateError(
                'both callers did not finish; received=$received; zone errors: $zoneErrors',
              ),
            );
            expect(received, hasLength(2));
            expect(
              identical(received[0], received[1]),
              isTrue,
              reason: 'duplicates preserve the exact owning request error',
            );
            expect(
              received.every(
                (error) =>
                    error.type ==
                    (failure == '404'
                        ? DioExceptionType.badResponse
                        : DioExceptionType.receiveTimeout),
              ),
              isTrue,
            );
            response = Completer<Object>();
            started = Completer<void>();
            final fresh = dio.get<List<int>>(
              'https://fixture.test/target.png',
              options: Options(responseType: ResponseType.bytes),
            );
            await started.future.timeout(
              const Duration(seconds: 3),
              onTimeout: () => throw StateError(
                'adapter did not start; zone errors: $zoneErrors',
              ),
            );
            expect(
              requests,
              2,
              reason:
                  'failure must release the key for a subsequent independent request',
            );
            response.complete(ResponseBody.fromBytes([1, 2, 3], 200));
            expect((await fresh).data, [1, 2, 3]);
            dio.close(force: true);
            await Future<void>.delayed(Duration.zero);
          } catch (error) {
            zoneErrors.add(error);
          }
        }, (error, stack) => zoneErrors.add(error));
        expect(zoneErrors, isEmpty);
      },
    );
  }

  test(
    'concurrent image success shares one fetch and releases the pending key',
    () async {
      var requests = 0;
      var response = Completer<Object>();
      var started = Completer<void>();
      final duplicateEntered = Completer<void>();
      var entered = 0;
      final dio = newGenericDio(baseUrl: null);
      addTearDown(() => dio.close(force: true));
      dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            entered++;
            handler.next(options);
            if (entered == 2) duplicateEntered.complete();
          },
        ),
      );
      dio.httpClientAdapter = _DeferredAdapter((options) {
        requests++;
        started.complete();
        return response.future;
      });
      Future<Response<List<int>>> request() => dio.get<List<int>>(
        'https://fixture.test/target.png',
        options: Options(responseType: ResponseType.bytes),
      );
      final first = request();
      await started.future;
      final duplicate = request();
      await duplicateEntered.future;
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
      response.complete(ResponseBody.fromBytes([1, 2, 3], 200));
      final results = await Future.wait([first, duplicate]);
      expect(results.map((result) => result.data), [
        [1, 2, 3],
        [1, 2, 3],
      ]);
      expect(identical(results[0].data, results[1].data), isTrue);
      expect(results.map((result) => result.statusCode), [200, 200]);
      response = Completer<Object>();
      started = Completer<void>();
      final fresh = request();
      await started.future;
      expect(requests, 2);
      response.complete(ResponseBody.fromBytes([4, 5], 200));
      expect((await fresh).data, [4, 5]);
    },
  );
}

class _FailureAdapter implements HttpClientAdapter {
  _FailureAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

class _DeferredAdapter implements HttpClientAdapter {
  _DeferredAdapter(this.respond);
  final Future<Object> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final result = await respond(options);
    // Throw in the adapter's request zone, as the production adapters do.
    if (result is DioException) throw result;
    return result as ResponseBody;
  }

  @override
  void close({bool force = false}) {}
}
