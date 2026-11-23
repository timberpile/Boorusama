import 'bookmark.dart';
import 'bookmark_group_tree.dart';
import 'bookmark_record_fields.dart';

/// Derived local-ID union. A remote saved Group is one ID and is never expanded.
final class BookmarkSubtreeProjection {
  factory BookmarkSubtreeProjection({
    required String groupId,
    required BookmarkGroupTree tree,
    required Map<int, Bookmark> byId,
  }) {
    final groupIds = tree.subtreeIds(groupId);
    final ids = <int>{};
    final earliest = <int, DateTime>{};
    final latest = <int, DateTime>{};
    for (final groupId in groupIds) {
      final group = tree.groupsById[groupId]!;
      for (final id in group.bookmarkIds) {
        final record = byId[id];
        if (record == null) continue;
        ids.add(id);
        final date = group.addedAt[id] ?? bookmarkCreatedAt(record);
        if (earliest[id] == null || date.isBefore(earliest[id]!))
          earliest[id] = date;
        if (latest[id] == null || date.isAfter(latest[id]!)) latest[id] = date;
      }
    }
    return BookmarkSubtreeProjection._(
      groupId,
      groupIds,
      Set.unmodifiable(ids),
      Map.unmodifiable(earliest),
      Map.unmodifiable(latest),
    );
  }
  const BookmarkSubtreeProjection._(
    this.groupId,
    this.includedGroupIds,
    this.bookmarkIds,
    this.earliestAddedAt,
    this.latestAddedAt,
  );
  final String groupId;
  final Set<String> includedGroupIds;
  final Set<int> bookmarkIds;
  final Map<int, DateTime> earliestAddedAt;
  final Map<int, DateTime> latestAddedAt;
}
