import 'dart:convert';

import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'mock_pixiv_server.dart';

void main() {
  late MockPixivServer server;
  late PixivClient client;
  const path = '/v2/illust/related';

  setUp(() async {
    server = MockPixivServer();
    client = PixivClient(baseUrl: await server.start(), accessToken: 'fixture');
  });
  tearDown(() => server.stop());

  test(
    'uses the anchor and preserves each indexed continuation value',
    () async {
      server.responseBody = jsonEncode({
        'illusts': [
          {'id': 100},
          {'id': 200},
        ],
        'next_url':
            '$kPixivApiBaseUrl$path?illust_id=42&filter=for_ios'
            '&seed_illust_ids%5B0%5D=42&viewed%5B0%5D=100&viewed%5B1%5D=200',
      });

      final first = await client.getRelatedIllusts(illustId: 42);
      expect(first.illusts.map((dto) => dto.id), [100, 200]);
      expect(server.lastRequest!.requestedUri.path, path);
      expect(server.lastRequest!.requestedUri.queryParameters, {
        'illust_id': '42',
        'filter': 'for_ios',
      });

      server.responseBody = '{"illusts":[{"id":300}],"next_url":null}';
      final next = await client.getRelatedIllusts(
        illustId: 42,
        cursor: first.nextCursor,
      );
      expect(next.illusts.single.id, 300);
      expect(next.nextCursor, isNull);
      expect(server.lastRequest!.headers['authorization'], 'Bearer fixture');
      expect(server.lastRequest!.requestedUri.queryParameters, {
        'illust_id': '42',
        'filter': 'for_ios',
        'seed_illust_ids[0]': '42',
        'viewed[0]': '100',
        'viewed[1]': '200',
      });

      await expectLater(
        client.getRelatedIllusts(illustId: 43, cursor: first.nextCursor),
        throwsArgumentError,
      );
    },
  );

  for (final url in [
    'https://other.example$path?illust_id=42&filter=for_ios',
    '$kPixivApiBaseUrl/v1/illust/detail?illust_id=42&filter=for_ios',
    '$kPixivApiBaseUrl$path?illust_id=43&filter=for_ios',
    '$kPixivApiBaseUrl$path?illust_id=42&filter=for_ios&viewed[0]=1&viewed[0]=2',
  ]) {
    test('rejects a mismatched or ambiguous continuation $url', () async {
      server.responseBody = jsonEncode({'illusts': [], 'next_url': url});
      await expectLater(
        client.getRelatedIllusts(illustId: 42),
        throwsFormatException,
      );
    });
  }

  test(
    'does not follow redirects with the Pixiv authorization header',
    () async {
      server.statusCode = 302;
      server.responseHeaders = {'location': 'https://other.example/related'};
      await expectLater(
        client.getRelatedIllusts(illustId: 42, cancelToken: CancelToken()),
        throwsA(isA<PixivException>()),
      );
    },
  );
}
