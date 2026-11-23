import 'package:booru_clients/danbooru.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  for (final exact in [false, true]) {
    test(
      'count preserves defaults and supports fresh exact requests: $exact',
      () async {
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (request, handler) {
                expect(request.path, '/counts/posts.json');
                expect(request.queryParameters, {
                  'tags': 'parent:12480551 rating:g',
                  if (exact) 'estimate_count': false,
                  if (exact) 'skip_cache': true,
                });
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: request,
                    statusCode: 200,
                    data: {
                      'counts': {'posts': 3},
                    },
                  ),
                );
              },
            ),
          );
        final client = DanbooruClient(baseUrl: 'https://source.test', dio: dio);
        expect(
          await client.countPosts(
            tags: ['parent:12480551', 'rating:g'],
            estimateCount: !exact,
            skipCache: exact,
          ),
          3,
        );
        dio.close();
      },
    );
  }
  test('fresh-count network failure remains unknown', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.reject(
            DioException(
              requestOptions: request,
              type: DioExceptionType.connectionError,
            ),
          ),
        ),
      );
    expect(
      await DanbooruClient(
        baseUrl: 'https://source.test',
        dio: dio,
      ).countPosts(tags: ['parent:1'], estimateCount: false, skipCache: true),
      isNull,
    );
    dio.close();
  });
}
