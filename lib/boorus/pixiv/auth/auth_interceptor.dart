// Dart imports:
import 'dart:async';

// Package imports:
import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import '../../../core/http/client/coordination.dart';

/// Marker written into `RequestOptions.extra` before a 401 is retried, so a
/// retried request is never refreshed-and-retried a second time.
const kPixivAuthRetryKey = 'pixivAuthRetried';

/// Builds the client used for the `/auth/token` calls.
///
/// The [Dio] behind it is deliberately BARE — `PixivAuthClient`'s default
/// constructor creates a plain `Dio` with no interceptors at all, in
/// particular no `LoggingInterceptor`: the token response body contains both
/// the access and the refresh token, and this app's logs are user-exportable
/// (copied to the clipboard, written to Downloads, pasted into issues), so
/// logging that traffic would be a public credential disclosure. Never route
/// token traffic through the app's shared Dio, and never pass
/// `skipCertificateVerification` here.
PixivAuthClient createPixivAuthClient({Dio? dio}) => PixivAuthClient(dio: dio);

typedef PixivTokenRefresher = Future<PixivTokens> Function(String refreshToken);

/// Attaches `Authorization: Bearer <access token>` to every Pixiv app-api
/// request, refreshes the access token before it expires, and retries a 401
/// once after refreshing.
///
/// Pixiv rotates the refresh token on every token response, so
/// [onTokenRefreshed] fires with the newest pair and its caller is
/// responsible for persisting it.
///
/// No log line here may take a token, an authorization code or a code
/// verifier as an argument — only lengths, booleans and error types.
class PixivAuthInterceptor extends Interceptor {
  PixivAuthInterceptor({
    required String refreshToken,
    PixivTokenRefresher? refresher,
    this.onTokenRefreshed,
    this.onAuthFailed,
    this.onLog,
    this.fallbackLifetime = const Duration(hours: 1),
    this.refreshBuffer = const Duration(minutes: 5),
    this.failureCooldown = const Duration(minutes: 1),
  }) : _refreshToken = refreshToken,
       _refresher =
           refresher ??
           ((token) => createPixivAuthClient().refresh(refreshToken: token));

  /// Assumed access-token lifetime when the token endpoint omits
  /// `expires_in`. Pixiv's real value is 3600s.
  final Duration fallbackLifetime;

  /// How long before expiry a refresh is triggered proactively. With
  /// Pixiv's one-hour tokens this refreshes at the ~55 minute mark, so a
  /// screenful of thumbnails never has to discover the expiry via 401s.
  final Duration refreshBuffer;

  /// After a failed refresh, how long to wait before attempting another
  /// one. Without this, every request of a dead session would fire its own
  /// token request, because there is no access token to reuse.
  final Duration failureCooldown;

  final void Function(PixivTokens tokens)? onTokenRefreshed;
  final void Function()? onAuthFailed;
  final void Function(String message)? onLog;

  final PixivTokenRefresher _refresher;

  String _refreshToken;
  String? _accessToken;
  DateTime? _accessTokenExpiry;
  DateTime? _lastFailureAt;

  /// The single-flight latch (FIX 6a). Requests arriving while a refresh is
  /// in progress await THIS future and then attach the fresh token, instead
  /// of bailing out and failing.
  final _refreshRegistry = ApiAuthRefreshRegistry();

  Dio? _dio;
  DioException? _lastRefreshError;

  /// The Dio this interceptor is installed on. A 401 is retried through it
  /// rather than through a throwaway `Dio`, so the retry still goes through
  /// the proxy settings, protocol selection and rate limiter that Dio
  /// carries.
  void attach(Dio dio) => _dio = dio;

  bool get _isExpiring {
    final expiry = _accessTokenExpiry;
    if (_accessToken == null || expiry == null) return true;

    return DateTime.now().isAfter(expiry.subtract(refreshBuffer));
  }

  bool get _isCoolingDown {
    final failedAt = _lastFailureAt;
    if (failedAt == null) return false;

    return DateTime.now().difference(failedAt) < failureCooldown;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final refreshError = _lastRefreshError;
    final retryAt = switch (refreshError?.error) {
      ApiCooldownException(:final retryAt) => retryAt,
      _ => null,
    };
    if (refreshError != null &&
        (retryAt == null || !DateTime.now().toUtc().isBefore(retryAt))) {
      _lastRefreshError = null;
      _accessTokenExpiry = null;
      _lastFailureAt = null;
    }
    if (_isExpiring && !_isCoolingDown) {
      await _refreshOnce(options);
    }

    if (_lastRefreshError case final error?) {
      handler.reject(error.copyWith(requestOptions: options));
      return;
    }
    if (options.cancelToken?.isCancelled ?? false) {
      handler.reject(options.cancelToken!.cancelError!);
      return;
    }
    _applyBearer(options);

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra[kPixivAuthRetryKey] == true;

    if (!isUnauthorized ||
        alreadyRetried ||
        _isCoolingDown ||
        !isApiSafeRead(err.requestOptions) ||
        (err.requestOptions.cancelToken?.isCancelled ?? false)) {
      handler.next(err);
      return;
    }

    final refreshed = await _refreshOnce(err.requestOptions);
    if (!refreshed) {
      if (_lastRefreshError case final error?) {
        handler.next(error.copyWith(requestOptions: err.requestOptions));
        return;
      }
      handler.next(err);
      return;
    }

    final dio = _dio;
    if (dio == null) {
      onLog?.call('Cannot retry after refresh: no Dio attached');
      handler.next(err);
      return;
    }

    final options = err.requestOptions;
    options.extra[kPixivAuthRetryKey] = true;
    _applyBearer(options);

    try {
      handler.resolve(await dio.fetch(options));
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }

  /// Runs at most one refresh at a time; concurrent callers get the same
  /// future and therefore the same outcome.
  Future<bool> _refreshOnce(RequestOptions options) async {
    try {
      return await runWithApiRequestContext(
        apiRequestContextFor(options),
        () => _refreshRegistry.run(this, _refresh),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) return false;
      rethrow;
    }
  }

  Future<bool> _refresh() async {
    _lastRefreshError = null;
    onLog?.call('Refreshing access token');

    try {
      final tokens = await _refresher(_refreshToken);
      final accessToken = tokens.accessToken;
      final refreshToken = tokens.refreshToken;

      if (accessToken == null || accessToken.isEmpty) {
        onLog?.call('Token response carried no access token');
        _lastFailureAt = DateTime.now();
        return false;
      }

      _accessToken = accessToken;
      _accessTokenExpiry = DateTime.now().add(
        switch (tokens.expiresIn) {
          final int seconds when seconds > 0 => Duration(seconds: seconds),
          _ => fallbackLifetime,
        },
      );
      _lastFailureAt = null;

      // Pixiv rotates the refresh token on every response; keeping the old
      // one would guarantee a forced logout on the next app start.
      if (refreshToken != null && refreshToken.isNotEmpty) {
        _refreshToken = refreshToken;
      }

      onLog?.call(
        'Access token refreshed, expires in ${tokens.expiresIn}s, '
        'rotated refresh token: ${refreshToken != null}',
      );

      onTokenRefreshed?.call(tokens);

      return true;
    } on PixivAuthException catch (e) {
      // The grant itself was rejected (expired or already-rotated refresh
      // token) — re-login is the only way out.
      onLog?.call('Refresh token rejected (code: ${e.code})');
      _accessToken = null;
      _accessTokenExpiry = null;
      _lastFailureAt = DateTime.now();
      onAuthFailed?.call();
      return false;
    } on DioException catch (e) {
      if (e.error is ApiCooldownException ||
          e.type == DioExceptionType.cancel) {
        _lastRefreshError = e;
        _lastFailureAt = DateTime.now();
        return false;
      }
      _lastFailureAt = DateTime.now();
      return false;
    } catch (e) {
      // Anything else (offline, rate limited, DNS) is transient: do not
      // tell the user their session expired over a dropped connection.
      onLog?.call('Token refresh failed: ${e.runtimeType}');
      _lastFailureAt = DateTime.now();
      return false;
    }
  }

  void _applyBearer(RequestOptions options) {
    final token = _accessToken;
    if (token == null) return;

    // Dio keeps request headers in a case-insensitive map, so this replaces
    // whatever `Authorization` the client attached per request rather than
    // adding a second one. Do NOT reach for `removeWhere` to clear the old
    // value first: on that map the VM feeds its internal deleted-key
    // sentinel to the custom `equals`, which throws a type error mid-retry.
    options.headers['Authorization'] = 'Bearer $token';
  }
}
