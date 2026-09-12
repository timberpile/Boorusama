import 'dart:convert';

import 'package:booru_clients/pixiv.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'mock_pixiv_server.dart';

void main() {
  group('PixivClient requests', () {
    late MockPixivServer server;
    late String baseUrl;
    late Dio dio;

    setUp(() async {
      server = MockPixivServer();
      baseUrl = await server.start();
      dio = Dio(
        BaseOptions(baseUrl: baseUrl, headers: {'X-App-Header': 'keep-me'}),
      );
    });

    tearDown(() async {
      await server.stop();
    });

    test(
      'attaches every required header and leaves the shared Dio untouched',
      () async {
        final originalHeaders = Map<String, dynamic>.from(dio.options.headers);
        final client = PixivClient(
          dio: dio,
          accessToken: 'token-abc',
          acceptLanguage: 'ja-JP',
        );

        await client.getRanking(mode: PixivRankingMode.day);

        final headers = server.lastRequest!.headers;
        expect(headers['authorization'], 'Bearer token-abc');
        expect(headers['user-agent'], kPixivUserAgent);
        expect(headers['app-os'], kPixivAppOs);
        expect(headers['app-os-version'], kPixivAppOsVersion);
        expect(headers['app-version'], kPixivAppVersion);
        expect(headers['accept-language'], 'ja-JP');
        expect(headers['referer'], kPixivApiReferer);

        final clientTime = headers['x-client-time'];
        expect(clientTime, isNotNull);
        final expectedHash = md5
            .convert(utf8.encode('$clientTime$kPixivHashSecret'))
            .toString();
        expect(headers['x-client-hash'], expectedHash);

        expect(dio.options.headers, originalHeaders);
      },
    );

    test('formats a ranking date as YYYY-MM-DD when one is given', () async {
      final client = PixivClient(dio: dio, accessToken: 'token');

      await client.getRanking(
        mode: PixivRankingMode.week,
        date: DateTime(2026, 3, 4),
      );

      expect(server.lastRequest!.url.queryParameters['date'], '2026-03-04');
    });

    test(
      'omits the ranking date parameter entirely when none is given',
      () async {
        final client = PixivClient(dio: dio, accessToken: 'token');

        await client.getRanking(mode: PixivRankingMode.day);

        expect(
          server.lastRequest!.url.queryParameters.containsKey('date'),
          false,
        );
      },
    );

    final offsetCases = [
      (page: 1, expectedOffset: '0'),
      (page: 2, expectedOffset: '30'),
      (page: 5, expectedOffset: '120'),
    ];
    for (final c in offsetCases) {
      test('computes offset ${c.expectedOffset} for page ${c.page}', () async {
        final client = PixivClient(dio: dio, accessToken: 'token');

        await client.getRanking(mode: PixivRankingMode.day, page: c.page);

        expect(
          server.lastRequest!.url.queryParameters['offset'],
          c.expectedOffset,
        );
      });
    }

    final hasMoreCases = [
      (
        body: '{"illusts": [], "next_url": "https://app-api.pixiv.net/next"}',
        expected: true,
      ),
      (body: '{"illusts": [], "next_url": null}', expected: false),
    ];
    for (final c in hasMoreCases) {
      test('reports hasMore as ${c.expected} from next_url', () async {
        server.responseBody = c.body;
        final client = PixivClient(dio: dio, accessToken: 'token');

        final result = await client.getRanking(mode: PixivRankingMode.day);

        expect(result.hasMore, c.expected);
      });
    }

    test(
      'raises when the body carries an error envelope with HTTP 200',
      () async {
        server.responseBody = '{"error": {"message": "something broke"}}';
        final client = PixivClient(dio: dio, accessToken: 'token');

        await expectLater(
          client.getRanking(mode: PixivRankingMode.day),
          throwsA(isA<PixivApiException>()),
        );
      },
    );

    test(
      'raises a rate-limit exception when the error message says so',
      () async {
        server.responseBody = '{"error": {"message": "Rate Limit exceeded"}}';
        final client = PixivClient(dio: dio, accessToken: 'token');

        await expectLater(
          client.getRanking(mode: PixivRankingMode.day),
          throwsA(isA<PixivRateLimitException>()),
        );
      },
    );

    test(
      'requests followed illusts from v2 with the default restrict of all',
      () async {
        final client = PixivClient(dio: dio, accessToken: 'token');

        await client.getFollowedIllusts(page: 1);

        expect(server.lastRequest!.url.path, 'v2/illust/follow');
        expect(server.lastRequest!.url.queryParameters['restrict'], 'all');
      },
    );

    final followRestrictCases = [
      (restrict: PixivFollowRestrict.all, expected: 'all'),
      (restrict: PixivFollowRestrict.public, expected: 'public'),
      (restrict: PixivFollowRestrict.private, expected: 'private'),
    ];
    for (final c in followRestrictCases) {
      test('sends restrict=${c.expected} for followed illusts', () async {
        final client = PixivClient(dio: dio, accessToken: 'token');

        await client.getFollowedIllusts(restrict: c.restrict, page: 1);

        expect(server.lastRequest!.url.queryParameters['restrict'], c.expected);
      });
    }

    test('pages followed illusts by offset', () async {
      final client = PixivClient(dio: dio, accessToken: 'token');

      await client.getFollowedIllusts(page: 3);

      expect(server.lastRequest!.url.queryParameters['offset'], '60');
    });

    test('parses followed illusts and reports hasMore from next_url', () async {
      server.responseBody =
          '{"illusts": [{"id": 1}], "next_url": "https://app-api.pixiv.net/next"}';
      final client = PixivClient(dio: dio, accessToken: 'token');

      final result = await client.getFollowedIllusts(page: 1);

      expect(result.illusts.length, 1);
      expect(result.hasMore, true);
    });

    test(
      'requests the recommended feed with include_ranking_illusts=true',
      () async {
        final client = PixivClient(dio: dio, accessToken: 'token');

        await client.getRecommendedIllusts(page: 1);

        expect(server.lastRequest!.url.path, 'v1/illust/recommended');
        expect(
          server.lastRequest!.url.queryParameters['include_ranking_illusts'],
          'true',
        );
      },
    );

    test('pages the recommended feed by offset', () async {
      final client = PixivClient(dio: dio, accessToken: 'token');

      await client.getRecommendedIllusts(page: 2);

      expect(server.lastRequest!.url.queryParameters['offset'], '30');
    });

    test(
      'parses the recommended feed, ignoring ranking_illusts, and reports hasMore from next_url',
      () async {
        server.responseBody = '''
        {
          "illusts": [{"id": 1}, {"id": 2}],
          "ranking_illusts": [{"id": 99}],
          "next_url": null
        }
        ''';
        final client = PixivClient(dio: dio, accessToken: 'token');

        final result = await client.getRecommendedIllusts(page: 1);

        expect(result.illusts.length, 2);
        expect(result.hasMore, false);
      },
    );

    final shortPageHasMoreCases = [
      (
        body:
            '{"illusts": [{"id": 1, "visible": false}], "next_url": "https://app-api.pixiv.net/next"}',
        expected: true,
      ),
      (
        body: '{"illusts": [{"id": 1, "visible": false}], "next_url": null}',
        expected: false,
      ),
    ];
    for (final c in shortPageHasMoreCases) {
      test(
        'reports hasMore as ${c.expected} from next_url even when the page holds only invisible stub illusts',
        () async {
          server.responseBody = c.body;
          final client = PixivClient(dio: dio, accessToken: 'token');

          final result = await client.getRecommendedIllusts(page: 1);

          expect(result.hasMore, c.expected);
        },
      );
    }

    final xRestrictCases = [
      (mode: PixivRankingMode.day, expected: 0),
      (mode: PixivRankingMode.week, expected: 0),
      (mode: PixivRankingMode.dayManga, expected: 0),
      (mode: PixivRankingMode.dayAi, expected: 0),
      (mode: PixivRankingMode.dayR18, expected: 1),
      (mode: PixivRankingMode.dayR18Ai, expected: 1),
      (mode: PixivRankingMode.dayMaleR18, expected: 1),
      (mode: PixivRankingMode.dayFemaleR18, expected: 1),
      (mode: PixivRankingMode.dayR18Manga, expected: 1),
      (mode: PixivRankingMode.weekR18, expected: 1),
      (mode: PixivRankingMode.weekR18Manga, expected: 1),
      (mode: PixivRankingMode.weekR18g, expected: 2),
      (mode: PixivRankingMode.weekR18gManga, expected: 2),
    ];
    for (final c in xRestrictCases) {
      test(
        'requires x_restrict level ${c.expected} for ranking mode ${c.mode.value}',
        () {
          expect(c.mode.minimumXRestrict, c.expected);
        },
      );
    }

    test(
      'never leaks the authorization header value in a failed request\'s exception',
      () async {
        await server.stop();
        final deadDio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        final client = PixivClient(
          dio: deadDio,
          accessToken: 'super-secret-token',
        );

        try {
          await client.getRanking(mode: PixivRankingMode.day);
          fail('expected a request failure');
        } catch (e) {
          expect(e.toString().contains('super-secret-token'), false);
        }
      },
    );
  });
}
