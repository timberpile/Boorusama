import 'dart:collection';

import 'package:collection/collection.dart';

import '../../bookmarks/src/data/stored_bookmark_codec.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../bookmarks/types.dart';

/// Exact Replace correspondence, not a content identity or a deduplication rule.
/// File IDs only join incoming memberships. Every occurrence consumes one local
/// occurrence with the same complete transferable payload and membership dates.
Map<int, Bookmark> matchUnaddressableBookmarkRecords({
  required Iterable<Bookmark> incoming,
  required Iterable<Bookmark> local,
  required Iterable<BookmarkGroup> incomingGroups,
  required Iterable<BookmarkGroup> localGroups,
  StoredBookmarkCodec codec = const StoredBookmarkCodec(),
}) {
  Map<int, List<(String, String)>> incidence(
    Iterable<Bookmark> records,
    Iterable<BookmarkGroup> groups,
  ) {
    final byId = {for (final record in records) record.id: record};
    final result = <int, List<(String, String)>>{};
    for (final group in groups) {
      for (final id in group.bookmarkIds) {
        final record = byId[id];
        if (record == null) {
          throw const FormatException('Absent Bookmark reference');
        }
        result.putIfAbsent(id, () => []).add((
          group.id,
          (group.addedAt[id] ?? bookmarkCreatedAt(record))
              .toUtc()
              .toIso8601String(),
        ));
      }
    }
    for (final entries in result.values) {
      entries.sort((a, b) {
        final group = a.$1.compareTo(b.$1);
        return group != 0 ? group : a.$2.compareTo(b.$2);
      });
    }
    return result;
  }

  final localRecords = local.toList();
  final incomingRecords = incoming.toList();
  final candidates =
      localRecords
          .where((record) => bookmarkContentIdentity(record) == null)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  final opaqueIncoming = incomingRecords
      .where((record) => bookmarkContentIdentity(record) == null)
      .toList();
  if (candidates.isEmpty || opaqueIncoming.isEmpty) return const {};
  final oldMemberships = incidence(localRecords, localGroups);
  final newMemberships = incidence(incomingRecords, incomingGroups);
  _ExactRecordKey key(
    Bookmark record,
    Map<int, List<(String, String)>> members,
  ) => _ExactRecordKey([
    codec.encodeForTransfer(record)..remove('id'),
    members[record.id] ?? const <(String, String)>[],
  ]);

  final buckets = <_ExactRecordKey, Queue<Bookmark>>{};
  for (final record in candidates) {
    buckets.putIfAbsent(key(record, oldMemberships), Queue.new).add(record);
  }
  final matches = <int, Bookmark>{};
  for (final record in opaqueIncoming) {
    final bucket = buckets[key(record, newMemberships)];
    if (bucket != null && bucket.isNotEmpty) {
      matches[record.id] = bucket.removeFirst();
    }
  }
  return matches;
}

final class _ExactRecordKey {
  const _ExactRecordKey(this.value);
  final Object value;
  static const _equality = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      other is _ExactRecordKey && _equality.equals(value, other.value);

  @override
  int get hashCode => _equality.hash(value);
}
