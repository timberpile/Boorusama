import 'dart:async';

import 'package:boorusama/core/bookmarks/src/data/bookmark_id_allocator.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Store store;
  late DataMutationCoordinator coordinator;
  BookmarkIdAllocator allocator({int existing = -1}) => BookmarkIdAllocator(
    store: store,
    coordinator: coordinator,
    highestExistingId: () async => existing,
  );
  setUp(() {
    store = _Store();
    coordinator = DataMutationCoordinator();
  });

  test(
    'reserves above all existing IDs and never lowers the durable counter',
    () async {
      final ids = allocator(existing: 120);
      expect(await ids.reserve(2), [121, 122]);
      expect(store.durable, 123);
      expect(await allocator(existing: 0).reserve(1), [123]);
      expect(store.durable, 124);
    },
  );

  test(
    'two repositories share one serialized namespace including ID zero',
    () async {
      final post = allocator();
      final group = allocator();
      final results = await Future.wait([
        post.reserve(2),
        group.reserve(2),
        post.reserve(1),
      ]);
      expect(results.expand((ids) => ids).toList(), [0, 1, 2, 3, 4]);
      expect(store.durable, 5);
      expect(await coordinator.runExclusive(() => group.reserve(1)), [5]);
    },
  );

  test(
    'does not publish IDs before reservation durability completes',
    () async {
      final barrier = Completer<void>();
      final started = Completer<void>();
      store.beforeSync = () async {
        started.complete();
        await barrier.future;
      };
      var completed = false;
      final pending = allocator().reserve(1).then((ids) {
        completed = true;
        return ids;
      });
      await started.future;
      expect(completed, isFalse);
      expect(store.durable, isNull);
      barrier.complete();
      expect(await pending, [0]);
      expect(store.durable, 1);
    },
  );

  test(
    'commit-then-throw consumes its reservation across a fresh allocator',
    () async {
      final ids = allocator();
      expect(await ids.reserve(1), [0]);
      store.failAfterSync = true;
      await expectLater(ids.reserve(1), throwsStateError);
      expect(store.durable, 2);
      store = _Store(durable: store.durable);
      expect(await allocator().reserve(1), [2]);
    },
  );

  test(
    'uncertain reservation must be recovered before any further allocation',
    () async {
      final ids = allocator();
      store.failBeforeWrite = true;
      await expectLater(ids.reserve(1), throwsStateError);
      store.failBeforeSync = true;
      await expectLater(ids.reserve(1), throwsStateError);
      expect(store.durable, isNull);
      final before = store.written.length;
      expect(await ids.reserve(1), [1]);
      expect(store.written.skip(before), [
        1,
        2,
      ], reason: 'Repair the conservative bound before allocating');
      expect(store.durable, 2);
    },
  );

  test(
    'storage-key exhaustion fails cleanly without wrapping or recycling',
    () async {
      store = _Store(durable: maxBookmarkId);
      final ids = allocator();
      expect(await ids.reserve(1), [maxBookmarkId]);
      expect(store.durable, maxBookmarkId + 1);
      final writes = store.written.length;
      await expectLater(
        ids.reserve(1),
        throwsA(isA<BookmarkIdExhaustedException>()),
      );
      expect(store.written.length, writes);
      expect(await ids.reserve(0), isEmpty);
    },
  );

  test('invalid counters and counts cannot publish a reservation', () async {
    for (final invalid in [-1, maxBookmarkId + 2]) {
      store = _Store(durable: invalid);
      await expectLater(allocator().reserve(1), throwsFormatException);
      expect(store.written, isEmpty);
    }
    store = _Store();
    await expectLater(allocator().reserve(-1), throwsArgumentError);
    expect(store.written, isEmpty);
  });
}

class _Store implements BookmarkIdStore {
  _Store({this.durable}) : current = durable;
  int? durable;
  int? current;
  final written = <int>[];
  var failBeforeWrite = false;
  var failBeforeSync = false;
  var failAfterSync = false;
  Future<void> Function()? beforeSync;

  @override
  Future<int?> readNextId() async => current;
  @override
  Future<void> writeNextId(int nextId) async {
    if (failBeforeWrite) {
      failBeforeWrite = false;
      throw StateError('Fixture write failure');
    }
    written.add(nextId);
    current = nextId;
  }

  @override
  Future<void> durableSync() async {
    await beforeSync?.call();
    if (failBeforeSync) {
      failBeforeSync = false;
      throw StateError('Fixture sync failure');
    }
    durable = current;
    if (failAfterSync) {
      failAfterSync = false;
      throw StateError('Fixture committed sync failure');
    }
  }
}
