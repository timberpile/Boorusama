import 'dart:typed_data';
import 'dart:io';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/auth/auth_interceptor.dart';
import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final host in ['i.pximg.net', 'media.example.invalid']) {
    test(
      'actual uncached share preparation strips API credentials for $host',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'pixiv-share-origin-',
        );
        addTearDown(() => root.delete(recursive: true));
        var refreshes = 0;
        var mediaRequests = 0;
        final dio = _client(
          refresher: (_) async => _tokens(++refreshes),
          respond: (options) {
            if (options.uri.host != 'app-api.pixiv.net') {
              mediaRequests++;
              expect(options.headers['Authorization'], isNull);
              expect(options.headers['Referer'], 'https://www.pixiv.net/');
            }
            return 200;
          },
        );
        await dio.get<void>('/v1/illust/detail');
        final service = ShareMediaPreparation(
          rootPath: root.path,
          dio: dio,
          cachedBytes: (_) async => null,
        );
        final lease = await service.prepare(
          url: 'https://$host/artwork.jpg',
          kind: ShareMediaKind.image,
          fallbackExtension: 'jpg',
          headers: const {
            'Authorization': 'Bearer fixture-stale',
            'Referer': 'https://www.pixiv.net/',
          },
        );
        expect(await File(lease.path).exists(), isTrue);
        expect(mediaRequests, 1);
        expect(refreshes, 1);
        await lease.release();
      },
    );
  }
  for (final url in [
    'https://i.pximg.net/image.jpg',
    'https://media.example.invalid/image.jpg',
    'https://app-api.pixiv.net.example.invalid/v1/illust/detail',
    'http://app-api.pixiv.net/v1/illust/detail',
    'https://app-api.pixiv.net:444/v1/illust/detail',
    'https://user@app-api.pixiv.net/v1/illust/detail',
  ]) {
    test('does not authorize or refresh an untrusted origin: $url', () async {
      var refreshes = 0;
      final dio = _client(
        refresher: (_) async {
          refreshes++;
          return _tokens(refreshes);
        },
        respond: (options) {
          expect(options.headers['Authorization'], isNull);
          expect(options.headers['Referer'], 'https://www.pixiv.net/');
          return 200;
        },
      );

      await dio.get<void>(
        url,
        options: Options(
          headers: {
            'authorization': 'Bearer stale-test-token',
            'Referer': 'https://www.pixiv.net/',
          },
        ),
      );

      expect(refreshes, 0);
    });
  }

  test('keeps bearer refresh and one retry on the exact API origin', () async {
    var refreshes = 0;
    final authorizations = <String?>[];
    final dio = _client(
      refresher: (_) async => _tokens(++refreshes),
      respond: (options) {
        authorizations.add(options.headers['Authorization'] as String?);
        expect(options.followRedirects, isFalse);
        return authorizations.length == 1 ? 401 : 200;
      },
    );

    await dio.get<void>(
      '/v1/illust/detail',
      options: Options(followRedirects: true),
    );

    expect(refreshes, 2);
    expect(authorizations, ['Bearer access-test-1', 'Bearer access-test-2']);
  });

  test('does not reuse an API bearer or refresh after a media 401', () async {
    var refreshes = 0;
    var mediaRequests = 0;
    final dio = _client(
      refresher: (_) async => _tokens(++refreshes),
      respond: (options) {
        if (options.uri.host == 'app-api.pixiv.net') return 200;
        mediaRequests++;
        expect(options.headers['Authorization'], isNull);
        return 401;
      },
    );
    await dio.get<void>('/v1/illust/detail');

    await expectLater(
      dio.get<void>(
        'https://i.pximg.net/image.jpg',
        options: Options(headers: {'Authorization': 'Bearer access-test-1'}),
      ),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'status code',
          401,
        ),
      ),
    );

    expect(refreshes, 1);
    expect(mediaRequests, 1);
  });

  test('does not repeatedly retry an unauthorized API request', () async {
    var refreshes = 0;
    var requests = 0;
    final dio = _client(
      refresher: (_) async => _tokens(++refreshes),
      respond: (_) {
        requests++;
        return 401;
      },
    );

    await expectLater(
      dio.get<void>('/v1/illust/detail'),
      throwsA(isA<DioException>()),
    );

    expect(refreshes, 2);
    expect(requests, 2);
  });
}

PixivTokens _tokens(int number) => PixivTokens(
  accessToken: 'access-test-$number',
  refreshToken: 'refresh-test-$number',
  expiresIn: 3600,
);

Dio _client({
  required PixivTokenRefresher refresher,
  required int Function(RequestOptions options) respond,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://app-api.pixiv.net'));
  final interceptor = PixivAuthInterceptor(
    refreshToken: 'refresh-test-initial',
    refresher: refresher,
  )..attach(dio);
  dio.interceptors.add(interceptor);
  dio.httpClientAdapter = _ResponseAdapter(respond);
  addTearDown(() => dio.close(force: true));
  return dio;
}

class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter(this.respond);

  final int Function(RequestOptions options) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    options.uri.host == 'app-api.pixiv.net' ? '{}' : 'fixture-image',
    respond(options),
    headers: {
      Headers.contentTypeHeader: [
        options.uri.host == 'app-api.pixiv.net'
            ? 'application/json'
            : 'image/jpeg',
      ],
    },
  );

  @override
  void close({bool force = false}) {}
}
