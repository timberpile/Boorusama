import 'package:booru_clients/philomena.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  test(
    'native q keeps field and URL underscores while sort uses API parameters',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      addTearDown(() => dio.close(force: true));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'images': [], 'total': 0},
              ),
            );
          },
        ),
      );
      final client = PhilomenaClient(dio: dio, baseUrl: 'https://example.test');
      await client.getImages(
        nativeQuery:
            'created_at.gte:2026-10-01,source_url:https://example.test/a_b.png',
        tags: ['ignored_fallback'],
        sortField: 'score',
        sortDirection: 'desc',
        page: 2,
        perPage: 20,
      );
      final params = requests.single.queryParameters;
      expect(
        params['q'],
        'created_at.gte:2026-10-01,source_url:https://example.test/a_b.png',
      );
      expect(params['sf'], 'score');
      expect(params['sd'], 'desc');
      expect(params['page'], 2);
      expect(params['per_page'], 20);
      requests.clear();
      await client.getImages(tags: ['twilight_sparkle', 'safe']);
      expect(requests.single.queryParameters['q'], 'twilight sparkle,safe');
    },
  );
}
