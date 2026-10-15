// Package imports:
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/http/client/types.dart';

void main() {
  group('SlidingWindowRateLimitInterceptor', () {
    late MockRequestInterceptorHandler handler;

    setUp(() {
      handler = MockRequestInterceptorHandler();
    });

    test('should skip rate limiting when resolver returns false', () {
      fakeAsync((time) {
        final interceptor = _interceptor(
          time,
          SlidingWindowRateLimitConfig(
            requestsPerWindow: 2,
            windowSizeMs: 1000,
            resolver: (options) =>
                !(options.path.endsWith('.jpg') ||
                    options.path.endsWith('.png')),
          ),
        );
        final options = RequestOptions(path: '/image.jpg', method: 'GET');
        for (var i = 0; i < 5; i++) {
          _expectNoScheduledDelay(time, interceptor, options, handler);
        }
      });
    });

    test('should apply rate limiting when resolver returns true', () {
      fakeAsync((time) {
        final interceptor = _interceptor(
          time,
          SlidingWindowRateLimitConfig(
            requestsPerWindow: 2,
            windowSizeMs: 1000,
            resolver: (options) =>
                !(options.path.endsWith('.jpg') ||
                    options.path.endsWith('.png')),
          ),
        );
        final options = RequestOptions(path: '/api/posts', method: 'GET');
        for (var i = 0; i < 2; i++) {
          _expectNoScheduledDelay(time, interceptor, options, handler);
        }
        _expectScheduledDelay(
          time,
          interceptor,
          options,
          handler,
          const Duration(seconds: 1),
        );
      });
    });

    test('should delay requests when exceeding rate limit', () {
      fakeAsync((time) {
        final interceptor = _interceptor(
          time,
          const SlidingWindowRateLimitConfig(
            requestsPerWindow: 2,
            windowSizeMs: 1000,
          ),
        );
        final options = RequestOptions(path: '/test', method: 'POST');
        for (var i = 0; i < 2; i++) {
          _expectNoScheduledDelay(time, interceptor, options, handler);
        }
        _expectScheduledDelay(
          time,
          interceptor,
          options,
          handler,
          const Duration(seconds: 1),
        );
      });
    });

    test('should clean up old timestamps', () {
      fakeAsync((time) {
        final interceptor = _interceptor(
          time,
          const SlidingWindowRateLimitConfig(
            requestsPerWindow: 2,
            windowSizeMs: 100,
          ),
        );
        final options = RequestOptions(path: '/test', method: 'PUT');
        for (var i = 0; i < 2; i++) {
          _expectNoScheduledDelay(time, interceptor, options, handler);
        }
        time.elapse(const Duration(milliseconds: 150));
        _expectNoScheduledDelay(time, interceptor, options, handler);
      });
    });

    test('should respect max delay limit', () {
      fakeAsync((time) {
        final interceptor = _interceptor(
          time,
          const SlidingWindowRateLimitConfig(
            requestsPerWindow: 1,
            windowSizeMs: 10000,
            maxDelayMs: 100,
          ),
        );
        final options = RequestOptions(path: '/test', method: 'DELETE');
        _expectNoScheduledDelay(time, interceptor, options, handler);
        _expectScheduledDelay(
          time,
          interceptor,
          options,
          handler,
          const Duration(milliseconds: 100),
        );
      });
    });

    test('should handle multiple requests within window correctly', () {
      fakeAsync((time) {
        final interceptor = _interceptor(
          time,
          const SlidingWindowRateLimitConfig(
            requestsPerWindow: 3,
            windowSizeMs: 1000,
          ),
        );
        final options = RequestOptions(path: '/test', method: 'PATCH');
        for (var i = 0; i < 3; i++) {
          _expectNoScheduledDelay(time, interceptor, options, handler);
        }
        _expectScheduledDelay(
          time,
          interceptor,
          options,
          handler,
          const Duration(seconds: 1),
        );
      });
    });
  });
}

SlidingWindowRateLimitInterceptor _interceptor(
  FakeAsync time,
  SlidingWindowRateLimitConfig config,
) => SlidingWindowRateLimitInterceptor(
  config: config,
  now: time.getClock(DateTime.utc(2026)).now,
);

// Assert timer policy rather than the speed of the test host's scheduler.
void _expectNoScheduledDelay(
  FakeAsync time,
  SlidingWindowRateLimitInterceptor interceptor,
  RequestOptions options,
  MockRequestInterceptorHandler handler,
) {
  handler.reset();
  var completed = false;
  interceptor.onRequest(options, handler).then((_) => completed = true);
  time.flushMicrotasks();
  expect(time.pendingTimers, isEmpty);
  expect(completed, isTrue);
  expect(handler.nextCalled, isTrue);
}

void _expectScheduledDelay(
  FakeAsync time,
  SlidingWindowRateLimitInterceptor interceptor,
  RequestOptions options,
  MockRequestInterceptorHandler handler,
  Duration delay,
) {
  handler.reset();
  var completed = false;
  interceptor.onRequest(options, handler).then((_) => completed = true);
  time.flushMicrotasks();
  expect(handler.nextCalled, isFalse);
  expect(completed, isFalse);
  expect(time.pendingTimers.single.duration, delay);
  time.elapse(delay - const Duration(milliseconds: 1));
  expect(handler.nextCalled, isFalse);
  expect(completed, isFalse);
  time.elapse(const Duration(milliseconds: 1));
  expect(handler.nextCalled, isTrue);
  expect(completed, isTrue);
}

class MockRequestInterceptorHandler extends RequestInterceptorHandler {
  var nextCalled = false;

  @override
  void next(RequestOptions requestOptions) {
    nextCalled = true;
  }

  @override
  void reject(
    DioException error, [
    bool callFollowingErrorInterceptor = false,
  ]) {}

  @override
  void resolve(
    Response response, [
    bool callFollowingResponseInterceptor = false,
  ]) {}

  void reset() {
    nextCalled = false;
  }
}
