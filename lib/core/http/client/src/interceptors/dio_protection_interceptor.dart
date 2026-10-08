// Dart imports:
import 'dart:async';
import 'dart:convert';

// Package imports:
import 'package:dio/dio.dart';
import '../coordination/coordinated_dio.dart';
import '../coordination/api_request_context.dart';

// Project imports:
import '../../../../ddos/handler/types.dart';
import '../../../../ddos/solver/types.dart';

class DioProtectionInterceptor extends Interceptor {
  DioProtectionInterceptor({
    required HttpProtectionHandler protectionHandler,
    required Dio dio,
  }) : _protectionHandler = protectionHandler,
       _dio = dio;

  static const _protectionRetryKey = 'boorusama.ddos_protection_retry';
  static const _rule34ReplayDelay = Duration(seconds: 2);

  final HttpProtectionHandler _protectionHandler;
  final Dio _dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final headers = await _protectionHandler.prepareRequestHeaders(
        options.uri,
        options.headers.map((k, v) => MapEntry(k, v.toString())),
      );

      options.headers.addAll(headers);
    } catch (e) {
      // Continue with request even if header preparation fails
    }

    return super.onRequest(options, handler);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    if (_isBulkTransfer(response.requestOptions) ||
        _isProtectionRetry(response.requestOptions) ||
        !isApiSafeRead(response.requestOptions) ||
        response.statusCode == 429) {
      return super.onResponse(response, handler);
    }

    try {
      final isProtection = await _protectionHandler.handleResponse(
        DioResponseAdapter(response),
      );

      if (isProtection) {
        final retryResponse = await _retryAfterProtection(
          response.requestOptions,
        );
        _protectionHandler.resetRetryAttempts(response.requestOptions.uri);
        handler.next(retryResponse);
        return;
      }
    } catch (e) {
      // Continue with normal response if handling fails
    }

    return super.onResponse(response, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_isBulkTransfer(err.requestOptions) ||
        _isProtectionRetry(err.requestOptions) ||
        !isApiSafeRead(err.requestOptions) ||
        err.response?.statusCode == 429) {
      return handler.next(err);
    }

    try {
      final solved = await _protectionHandler.handleError(DioErrorAdapter(err));

      if (solved) {
        try {
          final response = await _retryAfterProtection(err.requestOptions);
          handler.resolve(response);
        } on DioException catch (replayError) {
          if (!_shouldDelayRule34Replay(replayError)) {
            handler.next(replayError);
          } else {
            try {
              await _waitForRule34Replay(err.requestOptions.cancelToken);
              final response = await _retryAfterProtection(err.requestOptions);
              handler.resolve(response);
            } on DioException catch (finalError) {
              handler.next(finalError);
            }
          }
        } finally {
          _protectionHandler.resetRetryAttempts(err.requestOptions.uri);
        }
        return;
      }
    } catch (_) {
      // Continue with the original error if protection handling itself fails.
    }

    return handler.next(err);
  }

  bool _shouldDelayRule34Replay(DioException error) {
    final options = error.requestOptions;
    final uri = options.uri;
    return error.response?.statusCode == 403 &&
        uri.host == 'rule34.xxx' &&
        options.method.toUpperCase() == 'GET' &&
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
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
  }

  // Maintenance uses existing cookies but must leave interactive verification
  // to a normal browsing action rather than solve or replay challenges itself.
  bool _isBulkTransfer(RequestOptions options) =>
      apiRequestContextFor(options).requestClass ==
      ApiRequestClass.bulkTransfer;

  bool _isProtectionRetry(RequestOptions options) =>
      options.extra[_protectionRetryKey] == true;

  Future<Response<dynamic>> _retryAfterProtection(
    RequestOptions options,
  ) async {
    options.extra[apiNegotiatedKey] = true;
    final previous = options.extra[_protectionRetryKey];
    options.extra[_protectionRetryKey] = true;

    try {
      final headers = await _protectionHandler.prepareRequestHeaders(
        options.uri,
        options.headers.map((k, v) => MapEntry(k, v.toString())),
      );

      options.headers
        ..clear()
        ..addAll(headers);

      return await _dio.fetch(options);
    } finally {
      if (previous == null) {
        options.extra.remove(_protectionRetryKey);
      } else {
        options.extra[_protectionRetryKey] = previous;
      }
    }
  }
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
