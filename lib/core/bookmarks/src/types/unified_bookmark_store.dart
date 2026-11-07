import 'dart:async';

import '../../../boorus/booru/types.dart';
import '../../../content/types.dart';
import '../../../groups/folder_tree.dart';
import 'bookmark.dart';
import 'bookmark_group.dart';

/// The shared payload/ID authority for Posts, Groups and Related families.
/// Transfer IDs must be remapped before writing reserved local slots.
abstract interface class UnifiedBookmarkStore {
  bool get supportsUnifiedRecords;
  Future<int> readRevision();
  Future<T> runReadWriteScope<T>(Future<T> Function() operation);
  Future<Bookmark?> lookupContent(
    ContentIdentity identity, {
    required BooruType engine,
  });
  Future<void> commitOrganization({
    Iterable<Bookmark> records = const [],
    Set<int> removeIds = const {},
    List<BookmarkGroup> groups = const [],
    Set<String> removeGroupIds = const {},
    List<CollectionFolder>? folders,
  });
  Bookmark normalizeRecord(Bookmark record, {Bookmark? previous});

  Future<List<int>> reserveIds(int count);
  Future<List<Bookmark>> readAll();
  Future<Bookmark?> read(int id);
  Future<void> upsert(Bookmark bookmark);
  Future<void> upsertAll(Iterable<Bookmark> bookmarks);
  Future<void> delete(int id);
  Future<void> durableSync();
}

final class BookmarkCommittedChange {
  BookmarkCommittedChange({
    required Iterable<Bookmark> records,
    required Set<int> removedIds,
    required this.revision,
  }) : records = List.unmodifiable(records),
       removedIds = Set.unmodifiable(removedIds);

  final List<Bookmark> records;
  final Set<int> removedIds;
  final int revision;
}

final _bookmarkWriteObserverZoneKey = Object();

T observeBookmarkWrites<T>(
  T Function() operation,
  void Function(BookmarkCommittedChange) observer,
) => runZoned(
  operation,
  zoneValues: {_bookmarkWriteObserverZoneKey: observer},
);

void publishBookmarkWrite(BookmarkCommittedChange change) {
  final observer = Zone.current[_bookmarkWriteObserverZoneKey];
  if (observer is void Function(BookmarkCommittedChange)) observer(change);
}

UnifiedBookmarkStore? unifiedBookmarkStorage(Object? repository) =>
    switch (repository) {
      final UnifiedBookmarkStore store when store.supportsUnifiedRecords =>
        store,
      _ => null,
    };
