import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_quota_key.dart';
import 'api_quota_policy.dart';
import 'api_request_context.dart';
import 'api_request_coordinator.dart';

const _actualQuotaKey = 'boorusama.request.actualQuota';
const _cooldownKey = 'boorusama.request.cooldown';
const apiNegotiatedKey = 'boorusama.request.negotiated';

void coordinateApiDio(Dio dio, ApiRequestCoordinator coordinator) {
  if (dio.httpClientAdapter is CoordinatedHttpClientAdapter) return;
  dio.httpClientAdapter = CoordinatedHttpClientAdapter(
    dio.httpClientAdapter,
    coordinator,
  );
  dio.interceptors.insert(0, ApiRequestInterceptor(dio, coordinator));
}

bool isApiSafeRead(RequestOptions options) {
  if (options.extra[apiMutationRequestKey] == true) return false;
  if (options.extra[apiSafeReadRequestKey] == true) return true;
  final context = options.extra[apiRequestContextKey] as ApiRequestContext?;
  if (context?.replaySafety case final safety?) {
    return safety == ApiReplaySafety.safeRead;
  }
  return options.method.toUpperCase() == 'GET' ||
      options.method.toUpperCase() == 'HEAD';
}

final class CoordinatedHttpClientAdapter implements HttpClientAdapter {
  CoordinatedHttpClientAdapter(this.delegate, this.coordinator);
  final HttpClientAdapter delegate;
  final ApiRequestCoordinator coordinator;
  final _waiting = <CancelToken>{};
  var _closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
    }
    if (options.extra[apiMediaRequestKey] == true) {
      return delegate.fetch(options, requestStream, cancelFuture);
    }
    final context =
        options.extra[apiRequestContextKey] as ApiRequestContext? ??
        ApiRequestContext.current();
    var current = options;
    var redirects = 0;
    while (true) {
      final key = ApiQuotaKey.fromUri(current.uri);
      final transportState = isApiSafeRead(current)
          ? context.onDataTransport
          : null;
      transportState?.call(current.uri, false);
      final queuedCancellation = CancelToken();
      _waiting.add(queuedCancellation);
      final callerCancellation = options.cancelToken;
      if (callerCancellation != null) {
        if (callerCancellation.isCancelled) {
          queuedCancellation.cancel();
        } else {
          unawaited(
            callerCancellation.whenCancel.then(
              (e) => queuedCancellation.cancel(e),
            ),
          );
        }
      }
      late final ApiRequestPermit permit;
      try {
        permit = await coordinator.acquire(
          key,
          descriptor: ApiRequestDescriptor(
            method: current.method,
            path: current.uri.path,
            replaySafety: isApiSafeRead(current)
                ? ApiReplaySafety.safeRead
                : ApiReplaySafety.mutation,
          ),
          context: ApiRequestContext(
            requestClass: context.requestClass,
            requestClassResolver: context.requestClassResolver,
            allowCooldownRetryResolver: context.allowCooldownRetryResolver,
            onDataTransport: context.onDataTransport,
            changes: context.changes,
            admissionBehavior: context.admissionBehavior,
            replaySafety: context.replaySafety,
            cancelToken: queuedCancellation,
            canStart: context.canStart,
            canAdmit: context.canAdmit,
            allowCooldownRetry: context.allowCooldownRetry,
          ),
        );
      } finally {
        _waiting.remove(queuedCancellation);
      }
      var started = false;
      try {
        if (_closed) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
          );
        }
        if (options.cancelToken?.isCancelled ?? false) {
          throw options.cancelToken!.cancelError!;
        }
        if (!(context.canStart?.call() ?? true)) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
          );
        }
        if (!(context.canAdmit?.call() ?? true)) {
          throw DioException(
            requestOptions: options,
            error: const ApiAdmissionExpired(),
          );
        }
        // Shared auth ownership can change after reservation but before the
        // physical exchange. Reconsider only an undispatched reservation;
        // running credential rotation keeps its original accounting.
        if (permit.isPassive != context.isPassive) {
          permit.abandon();
          continue;
        }
        context.onStarted?.call();
        started = true;
        transportState?.call(current.uri, true);
        final originalBody = await delegate.fetch(
          current.copyWith(followRedirects: false),
          requestStream,
          cancelFuture,
        );
        final trackedUri = current.uri;
        final body = _PermitBody(
          originalBody,
          permit,
          onFinished: () => transportState?.call(trackedUri, false),
        ).response;
        if (body.statusCode == 429) {
          final header = _header(body.headers, 'retry-after');
          options.extra[_cooldownKey] = ApiCooldownException(
            key,
            coordinator.recordRateLimit(key, retryAfter: header),
          );
        }
        options.extra[_actualQuotaKey] = key;
        final location = _header(body.headers, 'location');
        final redirect = const [
          301,
          302,
          303,
          307,
          308,
        ].contains(body.statusCode);
        if (!redirect ||
            !options.followRedirects ||
            !isApiSafeRead(options) ||
            !const ['GET', 'HEAD'].contains(options.method.toUpperCase()) ||
            location == null) {
          return body;
        }
        await body.stream.drain<void>();
        if (redirects++ >= options.maxRedirects) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            message: 'Too many data redirects',
          );
        }
        final target = current.uri.resolve(location);
        if ((target.scheme != 'http' && target.scheme != 'https') ||
            target.userInfo.isNotEmpty) {
          throw DioException(
            requestOptions: options,
            message: 'Unsupported redirect scheme',
          );
        }
        final headers = Map<String, dynamic>.of(current.headers);
        if (ApiQuotaKey.fromUri(target) != key) {
          headers.removeWhere(
            (name, _) => !const [
              'accept',
              'accept-encoding',
              'accept-language',
              'user-agent',
              'range',
            ].contains(name.toLowerCase()),
          );
        }
        current = current.copyWith(
          path: target.toString(),
          baseUrl: '',
          queryParameters: const {},
          headers: headers,
        );
      } catch (_) {
        if (started) {
          permit.release();
          transportState?.call(current.uri, false);
        } else {
          permit.abandon();
        }
        rethrow;
      }
    }
  }

  @override
  void close({bool force = false}) {
    _closed = true;
    for (final token in _waiting) {
      token.cancel();
    }
    delegate.close(force: force);
  }
}

String? _header(Map<String, List<String>> headers, String name) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == name && entry.value.isNotEmpty) {
      return entry.value.first;
    }
  }
  return null;
}

final class _PermitBody {
  _PermitBody(this.original, this.permit, {this.onFinished}) {
    final output = StreamController<Uint8List>(sync: true);
    output.onListen = () {
      subscription = original.stream.listen(
        output.add,
        onError: (Object error, StackTrace stack) {
          output.addError(error, stack);
        },
        onDone: () {
          finish();
          output.close();
        },
      );
    };
    output.onPause = () => subscription?.pause();
    output.onResume = () => subscription?.resume();
    output.onCancel = cancel;
    response = ResponseBody(
      output.stream,
      original.statusCode,
      statusMessage: original.statusMessage,
      isRedirect: original.isRedirect,
      redirects: original.redirects,
      headers: original.headers,
      onClose: () {
        // Forward Dio adapter cleanup; its internal close callback is the only
        // way a decorating adapter can preserve transport-specific disposal.
        // ignore: invalid_use_of_internal_member
        original.close();
        unawaited(cancel());
      },
    )..extra = original.extra;
  }
  final ResponseBody original;
  final ApiRequestPermit permit;
  final void Function()? onFinished;
  var _finished = false;
  void finish() {
    if (_finished) return;
    _finished = true;
    permit.release();
    onFinished?.call();
  }

  StreamSubscription<Uint8List>? subscription;
  late final ResponseBody response;
  Future<void>? _cancellation;
  Future<void> cancel() => _cancellation ??= _cancel();
  Future<void> _cancel() async {
    try {
      await (subscription ??= original.stream.listen(null)).cancel();
    } finally {
      finish();
    }
  }
}

/// Auth ownership uses the normalized token attached by the request interceptor,
/// including a caller token passed directly through Dio Options.
ApiRequestContext apiRequestContextFor(RequestOptions options) {
  final context =
      options.extra[apiRequestContextKey] as ApiRequestContext? ??
      ApiRequestContext.current();
  return ApiRequestContext(
    requestClass: context.requestClass,
    requestClassResolver: context.requestClassResolver,
    allowCooldownRetryResolver: context.allowCooldownRetryResolver,
    onDataTransport: context.onDataTransport,
    changes: context.changes,
    admissionBehavior: context.admissionBehavior,
    replaySafety: context.replaySafety,
    cancelToken: options.cancelToken,
    canStart: context.canStart,
    canAdmit: context.canAdmit,
    onStarted: context.onStarted,
    allowCooldownRetry: context.allowCooldownRetry,
  );
}

final class ApiRequestInterceptor extends Interceptor {
  ApiRequestInterceptor(this.dio, this.coordinator);
  final Dio dio;
  final ApiRequestCoordinator coordinator;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra.putIfAbsent(
      apiRequestContextKey,
      () => ApiRequestContext.current(),
    );
    final context = options.extra[apiRequestContextKey] as ApiRequestContext;
    final token = context.cancelToken;
    if (token != null && !identical(token, options.cancelToken)) {
      final existing = options.cancelToken;
      if (existing == null) {
        options.cancelToken = token;
      } else {
        final merged = CancelToken();
        for (final source in [existing, token]) {
          if (source.isCancelled) {
            merged.cancel(source.cancelError);
          } else {
            source.whenCancel.then((e) => merged.cancel(e));
          }
        }
        options.cancelToken = merged;
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.extra[apiMediaRequestKey] == true) {
      handler.next(response);
      return;
    }
    if (_pixivRateLimited(response)) {
      final key = ApiQuotaKey.fromUri(response.requestOptions.uri);
      response.requestOptions.extra[_cooldownKey] = ApiCooldownException(
        key,
        coordinator.recordRateLimit(
          key,
          retryAfter: response.headers.value('retry-after'),
        ),
      );
    }
    final cooldown = response.requestOptions.extra[_cooldownKey];
    if (cooldown is ApiCooldownException) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: cooldown,
        ),
        true,
      );
    } else {
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        coordinator.recordSuccess(
          response.requestOptions.extra[_actualQuotaKey] as ApiQuotaKey? ??
              ApiQuotaKey.fromUri(response.requestOptions.uri),
        );
      }
      handler.next(response);
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final error = err;
    final options = error.requestOptions;
    if (options.extra[apiMediaRequestKey] == true) {
      handler.next(error);
      return;
    }
    var cooldown = options.extra[_cooldownKey] as ApiCooldownException?;
    if (error.error case final ApiCooldownException failure) {
      cooldown ??= failure;
    }
    if (cooldown == null && error.response != null) {
      final response = error.response!;
      if (_pixivRateLimited(response)) {
        final key = ApiQuotaKey.fromUri(options.uri);
        cooldown = ApiCooldownException(
          key,
          coordinator.recordRateLimit(
            key,
            retryAfter: response.headers.value('retry-after'),
          ),
        );
      }
    }
    final context =
        options.extra[apiRequestContextKey] as ApiRequestContext? ??
        const ApiRequestContext();
    final alreadyRetried =
        options.extra[apiRetryKey] == true ||
        options.extra[apiNegotiatedKey] == true ||
        options.extra['pixivAuthRetried'] == true ||
        options.extra['boorusama.ddos_protection_retry'] == true;
    final wait = cooldown == null
        ? null
        : coordinator.cooldownRemaining(cooldown.quota);
    final transient = const [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    ].contains(error.type);
    final brief =
        cooldown != null &&
        context.allowCooldownRetry &&
        wait != null &&
        !wait.isNegative &&
        wait <= const Duration(seconds: 2);
    if (!alreadyRetried &&
        isApiSafeRead(options) &&
        (transient || brief) &&
        !(options.cancelToken?.isCancelled ?? false)) {
      if (!(context.canAdmit?.call() ?? true)) {
        handler.next(
          cooldown == null ? error : error.copyWith(error: cooldown),
        );
        return;
      }
      options.extra[apiRetryKey] = true;
      try {
        if (brief) {
          final policyChanged = Completer<void>();
          final subscription = context.changes?.listen((_) {
            if ((!context.allowCooldownRetry ||
                    !(context.canAdmit?.call() ?? true)) &&
                !policyChanged.isCompleted) {
              policyChanged.complete();
            }
          });
          final delay = Completer<void>();
          final waitTimer = Timer(wait, delay.complete);
          final cancellation = await Future.any<Object?>([
            delay.future,
            if (options.cancelToken != null) options.cancelToken!.whenCancel,
            policyChanged.future,
          ]);
          waitTimer.cancel();
          await subscription?.cancel();
          if (cancellation is DioException) throw cancellation;
          if (!context.allowCooldownRetry ||
              !(context.canAdmit?.call() ?? true)) {
            handler.next(error.copyWith(error: cooldown));
            return;
          }
        }
        options.extra.remove(_cooldownKey);
        handler.resolve(await dio.fetch(options));
        return;
      } on DioException catch (e) {
        handler.next(
          e.error is ApiAdmissionExpired
              ? cooldown == null
                    ? error
                    : error.copyWith(error: cooldown)
              : e,
        );
        return;
      }
    }
    if (cooldown != null) options.extra[_cooldownKey] = cooldown;
    handler.next(cooldown == null ? error : error.copyWith(error: cooldown));
  }

  bool _pixivRateLimited(Response response) {
    if (response.requestOptions.uri.host != 'app-api.pixiv.net') return false;
    dynamic data = response.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return false;
      }
    }
    if (data is! Map || data['error'] is! Map) return false;
    final error = data['error'] as Map;
    return '${error['message'] ?? error['user_message'] ?? ''}'
        .toLowerCase()
        .contains('rate limit');
  }
}
