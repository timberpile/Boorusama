/// Base type for every exception this client raises.
///
/// [message] must never contain a token, authorization code, code verifier,
/// or any other secret — it is surfaced to app-level loggers that may end up
/// in a user-exportable log file.
sealed class PixivException implements Exception {
  const PixivException(this.message);

  final String message;

  @override
  String toString() => 'PixivException: $message';
}

/// The API returned an `{"error": ...}` body (which can arrive with an HTTP
/// 200 status) that isn't one of the more specific cases below.
class PixivApiException extends PixivException {
  const PixivApiException(super.message);

  @override
  String toString() => 'PixivApiException: $message';
}

/// The API reported it is rate-limiting this client.
///
/// This only surfaces the condition — enforcing a back-off is an app-layer
/// concern (later slice).
class PixivRateLimitException extends PixivException {
  const PixivRateLimitException(
    super.message, {
    this.retryAfter = const Duration(seconds: 300),
  });

  /// Canonical back-off hint; the API does not return a `Retry-After` value.
  final Duration retryAfter;

  @override
  String toString() => 'PixivRateLimitException: $message';
}

/// The refresh or authorization-code grant was rejected (e.g. an expired or
/// already-rotated refresh token), so the app should force a re-login.
class PixivAuthException extends PixivException {
  const PixivAuthException(super.message, {this.code});

  /// The auth error code from the envelope (e.g. `invalid_grant`), if any.
  final String? code;

  @override
  String toString() => 'PixivAuthException: $message';
}
