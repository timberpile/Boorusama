import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:background_downloader/background_downloader.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late VideoCacheManager manager;
  late _Adapter adapter;
  late Dio transport;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('guarded-video-');
    adapter = _Adapter();
    transport = Dio()..httpClientAdapter = adapter;
    manager = VideoCacheManager(
      fileDownloader: _Downloader(),
      dio: Dio(),
      cacheRootPathProvider: () => root.path,
      maxItemSize: 4,
      maxTotalCacheSize: 6,
    );
  });
  tearDown(() async {
    await manager.dispose();
    await root.delete(recursive: true);
  });
  Future<VideoCacheLease> acquire(
    String namespace, {
    bool retain = true,
    CancelToken? token,
    bool Function()? current,
  }) => manager.acquireGuardedVideo(
    'https://example.test/a.mp4',
    namespace: namespace,
    transport: transport,
    isCurrent: current ?? () => true,
    cancelToken: token ?? CancelToken(),
    retain: retain,
  );

  test('scoped cache hits, concurrent callers and leases', () async {
    final leases = await Future.wait([acquire('a'), acquire('a')]);
    expect(adapter.calls, 1);
    expect(leases.first.path, leases.last.path);
    expect(await File(leases.first.path).readAsBytes(), [1, 2, 3]);
    final other = await acquire('b');
    expect(adapter.calls, 2);
    expect(other.path, isNot(leases.first.path));
    await manager.clearAllVideos();
    expect(await File(leases.first.path).exists(), isTrue);
    await leases.first.release();
    await leases.last.release();
    await other.release();
    expect(await File(leases.first.path).exists(), isFalse);
  });

  test(
    'guarded preparation preserves explicit source headers and media purpose',
    () async {
      final lease = await manager.acquireGuardedVideo(
        'https://example.test/a.mp4',
        namespace: 'source',
        transport: transport,
        isCurrent: () => true,
        cancelToken: CancelToken(),
        headers: {
          'Source-Access': 'fixture-only',
          'Referer': 'https://example.test/',
        },
      );
      expect(adapter.lastRequest!.headers['Source-Access'], 'fixture-only');
      expect(adapter.lastRequest!.headers['Referer'], 'https://example.test/');
      expect(adapter.lastRequest!.extra['boorusama.request.media'], isTrue);
      await lease.release();
    },
  );

  test('retention is deferred until release and isolated', () async {
    final a = await acquire('a');
    final b = await acquire('b', retain: false);
    await b.release();
    expect(await File(b.path).exists(), isFalse);
    expect(await File(a.path).exists(), isTrue);
    await a.release();
  });

  test(
    'over limit, cancellation and revocation leave no partial file',
    () async {
      adapter.bytes = [1, 2, 3, 4, 5];
      await expectLater(acquire('a'), throwsA(isA<VideoCacheException>()));
      adapter.bytes = [1, 2, 3];
      final controller = StreamController<Uint8List>();
      adapter.stream = controller.stream;
      final started = adapter.started = Completer<void>();
      final token = CancelToken();
      final pending = acquire('b', token: token);
      await started.future;
      token.cancel();
      await expectLater(pending, throwsA(anything));
      await controller.close();
      adapter.stream = null;
      adapter.started = null;
      var valid = true;
      adapter.onFetch = () => valid = false;
      await expectLater(
        acquire('c', current: () => valid),
        throwsA(isA<VideoCacheException>()),
      );
      final dir = await manager.getCacheDirectory();
      expect(dir.listSync(), isEmpty);
    },
  );

  test(
    'clear and disposal cancel stalled transfers without publication',
    () async {
      for (final clearAll in [true, false]) {
        final controller = StreamController<Uint8List>();
        adapter.stream = controller.stream;
        final started = adapter.started = Completer<void>();
        final pending = acquire('clear');
        final result = expectLater(pending, throwsA(anything));
        await started.future;
        if (clearAll) {
          await manager.clearAllVideos();
        } else {
          await manager.clearCache(
            manager.generateCacheKey('clear\nhttps://example.test/a.mp4'),
          );
        }
        await result;
        await controller.close();
        final dir = await manager.getCacheDirectory();
        expect(dir.listSync(), isEmpty);
      }
      final controller = StreamController<Uint8List>();
      adapter.stream = controller.stream;
      final started = adapter.started = Completer<void>();
      final pending = acquire('dispose');
      final result = expectLater(pending, throwsA(anything));
      await started.future;
      await manager.dispose();
      await result;
      await controller.close();
      expect((await manager.getCacheDirectory()).listSync(), isEmpty);
    },
  );

  test(
    'rejects oversized scoped cache hits without removing the file',
    () async {
      final dir = await manager.getCacheDirectory();
      final key = manager.generateCacheKey('a\nhttps://example.test/a.mp4');
      final file = File('${dir.path}/$key');
      await file.writeAsBytes([1, 2, 3, 4, 5]);
      await expectLater(acquire('a'), throwsA(isA<VideoCacheException>()));
      expect(await file.exists(), isTrue);
      expect(adapter.calls, 0);
    },
  );

  test('staging bytes are counted once for quota eviction', () async {
    await manager.dispose();
    manager = VideoCacheManager(
      fileDownloader: _Downloader(),
      dio: Dio(),
      cacheRootPathProvider: () => root.path,
      maxItemSize: 4,
      maxTotalCacheSize: 7,
      evictionThreshold: 1,
    );
    final a = await acquire('a');
    await a.release();
    final b = await acquire('b');
    expect(await File(a.path).exists(), isTrue);
    await b.release();
  });

  test('queue rejects the 65th stalled request', () async {
    final controller = StreamController<Uint8List>();
    adapter.stream = controller.stream;
    final started = adapter.started = Completer<void>();
    final pending = [for (var i = 0; i < 64; i++) acquire('queue$i')];
    final results = [
      for (final future in pending) expectLater(future, throwsA(anything)),
    ];
    await started.future;
    await expectLater(acquire('overflow'), throwsA(isA<VideoCacheException>()));
    await manager.dispose();
    await Future.wait(results);
    await controller.close();
  });

  test('active lease blocks quota eviction', () async {
    final a = await acquire('a');
    adapter.bytes = [1, 2, 3, 4];
    await expectLater(acquire('b'), throwsA(isA<VideoCacheException>()));
    expect(await File(a.path).readAsBytes(), [1, 2, 3]);
    await a.release();
  });
}

class _Adapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  int calls = 0;
  List<int> bytes = [1, 2, 3];
  Stream<Uint8List>? stream;
  Completer<void>? started;
  void Function()? onFetch;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    calls++;
    expect(options.method, 'GET');
    onFetch?.call();
    started?.complete();
    return ResponseBody(stream ?? Stream.value(Uint8List.fromList(bytes)), 200);
  }

  @override
  void close({bool force = false}) {}
}

class _Downloader implements FileDownloader {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Downloader must not be used');
}
