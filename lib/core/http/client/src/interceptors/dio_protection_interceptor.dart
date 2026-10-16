// Dart imports:
import 'dart:async';
import 'dart:convert';

// Package imports:
import 'package:coreutils/coreutils.dart';
import 'package:dio/dio.dart';

// Project imports:
import '../../../../ddos/handler/types.dart';
import '../../../../ddos/solver/types.dart';
import '../coordination/api_request_context.dart';
import '../coordination/coordinated_dio.dart';

class DioProtectionInterceptor extends Interceptor {
  DioProtectionInterceptor({
    required HttpProtectionHandler protectionHandler,
    required Dio dio,
  }) : _protectionHandler = protectionHandler,
       _dio = dio;

  static const _attemptKey = 'boorusama.protection_attempt';

  ProtectionAttempt _attempt(RequestOptions options) =>
      options.extra.putIfAbsent(
        _attemptKey,
        () => _protectionHandler.beginAttempt(
          options.uri,
          ProtectionSource.dio,
        ),
      ) as ProtectionAttempt;

  static const _protectionRetryKey = 'boorusama.ddos_protection_retry';
  static const _rule34ReplayDelay = Duration(seconds: 2);

  final HttpProtectionHandler _protectionHandler;
  final Dio _dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final attempt = _attempt(options);
    attempt.record(
      RequestSent(
        method: options.method,
        retry: _isProtectionRetry(options),
        backend: _dio.httpClientAdapter.runtimeType.toString(),
      ),
      sensitive: ProtectionRequestDetails(options.uri),
    );
    try {
      final headers = await _protectionHandler.prepareRequestHeaders(
        options.uri,
        options.headers.map((k, v) => MapEntry(k, v.toString())),
        attempt: _attempt(options),
      );

      options.headers.addAll(headers);
    } catch (e) {
      attempt.record(
        ProtectionOperationFailed(
          ProtectionOperation.prepareHeaders,
          e.runtimeType.toString(),
        ),
      );
      // Continue with request even if header preparation fails
    }

    return super.onRequest(options, handler);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final attempt = _attempt(response.requestOptions);
    attempt.record(
      ResponseReceived(
        status: response.statusCode,
        retry: _isProtectionRetry(response.requestOptions),
      ),
    );
    _protectionHandler.observeSuccess(response.requestOptions.uri);
    if (_skipProtectionRecovery(response.requestOptions) ||
        response.statusCode == 429) {
      return super.onResponse(response, handler);
    }

    try {
      final isProtection = await _protectionHandler.handleResponse(
        DioResponseAdapter(response),
        attempt: attempt,
        challengeUri: challengeUriFor(response.requestOptions),
      );

      if (isProtection) {
        final retryResponse = await _recoverAfterProtection(
          response.requestOptions,
        );
        _protectionHandler.resetRetryAttempts(response.requestOptions.uri);
        handler.next(retryResponse);
        return;
      }
    } catch (e) {
      attempt.record(
        ProtectionOperationFailed(
          ProtectionOperation.recoveryOrRetry,
          e.runtimeType.toString(),
        ),
      );
      // Continue with normal response if handling fails
    }

    return super.onResponse(response, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = _attempt(err.requestOptions);
    attempt.record(
      ResponseReceived(
        status: err.response?.statusCode,
        errorType: err.type.name,
        retry: _isProtectionRetry(err.requestOptions),
      ),
    );
    if (_isProtectionRetry(err.requestOptions)) {
      _protectionHandler.observeRetryError(
        DioErrorAdapter(err),
        attempt: attempt,
      );
      return handler.next(err);
    }
    if (_skipProtectionRecovery(err.requestOptions) ||
        err.response?.statusCode == 429) {
      return handler.next(err);
    }

    final bool solved;
    try {
      solved = await _protectionHandler.handleError(
        DioErrorAdapter(err),
        attempt: attempt,
        challengeUri: challengeUriFor(err.requestOptions),
      );
    } catch (e) {
      attempt.record(
        ProtectionOperationFailed(
          ProtectionOperation.recoveryOrRetry,
          e.runtimeType.toString(),
        ),
      );
      return handler.next(err);
    }

    if (solved) {
      try {
        final response = await _recoverRule34Safely(err.requestOptions);
        _protectionHandler.resetRetryAttempts(err.requestOptions.uri);
        handler.resolve(response);
        return;
      } on DioException catch (replayError) {
        attempt.record(
          ProtectionOperationFailed(
            ProtectionOperation.recoveryOrRetry,
            replayError.runtimeType.toString(),
          ),
        );
        handler.next(replayError);
        return;
      } catch (e) {
        attempt.record(
          ProtectionOperationFailed(
            ProtectionOperation.recoveryOrRetry,
            e.runtimeType.toString(),
          ),
        );
      }
    }

    return handler.next(err);
  }

  bool _isProtectionRetry(RequestOptions options) =>
      options.extra[_protectionRetryKey] == true;

  bool _skipProtectionRecovery(RequestOptions options) =>
      _isProtectionRetry(options) ||
      !isApiSafeRead(options) ||
      apiRequestContextFor(options).requestClass ==
          ApiRequestClass.bulkTransfer;

  Future<Response<dynamic>> _recoverRule34Safely(
    RequestOptions options,
  ) async {
    try {
      return await _recoverAfterProtection(options);
    } on DioException catch (error) {
      if (!_shouldDelayRule34Replay(error)) rethrow;
      await _waitForRule34Replay(options.cancelToken);
      return _recoverAfterProtection(options);
    }
  }

  bool _shouldDelayRule34Replay(DioException error) {
    final options = error.requestOptions;
    final uri = options.uri;
    return error.response?.statusCode == 403 &&
        uri.host == 'rule34.xxx' &&
        isApiSafeRead(options) &&
        uri.path == '/index.php' &&
        uri.queryParameters['page'] == 'dapi' &&
        uri.queryParameters['s'] == 'post' &&
        uri.queryParameters['q'] == 'index';
  }

  Future<void> _waitForRule34Replay(CancelToken? cancelToken) async {
    if (cancelToken == null) {
      await Future<void>.delayed(_rule34ReplayDelay);
      return;
    }
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    final cancellation = await Future.any<DioException?>([
      Future<void>.delayed(_rule34ReplayDelay).then((_) => null),
      cancelToken.whenCancel,
    ]);
    if (cancellation != null) throw cancellation;
  }

  /// Retries with the solver's credentials. When the challenge browser loaded
  /// the requested page itself, that page answers the request if there is
  /// nothing to retry with or the retry is still blocked.
  Future<Response<dynamic>> _recoverAfterProtection(
    RequestOptions options,
  ) async {
    options.extra[apiNegotiatedKey] = true;
    final attempt = _attempt(options);
    final browserPage = switch (attempt.loadedPageFor(options.uri)) {
      final html? when challengeUriFor(options) == options.uri =>
        _browserPageResponse(options, html),
      _ => null,
    };
    Response<dynamic> useBrowserPage(Response<dynamic> page) {
      attempt.record(const LoadedPageUsed());
      return page;
    }

    if (browserPage != null && !attempt.receivedCredentials) {
      return useBrowserPage(browserPage);
    }
    try {
      return await _retryAfterProtection(options);
    } on DioException {
      if (browserPage == null) rethrow;
      return useBrowserPage(browserPage);
    }
  }

  Future<Response<dynamic>> _retryAfterProtection(
    RequestOptions options,
  ) async {
    final attempt = _attempt(options);
    final previous = options.extra[_protectionRetryKey];
    options.extra[_protectionRetryKey] = true;

    try {
      while (true) {
        attempt.retries++;
        attempt.record(RetryDispatched(attempt.retries));
        final headers = await _protectionHandler.prepareRequestHeaders(
          options.uri,
          options.headers.map((k, v) => MapEntry(k, v.toString())),
          attempt: attempt,
        );

        options.headers
          ..clear()
          ..addAll(headers);

        try {
          final response = await _dio.fetch(options);
          await _protectionHandler.confirmRetry(options.uri, attempt);
          return response;
        } on DioException catch (error) {
          if (attempt.retries >= _protectionHandler.maxRetries ||
              !_protectionHandler.selectAlternativeClearance(
                DioErrorAdapter(error),
                attempt,
              )) {
            rethrow;
          }
        }
      }
    } finally {
      if (previous == null) {
        options.extra.remove(_protectionRetryKey);
      } else {
        options.extra[_protectionRetryKey] = previous;
      }
    }
  }
}

/// The page a challenge browser opens for [options]. Replaying a request in
/// the browser repeats its side effects, so state-changing requests open the
/// site's base page on the same origin instead.
Uri challengeUriFor(RequestOptions options) {
  final uri = options.uri;
  final replayable =
      options.method.toUpperCase() == 'GET' &&
      options.extra[stateChangingRequestKey] != true;
  if (replayable) return uri;

  final base = Uri.tryParse(options.baseUrl);
  return switch (base) {
    final base?
        when (base.isScheme('http') || base.isScheme('https')) &&
            base.origin == uri.origin =>
      base,
    _ => Uri.parse('${uri.origin}/'),
  };
}

Response<dynamic>? _browserPageResponse(RequestOptions options, String html) {
  final data = switch (options.responseType) {
    ResponseType.bytes => utf8.encode(html),
    ResponseType.stream => null,
    ResponseType.json || ResponseType.plain => html,
  };
  if (data == null) return null;
  return Response(
    requestOptions: options,
    data: data,
    statusCode: 200,
    headers: Headers.fromMap({
      Headers.contentTypeHeader: ['text/html; charset=utf-8'],
    }),
  );
}

class DioResponseAdapter implements HttpResponse {
  const DioResponseAdapter(this._response);

  final Response _response;

  @override
  int? get statusCode => _response.statusCode;
  @override
  dynamic get data => _decodeData(_response.data);
  @override
  Uri get requestUri => _response.requestOptions.uri;
  @override
  Map<String, dynamic> get headers => _response.headers.map;
}

class DioErrorAdapter implements HttpError {
  const DioErrorAdapter(this._error);
  final DioException _error;

  @override
  HttpResponse? get response =>
      _error.response != null ? DioResponseAdapter(_error.response!) : null;
  @override
  Uri get requestUri => _error.requestOptions.uri;
  @override
  String? get message => _error.message;
}

dynamic _decodeData(dynamic data) => switch (data) {
  final List<int> bytes => _tryDecodeBytes(bytes),
  _ => data,
};

dynamic _tryDecodeBytes(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return bytes;
  }
}
