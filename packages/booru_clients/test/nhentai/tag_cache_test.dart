import 'dart:async';

import 'package:booru_clients/nhentai.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

NhentaiTag tag(int id, {String type = 'tag', String? name}) =>
    NhentaiTag(id: id, type: type, name: name ?? 'fixture_$id');
NhentaiResultPage<NhentaiTag> page(
  int n,
  Iterable<int> ids, {
  int count = 2,
  int total = 240,
  String category = 'tag',
}) => NhentaiResultPage(
  items: [for (final id in ids) tag(id, type: category)],
  page: n,
  total: total,
  pageCount: count,
  reportedPerPage: 120,
);

class Store implements NhentaiTagStore {
  final tags = <int, NhentaiTag>{};
  final checkpoints = <(String, String), NhentaiTagCheckpoint>{};
  final calls = <String>[];
  bool failBatch = false;
  bool failCheckpoint = false;
  Completer<void>? batchStarted;
  Completer<void>? batchGate;
  Completer<void>? checkpointStarted;
  Completer<void>? checkpointGate;
  void source(Uri source) => expect(source.toString(), 'https://nhentai.net');
  @override
  Future<Map<int, NhentaiTag>> readTags(Uri value, Set<int> ids) async {
    source(value);
    return {
      for (final id in ids) id: ?tags[id],
    };
  }

  @override
  Future<void> upsertTags(Uri value, List<NhentaiTag> values) async {
    source(value);
    calls.add('batch');
    if (batchStarted case final started? when !started.isCompleted) {
      started.complete();
    }
    await batchGate?.future;
    if (failBatch) {
      failBatch = false;
      throw StateError('batch write failed');
    }
    tags.addAll({for (final tag in values) tag.id: tag});
  }

  @override
  Future<NhentaiTagCheckpoint?> readCheckpoint(
    Uri value,
    String category,
    String sort,
  ) async {
    source(value);
    return checkpoints[(category, sort)];
  }

  @override
  Future<void> writeCheckpoint(
    Uri value,
    NhentaiTagCheckpoint checkpoint,
  ) async {
    source(value);
    calls.add('checkpoint');
    if (checkpointStarted case final started? when !started.isCompleted) {
      started.complete();
    }
    await checkpointGate?.future;
    if (failCheckpoint) {
      failCheckpoint = false;
      throw StateError('checkpoint write failed');
    }
    checkpoints[(checkpoint.category, checkpoint.sort)] = checkpoint;
  }
}

class StoreWrapper
    implements NhentaiTagStore, NhentaiTagStoreSerializationOwner {
  StoreWrapper(this.delegate);
  final Store delegate;
  @override
  Object get serializationOwner => delegate;
  @override
  Future<Map<int, NhentaiTag>> readTags(Uri source, Set<int> ids) =>
      delegate.readTags(source, ids);
  @override
  Future<void> upsertTags(Uri source, List<NhentaiTag> tags) =>
      delegate.upsertTags(source, tags);
  @override
  Future<NhentaiTagCheckpoint?> readCheckpoint(
    Uri source,
    String category,
    String sort,
  ) => delegate.readCheckpoint(source, category, sort);
  @override
  Future<void> writeCheckpoint(Uri source, NhentaiTagCheckpoint checkpoint) =>
      delegate.writeCheckpoint(source, checkpoint);
}

void main() {
  test(
    'native details can remember observed tags without another lookup',
    () async {
      final store = Store();
      final cache = NhentaiTagCache(
        store: store,
        lookup: (_, _) => throw StateError('Already observed'),
        catalog: (_, _, _, _) => throw UnimplementedError(),
      );
      addTearDown(cache.dispose);
      await cache.remember([tag(5), tag(5, name: 'latest')]);
      expect((await cache.resolveVisible([5]))[5]!.name, 'latest');
      expect(store.calls, ['batch']);
    },
  );
  test(
    'constructor does no work and visible IDs resolve in deduplicated batches',
    () async {
      final store = Store();
      final requests = <List<int>>[];
      final cache = NhentaiTagCache(
        store: store,
        lookup: (ids, token) async {
          requests.add(ids);
          return [for (final id in ids) tag(id)];
        },
        catalog: (_, _, _, _) =>
            throw StateError('No catalog during visible lookup'),
      );
      addTearDown(cache.dispose);
      expect(requests, isEmpty);
      expect(store.calls, isEmpty);
      final visible = await cache.resolveVisible([
        ...List.generate(205, (i) => i + 1),
        1,
        1,
      ]);
      expect(visible.length, 205);
      expect(requests.map((r) => r.length), [100, 100, 5]);
      await cache.resolveVisible([1, 2, 205]);
      expect(requests.length, 3);
    },
  );
  test(
    'overlapping visible callers share reads but cancellation does not revoke the other',
    () async {
      final store = Store();
      final started = Completer<void>();
      final result = Completer<List<NhentaiTag>>();
      var count = 0;
      final cache = NhentaiTagCache(
        store: store,
        lookup: (ids, token) {
          count++;
          started.complete();
          return result.future;
        },
        catalog: (_, _, _, _) => throw UnimplementedError(),
      );
      addTearDown(cache.dispose);
      final token = CancelToken();
      final first = cache.resolveVisible([1, 2], cancelToken: token);
      final cancelled = expectLater(first, throwsA(isA<DioException>()));
      await started.future;
      final second = cache.resolveVisible([1, 2]);
      token.cancel('first observer left');
      await cancelled;
      result.complete([tag(1), tag(2)]);
      expect((await second).keys, {1, 2});
      expect(count, 1);
    },
  );
  test(
    'source disposal cancels shared visible transport and never stores late tags',
    () async {
      final store = Store();
      final started = Completer<CancelToken>();
      final result = Completer<List<NhentaiTag>>();
      final cache = NhentaiTagCache(
        store: store,
        lookup: (ids, token) {
          started.complete(token);
          return result.future;
        },
        catalog: (_, _, _, _) => throw UnimplementedError(),
      );
      final read = cache.resolveVisible([1]);
      final cancelled = expectLater(read, throwsA(isA<DioException>()));
      final token = await started.future;
      cache.dispose();
      expect(token.isCancelled, isTrue);
      result.complete([tag(1)]);
      await cancelled;
      await Future<void>.value();
      expect(store.tags, isEmpty);
    },
  );
  test(
    'actual 120-result pages advance by server page facts and retain partial coverage',
    () async {
      final store = Store();
      final requests = <int>[];
      final now = DateTime.utc(2026, 11, 8);
      final cache = NhentaiTagCache(
        store: store,
        lookup: (_, _) => throw UnimplementedError(),
        catalog: (category, sort, n, token) async {
          requests.add(n);
          return page(
            n,
            List.generate(120, (i) => i + (n == 1 ? 1 : 115)),
            total: n == 1 ? 240 : 245,
          );
        },
        now: () => now,
      );
      addTearDown(cache.dispose);
      final first = await cache.warmCatalog('tag');
      expect(first.nextPage, 2);
      expect(store.tags.length, 120);
      expect(store.calls, ['batch', 'checkpoint']);
      expect(first.observedAt, now);
      final second = await cache.warmCatalog('tag');
      expect(second.nextPage, isNull);
      expect(second.seenIds.length, 234);
      expect(second.catalogChanged, isTrue);
      expect(second.coverageIsComplete, isFalse);
      expect(requests, [1, 2]);
      await cache.warmCatalog('tag');
      expect(requests, [1, 2]);
    },
  );
  for (final failure in ['batch', 'checkpoint']) {
    test(
      '$failure failure replays the same source page after recreation without losing known tags',
      () async {
        final store = Store()
          ..failBatch = failure == 'batch'
          ..failCheckpoint = failure == 'checkpoint';
        final requests = <int>[];
        NhentaiTagCache open() => NhentaiTagCache(
          store: StoreWrapper(store),
          lookup: (_, _) => throw UnimplementedError(),
          catalog: (category, sort, n, token) async {
            requests.add(n);
            return page(n, [1, 2]);
          },
        );
        final first = open();
        await expectLater(first.warmCatalog('tag'), throwsStateError);
        first.dispose();
        expect(store.checkpoints, isEmpty);
        if (failure == 'checkpoint') expect(store.tags.keys, {1, 2});
        final second = open();
        addTearDown(second.dispose);
        final state = await second.warmCatalog('tag');
        expect(state.nextPage, 2);
        expect(requests, [1, 1]);
        expect(store.tags.length, 2);
      },
    );
  }
  test(
    'repeated, empty-continuing and unproven pages do not advance checkpoint',
    () async {
      final store = Store();
      var mode = 'normal';
      final cache = NhentaiTagCache(
        store: store,
        lookup: (_, _) => throw UnimplementedError(),
        catalog: (category, sort, n, token) async => switch (mode) {
          'repeat' => page(n, [1, 2]),
          'empty' => page(n, [], count: 3),
          'unknown' => NhentaiResultPage(items: [tag(3)], page: n),
          _ => page(n, [1, 2]),
        },
      );
      addTearDown(cache.dispose);
      await cache.warmCatalog('tag');
      final original = store.checkpoints[('tag', 'popular')];
      for (final value in ['repeat', 'empty', 'unknown']) {
        mode = value;
        await expectLater(cache.warmCatalog('tag'), throwsStateError);
        expect(store.checkpoints[('tag', 'popular')], same(original));
      }
    },
  );
  test(
    'category checkpoints are independent and known tags survive category sweeps',
    () async {
      final store = Store();
      final cache = NhentaiTagCache(
        store: store,
        lookup: (_, _) => throw UnimplementedError(),
        catalog: (category, sort, n, token) async =>
            page(n, [category == 'tag' ? 1 : 2], count: 1, category: category),
      );
      addTearDown(cache.dispose);
      await cache.warmCatalog('tag');
      await cache.warmCatalog('artist');
      expect(store.checkpoints.keys, {
        ('tag', 'popular'),
        ('artist', 'popular'),
      });
      expect(store.tags.keys, {1, 2});
    },
  );
  test(
    'visible IDs proceed during an in-flight catalog and take priority before the next page',
    () async {
      final store = Store();
      final catalogStarted = Completer<void>();
      final catalogResult = Completer<NhentaiResultPage<NhentaiTag>>();
      final visibleStarted = Completer<void>();
      final visibleResult = Completer<List<NhentaiTag>>();
      final events = <String>[];
      final cache = NhentaiTagCache(
        store: store,
        lookup: (ids, token) {
          events.add('visible');
          visibleStarted.complete();
          return visibleResult.future;
        },
        catalog: (category, sort, n, token) {
          events.add('catalog:$n');
          if (n == 1) {
            catalogStarted.complete();
            return catalogResult.future;
          }
          return Future.value(page(n, [2]));
        },
      );
      addTearDown(cache.dispose);
      final warm = cache.warmCatalog('tag', pageBudget: 2);
      await catalogStarted.future;
      final visible = cache.resolveVisible([99]);
      await visibleStarted.future;
      catalogResult.complete(page(1, [1]));
      await Future<void>.value();
      await Future<void>.value();
      expect(events, ['catalog:1', 'visible']);
      visibleResult.complete([tag(99)]);
      await visible;
      await warm;
      expect(events, ['catalog:1', 'visible', 'catalog:2']);
      expect(store.tags.keys, {1, 2, 99});
    },
  );
  test(
    'a bounded recheck retains unseen known tags and refreshes source names',
    () async {
      final store = Store();
      var fresh = false;
      final cache = NhentaiTagCache(
        store: store,
        lookup: (_, _) => throw UnimplementedError(),
        catalog: (category, sort, n, token) async => NhentaiResultPage(
          items: fresh ? [tag(1, name: 'renamed')] : [tag(1), tag(2)],
          page: n,
          pageCount: 1,
          total: fresh ? 1 : 2,
        ),
      );
      addTearDown(cache.dispose);
      await cache.warmCatalog('tag');
      fresh = true;
      final result = await cache.warmCatalog('tag', restartSweep: true);
      expect(result.nextPage, isNull);
      expect(result.seenIds, {1});
      expect(store.tags[1]!.name, 'renamed');
      expect(store.tags.containsKey(2), isTrue);
      expect(result.coverageIsComplete, isFalse);
    },
  );

  test(
    'catalog cancellation during batch persistence never advances the checkpoint',
    () async {
      final store = Store()
        ..batchStarted = Completer<void>()
        ..batchGate = Completer<void>();
      final cache = NhentaiTagCache(
        store: store,
        lookup: (_, _) => throw UnimplementedError(),
        catalog: (category, sort, n, token) async => page(n, [1]),
      );
      addTearDown(cache.dispose);
      final token = CancelToken();
      final warm = cache.warmCatalog('tag', cancelToken: token);
      final cancelled = expectLater(warm, throwsA(isA<DioException>()));
      await store.batchStarted!.future;
      token.cancel('fixture left');
      final resumed = cache.warmCatalog('tag');
      store.batchGate!.complete();
      await cancelled;
      expect((await resumed).nextPage, 2);
      expect(store.calls, ['batch', 'batch', 'checkpoint']);
    },
  );

  for (final replaceSource in [false, true]) {
    test(
      '${replaceSource ? 'disposed replacement' : 'cancelled caller'} waits for a started checkpoint before resuming traversal',
      () async {
        final store = Store()
          ..checkpointStarted = Completer<void>()
          ..checkpointGate = Completer<void>();
        final requests = <int>[];
        NhentaiTagCache open() => NhentaiTagCache(
          store: StoreWrapper(store),
          lookup: (_, _) => throw UnimplementedError(),
          catalog: (category, sort, n, token) async {
            requests.add(n);
            return page(n, [n]);
          },
        );
        final first = open();
        addTearDown(first.dispose);
        final token = CancelToken();
        final warm = first.warmCatalog('tag', cancelToken: token);
        final cancelled = expectLater(warm, throwsA(isA<DioException>()));
        var firstSettled = false;
        unawaited(cancelled.then((_) => firstSettled = true));
        await store.checkpointStarted!.future;
        if (replaceSource) {
          first.dispose();
        } else {
          token.cancel('fixture left');
        }
        final next = replaceSource ? open() : first;
        if (replaceSource) addTearDown(next.dispose);
        final resumed = next.warmCatalog('tag');
        // Drain already queued cancellation/dispatch continuations while the
        // durable write remains explicitly gated, without a host-time budget.
        await Future<void>.value();
        await Future<void>.value();
        expect(firstSettled, isFalse);
        expect(requests, [1]);
        expect(store.calls, ['batch', 'checkpoint']);
        store.checkpointGate!.complete();
        await cancelled;
        final result = await resumed;
        expect(requests, [1, 2]);
        expect(result.seenIds, {1, 2});
        expect(result.nextPage, isNull);
        expect(store.checkpoints[('tag', 'popular')], same(result));
        expect(store.calls, ['batch', 'checkpoint', 'batch', 'checkpoint']);
      },
    );
  }

  test(
    'late visible upsert cannot overwrite a replacement source observation',
    () async {
      final store = Store()
        ..batchStarted = Completer<void>()
        ..batchGate = Completer<void>();
      final secondLookup = Completer<void>();
      NhentaiTagCache open(String name) => NhentaiTagCache(
        store: store,
        lookup: (ids, token) async {
          if (name == 'new') secondLookup.complete();
          return [tag(1, name: name)];
        },
        catalog: (_, _, _, _) => throw UnimplementedError(),
      );
      final first = open('old');
      final read = first.resolveVisible([1]);
      final cancelled = expectLater(read, throwsA(isA<DioException>()));
      await store.batchStarted!.future;
      first.dispose();
      await cancelled;
      final second = open('new');
      addTearDown(second.dispose);
      final refreshed = second.resolveVisible([1]);
      await secondLookup.future;
      expect(store.calls, ['batch']);
      store.batchGate!.complete();
      expect((await refreshed)[1]!.name, 'new');
      expect(store.tags[1]!.name, 'new');
      expect(store.calls, ['batch', 'batch']);
    },
  );

  test(
    'checkpoint failure after cancellation releases the store queue for safe replay',
    () async {
      final store = Store()
        ..checkpointStarted = Completer<void>()
        ..checkpointGate = Completer<void>()
        ..failCheckpoint = true;
      final requests = <int>[];
      NhentaiTagCache open() => NhentaiTagCache(
        store: store,
        lookup: (_, _) => throw UnimplementedError(),
        catalog: (category, sort, n, token) async {
          requests.add(n);
          return page(n, [1]);
        },
      );
      final first = open();
      final failed = expectLater(first.warmCatalog('tag'), throwsStateError);
      await store.checkpointStarted!.future;
      first.dispose();
      final second = open();
      addTearDown(second.dispose);
      final replay = second.warmCatalog('tag');
      store.checkpointGate!.complete();
      await failed;
      final result = await replay;
      expect(requests, [1, 1]);
      expect(result.nextPage, 2);
      expect(store.tags.keys, {1});
      expect(store.checkpoints[('tag', 'popular')], same(result));
    },
  );
}
