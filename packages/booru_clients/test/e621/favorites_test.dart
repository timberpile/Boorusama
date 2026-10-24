import 'package:booru_clients/e621.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  for (final wrapped in [false, true]) {
    test(
      'favorites preserves API order and pagination (wrapped=$wrapped)',
      () async {
        final requests = <RequestOptions>[];
        final posts = [
          for (final id in [7, 90, 2]) {'id': id},
        ];
        final dio = Dio(BaseOptions(baseUrl: 'https://e926.net'))
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                requests.add(options);
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: wrapped ? {'posts': posts} : posts,
                    statusCode: 200,
                  ),
                );
              },
            ),
          );
        final client = E621Client(
          baseUrl: 'https://e926.net',
          dio: dio,
          login: 'fixture',
          apiKey: 'fixture-key',
        );
        final result = await client.getFavorites(page: 2, limit: 100);
        expect(result.map((p) => p.id), [7, 90, 2]);
        expect(requests.single.path, '/favorites.json');
        expect(requests.single.queryParameters, {'page': 2, 'limit': 100});
        expect(requests.single.headers['Authorization'], startsWith('Basic '));
      },
    );
  }
}
