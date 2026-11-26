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
    'popularity sorts use search with a wildcard only for unfiltered listings',
    () async {
      await client.getGalleries(page: 2);
      expect(requests.single.uri.path, '/api/v2/galleries');
      expect(requests.single.uri.queryParameters.containsKey('sort'), isFalse);
      for (final (sort, parameter) in [
        (NhentaiGallerySort.popularToday, 'popular-today'),
        (NhentaiGallerySort.popularWeek, 'popular-week'),
        (NhentaiGallerySort.popularAllTime, 'popular'),
      ]) {
        await client.getGalleries(page: 2, sort: sort);
        expect(requests.last.uri.path, '/api/v2/search');
        expect(requests.last.uri.queryParameters, {
          'page': '2',
          'query': '*',
          'sort': parameter,
        });
        await client.getGalleries(query: 'language:english', sort: sort);
        expect(requests.last.uri.queryParameters['query'], 'language:english');
        expect(requests.last.uri.queryParameters['sort'], parameter);
      }
    },
  );
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

  test(
    'discovery preserves the service shapes and uses fixed public GETs',
    () async {
      response = {'id': 47};
      expect(await client.getRandomGalleryId(), 47);
      response = [
        {'id': 93},
        {'id': 61},
      ];
      expect((await client.getPopularGalleries()).map((item) => item.id), [
        93,
        61,
      ]);
      response = {
        'result': [
          {'id': 61},
        ],
      };
      expect((await client.getRelatedGalleries(47)).single.id, 61);
      expect(requests.map((request) => request.uri.path), [
        '/api/v2/galleries/random',
        '/api/v2/galleries/popular',
        '/api/v2/galleries/47/related',
      ]);
      expect(
        requests.every(
          (request) => request.method == 'GET' && !request.uri.hasQuery,
        ),
        isTrue,
      );
      response = {'id': 0};
      await expectLater(client.getRandomGalleryId(), throwsFormatException);
    },
  );

  test(
    'account source reads real favorites continuation and confirmed mutations',
    () async {
      final account = NhentaiAccountClient(dio: dio);
      response = {'id': 12, 'username': 'fixture'};
      expect(await account.getAccount(), (id: 12, username: 'fixture'));
      response = {
        'result': [
          {'id': 19},
        ],
        'num_pages': 3,
        'per_page': 1,
      };
      final page = await account.getFavorites(2);
      expect(page.items.single.id, 19);
      expect(page.hasMore, isTrue);
      response = {'favorited': true};
      expect(await account.setFavorite(19, true), isTrue);
      response = {'favorited': false};
      expect(await account.setFavorite(19, false), isFalse);
      expect(requests.map((request) => (request.method, request.uri.path)), [
        ('GET', '/api/v2/user'),
        ('GET', '/api/v2/favorites'),
        ('POST', '/api/v2/galleries/19/favorite'),
        ('DELETE', '/api/v2/galleries/19/favorite'),
      ]);
      expect(requests[1].uri.queryParameters, {'page': '2'});
      expect(
        requests.every(
          (request) => request.data == null && !request.followRedirects,
        ),
        isTrue,
      );
      response = {'favorited': 'true'};
      await expectLater(account.setFavorite(19, true), throwsFormatException);
    },
  );
}
