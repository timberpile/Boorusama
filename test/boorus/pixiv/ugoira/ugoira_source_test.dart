import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/ugoira/ugoira_source.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'uses the artwork id and keeps ZIP traffic on the media transport',
    () async {
      final client = _Client('https://i.pximg.net/sample.zip');
      final adapter = _ArchiveAdapter();
      final media = Dio()..httpClientAdapter = adapter;
      addTearDown(() => media.close(force: true));
      final token = CancelToken();

      final result = await PixivUgoiraSource(client: client, media: media).load(
        987654,
        token,
      );

      expect(client.request, (987654, token));
      expect(result.durationMilliseconds, 75);
      final request = adapter.requests.single;
      expect(request.uri.host, 'i.pximg.net');
      expect(request.headers, containsPair('Referer', kPixivImageReferer));
      expect(request.headers, isNot(contains('Authorization')));
      expect(request.extra, containsPair(apiMediaRequestKey, true));
      expect(request.followRedirects, isFalse);
    },
  );

  test('reports received ZIP bytes until archive preparation', () async {
    late double firstFraction;
    final media = Dio()
      ..httpClientAdapter = _ArchiveAdapter((bytes) {
        const firstChunkSize = 10;
        firstFraction = firstChunkSize / bytes.length;
        return ResponseBody(
          Stream.fromIterable([
            Uint8List.sublistView(bytes, 0, firstChunkSize),
            Uint8List.sublistView(bytes, firstChunkSize),
          ]),
          200,
          headers: {
            Headers.contentLengthHeader: ['${bytes.length}'],
          },
        );
      });
    addTearDown(() => media.close(force: true));
    final progress = <double?>[];
    final source = PixivUgoiraSource(
      client: _Client('https://i.pximg.net/sample.zip'),
      media: media,
    );

    final duration = await source.prepare(
      122,
      CancelToken(),
      (animation) {
        expect(progress, [0, firstFraction, 1, null]);
        return animation.durationMilliseconds;
      },
      onDownloadProgress: progress.add,
    );
    expect(duration, 75);
  });

  for (final hasContentEncoding in [false, true]) {
    test(
      'leaves ZIP size indeterminate (content encoded: $hasContentEncoding)',
      () async {
        final media = Dio()
          ..httpClientAdapter = _ArchiveAdapter(
            (bytes) => ResponseBody.fromBytes(
              bytes,
              200,
              headers: {
                if (hasContentEncoding) ...{
                  Headers.contentLengthHeader: ['${bytes.length - 10}'],
                  Headers.contentEncodingHeader: ['gzip'],
                },
              },
            ),
          );
        addTearDown(() => media.close(force: true));
        final progress = <double?>[];
        final source = PixivUgoiraSource(
          client: _Client('https://i.pximg.net/sample.zip'),
          media: media,
        );

        final duration = await source.prepare(
          122,
          CancelToken(),
          (animation) => animation.durationMilliseconds,
          onDownloadProgress: progress.add,
        );
        expect(progress, isEmpty);
        expect(duration, 75);
      },
    );
  }

  test(
    'a rejected archive host or cancelled metadata never fetches a ZIP',
    () async {
      final adapter = _ArchiveAdapter();
      final media = Dio()..httpClientAdapter = adapter;
      addTearDown(() => media.close(force: true));

      final external = PixivUgoiraSource(
        client: _Client('https://example.com/sample.zip'),
        media: media,
      );
      await expectLater(
        external.load(1234, CancelToken()),
        throwsFormatException,
      );

      final trusted = PixivUgoiraSource(
        client: _Client('https://i.pximg.net/sample.zip'),
        media: media,
      );
      await expectLater(
        trusted.load(1234, CancelToken()..cancel()),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test('a new image cache instance reuses the archive offline', () async {
    final root = await Directory.systemTemp.createTemp('ugoira-cache-test');
    addTearDown(() => root.delete(recursive: true));
    final first = _ObservedCache(root.path);
    final media = Dio()..httpClientAdapter = _ArchiveAdapter();
    addTearDown(() => media.close(force: true));
    final online = PixivUgoiraSource(
      client: _Client('https://i.pximg.net/sample.zip'),
      media: media,
      cache: first,
      cacheScope: 'profile/account-a',
    );
    try {
      final animation = await online.load(122, CancelToken());
      expect(animation.durationMilliseconds, 75);
      await first.saved.future.timeout(const Duration(seconds: 10));
    } finally {
      await first.dispose();
    }

    final reopened = _ObservedCache(root.path);
    addTearDown(reopened.dispose);
    final offlineClient = _Client('https://example.com/must-not-fetch.zip');
    final offlineAdapter = _ArchiveAdapter();
    final offlineMedia = Dio()..httpClientAdapter = offlineAdapter;
    addTearDown(() => offlineMedia.close(force: true));
    PixivUgoiraSource source(String scope) => PixivUgoiraSource(
      client: offlineClient,
      media: offlineMedia,
      cache: reopened,
      cacheScope: scope,
    );
    final progress = <double?>[];
    final animation = await source('profile/account-a').prepare(
      122,
      CancelToken(),
      (animation) => animation,
      onDownloadProgress: progress.add,
    );
    expect(animation.durationMilliseconds, 75);
    expect(offlineClient.request, isNull);
    expect(offlineAdapter.requests, isEmpty);
    expect(progress, isEmpty);

    await expectLater(
      source('profile/account-b').load(122, CancelToken()),
      throwsFormatException,
    );
    expect(offlineClient.request?.$1, 122);
    expect(offlineAdapter.requests, isEmpty);
  });

  test('a corrupt disk record is replaced by one authorized fetch', () async {
    final root = await Directory.systemTemp.createTemp('ugoira-cache-test');
    addTearDown(() => root.delete(recursive: true));
    final cache = _ObservedCache(root.path);
    addTearDown(cache.dispose);
    final key = cache.generateCacheKey('pixiv-ugoira-v1:profile/account-a:122');
    await cache.saveFile(key, Uint8List.fromList([1, 2, 3, 4, 5]));
    cache.saved = Completer<void>();

    final adapter = _ArchiveAdapter();
    final media = Dio()..httpClientAdapter = adapter;
    addTearDown(() => media.close(force: true));
    final source = PixivUgoiraSource(
      client: _Client('https://i.pximg.net/sample.zip'),
      media: media,
      cache: cache,
      cacheScope: 'profile/account-a',
    );
    expect((await source.load(122, CancelToken())).durationMilliseconds, 75);
    await cache.saved.future.timeout(const Duration(seconds: 10));
    expect((await source.load(122, CancelToken())).durationMilliseconds, 75);
    expect(adapter.requests, hasLength(1));

    await cache.clearAllCache();
    cache.saved = Completer<void>();
    expect((await source.load(122, CancelToken())).durationMilliseconds, 75);
    await cache.saved.future.timeout(const Duration(seconds: 10));
    expect(adapter.requests, hasLength(2));
  });
}

class _Client extends PixivClient {
  _Client(this.zip) : super(accessToken: 'fixture');

  final String zip;
  (int, CancelToken?)? request;

  @override
  Future<PixivUgoiraMetadataDto?> getUgoiraMetadata({
    required int illustId,
    CancelToken? cancelToken,
  }) async {
    request = (illustId, cancelToken);
    return PixivUgoiraMetadataDto(
      zipUrlMedium: zip,
      frames: const [PixivUgoiraFrame(file: '000000.jpg', delay: 75)],
    );
  }
}

class _ArchiveAdapter implements HttpClientAdapter {
  _ArchiveAdapter([this.buildResponse]);

  final ResponseBody Function(Uint8List bytes)? buildResponse;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('000000.jpg', [0xff, 0xd8, 0xff, 1]));
    final bytes = ZipEncoder().encodeBytes(archive);
    return buildResponse?.call(bytes) ?? ResponseBody.fromBytes(bytes, 200);
  }

  @override
  void close({bool force = false}) {}
}

class _ObservedCache extends DefaultImageCacheManager {
  _ObservedCache(String root) : super(cacheRootPathProvider: () => root);

  var saved = Completer<void>();

  @override
  Future<ImageCacheWriteSession> beginFileWrite(String key) async =>
      _ObservedWrite(await super.beginFileWrite(key), saved);
}

class _ObservedWrite implements ImageCacheWriteSession {
  _ObservedWrite(this.write, this.saved);

  final ImageCacheWriteSession write;
  final Completer<void> saved;

  @override
  String get stagedPath => write.stagedPath;

  @override
  Future<void> abort() => write.abort();

  @override
  Future<ImageCacheFileLease> commit() => write.commit();

  @override
  Future<void> saveBytes(Uint8List bytes) async {
    await write.saveBytes(bytes);
    if (!saved.isCompleted) saved.complete();
  }
}
