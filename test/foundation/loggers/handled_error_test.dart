import 'dart:io';

import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/common.dart';

void main() {
  test(
    'retains safe storage codes without messages, paths or SQL payloads',
    () {
      final logger = AppLogger();
      for (final error in [
        const FileSystemException(
          'private-message',
          '/private-path',
          OSError('private-os-message', 28),
        ),
        SqliteException(
          extendedResultCode: 2067,
          message: 'private-message',
          explanation: 'private-explanation',
          causingStatement: 'private-sql',
          parametersToStatement: ['private-parameter'],
          operation: 'private-operation',
          offset: 9,
        ),
      ]) {
        logger.handledError('Storage', 'save', error: error);
      }
      final text = logger.dump();
      expect(text, contains('os_error=28'));
      expect(text, contains('sqlite_result=19'));
      expect(text, contains('sqlite_extended=2067'));
      expect(text, contains('sqlite_offset=9'));
      expect(text, isNot(contains('private-')));
    },
  );

  test(
    'retains a bounded nested OS cause without socket or request details',
    () {
      final logger = AppLogger();
      logger.handledError(
        'Network',
        'connect',
        error: DioException(
          requestOptions: RequestOptions(
            path: 'https://private-host/private-query',
          ),
          type: DioExceptionType.connectionError,
          error: const SocketException(
            'private-message',
            osError: OSError('private-os-message', 13),
          ),
        ),
      );
      expect(logger.dump(), contains('cause_os_error=13'));
      expect(logger.dump(), isNot(contains('private-')));
    },
  );

  test(
    'retains operation, technical cause and source frames without payloads',
    () {
      final logger = AppLogger();
      final request = RequestOptions(
        path: 'https://private.example/user/token?tags=private-query',
        headers: {'Authorization': 'Bearer secret-token'},
      );
      logger.handledError(
        'Search',
        'load_page',
        error: DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: request,
            statusCode: 503,
            data: {'password': 'private-payload'},
          ),
          message: 'secret-token private-query',
          error: const FormatException('private-payload', 'secret-token', 7),
        ),
        stackTrace: StackTrace.fromString(
          '#0 Search.load (package:boorusama/core/search/search.dart:12:3)\n'
          '#1 remote (https://private.example/secret-token:1:2)\n'
          '#2 local (/home/private-user/secret-token.dart:5:9)',
        ),
        outcome: 'cached_page_retained',
      );

      final message = logger.dump();
      expect(message, contains('load_page'));
      expect(message, contains('DioException'));
      expect(message, contains('badResponse'));
      expect(message, contains('http_status=503'));
      expect(message, contains('FormatException'));
      expect(message, contains('offset=7'));
      expect(
        message,
        contains('package:boorusama/core/search/search.dart:12:3'),
      );
      expect(message, contains('cached_page_retained'));
      for (final privateValue in [
        'private.example',
        'secret-token',
        'private-query',
        'private-payload',
        'private-user',
        'Authorization',
      ]) {
        expect(message, isNot(contains(privateValue)));
      }
      expect(logger.logs.single.sensitiveMessage, isNull);
    },
  );

  test('routine Dio cancellation produces no diagnostic', () {
    final logger = AppLogger();
    logger.handledError(
      'Search',
      'load_page',
      error: DioException(
        requestOptions: RequestOptions(path: '/private'),
        type: DioExceptionType.cancel,
      ),
    );
    expect(logger.logs, isEmpty);
  });

  test('does not evaluate arbitrary exception messages', () {
    final logger = AppLogger();
    logger.handledError('Storage', 'decode', error: _UnsafeException());
    expect(logger.logs.single.safeMessage, contains('_UnsafeException'));
  });

  test('bounds stack output and reports fallback at warning level', () {
    final logger = AppLogger();
    logger.handledError(
      'Storage',
      'decode',
      error: const FormatException('secret'),
      stackTrace: StackTrace.fromString(
        List.generate(
          100,
          (index) => '#$index decode (package:boorusama/file.dart:$index:1)',
        ).join('\n'),
      ),
      outcome: 'generic_post_retained',
      level: LogLevel.warning,
    );
    expect(logger.logs.single.level, LogLevel.warning);
    expect(
      RegExp('package:boorusama/').allMatches(logger.dump()),
      hasLength(8),
    );
    expect(logger.dump(), isNot(contains('secret')));
  });
}

class _UnsafeException implements Exception {
  @override
  String toString() => throw StateError('must not read private payload');
}
