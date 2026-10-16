import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:dio/dio.dart';
import 'package:retriable/retriable.dart';

void main() {
  test('cancellation interrupts Retry-After without another attempt', () {
    fakeAsync((clock) {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 503,
                    headers: Headers.fromMap({
                      'retry-after': ['30'],
                    }),
                  ),
                ),
              );
            },
          ),
        );
      final cancellation = CancelToken();
      var finished = false;
      tryGetResponse<String>(
        Uri.parse('https://example.test/a'),
        dio: dio,
        cancelToken: cancellation,
      ).then(
        (_) {
          finished = true;
        },
        onError: (Object _) {
          finished = true;
        },
      );
      clock.flushMicrotasks();
      clock.elapse(Duration.zero);
      clock.flushMicrotasks();
      cancellation.cancel();
      clock.flushMicrotasks();
      clock.elapse(Duration.zero);
      clock.flushMicrotasks();
      expect(finished, isTrue);
      expect(clock.nonPeriodicTimerCount, 0);
      dio.close();
    });
  });
}
