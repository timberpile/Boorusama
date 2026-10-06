import 'dart:math';
// Flutter imports:
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:i18n/i18n.dart';

// Project imports:
import 'error.dart';

export 'error.dart';

abstract interface class AppErrorTranslator {
  String translateAppError(BuildContext context, AppError error);
  String translateServerError(BuildContext context, ServerError error);
}

class DefaultAppErrorTranslator implements AppErrorTranslator {
  @override
  String translateAppError(
    BuildContext context,
    AppError error,
  ) => switch (error.type) {
    AppErrorType.cannotReachServer =>
      context.t.search.errors.cannot_reach_server,
    AppErrorType.handshakeFailed => context.t.search.errors.handshake_failed,
    AppErrorType.certificateError => context.t.search.errors.certificate_error,
    AppErrorType.loadDataFromServerFailed =>
      context.t.search.errors.failed_to_load_data,
  };

  @override
  String translateServerError(BuildContext context, ServerError error) =>
      error is RateLimitedError
      ? rateLimitWaitText(context, error.retryAt)
      : switch (error.httpStatusCode) {
          401 => context.t.search.errors.forbidden,
          403 => context.t.search.errors.access_denied,
          410 => context.t.search.errors.pagination_limit,
          422 => context.t.search.errors.tag_limit,
          429 => context.t.search.errors.rate_limited,
          500 => context.t.search.errors.database_timeout,
          502 => context.t.search.errors.max_capacity,
          503 => context.t.search.errors.down,
          _ => context.t.search.errors.unknown,
        };
}

String rateLimitWaitText(
  BuildContext context,
  DateTime retryAt, {
  DateTime? now,
}) {
  final seconds = max(
    0,
    (retryAt.difference(now ?? DateTime.now().toUtc()).inMilliseconds / 1000)
        .ceil(),
  );
  return seconds == 1
      ? context.t.search.errors.rate_limited_wait_one
      : context.t.search.errors.rate_limited_wait.replaceAll(
          '{seconds}',
          '$seconds',
        );
}
