import 'dart:ui' as ui;

import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart';

import '../posts/details/progressive_image_test_utils.dart' show lowerPng;

import 'dart:async';
import 'dart:typed_data';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/http/client/src/data/public_read_http_adapter.dart';
import 'package:coreutils/coreutils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Realbooru native anonymous detail parser and media GET decode without account headers',
    (tester) async {
      await tester.runAsync(() async {
        final source = const AnonymousSourcePolicy().resolve(
          BooruType.gelbooruV2,
          Uri.parse('https://realbooru.com'),
        )!;
        final coordinator = ApiRequestCoordinator();
        final delegate = _RecordingAdapter(
          responses: [
            ResponseBody.fromString(
              '<input name="id" value="42"><img id="image" src="/images/ab/cd/fixture.png" width="1" height="1">',
              200,
              headers: {
                Headers.contentTypeHeader: ['text/html'],
              },
            ),
            ResponseBody.fromBytes(
              lowerPng,
              200,
              headers: {
                Headers.contentTypeHeader: ['image/png'],
              },
            ),
          ],
        );
        final dio = _coordinatedDio(delegate, coordinator, source);
        addTearDown(() {
          dio.close(force: true);
          coordinator.dispose();
        });
        final response = await dio.get<String>(
          '/index.php?page=post&s=view&id=42',
        );
        final post = parseRbPostHtml(response, {
          'baseUrl': source.site.toString(),
        });
        expect(post, isNotNull);
        final media = await dio.get<List<int>>(
          post!.sampleUrl!,
          options: Options(responseType: ResponseType.bytes),
        );
        {
          final codec = await ui.instantiateImageCodec(
            Uint8List.fromList(media.data!),
          );
          final frame = await codec.getNextFrame();
          expect(frame.image.width, greaterThan(0));
          frame.image.dispose();
          codec.dispose();
        }
        expect(delegate.calls, hasLength(2));
        for (final call in delegate.calls) {
          _expectNoCredentialHeaders(call.options.headers);
          expect(call.requestStream, isNull);
          expect(call.options.data, isNull);
        }
      });
    },
  );

  final source = const AnonymousSourcePolicy().resolve(
    BooruType.danbooru,
    Uri.parse('https://safebooru.donmai.us'),
  )!;

  group('Dio adapter integration', () {
    test(
      'coordinated Dio GET reaches only the guarded fake transport',
      () async {
        final coordinator = ApiRequestCoordinator();
        final delegate = _RecordingAdapter(
          responses: [
            ResponseBody.fromString(
              '{"id":7}',
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            ),
          ],
        );
        final dio = _coordinatedDio(delegate, coordinator, source);
        addTearDown(() {
          dio.close(force: true);
          coordinator.dispose();
        });

        final response = await dio
            .get<Map<String, dynamic>>('/posts/7.json')
            .timeout(const Duration(seconds: 5));

        expect(response.data, {'id': 7});
        expect(delegate.calls, hasLength(1));
        final call = delegate.calls.single;
        expect(
          call.options.uri.toString(),
          'https://safebooru.donmai.us/posts/7.json',
        );
        expect(call.options.method, 'GET');
        expect(call.requestStream, isNull);
        expect(call.options.data, isNull);
        expect(call.options.followRedirects, isFalse);
        _expectNoCredentialHeaders(call.options.headers);
      },
    );

    test('Dio redirect is checked before follow and permits a safe same-origin target', () async {
      final coordinator = ApiRequestCoordinator();
      final delegate = _RecordingAdapter(
        responses: [
          _redirect('https://foreign.test/posts/8.json'),
          _redirect('https://safebooru.donmai.us/posts/8.json'),
          ResponseBody.fromString(
            '{"id":8}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        ],
      );
      final dio = _coordinatedDio(delegate, coordinator, source);
      addTearDown(() {
        dio.close(force: true);
        coordinator.dispose();
      });

      await expectLater(
        dio.get('/posts/7.json').timeout(const Duration(seconds: 5)),
        throwsA(isA<DioException>()),
      );
      expect(delegate.calls, hasLength(1));
      expect(delegate.calls.single.options.followRedirects, isFalse);

      final response = await dio
          .get<Map<String, dynamic>>('/posts/7.json')
          .timeout(const Duration(seconds: 5));
      expect(response.data, {'id': 8});
      expect(delegate.calls, hasLength(3));
      expect(
        delegate.calls.map((call) => call.options.uri.toString()),
        [
          'https://safebooru.donmai.us/posts/7.json',
          'https://safebooru.donmai.us/posts/7.json',
          'https://safebooru.donmai.us/posts/8.json',
        ],
      );
      expect(
        delegate.calls.every((call) => !call.options.followRedirects),
        isTrue,
      );
      for (final call in delegate.calls) {
        _expectNoCredentialHeaders(call.options.headers);
      }
    });
  });

  group('request boundary', () {
    test(
      'forwards allowed API and CDN GETs once without native redirects',
      () async {
        final delegate = _RecordingAdapter();
        final adapter = _adapter(delegate, source);

        await adapter.fetch(
          _options('https://safebooru.donmai.us/posts/7.json'),
          null,
          null,
        );
        await adapter.fetch(
          _options('https://cdn.donmai.us/original/x.jpg'),
          null,
          null,
        );

        expect(delegate.calls, hasLength(2));
        expect(delegate.calls.map((call) => call.options.uri.toString()), [
          'https://safebooru.donmai.us/posts/7.json',
          'https://cdn.donmai.us/original/x.jpg',
        ]);
        expect(
          delegate.calls.every((call) => !call.options.followRedirects),
          isTrue,
        );
      },
    );

    test(
      'rejects credential headers case-insensitively before transport',
      () async {
        for (final header in [
          'Authorization',
          'cOoKiE',
          'Proxy-Authorization',
          'X-Api-Key',
          'API-KEY',
        ]) {
          final delegate = _RecordingAdapter();
          final adapter = _adapter(delegate, source);
          await _expectDenied(
            adapter.fetch(
              _options(
                'https://safebooru.donmai.us/posts/7.json',
                headers: {header: 'secret'},
              ),
              null,
              null,
            ),
          );
          expect(delegate.calls, isEmpty, reason: header);
        }
      },
    );

    test(
      'rejects foreign, private, root, query-token and unlisted CDN URLs',
      () async {
        for (final url in [
          'https://foreign.test/posts/7.json',
          'https://safebooru.donmai.us/',
          'https://localhost/posts/7.json',
          'https://127.0.0.1/posts/7.json',
          'https://safebooru.donmai.us/posts/7.json?token=secret',
          'https://cdn.other.test/original/x.jpg',
        ]) {
          final delegate = _RecordingAdapter();
          final adapter = _adapter(delegate, source);
          await _expectDenied(adapter.fetch(_options(url), null, null));
          expect(delegate.calls, isEmpty, reason: url);
        }
      },
    );

    test(
      'rejects writes, state-changing GETs and GET request bodies',
      () async {
        for (final method in ['POST', 'DELETE']) {
          final delegate = _RecordingAdapter();
          final adapter = _adapter(delegate, source);
          await _expectDenied(
            adapter.fetch(
              _options(
                'https://safebooru.donmai.us/posts/7.json',
                method: method,
                extra: {apiSafeReadRequestKey: true},
              ),
              null,
              null,
            ),
          );
          expect(delegate.calls, isEmpty);
        }

        for (final mutation in [
          {stateChangingRequestKey: true},
          {apiMutationRequestKey: true},
        ]) {
          final delegate = _RecordingAdapter();
          final adapter = _adapter(delegate, source);
          await _expectDenied(
            adapter.fetch(
              _options(
                'https://safebooru.donmai.us/posts/7.json',
                extra: {...mutation, apiSafeReadRequestKey: true},
              ),
              null,
              null,
            ),
          );
          expect(delegate.calls, isEmpty);
        }

        final delegate = _RecordingAdapter();
        final adapter = _adapter(delegate, source);
        await _expectDenied(
          adapter.fetch(
            _options(
              'https://safebooru.donmai.us/posts/7.json',
              data: 'payload',
            ),
            null,
            null,
          ),
        );
        expect(delegate.calls, isEmpty);
      },
    );

    test('rejects a request stream before transport', () async {
      final delegate = _RecordingAdapter();
      final adapter = _adapter(delegate, source);
      await _expectDenied(
        adapter.fetch(
          _options('https://safebooru.donmai.us/posts/7.json'),
          const Stream<Uint8List>.empty(),
          null,
        ),
      );
      expect(delegate.calls, isEmpty);
    });
  });

  group('redirect boundary', () {
    test(
      'allows an explicitly validated same-host API and CDN redirect',
      () async {
        for (final target in [
          'https://safebooru.donmai.us/posts/8.json',
          'https://cdn.donmai.us/original/x.jpg',
        ]) {
          final delegate = _RecordingAdapter(
            responses: [
              _redirect(target),
              ResponseBody.fromString('ok', 200),
            ],
          );
          final adapter = _adapter(delegate, source);

          final response = await adapter.fetch(
            _options(
              'https://safebooru.donmai.us/posts/7.json',
              followRedirects: true,
            ),
            null,
            null,
          );

          expect(response.statusCode, 200);
          expect(delegate.calls, hasLength(2));
          expect(delegate.calls.last.options.uri.toString(), target);
          expect(
            delegate.calls.every((call) => !call.options.followRedirects),
            isTrue,
          );
        }
      },
    );

    test('rejects foreign, private, userinfo, downgrade and token redirects before follow', () async {
      for (final target in [
        'https://foreign.test/posts/8.json',
        'https://localhost/posts/8.json',
        'https://user@safebooru.donmai.us/posts/8.json',
        'http://safebooru.donmai.us/posts/8.json',
        'https://safebooru.donmai.us/posts/8.json?token=secret',
      ]) {
        final delegate = _RecordingAdapter(responses: [_redirect(target)]);
        final adapter = _adapter(delegate, source);
        await _expectDenied(
          adapter.fetch(
            _options(
              'https://safebooru.donmai.us/posts/7.json',
              followRedirects: true,
            ),
            null,
            null,
          ),
        );
        expect(delegate.calls, hasLength(1), reason: target);
      }
    });

    test('enforces the original max redirect bound', () async {
      final delegate = _RecordingAdapter(
        responses: [_redirect('https://safebooru.donmai.us/posts/8.json')],
      );
      final adapter = _adapter(delegate, source);
      await expectLater(
        adapter.fetch(
          _options(
            'https://safebooru.donmai.us/posts/7.json',
            followRedirects: true,
            maxRedirects: 0,
          ),
          null,
          null,
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.message,
            'redirect bound rejection',
            'Invalid public read redirect',
          ),
        ),
      ).timeout(const Duration(seconds: 5));
      expect(delegate.calls, hasLength(1));
    });
  });

  group('scope invalidation and close', () {
    test('does not start transport when scope is already stale', () async {
      const current = false;
      final delegate = _RecordingAdapter();
      final adapter = _adapter(delegate, source, current: () => current);
      await _expectCancelled(
        adapter.fetch(
          _options('https://safebooru.donmai.us/posts/7.json'),
          null,
          null,
        ),
      );
      expect(delegate.calls, isEmpty);
    });

    test('cancels an in-flight response after scope invalidation', () async {
      final current = _MutableFlag(true);
      final responseCompleter = Completer<ResponseBody>();
      final delegate = _RecordingAdapter(
        onFetch: (_) => responseCompleter.future,
      );
      final adapter = _adapter(delegate, source, current: () => current.value);
      final pending = adapter.fetch(
        _options('https://safebooru.donmai.us/posts/7.json'),
        null,
        null,
      );
      expect(delegate.calls, hasLength(1));
      current.value = false;
      responseCompleter.complete(ResponseBody.fromString('discard', 200));

      await _expectCancelled(pending);
      expect(delegate.calls, hasLength(1));
    });

    test('rejects late response chunks after scope invalidation', () async {
      final current = _MutableFlag(true);
      final body = StreamController<Uint8List>();
      final delegate = _RecordingAdapter(
        onFetch: (_) async => ResponseBody(body.stream, 200),
      );
      final adapter = _adapter(delegate, source, current: () => current.value);
      final response = await adapter.fetch(
        _options('https://safebooru.donmai.us/posts/7.json'),
        null,
        null,
      );
      final chunks = <Uint8List>[];
      final streamError = Completer<Object>();
      final subscription = response.stream.listen(
        chunks.add,
        onError: streamError.complete,
      );
      current.value = false;
      body.add(Uint8List.fromList([1]));

      final error = await streamError.future.timeout(
        const Duration(seconds: 5),
      );
      expect(error, isA<DioException>());
      expect(chunks, isEmpty);
      await subscription.cancel();
      await body.close();
    });

    test(
      'close is idempotent and later requests do not reach delegate',
      () async {
        final delegate = _RecordingAdapter();
        final adapter = _adapter(delegate, source);
        adapter.close();
        adapter.close(force: true);

        expect(delegate.closeCalls, 1);
        await _expectCancelled(
          adapter.fetch(
            _options('https://safebooru.donmai.us/posts/7.json'),
            null,
            null,
          ),
        );
        expect(delegate.calls, isEmpty);
      },
    );
  });
}

PublicReadHttpClientAdapter _adapter(
  _RecordingAdapter delegate,
  AnonymousSource source, {
  bool Function()? current,
}) => PublicReadHttpClientAdapter(
  delegate: delegate,
  source: source,
  current: current ?? () => true,
);

Dio _coordinatedDio(
  _RecordingAdapter delegate,
  ApiRequestCoordinator coordinator,
  AnonymousSource source,
) {
  final dio = Dio(
    BaseOptions(
      baseUrl: '${source.site.origin}/',
      headers: {
        'User-Agent': 'Boorusama transport boundary test',
        'Referer': source.site.toString(),
      },
    ),
  )..httpClientAdapter = _adapter(delegate, source);
  coordinateApiDio(dio, coordinator);
  return dio;
}

void _expectNoCredentialHeaders(Map<String, dynamic> headers) {
  final names = headers.keys.map((name) => name.toLowerCase()).toSet();
  expect(
    names.intersection({
      'authorization',
      'proxy-authorization',
      'cookie',
      'x-api-key',
      'api-key',
    }),
    isEmpty,
  );
}

RequestOptions _options(
  String url, {
  String method = 'GET',
  Map<String, dynamic> headers = const {},
  Map<String, dynamic> extra = const {},
  Object? data,
  bool followRedirects = false,
  int maxRedirects = 5,
}) {
  final uri = Uri.parse(url);
  return RequestOptions(
    path: uri.toString(),
    baseUrl: '',
    method: method,
    headers: headers,
    extra: extra,
    data: data,
    followRedirects: followRedirects,
    maxRedirects: maxRedirects,
  );
}

ResponseBody _redirect(String location) => ResponseBody.fromString(
  '',
  302,
  headers: {
    'location': [location],
  },
);

Future<void> _expectDenied(Future<ResponseBody> request) async {
  await expectLater(
    request,
    throwsA(
      isA<DioException>().having(
        (error) => error.message,
        'policy rejection',
        'Request is outside the public read policy',
      ),
    ),
  ).timeout(const Duration(seconds: 5));
}

Future<void> _expectCancelled(Future<ResponseBody> request) async {
  await expectLater(
    request,
    throwsA(
      isA<DioException>().having(
        (error) => error.type,
        'cancellation type',
        DioExceptionType.cancel,
      ),
    ),
  ).timeout(const Duration(seconds: 5));
}

final class _RecordedCall {
  const _RecordedCall(this.options, this.requestStream, this.cancelFuture);

  final RequestOptions options;
  final Stream<Uint8List>? requestStream;
  final Future<void>? cancelFuture;
}

final class _MutableFlag {
  _MutableFlag(this.value);

  bool value;
}

final class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({
    List<ResponseBody>? responses,
    Future<ResponseBody> Function(_RecordedCall call)? onFetch,
  }) : _responses = [...?responses],
       onFetch = onFetch;

  final List<ResponseBody> _responses;
  final Future<ResponseBody> Function(_RecordedCall call)? onFetch;
  final calls = <_RecordedCall>[];
  var closeCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final call = _RecordedCall(options, requestStream, cancelFuture);
    calls.add(call);
    if (onFetch case final handler?) return handler(call);
    if (_responses.isNotEmpty) return Future.value(_responses.removeAt(0));
    return Future.value(ResponseBody.fromString('ok', 200));
  }

  @override
  void close({bool force = false}) {
    closeCalls++;
  }
}
