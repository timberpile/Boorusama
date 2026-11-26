import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/boorus/nhentai/favorites/account.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/nhentai_public_transport.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Gallery access requires explicit platform qualification', () {
    const policy = AnonymousSourcePolicy();
    final site = Uri.parse('https://nhentai.net/');
    expect(policy.resolve(BooruType.nhentai, site), isNull);
    expect(policy.forNamespace(BooruType.nhentai, site.host), isNull);
  });

  test('public search permits only the supported popularity parameters', () {
    final source = const AnonymousSourcePolicy(nhentaiEnabled: true)
        .resolve(BooruType.nhentai, Uri.parse('https://nhentai.net/'))!;
    final search = source.site
        .resolve('/api/v2/search')
        .replace(
          queryParameters: {'page': '2', 'query': '*'},
        );
    expect(source.allowsApi(search), isTrue);
    for (final sort in ['popular-today', 'popular-week', 'popular']) {
      final sorted = search.replace(
        queryParameters: {
          ...search.queryParameters,
          'sort': sort,
        },
      );
      expect(source.allowsApi(sorted), isTrue);
      expect(
        source.allowsApi(sorted.replace(path: '/api/v2/galleries')),
        isFalse,
      );
    }
    expect(
      source.allowsApi(
        search.replace(query: '${search.query}&sort=unsupported'),
      ),
      isFalse,
    );
    expect(
      source.allowsApi(
        search.replace(query: '${search.query}&sort=popular&sort=popular-week'),
      ),
      isFalse,
    );
  });

  test('anonymous autocomplete sends only the approved JSON request', () async {
    final source = const AnonymousSourcePolicy(nhentaiEnabled: true)
        .resolve(BooruType.nhentai, Uri.parse('https://nhentai.net/'))!;
    final delegate = _RecordingAdapter();
    final coordinator = ApiRequestCoordinator();
    final dio = Dio()..httpClientAdapter = delegate;
    dio.httpClientAdapter = NhentaiPublicTransport(
      dio: dio,
      source: source,
      current: () => true,
    );
    coordinateApiDio(dio, coordinator);
    addTearDown(() {
      dio.close(force: true);
      coordinator.dispose();
    });
    final path = source.site.resolve(NhentaiClient.tagSearchPath);
    final data = jsonEncode({
      'query': 'vanilla',
      'type': 'artist',
      'limit': 10,
    });
    await runWithApiRequestContext(
      const ApiRequestContext(replaySafety: ApiReplaySafety.safeRead),
      () async {
        expect(
          await NhentaiClient(dio: dio).searchTags('vanilla', type: 'artist'),
          isEmpty,
        );
        expect(delegate.requests.single.method, 'POST');
        expect(delegate.requests.single.uri, path);
        expect(delegate.requests.single.followRedirects, isFalse);
        expect(delegate.bodies.single, data);
        for (final (uri, body, headers, follow) in [
          (path, data, {'Cookie': 'test-cookie'}, false),
          (path, data, {'Authorization': 'test-key'}, false),
          (path, '{"query":"vanilla","limit":99}', <String, String>{}, false),
          (
            path,
            '{"query":"vanilla","limit":10,"token":"test"}',
            <String, String>{},
            false,
          ),
          (path.replace(query: 'q=vanilla'), data, <String, String>{}, false),
          (
            path.replace(host: 'foreign.example'),
            data,
            <String, String>{},
            false,
          ),
          (
            path.replace(path: '/api/v2/galleries/1/favorite'),
            data,
            <String, String>{},
            false,
          ),
        ]) {
          await expectLater(
            dio.postUri<void>(
              uri,
              data: body,
              options: Options(
                contentType: Headers.jsonContentType,
                headers: headers,
                followRedirects: follow,
              ),
            ),
            throwsA(isA<DioException>()),
          );
        }
        await expectLater(dio.getUri<void>(path), throwsA(isA<DioException>()));
        expect(delegate.requests, hasLength(1));
        delegate.redirect = true;
        await expectLater(
          NhentaiClient(dio: dio).searchTags('vanilla'),
          throwsA(isA<DioException>()),
        );
      },
    );
    expect(delegate.requests, hasLength(2));
    expect(delegate.requests.last.uri, path);
    expect(delegate.requests.last.followRedirects, isFalse);
  });

  test(
    'public discovery policy never covers account paths or extra queries',
    () {
      final source = const AnonymousSourcePolicy(nhentaiEnabled: true)
          .resolve(BooruType.nhentai, Uri.parse('https://nhentai.net/'))!;
      for (final path in ['random', 'popular', '42/related']) {
        final uri = source.site.resolve('/api/v2/galleries/$path');
        expect(source.allowsApi(uri), isTrue);
        expect(source.allowsApi(uri.replace(query: 'page=1')), isFalse);
      }
      for (final path in [
        'user',
        'favorites?page=1',
        'galleries/42/favorite',
      ]) {
        expect(source.allowsApi(source.site.resolve('/api/v2/$path')), isFalse);
      }
    },
  );

  test('account key reaches only approved exact endpoints and never follows a redirect', () async {
    final delegate = _RecordingAdapter();
    var current = true;
    final dio = Dio()
      ..httpClientAdapter = NhentaiAccountTransport(
        delegate: delegate,
        apiKey: 'synthetic-test-api-key',
        current: () => current,
      );
    addTearDown(() => dio.close(force: true));
    final account = Uri.parse('https://nhentai.net/api/v2/user');
    final response = await dio.getUri<String>(
      account,
      options: Options(
        headers: {'Cookie': 'unexpected', 'Authorization': 'foreign'},
      ),
    );
    expect(response.requestOptions.headers['Authorization'], 'foreign');
    expect(
      delegate.requests.single.headers['Authorization'],
      'Key synthetic-test-api-key',
    );
    expect(
      delegate.requests.single.headers.keys.map((name) => name.toLowerCase()),
      isNot(contains('cookie')),
    );
    for (final uri in [
      account.replace(host: 'i1.nhentai.net'),
      account.replace(port: 8443),
      account.replace(query: 'extra=1'),
      account.resolve('galleries/42'),
      account.resolve('galleries/42/favorite'),
      Uri.parse('https://nhentai.net.evil.test/api/v2/user'),
    ]) {
      await expectLater(dio.getUri<String>(uri), throwsA(isA<DioException>()));
    }
    await expectLater(
      dio.postUri<String>(account),
      throwsA(isA<DioException>()),
    );
    expect(delegate.requests, hasLength(1));
    delegate.redirect = true;
    await expectLater(
      dio.getUri<String>(account),
      throwsA(isA<DioException>()),
    );
    expect(delegate.requests, hasLength(2));
    expect(delegate.requests.last.followRedirects, isFalse);
    current = false;
    await expectLater(
      dio.getUri<String>(account),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    expect(delegate.requests, hasLength(2));
  });

  test('Gallery transport shares config and enforces CDN, headers and redirect policy', () async {
    final site = Uri.parse('https://nhentai.net/');
    final source = const AnonymousSourcePolicy(nhentaiEnabled: true)
        .resolve(BooruType.nhentai, site)!;
    final delegate = _RecordingAdapter();
    var current = true;
    final dio = Dio()..httpClientAdapter = delegate;
    final transport = NhentaiPublicTransport(
      dio: dio,
      source: source,
      current: () => current,
    );
    dio.httpClientAdapter = transport;
    expect(NhentaiPublicTransport.of(dio), same(transport));
    final coordinator = ApiRequestCoordinator();
    coordinateApiDio(dio, coordinator);
    expect(NhentaiPublicTransport.of(dio), same(transport));
    addTearDown(() {
      dio.close(force: true);
      coordinator.dispose();
    });

    final policy = await transport.mediaPolicy();
    expect(await transport.mediaPolicy(), same(policy));
    expect(delegate.requests.single.uri.path, '/api/v2/config');
    final image = Uri.parse('https://i1.nhentai.net/galleries/51/page.webp');
    final thumbnail = Uri.parse(
      'https://t1.nhentai.net/galleries/51/thumb.webp.webp',
    );
    expect((await dio.getUri<String>(image)).data, 'fixture');
    expect((await dio.getUri<String>(thumbnail)).data, 'fixture');
    expect(delegate.requests, hasLength(3));
    await expectLater(
      dio.getUri<String>(image.replace(host: 'i2.nhentai.net')),
      throwsA(isA<DioException>()),
    );
    await expectLater(
      dio.getUri<String>(
        image,
        options: Options(headers: {'Cookie': 'fixture'}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(delegate.requests, hasLength(3));
    delegate.redirect = true;
    await expectLater(dio.getUri<String>(image), throwsA(isA<DioException>()));
    expect(delegate.requests, hasLength(4));
    expect(delegate.requests.last.followRedirects, isFalse);
    current = false;
    await expectLater(
      dio.getUri<String>(image),
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    expect(delegate.requests, hasLength(4));
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bodies = <String>[];
  var redirect = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final body = await requestStream.expand((bytes) => bytes).toList();
      bodies.add(utf8.decode(body));
    }
    if (!redirect && options.uri.path == NhentaiClient.tagSearchPath) {
      return ResponseBody.fromString(
        '[]',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.uri.path == '/api/v2/config') {
      return ResponseBody.fromString(
        jsonEncode({
          'image_servers': ['https://i1.nhentai.net'],
          'thumb_servers': ['https://t1.nhentai.net'],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return redirect
        ? ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': ['https://foreign.example/redirect.webp'],
            },
          )
        : ResponseBody.fromString('fixture', 200);
  }

  @override
  void close({bool force = false}) {}
}
