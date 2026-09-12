import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('DioException toString safety', () {
    // Underwrites the safety of code elsewhere that logs a caught
    // DioException directly (e.g. `onLog('...: $e')`) — a secret must never
    // ride along even though the exception was built from a request that
    // carried one.
    test(
      'does not include the Authorization header value or the form body',
      () {
        final requestOptions = RequestOptions(
          path: '/auth/token',
          headers: {'Authorization': 'Bearer super-secret-token'},
          data: {
            'client_secret': 'client-secret-value',
            'refresh_token': 'refresh-token-value',
          },
        );
        final exception = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
        );

        final text = exception.toString();

        expect(text.contains('super-secret-token'), false);
        expect(text.contains('client-secret-value'), false);
        expect(text.contains('refresh-token-value'), false);
      },
    );
  });
}
