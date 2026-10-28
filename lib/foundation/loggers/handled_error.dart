import 'package:dio/dio.dart';
import 'package:sqlite3/common.dart';

import 'handled_error_stub.dart' if (dart.library.io) 'handled_error_io.dart';
import 'logger.dart';

/// Diagnostic context must be code-owned operation/outcome identifiers, never
/// a query, file name, profile value or server-provided text. Exception messages
/// and payloads are deliberately not read, even when sensitive logs are enabled.
extension HandledErrorLogger on Logger {
  void handledError(
    String service,
    String operation, {
    required Object error,
    StackTrace? stackTrace,
    String? outcome,
    LogLevel level = LogLevel.error,
  }) {
    if (error is DioException && error.type == DioExceptionType.cancel) return;

    final details = <String>[
      operation,
      _technicalCause(error),
      if (outcome != null) 'outcome=$outcome',
    ];
    final frames = stackTrace == null
        ? const <String>[]
        : _sourceFrames(stackTrace);
    log(
      service,
      '${details.join('; ')}${frames.isEmpty ? '' : '\n${frames.join('\n')}'}',
      level: level,
    );
  }
}

String _technicalCause(Object error) {
  final details = <String>['error=${error.runtimeType}'];
  details.addAll(_safeErrorDetails(error));
  if (error is DioException) {
    details.add('request_type=${error.type.name}');
    if (error.response?.statusCode case final status?) {
      details.add('http_status=$status');
    }
    final cause = error.error;
    if (cause != null && !identical(cause, error)) {
      // Do not traverse arbitrary wrapper graphs or serialize their payloads.
      details.add('cause=${cause.runtimeType}');
      details.addAll(_safeErrorDetails(cause, prefix: 'cause_'));
    }
  }
  return details.join('; ');
}

List<String> _safeErrorDetails(Object error, {String prefix = ''}) => [
  if (error is FormatException && error.offset != null)
    '${prefix}offset=${error.offset}',
  ...platformErrorDetails(error).map((detail) => '$prefix$detail'),
  if (error is SqliteException) ...[
    '${prefix}sqlite_result=${error.resultCode}',
    '${prefix}sqlite_extended=${error.extendedResultCode}',
    if (error.offset != null) '${prefix}sqlite_offset=${error.offset}',
  ],
];

final _sourceLocation = RegExp(
  r'\(((?:package|dart):[A-Za-z0-9_./-]+:\d+(?::\d+)?)\)\s*$',
);

List<String> _sourceFrames(StackTrace stackTrace) => stackTrace
    .toString()
    .split('\n')
    .map((line) => _sourceLocation.firstMatch(line)?[1])
    .whereType<String>()
    .take(8)
    .toList();
