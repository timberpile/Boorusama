import 'dart:async';

// Package imports:
import 'package:dio/dio.dart';
import 'package:retriable/retriable.dart';

// Project imports:
import '../types/http_utils.dart';

/// A resolver function to determine if a request should be rate-limited.
typedef RateLimitResolver = bool Function(RequestOptions options);

bool _defaultRateLimitResolver(RequestOptions options) {
  // Default resolver will not rate limit image requests
  return !HttpUtils.isImageRequest(options);
}

class SlidingWindowRateLimitConfig {
  const SlidingWindowRateLimitConfig({
    required this.requestsPerWindow,
    required this.windowSizeMs,
    this.maxDelayMs = 5000,
    this.resolver = _defaultRateLimitResolver,
    this.retryAfterFallback,
  });

  final int requestsPerWindow;
  final int windowSizeMs;
  final int maxDelayMs;
  final RateLimitResolver resolver;
  final Duration? retryAfterFallback;
}

class SlidingWindowRateLimitInterceptor extends Interceptor {
  SlidingWindowRateLimitInterceptor({
    required SlidingWindowRateLimitConfig config,
    DateTime Function()? now,
  }) : _config = config,
       _now = now ?? DateTime.now;

  final SlidingWindowRateLimitConfig _config;
  final DateTime Function() _now;
  final List<DateTime> _requestTimestamps = [];
  Future<void> _pendingRequest = Future.value();
  DateTime? _blockedUntil;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _recordCooldown(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _recordCooldown(err.response);
    handler.next(err);
  }

  void _recordCooldown(Response? response) {
    final fallback = _config.retryAfterFallback;
    if (fallback == null ||
        response == null ||
        response.statusCode != 429 ||
        !_config.resolver(response.requestOptions)) {
      return;
    }

    final delay = retryAfterFromHeaders(response.headers) ?? fallback;
    final deadline = _now().add(delay);
    final current = _blockedUntil;
    if (current == null || deadline.isAfter(current)) {
      _blockedUntil = deadline;
    }
  }

  Future<void> _waitForCooldown(CancelToken? cancelToken) async {
    while (cancelToken?.isCancelled != true) {
      final deadline = _blockedUntil;
      if (deadline == null) return;
      final remaining = deadline.difference(_now());
      if (remaining <= Duration.zero) return;
      await _wait(remaining, cancelToken);
    }
  }

  Future<void> _wait(Duration delay, CancelToken? cancelToken) async {
    final completed = Completer<void>();
    final timer = Timer(delay, completed.complete);
    try {
      await Future.any([
        completed.future,
        if (cancelToken != null) cancelToken.whenCancel,
      ]);
    } finally {
      timer.cancel();
    }
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_config.resolver(options)) {
      handler.next(options);
      return;
    }

    final previous = _pendingRequest;
    final completed = Completer<void>();
    _pendingRequest = completed.future;

    try {
      await previous;
      await _admit(options, handler);
    } finally {
      completed.complete();
    }
  }

  Future<void> _admit(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final cancelToken = options.cancelToken;
    await _waitForCooldown(cancelToken);
    if (cancelToken?.cancelError case final error?) {
      handler.reject(error);
      return;
    }

    final now = _now();

    // Clean old timestamps outside the window
    _requestTimestamps.removeWhere(
      (timestamp) =>
          now.difference(timestamp).inMilliseconds >= _config.windowSizeMs,
    );

    // Calculate delay needed if we would exceed the limit
    if (_requestTimestamps.length >= _config.requestsPerWindow) {
      final oldestInWindow = _requestTimestamps.first;
      final timeSinceOldest = now.difference(oldestInWindow).inMilliseconds;
      final delayNeeded = _config.windowSizeMs - timeSinceOldest;

      if (delayNeeded > 0) {
        final delayMs = delayNeeded.clamp(0, _config.maxDelayMs);
        await _wait(Duration(milliseconds: delayMs), cancelToken);
      }
    }

    while (true) {
      await _waitForCooldown(cancelToken);
      if (cancelToken?.cancelError case final error?) {
        handler.reject(error);
        return;
      }

      final admittedAt = _now();
      if (_blockedUntil case final deadline?
          when deadline.isAfter(admittedAt)) {
        continue;
      }
      _requestTimestamps
        ..removeWhere(
          (timestamp) =>
              admittedAt.difference(timestamp).inMilliseconds >=
              _config.windowSizeMs,
        )
        ..add(admittedAt);
      handler.next(options);
      return;
    }
  }
}
