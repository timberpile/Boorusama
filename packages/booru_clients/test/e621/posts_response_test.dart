import 'package:booru_clients/e621.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

E621Client clientFor(Object? body) => E621Client(
  baseUrl: 'https://e926.net',
  dio: Dio(BaseOptions(baseUrl: 'https://e926.net'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: body,
            ),
          );
        },
      ),
    ),
);

void main() {
  for (final body in [
    null,
    <String, Object>{},
    {'success': false, 'message': 'Temporary restriction'},
    {'posts': null},
    {'success': false, 'posts': <Object>[]},
  ]) {
    test(
      'invalid successful HTTP payload cannot become history exhaustion: $body',
      () async {
        await expectLater(clientFor(body).getPosts(), throwsFormatException);
      },
    );
  }
  for (final body in [
    <Object>[],
    {'posts': <Object>[]},
  ]) {
    test('valid empty source response remains empty: $body', () async {
      expect(await clientFor(body).getPosts(), isEmpty);
    });
  }
}
