// Package imports:
import 'package:equatable/equatable.dart';

enum AppErrorType {
  cannotReachServer,
  handshakeFailed,
  certificateError,
  loadDataFromServerFailed,
}

sealed class BooruError extends Error {
  BooruError({
    required this.message,
  });

  final String message;
}

class AppError extends BooruError with Equatable {
  AppError({
    required this.type,
    required super.message,
  });

  final AppErrorType type;

  @override
  String toString() => 'Error: $message';

  @override
  List<Object?> get props => [type, message];
}

class ServerError extends BooruError with Equatable {
  ServerError({
    required this.httpStatusCode,
    required super.message,
  });

  final int? httpStatusCode;

  @override
  String toString() => 'HTTP error with status code $httpStatusCode';

  @override
  List<Object?> get props => [httpStatusCode, message];
}

class RateLimitedError extends ServerError {
  RateLimitedError(this.retryAt)
    : super(httpStatusCode: 429, message: 'API cooldown');
  final DateTime retryAt;
  @override
  List<Object?> get props => [...super.props, retryAt];
}

class RequestCancelledError extends BooruError {
  RequestCancelledError() : super(message: 'Request cancelled');
}

class UnknownError extends BooruError {
  UnknownError({
    required this.error,
    required super.message,
  });

  final Object error;

  @override
  String toString() => error.toString();
}

extension ServerErrorX on ServerError {
  bool get isServerError => switch (httpStatusCode) {
    final statusCode? => statusCode >= 500 && statusCode < 600,
    null => false,
  };
}
