import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/http/client/src/data/public_read_http_adapter.dart';
import 'package:boorusama/core/http/client/src/data/source_media_http_adapter.dart';
import 'package:boorusama/core/videos/cache/guarded_video_stream.dart';
import 'package:boorusama/core/videos/cache/prepare_bound_video.dart';
import 'package:boorusama/core/videos/engines/types.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const upstream = 'https://private.example/install/video.webm';
const total = 200 * 1024 * 1024;

class _Cache extends Fake implements VideoCacheManager {
  var reads = 0;
  @override
  int get maxItemSize => 100 * 1024 * 1024;
  @override
  int get maxTotalCacheSize => 1;
  @override
  Future<VideoCacheLease> acquireGuardedVideo(
    String url, {
    required String namespace,
    required Dio transport,
    required bool Function() isCurrent,
    required CancelToken cancelToken,
    Map<String, String>? headers,
    bool retain = true,
  }) async {
    reads++;
    throw StateError('Large video must not require a cache file');
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions, Future<void>?) handler;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

Dio _private(_Adapter adapter, bool Function() current) =>
    Dio()
      ..httpClientAdapter = SourceMediaHttpClientAdapter(
        delegate: adapter,
        source: Uri.parse('https://private.example/install'),
        current: current,
      );

HttpClient _client() {
  final client = HttpClient()..findProxy = (_) => 'DIRECT';
  addTearDown(() => client.close(force: true));
  return client;
}

void main() {
  for (final cacheOn in [false, true]) {
    test(
      'private video above optional quota streams with cache=$cacheOn',
      () async {
        final cache = _Cache();
        final adapter = _Adapter(
          (options, _) async => ResponseBody.fromBytes(
            List.generate(32, (i) => i),
            206,
            headers: {
              'content-length': ['32'],
              'content-type': ['video/webm'],
              'content-range': ['bytes 0-31/$total'],
              'accept-ranges': ['bytes'],
            },
          ),
        );
        final dio = _private(adapter, () => true);
        addTearDown(() => dio.close(force: true));
        final cancel = CancelToken();
        final prepared = await prepareBoundVideo(
          url: upstream,
          namespace: 'private-scope',
          transport: dio,
          headers: const {'Authorization': 'source-secret'},
          isCurrent: () => true,
          cancellation: cancel,
          fileSize: total,
          cache: cacheOn ? cache : null,
        );
        addTearDown(prepared.release!);
        expect(prepared.source, isA<GuardedStreamingVideoSource>());
        expect(prepared.source.originalUrl, upstream);
        final local = Uri.parse(prepared.source.url);
        expect(local.host, InternetAddress.loopbackIPv4.address);
        expect(cache.reads, 0);
        expect(adapter.requests, isEmpty, reason: 'Opening the shell is lazy');
        final request = await _client().getUrl(local);
        request.headers.set('Range', 'bytes=0-31');
        request.headers.set('If-Range', 'fixture-etag');
        request.headers.set('Authorization', 'native-untrusted');
        request.headers.set('Cookie', 'native-cookie');
        final response = await request.close();
        expect(response.statusCode, 206);
        expect(response.headers.value('content-range'), 'bytes 0-31/$total');
        expect(
          await response.fold<List<int>>(
            [],
            (out, chunk) => out..addAll(chunk),
          ),
          List.generate(32, (i) => i),
        );
        expect(
          adapter.requests.single.headers['Authorization'],
          'source-secret',
        );
        expect(adapter.requests.single.headers.containsKey('Cookie'), isFalse);
        expect(adapter.requests.single.headers['range'], 'bytes=0-31');
        expect(adapter.requests.single.headers['if-range'], 'fixture-etag');
      },
    );
  }

  test(
    'HEAD, seek ranges and redirect stripping stay in the source adapter',
    () async {
      final adapter = _Adapter((options, _) async {
        if (options.uri.host == 'private.example') {
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': ['https://cdn.example/video.webm'],
            },
          );
        }
        return ResponseBody.fromString(
          '',
          200,
          headers: {
            'content-type': ['video/webm'],
            'content-length': ['$total'],
          },
        );
      });
      final dio = _private(adapter, () => true);
      addTearDown(() => dio.close(force: true));
      final stream = await GuardedVideoStream.open(
        transport: dio,
        upstream: upstream,
        headers: const {
          'Authorization': 'source-secret',
          'Cookie': 'source-cookie',
          'X-Api-Key': 'source-key',
        },
        isCurrent: () => true,
        cancellation: CancelToken(),
      );
      addTearDown(stream.close);
      final response = await (await _client().headUrl(stream.uri)).close();
      expect(response.statusCode, 200);
      expect(response.contentLength, total);
      await response.drain<void>();
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.map((r) => r.method), everyElement('HEAD'));
      expect(
        adapter.requests.last.headers.keys.map((k) => k.toLowerCase()),
        isNot(
          anyOf(
            contains('authorization'),
            contains('cookie'),
            contains('x-api-key'),
          ),
        ),
      );
      expect(response.headers.value('location'), isNull);
    },
  );

  test(
    'untrusted local paths, methods and ranges never contact the source',
    () async {
      final adapter = _Adapter(
        (_, _) async => throw StateError('No request allowed'),
      );
      final dio = _private(adapter, () => true);
      addTearDown(() => dio.close(force: true));
      final stream = await GuardedVideoStream.open(
        transport: dio,
        upstream: upstream,
        headers: const {},
        isCurrent: () => true,
        cancellation: CancelToken(),
      );
      addTearDown(stream.close);
      for (final uri in [
        stream.uri.replace(path: '/wrong'),
        stream.uri.replace(query: 'url=https://evil.example'),
      ]) {
        final response = await (await _client().getUrl(uri)).close();
        expect(response.statusCode, 403);
        await response.drain<void>();
      }
      final post = await (await _client().postUrl(stream.uri)).close();
      expect(post.statusCode, 403);
      await post.drain<void>();
      final request = await _client().getUrl(stream.uri);
      request.headers.set('Range', 'bytes=0-1,3-4');
      final invalidRange = await request.close();
      expect(invalidRange.statusCode, 416);
      await invalidRange.drain<void>();
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'revocation while upstream headers are pending closes native requests',
    () async {
      var current = true;
      final entered = Completer<void>();
      final cancelled = Completer<void>();
      final gate = Completer<ResponseBody>();
      final adapter = _Adapter((_, cancellation) {
        entered.complete();
        cancellation!.then((_) => cancelled.complete());
        return gate.future;
      });
      final dio = _private(adapter, () => current);
      addTearDown(() => dio.close(force: true));
      final cancellation = CancelToken();
      final stream = await GuardedVideoStream.open(
        transport: dio,
        upstream: upstream,
        headers: const {},
        isCurrent: () => current,
        cancellation: cancellation,
      );
      final request = await _client().getUrl(stream.uri);
      final pending = () async {
        try {
          final response = await request.close();
          expect(response.statusCode, HttpStatus.forbidden);
          expect(
            await response.fold<List<int>>(
              [],
              (out, data) => out..addAll(data),
            ),
            isEmpty,
          );
        } on HttpException {
          // Closing the local socket before headers is an equivalent rejection.
        }
      }();
      await entered.future.timeout(const Duration(seconds: 10));
      current = false;
      cancellation.cancel('test revocation');
      await cancelled.future.timeout(const Duration(seconds: 10));
      await stream.close();
      await pending;
      gate.complete(ResponseBody.fromString('late forbidden bytes', 200));
      await stream.close();
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    'public foreign redirects cannot escape through the local stream',
    () async {
      final adapter = _Adapter(
        (_, _) async => ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': ['https://evil.example/video.mp4'],
          },
        ),
      );
      final source = const AnonymousSourcePolicy().resolve(
        BooruType.danbooru,
        Uri.parse('https://danbooru.donmai.us'),
      )!;
      final dio = Dio()
        ..httpClientAdapter = PublicReadHttpClientAdapter(
          delegate: adapter,
          source: source,
          current: () => true,
        );
      addTearDown(() => dio.close(force: true));
      final stream = await GuardedVideoStream.open(
        transport: dio,
        upstream: 'https://cdn.donmai.us/video.mp4',
        headers: const {},
        isCurrent: () => true,
        cancellation: CancelToken(),
      );
      addTearDown(stream.close);
      final request = await _client().getUrl(stream.uri);
      final response = await request.close();
      expect(response.statusCode, HttpStatus.badGateway);
      expect(
        await response.fold<List<int>>([], (out, data) => out..addAll(data)),
        isEmpty,
      );
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.uri.host, 'cdn.donmai.us');
    },
  );

  test('revocation during a body never forwards late chunks', () async {
    var current = true;
    final chunks = StreamController<Uint8List>();
    final dio = _private(
      _Adapter(
        (_, _) async => ResponseBody(
          chunks.stream,
          200,
          headers: {
            'content-type': ['video/webm'],
          },
        ),
      ),
      () => current,
    );
    addTearDown(() => dio.close(force: true));
    final stream = await GuardedVideoStream.open(
      transport: dio,
      upstream: upstream,
      headers: const {},
      isCurrent: () => current,
      cancellation: CancelToken(),
    );
    addTearDown(stream.close);
    final pending = (await _client().getUrl(stream.uri)).close();
    chunks.add(Uint8List.fromList([1, 2, 3]));
    final response = await pending;
    final receivedFirst = Completer<void>();
    final done = Completer<void>();
    final bytes = <int>[];
    final sub = response.listen(
      (chunk) {
        bytes.addAll(chunk);
        if (!receivedFirst.isCompleted) receivedFirst.complete();
      },
      onError: (Object _) {
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
    );
    await receivedFirst.future.timeout(const Duration(seconds: 10));
    current = false;
    chunks.add(Uint8List.fromList([99, 100]));
    await done.future.timeout(const Duration(seconds: 10));
    expect(bytes, [1, 2, 3]);
    await sub.cancel();
    await chunks.close();
  });

  test(
    'native seek concurrency is bounded and disposal cancels pending reads',
    () async {
      final fourEntered = Completer<void>();
      final gates = <Completer<ResponseBody>>[];
      final adapter = _Adapter((_, _) {
        final gate = Completer<ResponseBody>();
        gates.add(gate);
        if (gates.length == 4) fourEntered.complete();
        return gate.future;
      });
      final dio = _private(adapter, () => true);
      addTearDown(() => dio.close(force: true));
      final stream = await GuardedVideoStream.open(
        transport: dio,
        upstream: upstream,
        headers: const {},
        isCurrent: () => true,
        cancellation: CancelToken(),
      );
      final client = _client()..maxConnectionsPerHost = 8;
      final pending = <Future<void>>[];
      for (var i = 0; i < 4; i++) {
        final request = await client.getUrl(stream.uri);
        pending.add(() async {
          try {
            final response = await request.close();
            expect(response.statusCode, HttpStatus.forbidden);
            await response.drain<void>();
          } on HttpException {
            /* Forced close before headers. */
          }
        }());
      }
      await fourEntered.future.timeout(const Duration(seconds: 10));
      final overflow = await (await client.getUrl(stream.uri)).close();
      expect(overflow.statusCode, HttpStatus.serviceUnavailable);
      await overflow.drain<void>();
      expect(adapter.requests, hasLength(4));
      await stream.close();
      await Future.wait(pending);
      for (final gate in gates) gate.complete(ResponseBody.fromString('', 200));
    },
  );
}
