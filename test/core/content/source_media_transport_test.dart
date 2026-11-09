import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:boorusama/core/http/client/src/data/source_media_http_adapter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/configs/network/types.dart';

void main() {
  test('Pixiv media resolver and final adapter retain image protocol header and decode bytes', () async {
    final bytes = await File('test/fixtures/post_quality/original.png')
        .readAsBytes();
    for (final site in [
      'https://pixiv.net',
      'https://www.pixiv.net',
      'https://app-api.pixiv.net',
    ]) {
      final delegate = _Delegate()..stream = Stream.value(bytes);
      final request = MediaRequest.resolve(
        'https://i.pximg.net/img.jpg',
        overrides: const [],
        sourceUrl: site,
        headers: const {
          'Referer': 'https://www.pixiv.net/',
          'Authorization': 'Bearer secret',
          'Cookie': 'secret',
        },
      );
      final dio =
          Dio(BaseOptions(headers: {'Authorization': 'Bearer base-secret'}))
            ..httpClientAdapter = SourceMediaHttpClientAdapter(
              delegate: delegate,
              source: Uri.parse(site),
              current: () => true,
            );
      try {
        final response = await dio.get<List<int>>(
          request.url,
          options: Options(
            headers: request.headers,
            responseType: ResponseType.bytes,
            extra: const {'boorusama.request.media': true},
          ),
        );
        expect(
          delegate.requests.single.headers['Referer'],
          'https://www.pixiv.net/',
        );
        expect(
          delegate.requests.single.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains('authorization')),
        );
        expect(
          delegate.requests.single.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains('cookie')),
        );
        final codec = await ui.instantiateImageCodec(
          Uint8List.fromList(response.data!),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      } finally {
        dio.close(force: true);
      }
    }
  });

  test('Pixiv explicit media overrides retain referer but foreign redirects strip it', () async {
    final delegate = _Delegate()..locations.add('https://foreign.test/image');
    final rules = [MediaHostOverride(from: 'i.pximg.net', to: 'media.test')];
    final request = MediaRequest.resolve(
      'https://i.pximg.net/img.jpg',
      overrides: rules,
      sourceUrl: 'https://pixiv.net',
      headers: const {
        'Referer': 'https://www.pixiv.net/',
        'Authorization': 'secret',
      },
    );
    final dio = Dio()
      ..httpClientAdapter = SourceMediaHttpClientAdapter(
        delegate: delegate,
        source: Uri.parse('https://pixiv.net'),
        mediaHostOverrides: rules,
        current: () => true,
      );
    try {
      await dio.get<List<int>>(
        request.url,
        options: Options(
          headers: request.headers,
          responseType: ResponseType.bytes,
          extra: const {'boorusama.request.media': true},
        ),
      );
      expect(
        delegate.requests.first.headers['Referer'],
        'https://www.pixiv.net/',
      );
      expect(
        delegate.requests.last.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('referer')),
      );
    } finally {
      dio.close(force: true);
    }
  });

  late _Delegate delegate;
  late SourceMediaHttpClientAdapter adapter;
  late Dio dio;
  var current = true;
  setUp(() {
    current = true;
    delegate = _Delegate();
    adapter = SourceMediaHttpClientAdapter(
      delegate: delegate,
      source: Uri.parse('https://source.test/app'),
      current: () => current,
    );
    dio = Dio(
      BaseOptions(
        headers: {
          'Authorization': 'secret',
          'Cookie': 'secret',
          'Hydrus-Client-API-Access-Key': 'secret',
          'Referer': 'https://source.test/private?q=secret',
        },
      ),
    )..httpClientAdapter = adapter;
  });
  Future<Response<ResponseBody>> get(
    String url, {
    Map<String, String>? headers,
    int? maxRedirects,
  }) => dio.get<ResponseBody>(
    url,
    options: Options(
      responseType: ResponseType.stream,
      headers: headers,
      maxRedirects: maxRedirects,
      extra: const {'boorusama.request.media': true},
    ),
  );
  Future<void> consume(Response<ResponseBody> response) =>
      response.data!.stream.drain<void>();

  test(
    'same installation retains credentials; foreign and sibling paths filter',
    () async {
      await consume(await get('https://source.test/app/image?q=1'));
      expect(delegate.requests.last.headers['Authorization'], 'secret');
      await consume(await get('https://source.test/app/image?path=%2Fvalue'));
      expect(delegate.requests.last.headers['Authorization'], 'secret');
      expect(delegate.requests.last.followRedirects, isFalse);
      for (final url in [
        'https://source.test/app/%2e%2e/other/image',
        'https://source.test/app%2fother/image',
        'https://source.test/app%5cother/image',
      ]) {
        await consume(await get(url));
        expect(
          delegate.requests.last.headers.keys.map((e) => e.toLowerCase()),
          isNot(contains('authorization')),
        );
      }
      await consume(await get('https://source.test/other/image'));
      expect(
        delegate.requests.last.headers.keys.map((e) => e.toLowerCase()),
        isNot(contains('cookie')),
      );
      expect(
        delegate.requests.last.headers.keys.map((e) => e.toLowerCase()),
        isNot(contains('hydrus-client-api-access-key')),
      );
      expect(
        delegate.requests.last.headers.keys.map((e) => e.toLowerCase()),
        isNot(contains('referer')),
      );
      await consume(
        await get(
          'https://foreign.test/image',
          headers: {'Referer': 'https://source.test/'},
        ),
      );
      expect(delegate.requests.last.headers['Referer'], 'https://source.test/');
      expect(
        delegate.requests.last.headers.keys.map((e) => e.toLowerCase()),
        isNot(contains('authorization')),
      );
    },
  );

  test('redirects strip secrets, preserve target query and reject downgrade and loops', () async {
    delegate.locations.add('https://foreign.test/image?visible=1');
    await consume(await get('https://source.test/app/image'));
    expect(delegate.requests.last.uri.query, 'visible=1');
    expect(
      delegate.requests.last.headers.keys.map((e) => e.toLowerCase()),
      isNot(contains('authorization')),
    );
    delegate.locations.add('http://foreign.test/image');
    final before = delegate.requests.length;
    await expectLater(
      get('https://source.test/app/image'),
      throwsA(isA<DioException>()),
    );
    expect(delegate.requests.length, before + 1);
    delegate.locations.addAll(['/app/a', '/app/b']);
    await expectLater(
      get('https://source.test/app/image', maxRedirects: 1),
      throwsA(isA<DioException>()),
    );
  });

  test(
    'stale and closed adapter reject headers and stream data, retain delegate',
    () async {
      final stream = StreamController<Uint8List>();
      delegate.stream = stream.stream;
      final response = await get('https://source.test/app/image');
      final reading = response.data!.stream.toList();
      current = false;
      stream.add(Uint8List.fromList([1]));
      await expectLater(reading, throwsA(anything));
      await stream.close();
      current = true;
      delegate.started = Completer<void>();
      final gate = delegate.gate = Completer<void>();
      final pending = get('https://source.test/app/image');
      final error = expectLater(pending, throwsA(isA<DioException>()));
      await delegate.started.future;
      adapter.close();
      await error;
      gate.complete();
      expect(delegate.closed, isFalse);
    },
  );
}

class _Delegate implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final locations = <String>[];
  var started = Completer<void>();
  Completer<void>? gate;
  Stream<Uint8List>? stream;
  var closed = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (!started.isCompleted) started.complete();
    if (gate != null) await gate!.future;
    if (locations.isNotEmpty) {
      return ResponseBody(
        const Stream.empty(),
        302,
        headers: {
          'location': [locations.removeAt(0)],
        },
      );
    }
    return ResponseBody(stream ?? Stream.value(Uint8List.fromList([1])), 200);
  }

  @override
  void close({bool force = false}) => closed = true;
}
