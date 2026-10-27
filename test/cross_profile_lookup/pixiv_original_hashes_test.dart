import 'dart:async';
import 'dart:typed_data';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/src/data/pixiv_original_hashes.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _hash = '5d41402abc4b2a76b9719d911017c592';
String _url(int page) =>
    'https://i.pximg.net/img-original/img/2026/01/01/00/00/00/12345_p$page.png';
PixivIllustDto _artwork({
  int pages = 1,
  String type = 'illust',
  bool visible = true,
}) => PixivIllustDto.fromJson({
  'id': 12345,
  'type': type,
  'page_count': pages,
  'visible': visible,
  if (pages == 1) 'meta_single_page': {'original_image_url': _url(0)},
  if (pages > 1)
    'meta_pages': [
      for (var page = 0; page < pages; page++)
        {
          'image_urls': {'original': _url(page)},
        },
    ],
});

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions, Future<void>?) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets('an original still making progress after 20 seconds completes', (
    tester,
  ) async {
    final body = StreamController<Uint8List>();
    final started = Completer<void>();
    final adapter = _Adapter((options, cancelled) async {
      unawaited(
        cancelled!.then((_) {
          if (!body.isClosed) unawaited(body.close());
        }),
      );
      started.complete();
      return ResponseBody(
        body.stream,
        200,
        headers: {
          Headers.contentTypeHeader: ['image/png'],
          Headers.contentLengthHeader: ['5'],
        },
      );
    });
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final session = CancelToken();
    addTearDown(session.cancel);
    final outcome = expectLater(
      PixivOriginalMediaHasher(
        dio: dio,
        queue: PixivHashDownloadQueue(),
      ).hash(Uri.parse(_url(0)), 10, (_) {}, session),
      completion(_hash),
    );
    for (var step = 0; step < 20 && !started.isCompleted; step++) {
      await tester.pump(Duration.zero);
    }
    expect(started.isCompleted, isTrue);
    for (final byte in 'hello'.codeUnits) {
      if (body.isClosed) break;
      body.add(Uint8List.fromList([byte]));
      await tester.pump(const Duration(seconds: 6));
    }
    if (!body.isClosed) unawaited(body.close());
    await tester.pump(Duration.zero);
    await outcome;
  });

  test(
    'originals are streamed into MD5 with only public CDN request headers',
    () async {
      final adapter = _Adapter(
        (_, _) async => ResponseBody.fromBytes(
          'hello'.codeUnits,
          200,
          headers: {
            Headers.contentTypeHeader: ['image/png'],
            Headers.contentLengthHeader: ['5'],
          },
        ),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final hasher = PixivOriginalMediaHasher(
        dio: dio,
        queue: PixivHashDownloadQueue(),
      );
      var bytes = 0;
      expect(
        await hasher.hash(
          Uri.parse(_url(0)),
          10,
          (n) => bytes += n,
          CancelToken(),
        ),
        _hash,
      );
      expect(bytes, 5);
      expect(adapter.requests.single.followRedirects, isFalse);
      expect(
        adapter.requests.single.headers['Referer'],
        'https://www.pixiv.net/',
      );
      expect(
        adapter.requests.single.headers.keys.map((s) => s.toLowerCase()),
        isNot(anyOf(contains('authorization'), contains('cookie'))),
      );
    },
  );

  for (final (name, body, limit) in [
    (
      'declared size',
      ResponseBody.fromBytes(
        [1, 2],
        200,
        headers: {
          Headers.contentTypeHeader: ['image/png'],
          Headers.contentLengthHeader: ['100'],
        },
      ),
      4,
    ),
    (
      'streamed size',
      ResponseBody.fromBytes(
        [1, 2, 3, 4, 5],
        200,
        headers: {
          Headers.contentTypeHeader: ['image/png'],
        },
      ),
      4,
    ),
    (
      'truncated body',
      ResponseBody.fromBytes(
        [1, 2],
        200,
        headers: {
          Headers.contentTypeHeader: ['image/png'],
          Headers.contentLengthHeader: ['3'],
        },
      ),
      4,
    ),
    (
      'HTML error body',
      ResponseBody.fromBytes(
        [1, 2],
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      ),
      4,
    ),
    (
      'redirect',
      ResponseBody.fromBytes(
        [],
        302,
        headers: {
          'location': ['https://evil.test/a.png'],
        },
      ),
      4,
    ),
  ]) {
    test('rejects $name rather than inventing an original digest', () async {
      final adapter = _Adapter((_, _) async => body);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final hasher = PixivOriginalMediaHasher(
        dio: dio,
        queue: PixivHashDownloadQueue(),
      );
      await expectLater(
        hasher.hash(Uri.parse(_url(0)), limit, (_) {}, CancelToken()),
        throwsA(anything),
      );
      expect(adapter.requests, hasLength(1));
    });
  }

  for (final deadline in [false, true]) {
    testWidgets(
      deadline
          ? 'the original download deadline cancels the body stream'
          : 'session cancellation aborts an active original body',
      (tester) async {
        final body = StreamController<Uint8List>();
        addTearDown(() {
          unawaited(body.close());
        });
        final started = Completer<void>();
        final cancelled = Completer<void>();
        final adapter = _Adapter((options, signal) async {
          unawaited(
            signal!.then((_) {
              if (!cancelled.isCompleted) cancelled.complete();
              unawaited(body.close());
            }),
          );
          started.complete();
          return ResponseBody(
            body.stream,
            200,
            headers: {
              Headers.contentTypeHeader: ['image/png'],
            },
          );
        });
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final hasher = PixivOriginalMediaHasher(
          dio: dio,
          queue: PixivHashDownloadQueue(),
        );
        final session = CancelToken();
        addTearDown(session.cancel);
        final outcome = expectLater(
          hasher.hash(Uri.parse(_url(0)), 10, (_) {}, session),
          throwsA(isA<DioException>()),
        );
        for (var step = 0; step < 20 && !started.isCompleted; step++) {
          await tester.pump(Duration.zero);
        }
        expect(started.isCompleted, isTrue);
        if (deadline) {
          await tester.pump(const Duration(seconds: 61));
        } else {
          session.cancel();
          await tester.pump(Duration.zero);
        }
        await outcome;
        expect(cancelled.isCompleted, isTrue);
        expect(adapter.requests, hasLength(1));
      },
    );
  }

  test(
    'all target callers share one metadata and serial original resolution',
    () async {
      var metadata = 0;
      final downloaded = <Uri>[];
      final resolver = PixivOriginalHashResolver(
        artworkId: '12345',
        loadArtwork: () async {
          metadata++;
          return _artwork(pages: 2);
        },
        hashOriginal: (uri, limit, consume, token) async {
          downloaded.add(uri);
          consume(5);
          return _hash;
        },
      );
      addTearDown(resolver.dispose);
      final results = await Future.wait(
        List.generate(4, (_) => resolver.resolve()),
      );
      expect(metadata, 1);
      expect(downloaded.map((u) => u.toString()), [_url(0), _url(1)]);
      expect(
        results.every(
          (r) =>
              r.hashes.length == 1 &&
              r.hashes.single == _hash &&
              r.issue == null,
        ),
        isTrue,
      );
    },
  );

  test(
    'missing authentication never attempts Pixiv metadata or image requests',
    () async {
      final resolver = PixivOriginalHashResolver(
        artworkId: '12345',
        hashOriginal: (_, _, _, _) =>
            throw StateError('No image request permitted'),
      );
      addTearDown(resolver.dispose);
      final result = await resolver.resolve();
      expect(result.hashes, isEmpty);
      expect(result.issue, PixivLookupCoverageIssue.authentication);
    },
  );

  test('Ugoira and restricted artworks do not hash preview frames', () async {
    for (final dto in [_artwork(type: 'ugoira'), _artwork(visible: false)]) {
      final resolver = PixivOriginalHashResolver(
        artworkId: '12345',
        loadArtwork: () async => dto,
        hashOriginal: (_, _, _, _) =>
            throw StateError('No image request permitted'),
      );
      addTearDown(resolver.dispose);
      final result = await resolver.resolve();
      expect(result.hashes, isEmpty);
      expect(
        result.issue,
        dto.type == 'ugoira'
            ? PixivLookupCoverageIssue.ugoira
            : PixivLookupCoverageIssue.restricted,
      );
    }
  });

  test(
    'page and cumulative size limits preserve partial coverage honestly',
    () async {
      var downloads = 0;
      final resolver = PixivOriginalHashResolver(
        artworkId: '12345',
        loadArtwork: () async => _artwork(pages: 4),
        maxPages: 3,
        maxTotalBytes: 10,
        hashOriginal: (_, maxBytes, consume, _) async {
          downloads++;
          expect(maxBytes, lessThanOrEqualTo(10));
          consume(5);
          return _hash;
        },
      );
      addTearDown(resolver.dispose);
      final result = await resolver.resolve();
      expect(downloads, 2);
      expect(result.hashes, [_hash]);
      expect(result.issue, PixivLookupCoverageIssue.originalsUnavailable);
    },
  );

  test(
    'a failed original page does not erase successful page hashes',
    () async {
      final resolver = PixivOriginalHashResolver(
        artworkId: '12345',
        loadArtwork: () async => _artwork(pages: 2),
        hashOriginal: (uri, _, _, _) async {
          if (uri.path.endsWith('_p1.png')) throw StateError('unavailable');
          return _hash;
        },
      );
      addTearDown(resolver.dispose);
      final result = await resolver.resolve();
      expect(result.hashes, [_hash]);
      expect(result.issue, PixivLookupCoverageIssue.originalsUnavailable);
    },
  );

  test(
    'source removal revokes cached digests and prevents later page requests',
    () async {
      var current = true;
      var downloads = 0;
      final resolver = PixivOriginalHashResolver(
        artworkId: '12345',
        loadArtwork: () async => _artwork(),
        isSourceCurrent: () => current,
        hashOriginal: (_, _, _, _) async {
          downloads++;
          return _hash;
        },
      );
      addTearDown(resolver.dispose);
      expect((await resolver.resolve()).hashes, [_hash]);
      current = false;
      expect((await resolver.resolve()).hashes, isEmpty);
      expect(downloads, 1);
    },
  );

  test('queued cancellation does not acquire a CDN request slot', () async {
    final queue = PixivHashDownloadQueue();
    final first = Completer<String>();
    final second = Completer<String>();
    final one = queue.run(() => first.future, CancelToken());
    final two = queue.run(() => second.future, CancelToken());
    final token = CancelToken();
    var started = false;
    final cancelled = expectLater(
      queue.run(() async {
        started = true;
        return _hash;
      }, token),
      throwsA(isA<DioException>()),
    );
    token.cancel();
    await cancelled;
    expect(started, isFalse);
    first.complete(_hash);
    second.complete(_hash);
    await Future.wait([one, two]);
  });

  testWidgets('a metadata hang is bounded by the controlled timeout', (
    tester,
  ) async {
    final metadata = Completer<PixivIllustDto?>();
    final resolver = PixivOriginalHashResolver(
      artworkId: '12345',
      loadArtwork: () => metadata.future,
      hashOriginal: (_, _, _, _) => throw StateError('No download permitted'),
    );
    addTearDown(resolver.dispose);
    final future = resolver.resolve();
    await tester.pump(const Duration(seconds: 11));
    expect((await future).issue, PixivLookupCoverageIssue.originalsUnavailable);
    metadata.complete(_artwork());
  });

  for (final value in [
    'http://i.pximg.net/img-original/12345_p0.png',
    'https://pximg.net.evil.test/img-original/12345_p0.png',
    'https://secret@i.pximg.net/img-original/12345_p0.png',
    'https://i.pximg.net:444/img-original/12345_p0.png',
    'https://i.pximg.net/img-original/123456_p0.png',
    'https://i.pximg.net/img-original/12345_p1.png',
    'https://i.pximg.net/img-original/12345_p0.zip',
    'https://s.pximg.net/common/images/limit_unknown_360.png',
    '${_url(0)}?token=anything',
  ]) {
    test('rejects unsafe or non-original media URI $value', () {
      expect(
        PixivOriginalHashResolver.safeOriginalUri(value, '12345', 0),
        isNull,
      );
    });
  }
}
