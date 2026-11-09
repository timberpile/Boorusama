import 'dart:async';

import 'package:dio/dio.dart';

import 'models.dart';

/// Source-local persistence seam. Implementations upsert idempotently by source
/// and tag ID; canonical source names are separate from UI translations.
/// Persisting the batch before its checkpoint makes an interrupted page replay safe.
abstract interface class NhentaiTagStore {
  Future<Map<int, NhentaiTag>> readTags(Uri source, Set<int> ids);
  Future<void> upsertTags(Uri source, List<NhentaiTag> tags);
  Future<NhentaiTagCheckpoint?> readCheckpoint(
    Uri source,
    String category,
    String sort,
  );
  Future<void> writeCheckpoint(Uri source, NhentaiTagCheckpoint checkpoint);
}

/// Wrappers over the same open durable store share its mutation owner. A new
/// source/coordinator must not race an old wrapper's already-started write.
abstract interface class NhentaiTagStoreSerializationOwner {
  Object get serializationOwner;
}

final class NhentaiTagCheckpoint {
  NhentaiTagCheckpoint({
    required this.category,
    required this.sort,
    required this.nextPage,
    required this.observedAt,
    required Set<int> seenIds,
    this.observedTotal,
    this.observedPageCount,
    this.catalogChanged = false,
  }) : seenIds = Set.unmodifiable(seenIds);
  final String category;
  final String sort;

  /// Null means the observed sweep reached its reported end, not full coverage.
  final int? nextPage;
  final DateTime observedAt;
  final Set<int> seenIds;
  final int? observedTotal;
  final int? observedPageCount;
  final bool catalogChanged;

  /// Popularity/name paging may shift while traversing the catalog.
  bool get coverageIsComplete => false;
}

typedef NhentaiTagLookup =
    Future<List<NhentaiTag>> Function(List<int> ids, CancelToken cancelToken);
typedef NhentaiTagCatalog =
    Future<NhentaiResultPage<NhentaiTag>> Function(
      String category,
      String sort,
      int page,
      CancelToken cancelToken,
    );

/// Visible lookup and bounded catalog work share one source lifecycle. No work
/// starts in the constructor, and a catalog sweep never blocks visible lookups.
final class NhentaiTagCache {
  NhentaiTagCache({
    required this.store,
    required this.lookup,
    required this.catalog,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       _coordinator =
           _storeCoordinators[switch (store) {
                 NhentaiTagStoreSerializationOwner(:final serializationOwner) =>
                   serializationOwner,
                 _ => store,
               }] ??=
               _TagStoreCoordinator();
  static final source = Uri.parse('https://nhentai.net');
  // A replacement source can share the store while an old source's durable
  // write is still settling. Instance-local queues cannot order those writes.
  static final _storeCoordinators = Expando<_TagStoreCoordinator>();
  final _TagStoreCoordinator _coordinator;
  final NhentaiTagStore store;
  final NhentaiTagLookup lookup;
  final NhentaiTagCatalog catalog;
  final DateTime Function() now;
  final _lifetime = CancelToken();
  final _pendingIds = <int, Future<NhentaiTag?>>{};
  var _visibleCalls = 0;
  Completer<void>? _visibleDrained;

  void _check(CancelToken? token) {
    if (_lifetime.cancelError case final error?) throw error;
    if (token?.cancelError case final error?) throw error;
  }

  Future<T> _wait<T>(Future<T> value, CancelToken? token) => Future.any([
    value,
    _lifetime.whenCancel.then<T>((error) => throw error),
    if (token != null) token.whenCancel.then<T>((error) => throw error),
  ]);

  Future<void> _persist(
    Future<void> Function() write,
    CancelToken? token,
  ) async {
    // Cancellation may stop a write before dispatch, but cannot cancel an
    // already-started local mutation or release its serialization barrier.
    await _coordinator.write(() {
      _check(token);
      return write();
    });
    _check(token);
  }

  Future<Map<int, NhentaiTag>> resolveVisible(
    Iterable<int> requested, {
    CancelToken? cancelToken,
  }) async {
    _check(cancelToken);
    final ids = requested.toSet();
    if (ids.any((id) => id < 1 || id > 9007199254740991)) {
      throw ArgumentError('Invalid tag ID');
    }
    if (ids.isEmpty) return const {};
    _visibleCalls++;
    _visibleDrained ??= Completer<void>();
    try {
      final cached = await _wait(store.readTags(source, ids), cancelToken);
      _check(cancelToken);
      final missing = ids.where((id) => !cached.containsKey(id)).toSet();
      final toFetch = missing
          .where((id) => !_pendingIds.containsKey(id))
          .toList();
      for (var offset = 0; offset < toFetch.length; offset += 100) {
        final batch = toFetch.skip(offset).take(100).toList();
        // Per-caller cancellation cannot revoke another visible observer's read.
        // The source lifetime owns shared request cancellation.
        final result = _lookupBatch(batch);
        for (final id in batch) {
          _pendingIds[id] = result.then((tags) => tags[id]);
        }
      }
      final pending = [
        for (final id in missing) (id: id, future: _pendingIds[id]!),
      ];
      final results = await _wait(
        Future.wait([
          for (final item in pending)
            item.future.then((tag) => (id: item.id, tag: tag)),
        ]),
        cancelToken,
      );
      _check(cancelToken);
      return Map.unmodifiable({
        ...cached,
        for (final item in results)
          if (item.tag != null) item.id: item.tag!,
      });
    } finally {
      _visibleCalls--;
      if (_visibleCalls == 0) {
        _visibleDrained?.complete();
        _visibleDrained = null;
      }
    }
  }

  Future<Map<int, NhentaiTag>> _lookupBatch(List<int> ids) async {
    try {
      final tags = await lookup(ids, _lifetime);
      _check(null);
      if (tags.any((tag) => !ids.contains(tag.id))) {
        throw const FormatException('Foreign visible tag');
      }
      final unique = {for (final tag in tags) tag.id: tag};
      await _persist(
        () => store.upsertTags(source, unique.values.toList()),
        null,
      );
      return unique;
    } finally {
      for (final id in ids) {
        _pendingIds.remove(id);
      }
    }
  }

  /// Details already carry canonical tags. Reuse the same durable-write owner
  /// without requesting those IDs again or racing an outgoing source's write.
  Future<void> remember(Iterable<NhentaiTag> observed) {
    _check(null);
    final tags = {for (final tag in observed) tag.id: tag};
    if (tags.keys.any((id) => id < 1 || id > 9007199254740991)) {
      return Future.error(ArgumentError('Invalid observed tag ID'));
    }
    return _persist(() => store.upsertTags(source, tags.values.toList()), null);
  }

  Future<NhentaiTagCheckpoint> warmCatalog(
    String category, {
    String sort = 'popular',
    int pageBudget = 1,
    bool restartSweep = false,
    CancelToken? cancelToken,
  }) {
    if (!RegExp(r'^[a-z][a-z0-9_-]*$').hasMatch(category) ||
        category == 'general' ||
        !const ['popular', 'name'].contains(sort) ||
        pageBudget < 1 ||
        pageBudget > 5) {
      return Future.error(ArgumentError('Invalid bounded catalog request'));
    }
    final operation = _coordinator.catalogTail.then(
      (_) => _warm(category, sort, pageBudget, cancelToken, restartSweep),
    );
    _coordinator.catalogTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<NhentaiTagCheckpoint> _warm(
    String category,
    String sort,
    int budget,
    CancelToken? token,
    bool restartSweep,
  ) async {
    _check(token);
    var checkpoint = await _wait(
      store.readCheckpoint(source, category, sort),
      token,
    );
    // A new observation pass retains known tag records and only replaces the
    // checkpoint after a successfully persisted first batch.
    if (restartSweep) checkpoint = null;
    for (var work = 0; work < budget; work++) {
      _check(token);
      if (checkpoint != null && checkpoint.nextPage == null) return checkpoint;
      // A visible request queued before this dispatch owns priority. Already
      // dispatched network work is left to the ordinary HTTP coordinator.
      while (_visibleCalls > 0) {
        await _wait(_visibleDrained!.future, token);
      }
      _check(token);
      final page = checkpoint?.nextPage ?? 1;
      final request = CancelToken();
      unawaited(
        _lifetime.whenCancel.then((_) => request.cancel('Source disposed')),
      );
      if (token != null) {
        unawaited(
          token.whenCancel.then((_) => request.cancel('Catalog cancelled')),
        );
      }
      final batch = await _wait(catalog(category, sort, page, request), token);
      _check(token);
      if (batch.page != page ||
          batch.items.any((tag) => tag.type != category)) {
        throw const FormatException('Foreign catalog page');
      }
      if (batch.hasMore == null) {
        throw StateError('Unproven catalog continuation');
      }
      if (batch.pageCount! < page &&
          (batch.items.isNotEmpty || batch.total != 0)) {
        throw StateError('Contradictory catalog page metadata');
      }
      final ids = batch.items.map((tag) => tag.id).toSet();
      if ((ids.isEmpty && batch.hasMore == true) ||
          (ids.isNotEmpty &&
              ids.every((id) => checkpoint?.seenIds.contains(id) ?? false))) {
        throw StateError('Tag catalog did not progress');
      }
      final next = NhentaiTagCheckpoint(
        category: category,
        sort: sort,
        nextPage: batch.hasMore! ? page + 1 : null,
        observedAt: now().toUtc(),
        seenIds: {...?checkpoint?.seenIds, ...ids},
        observedTotal: batch.total,
        observedPageCount: batch.pageCount,
        catalogChanged:
            (checkpoint?.catalogChanged ?? false) ||
            (checkpoint != null &&
                (checkpoint.observedTotal != batch.total ||
                    checkpoint.observedPageCount != batch.pageCount)),
      );
      // Ordering matters: checkpoint failure can only cause harmless batch replay.
      await _persist(
        () => store.upsertTags(
          source,
          {for (final tag in batch.items) tag.id: tag}.values.toList(),
        ),
        token,
      );
      await _persist(() => store.writeCheckpoint(source, next), token);
      checkpoint = next;
    }
    return checkpoint!;
  }

  void dispose() {
    _lifetime.cancel('nhentai tag source disposed');
  }
}

final class _TagStoreCoordinator {
  Future<void> catalogTail = Future.value();
  Future<void> _writeTail = Future.value();

  Future<void> write(Future<void> Function() mutation) {
    final operation = _writeTail.then((_) => mutation());
    _writeTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}
