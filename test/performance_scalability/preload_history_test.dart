import 'dart:async';
import 'dart:typed_data';

import 'package:boorusama/core/posts/media_preload/src/direction_history.dart';
import 'package:boorusama/core/posts/media_preload/src/preload_manager.dart';
import 'package:boorusama/core/posts/media_preload/src/preload_media.dart';
import 'package:boorusama/core/posts/media_preload/src/preload_strategy.dart';
import 'package:boorusama/core/posts/media_preload/src/types.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

PreloadResult plan(List<String> urls, {Set<String> cancel = const {}}) =>
    PreloadResult(
      prioritizedUrls: [
        for (final url in urls)
          PrioritizedUrl(
            url: url,
            priority: 1,
            distance: 1,
            relevanceZone: RelevanceZone.immediate,
          ),
      ],
      cancelUrls: cancel,
    );

void main() {
  test(
    'completion history is bounded and capacity eviction permits a later probe',
    () {
      fakeAsync((async) {
        final requested = <String>[];
        final manager = PreloadManager(
          elapsed: () => async.elapsed,
          preloader: (url, _) async {
            requested.add(url);
          },
        );
        for (var i = 0; i < 300; i++) {
          manager.preloadMedias(plan(['url:$i']));
          async.flushMicrotasks();
        }
        expect(manager.state.completedUrls.length, 256);
        expect(manager.state.activeDownloads, isEmpty);
        manager.preloadMedias(plan(['url:0']));
        async.flushMicrotasks();
        expect(requested.where((url) => url == 'url:0').length, 2);
        expect(manager.state.completedUrls.length, 256);
        manager.dispose();
        expect(manager.state.completedUrls, isEmpty);
      });
    },
  );

  test(
    'completion expires before the real directional strategy plans a revisit',
    () {
      fakeAsync((async) {
        var calls = 0;
        final manager = PreloadManager(
          elapsed: () => async.elapsed,
          preloader: (_, _) async {
            calls++;
          },
        );
        final strategy = DirectionBasedPreloadStrategy(
          directionHistory: DirectionHistory(),
        );
        void request() => manager.preloadWithStrategy(
          strategy: strategy,
          currentPage: 0,
          itemCount: 2,
          mediaBuilder: (index) => ImageMedia.fromUrl('url:$index'),
        );
        request();
        async.flushMicrotasks();
        expect(calls, 1);
        async.elapse(const Duration(seconds: 29));
        request();
        async.flushMicrotasks();
        expect(calls, 1);
        async.elapse(const Duration(seconds: 1));
        expect(calls, 1); // Expiry alone never schedules transport.
        request();
        async.flushMicrotasks();
        expect(calls, 2);
        manager.dispose();
      });
    },
  );

  test('failed transport is retried only by a later plan after cooldown', () {
    fakeAsync((async) {
      var calls = 0;
      final manager = PreloadManager(
        elapsed: () => async.elapsed,
        preloader: (_, _) async {
          if (++calls == 1) throw StateError('offline');
        },
      );
      manager.preloadMedias(plan(['A']));
      async.flushMicrotasks();
      expect(manager.state.completedUrls, isEmpty);
      for (var i = 0; i < 100; i++) {
        manager.preloadMedias(plan(['A']));
        async.flushMicrotasks();
      }
      expect(calls, 1);
      async.elapse(const Duration(seconds: 5));
      expect(calls, 1);
      manager.preloadMedias(plan(['A']));
      async.flushMicrotasks();
      expect(calls, 2);
      expect(manager.state.completedUrls, {'A'});
      manager.dispose();
    });
  });

  for (final failed in [false, true]) {
    test(
      'one plan cannot repeat a URL after ${failed ? "failure cooldown" : "completion expiry"}',
      () {
        fakeAsync((clock) {
          final requested = <String>[];
          final blocked = Completer<void>();
          final manager = PreloadManager(
            elapsed: () => clock.elapsed,
            downloadConfiguration: const DownloadConfiguration(
              maxConcurrentDownloads: 1,
            ),
            preloader: (url, _) {
              requested.add(url);
              if (url == 'B') return blocked.future;
              if (failed &&
                  requested.where((value) => value == 'A').length == 1) {
                return Future<void>.error(StateError('offline'));
              }
              return Future<void>.value();
            },
          );
          // The later, higher-priority occurrence must win deduplication, so A
          // still starts before B even though its first occurrence ranks last.
          manager.preloadMedias(
            PreloadResult(
              prioritizedUrls: [
                for (final entry in [('A', 1.0), ('B', 2.0), ('A', 3.0)])
                  PrioritizedUrl(
                    url: entry.$1,
                    priority: entry.$2,
                    distance: 1,
                    relevanceZone: RelevanceZone.immediate,
                  ),
              ],
            ),
          );
          clock.flushMicrotasks();
          expect(requested, ['A', 'B']);
          clock.elapse(Duration(seconds: failed ? 5 : 30));
          blocked.complete();
          clock.flushMicrotasks();
          expect(requested, ['A', 'B']);
          expect(manager.state.activeDownloads, isEmpty);
          // Expiry restores eligibility; only a new plan may dispatch A again.
          manager.preloadMedias(plan(['A']));
          clock.flushMicrotasks();
          expect(requested, ['A', 'B', 'A']);
          expect(manager.state.completedUrls, contains('A'));
          manager.dispose();
        });
      },
    );
  }

  test(
    'negative history has bounded capacity rather than retaining every failure',
    () {
      fakeAsync((async) {
        var calls = 0;
        final manager = PreloadManager(
          elapsed: () => async.elapsed,
          preloader: (_, _) async {
            calls++;
            throw StateError('offline');
          },
        );
        for (var i = 0; i < 300; i++) {
          manager.preloadMedias(plan(['url:$i']));
          async.flushMicrotasks();
        }
        manager.preloadMedias(plan(['url:299']));
        async.flushMicrotasks();
        expect(calls, 300);
        manager.preloadMedias(plan(['url:0']));
        async.flushMicrotasks();
        expect(calls, 301);
        manager.dispose();
      });
    },
  );

  for (final failOld in [false, true]) {
    test(
      'a late cancelled ${failOld ? "failure" : "success"} cannot take ownership from its replacement',
      () {
        fakeAsync((async) {
          final pending = <Completer<void>>[];
          final tokens = <CancelToken>[];
          final manager = PreloadManager(
            elapsed: () => async.elapsed,
            preloader: (_, token) {
              tokens.add(token);
              final result = Completer<void>();
              pending.add(result);
              return result.future;
            },
          );
          manager.preloadMedias(plan(['A']));
          manager.preloadMedias(plan(['A'], cancel: {'A'}));
          expect(tokens.first.isCancelled, isTrue);
          expect(pending.length, 2);
          if (failOld) {
            pending.first.completeError(StateError('late'));
          } else {
            pending.first.complete();
          }
          async.flushMicrotasks();
          expect(manager.state.activeDownloads, {'A'});
          expect(manager.state.completedUrls, isEmpty);
          pending.last.complete();
          async.flushMicrotasks();
          expect(manager.state.activeDownloads, isEmpty);
          expect(manager.state.completedUrls, {'A'});
          manager.dispose();
        });
      },
    );
  }

  test('deduplication, two active slots, and disposal remain bounded', () {
    fakeAsync((async) {
      final pending = <String, Completer<void>>{};
      final tokens = <CancelToken>[];
      final manager = PreloadManager(
        elapsed: () => async.elapsed,
        downloadConfiguration: const DownloadConfiguration(
          maxConcurrentDownloads: 2,
        ),
        preloader: (url, token) {
          tokens.add(token);
          return (pending[url] = Completer<void>()).future;
        },
      );
      manager.preloadMedias(plan(['A', 'A', 'B', 'C']));
      expect(pending.length, 2);
      expect(manager.state.activeDownloads.length, 2);
      pending.values.first.complete();
      async.flushMicrotasks();
      expect(pending.length, 3);
      expect(manager.state.activeDownloads.length, 2);
      manager.dispose();
      expect(tokens.where((token) => !token.isCancelled).length, 1);
      for (final operation in pending.values) {
        if (!operation.isCompleted) operation.complete();
      }
      async.flushMicrotasks();
      manager.preloadMedias(plan(['D']));
      async.flushMicrotasks();
      expect(pending.containsKey('D'), isFalse);
      expect(manager.state.completedUrls, isEmpty);
      expect(manager.state.activeDownloads, isEmpty);
    });
  });

  test(
    'disabling automatic media cancels active work without late completion',
    () {
      fakeAsync((async) {
        var enabled = true;
        final operation = Completer<void>();
        late CancelToken token;
        final manager = PreloadManager(
          elapsed: () => async.elapsed,
          isEnabled: () => enabled,
          preloader: (_, value) {
            token = value;
            return operation.future;
          },
        );
        manager.preloadMedias(plan(['A']));
        enabled = false;
        manager.preloadMedias(plan(['B']));
        expect(token.isCancelled, isTrue);
        operation.complete();
        async.flushMicrotasks();
        expect(manager.state.completedUrls, isEmpty);
        expect(manager.state.activeDownloads, isEmpty);
        manager.dispose();
      });
    },
  );

  for (final propagate in [false, true]) {
    test(
      'image preloader ${propagate ? "reports" : "suppresses"} empty transport failure when requested',
      () async {
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (request, handler) {
                handler.resolve(
                  Response<List<int>>(
                    requestOptions: request,
                    statusCode: 200,
                    data: [],
                  ),
                );
              },
            ),
          );
        addTearDown(() => dio.close(force: true));
        final image = ImagePreloader(cacheManager: _ByteCache(), dio: dio);
        final result = image.preloadImage(
          'https://image.test/A',
          propagateErrors: propagate,
        );
        if (propagate) {
          await expectLater(result, throwsStateError);
        } else {
          await result;
        }
      },
    );
  }

  test('real image-preloader failure reaches manager retry policy', () async {
    var calls = 0;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.resolve(
              Response<List<int>>(
                requestOptions: request,
                statusCode: 200,
                data: ++calls == 1 ? [] : [1, 2, 3],
              ),
            );
          },
        ),
      );
    addTearDown(() => dio.close(force: true));
    final cache = _ByteCache();
    final image = ImagePreloader(cacheManager: cache, dio: dio);
    var elapsed = Duration.zero;
    final completions = <Completer<void>>[];
    final manager = PreloadManager(
      elapsed: () => elapsed,
      preloader: (url, token) async {
        final completed = Completer<void>();
        completions.add(completed);
        try {
          await image.preloadImage(
            url,
            cancelToken: token,
            propagateErrors: true,
          );
        } finally {
          completed.complete();
        }
      },
    );
    addTearDown(manager.dispose);
    Future<void> settle() async {
      await completions.last.future;
      // Await the manager continuation without relying on a wall-clock sleep.
      await Future<void>.value();
      await Future<void>.value();
    }

    manager.preloadMedias(plan(['https://image.test/A']));
    await settle();
    expect(manager.state.completedUrls, isEmpty);
    expect(manager.state.activeDownloads, isEmpty);
    manager.preloadMedias(plan(['https://image.test/A']));
    expect(calls, 1);
    elapsed = const Duration(seconds: 5);
    manager.preloadMedias(plan(['https://image.test/A']));
    await settle();
    expect(calls, 2);
    expect(cache.entries['https://image.test/A'], [1, 2, 3]);
    expect(manager.state.completedUrls, {'https://image.test/A'});
  });
}

class _ByteCache implements ImageCacheManager {
  final entries = <String, Uint8List>{};
  @override
  String generateCacheKey(String url, {String? customKey}) => customKey ?? url;
  @override
  FutureOr<bool> hasValidCache(String key, {Duration? maxAge}) =>
      entries.containsKey(key);
  @override
  Future<void> saveFile(String key, Uint8List bytes) async {
    entries[key] = bytes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
