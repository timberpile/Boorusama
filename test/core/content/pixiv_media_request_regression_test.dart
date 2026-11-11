import 'dart:typed_data';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/pixiv_repository.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/network/types.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_dio.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/src/image_fetcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Exercise both production header boundaries, not a separate approximation of
// their rules. Only the remote server is replaced by a deterministic fixture.
const _variants = [
  'https://i.pximg.net/c/540x540_10_webp/img-master/100_p0_square1200.jpg',
  'https://i.pximg.net/c/600x1200_90_webp/img-master/100_p0_master1200.jpg',
  'https://i.pximg.net/img-original/100_p0.jpg',
  'https://s.pximg.net/common/images/limit_unviewable_360.png',
];

void main() {
  for (final source in ['https://pixiv.net/', 'https://www.pixiv.net/']) {
    test(
      'Pixiv variants retain their public Referer through $source',
      () async {
        final fixture = _Fixture(source);
        addTearDown(fixture.dispose);
        for (final url in _variants) {
          final request = fixture.resolve(url);
          final bytes = await ImageFetcher.fetchImageBytes(
            url: request.url,
            dio: fixture.media,
            headers: request.headers,
            printError: false,
          );
          expect(bytes, orderedEquals(_imageBytes));
          final sent = fixture.adapter.requests.last;
          expect(sent.uri.toString(), url);
          expect(_header(sent.headers, 'referer'), kPixivImageReferer);
          _expectNoCredentials(sent.headers);
        }
        expect(fixture.adapter.requests, hasLength(_variants.length));
        expect(fixture.authInterceptorCalls, 0);
      },
    );
  }

  test('scoped transport independently preserves the Pixiv Referer', () async {
    final fixture = _Fixture('https://pixiv.net/');
    addTearDown(fixture.dispose);
    final bytes = await ImageFetcher.fetchImageBytes(
      url: _variants.first,
      dio: fixture.media,
      headers: fixture.headers,
      printError: false,
    );
    expect(bytes, orderedEquals(_imageBytes));
    _expectNoCredentials(fixture.adapter.requests.single.headers);
  });

  test(
    'unbound media receives the resolved Pixiv Referer without secrets',
    () async {
      final fixture = _Fixture('https://pixiv.net/');
      addTearDown(fixture.dispose);
      final replacement = Dio()..httpClientAdapter = fixture.adapter;
      addTearDown(() => replacement.close(force: true));
      final request = fixture.resolve(_variants.first);
      expect(request.overridden, isTrue);
      expect(
        await ImageFetcher.fetchImageBytes(
          url: request.url,
          dio: replacement,
          headers: request.headers,
          printError: false,
        ),
        orderedEquals(_imageBytes),
      );
      _expectNoCredentials(fixture.adapter.requests.single.headers);
    },
  );

  test('explicit media overrides do not inherit the Pixiv Referer', () async {
    final fixture = _Fixture('https://pixiv.net/');
    addTearDown(fixture.dispose);
    fixture.adapter.requireReferer = false;
    final request = fixture.resolve(
      _variants.first,
      overrides: [MediaHostOverride(from: 'i.pximg.net', to: 'mirror.test')],
    );
    await ImageFetcher.fetchImageBytes(
      url: request.url,
      dio: fixture.media,
      headers: request.headers,
      printError: false,
    );
    final sent = fixture.adapter.requests.single;
    expect(sent.uri.host, 'mirror.test');
    expect(_header(sent.headers, 'referer'), isNull);
    _expectNoCredentials(sent.headers);
  });

  test(
    'Pixiv alias permission is not a general cross-origin exception',
    () async {
      final fixture = _Fixture('https://pixiv.net/');
      addTearDown(fixture.dispose);
      fixture.adapter.requireReferer = false;
      for (final url in [
        'https://foreign.test/image.jpg',
        'https://i.pximg.net.evil.test/image.jpg',
        'http://i.pximg.net/image.jpg',
        'https://i.pximg.net:8443/image.jpg',
      ]) {
        // Bypass the resolver deliberately: the final boundary must also reject
        // the alias on its own, including after a redirect.
        await ImageFetcher.fetchImageBytes(
          url: url,
          dio: fixture.media,
          headers: fixture.headers,
          printError: false,
        );
        final sent = fixture.adapter.requests.last;
        expect(_header(sent.headers, 'referer'), isNull, reason: url);
        _expectNoCredentials(sent.headers);
      }
      for (final referer in [
        'https://www.pixiv.net/private',
        'https://www.pixiv.net/?token=secret',
        'https://www.pixiv.net/#secret',
        'https://secret@www.pixiv.net/',
        'http://www.pixiv.net/',
        'https://www.pixiv.net:8443/',
        'https://www.pixiv.net.evil.test/',
      ]) {
        await ImageFetcher.fetchImageBytes(
          url: _variants.first,
          dio: fixture.media,
          headers: {...fixture.headers, 'Referer': referer},
          printError: false,
        );
        expect(
          _header(fixture.adapter.requests.last.headers, 'referer'),
          isNull,
          reason: referer,
        );
      }
    },
  );

  test('redirects cannot retain the Pixiv alias outside its CDN', () async {
    final fixture = _Fixture('https://pixiv.net/');
    addTearDown(fixture.dispose);
    fixture.media.options.followRedirects = true;
    fixture.adapter
      ..requireReferer = false
      ..redirect = 'https://foreign.test/final.jpg';
    final request = fixture.resolve(_variants.first);
    await ImageFetcher.fetchImageBytes(
      url: request.url,
      dio: fixture.media,
      headers: request.headers,
      printError: false,
    );
    expect(fixture.adapter.requests, hasLength(2));
    expect(
      _header(fixture.adapter.requests.first.headers, 'referer'),
      kPixivImageReferer,
    );
    expect(_header(fixture.adapter.requests.last.headers, 'referer'), isNull);
    for (final sent in fixture.adapter.requests) {
      _expectNoCredentials(sent.headers);
      expect(sent.followRedirects, isFalse);
    }
  });
}

Object? _header(Map<String, dynamic> headers, String name) => headers.entries
    .where((entry) => entry.key.toLowerCase() == name)
    .map((entry) => entry.value)
    .firstOrNull;

void _expectNoCredentials(Map<String, dynamic> headers) {
  for (final name in ['authorization', 'cookie', 'origin', 'x-api-key']) {
    expect(_header(headers, name), isNull, reason: name);
  }
}

final _imageBytes = Uint8List.fromList([137, 80, 78, 71]);

class _Fixture {
  _Fixture(String source) {
    config = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': '11111111-1111-4111-8111-111111111111',
      'booruId': BooruType.pixiv.id,
      'booruIdHint': BooruType.pixiv.id,
      'url': source,
    });
    final access = ContentAccessContext.profile(
      config: config,
      authEpoch: 1,
      policyEpoch: 1,
    );
    sourceDio = Dio(
      BaseOptions(
        baseUrl: kPixivApiBaseUrl,
        followRedirects: false,
        headers: _credentials,
      ),
    )..httpClientAdapter = adapter;
    sourceDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          authInterceptorCalls++;
          handler.next(options);
        },
      ),
    );
    container = ProviderContainer(
      overrides: [
        contentAccessContextProvider(access.key).overrideWithValue(access),
        dioForWidgetProvider(config.auth).overrideWithValue(sourceDio),
      ],
    );
    final engineHeaders = Provider(
      (ref) => PixivRepository(ref: ref).extraHttpHeaders(config.auth),
    );
    headers = {..._credentials, ...container.read(engineHeaders)};
    subscription = container.listen(
      contentMediaDioProvider(access.key),
      (_, _) {},
    );
    media = subscription.read();
  }

  static const _credentials = <String, String>{
    'Authorization': 'fixture-bearer',
    'Cookie': 'fixture-cookie',
    'Origin': 'https://pixiv.net',
    'X-Api-Key': 'fixture-key',
  };
  final adapter = _CdnAdapter();
  var authInterceptorCalls = 0;
  late final BooruConfig config;
  late final Dio sourceDio;
  late final Dio media;
  late final ProviderContainer container;
  late final ProviderSubscription<Dio> subscription;
  late final Map<String, String> headers;

  MediaRequest resolve(
    String url, {
    List<MediaHostOverride> overrides = const [],
  }) => MediaRequest.resolve(
    url,
    sourceUrl: config.url,
    headers: headers,
    overrides: overrides,
  );

  void dispose() {
    subscription.close();
    container.dispose();
    sourceDio.close(force: true);
  }
}

class _CdnAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool requireReferer = true;
  String? redirect;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (redirect case final location?) {
      redirect = null;
      return ResponseBody.fromBytes(
        [],
        302,
        headers: {
          'location': [location],
        },
      );
    }
    final permitted =
        !requireReferer ||
        _header(options.headers, 'referer') == kPixivImageReferer;
    return ResponseBody.fromBytes(
      permitted ? _imageBytes : [],
      permitted ? 200 : 403,
    );
  }

  @override
  void close({bool force = false}) {}
}
