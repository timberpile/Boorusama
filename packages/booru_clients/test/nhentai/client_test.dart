import 'dart:async';
import 'package:booru_clients/nhentai.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  late Dio dio;
  late NhentaiClient client;
  final requests = <RequestOptions>[];
  Object? response;
  setUp(() {
    requests.clear();
    response = {'result': [], 'num_pages': 0, 'total': 0};
    dio = Dio(BaseOptions(baseUrl: 'https://unrelated.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.resolve(
            Response(requestOptions: request, statusCode: 200, data: response),
          );
        },
      ),
    );
    client = NhentaiClient(dio: dio);
  });
  tearDown(() => dio.close(force: true));
  test(
    'bodyless exact API GET preserves query and raw server pagination',
    () async {
      response = {
        'result': [
          for (var i = 0; i < 120; i++) {'id': i + 1},
        ],
        'num_pages': 40,
        'total': 4774,
        'per_page': 120,
      };
      final page = await client.getGalleries(
        page: 2,
        perPage: 5,
        query: 'tag:synthetic /?',
      );
      final r = requests.single;
      expect(r.uri.host, 'nhentai.net');
      expect(r.uri.path, '/api/v2/search');
      expect(r.uri.queryParameters, {
        'page': '2',
        'per_page': '5',
        'query': 'tag:synthetic /?',
      });
      expect(r.method, 'GET');
      expect(r.data, isNull);
      expect(r.followRedirects, isFalse);
      expect(
        r.headers.keys.where(
          (k) => ['authorization', 'cookie'].contains(k.toLowerCase()),
        ),
        isEmpty,
      );
      expect(page.rawCount, 120);
      expect(page.hasMore, isTrue);
      expect(page.reportedPerPage, 120);
    },
  );
  test(
    'tag categories and bounded ID batches use verified parameter forms',
    () async {
      response = [
        {'id': 9, 'type': 'tag', 'name': 'synthetic'},
      ];
      expect((await client.getTagsByIds([9, 9])).single.id, 9);
      expect(requests.single.uri.queryParameters, {'ids': '9'});
      await expectLater(
        client.getTagsByIds(List.generate(101, (i) => i + 1)),
        throwsArgumentError,
      );
      response = {'result': [], 'num_pages': 0, 'total': 0};
      requests.clear();
      await client.getTagCatalog('tag', page: 2, perPage: 5);
      expect(requests.single.uri.path, '/api/v2/tags/tag');
      expect(requests.single.uri.queryParameters, {
        'page': '2',
        'per_page': '5',
        'sort': 'popular',
      });
      await expectLater(client.getTagCatalog('general'), throwsArgumentError);
    },
  );
  test(
    'foreign responses do not enter a requested Gallery or tag identity',
    () async {
      response = {'id': 2};
      await expectLater(client.getGallery(1), throwsFormatException);
      response = [
        {'id': 2, 'type': 'tag', 'name': 'synthetic'},
      ];
      await expectLater(client.getTagsByIds([1]), throwsFormatException);
    },
  );
  test('cancellation reaches the actual pending Dio request', () async {
    dio.interceptors.clear();
    final started = Completer<void>();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          started.complete();
          options.cancelToken!.whenCancel.then(
            (error) => handler.reject(error),
          );
        },
      ),
    );
    final token = CancelToken();
    final read = client.getGalleries(cancelToken: token);
    final cancelled = expectLater(
      read,
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    await started.future;
    token.cancel('fixture disposed');
    await cancelled;
  });
}
