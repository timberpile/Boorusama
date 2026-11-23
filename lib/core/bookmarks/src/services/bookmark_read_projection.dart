import '../../../backups/mitemite/reading_state.dart';
import '../types/bookmark.dart';
import '../types/bookmark_grid_entry.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_view.dart';

export '../../../backups/mitemite/reading_state.dart' show BookmarkReadTarget;

enum BookmarkSeenFilter { all, unseen, seen }

/// Read-only projection of complete memberships, independent of search, media
/// availability and sorting. Combined subtrees capture all canonical memberships
/// for a collapsed occurrence; normal Group views retain one reading target.
final class BookmarkReadProjection {
  factory BookmarkReadProjection(
    BookmarkLibraryState state,
    BookmarkView view,
  ) {
    final root = view.groupId;
    final publisher = state.mirrors.owners[root]?.publisher;
    if (root == null || publisher == null) {
      return const BookmarkReadProjection._({}, {}, {});
    }
    final memberships = <int, List<BookmarkReadTarget>>{};
    final unseen = <int>{};
    final pending = [root];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      final owner = state.mirrors.owners[id];
      if (owner == null ||
          owner.publisher != publisher ||
          owner.reading.isEmpty)
        continue;
      final reading = SyncGroupReadingState.fromJson(owner.reading);
      final unread = reading.unreadMembers;
      for (final recordId in state.groupsById[id]?.bookmarkIds ?? <int>{}) {
        final record = state.byId[recordId];
        if (record == null) continue;
        final member = syncBookmarkMemberKey(record);
        if (!reading.members.contains(member)) continue;
        memberships
            .putIfAbsent(recordId, () => [])
            .add(
              BookmarkReadTarget(
                groupId: id,
                publisher: publisher,
                source: owner.source,
                member: member,
                scopeGroupId: view.kind == BookmarkViewKind.subtree
                    ? root
                    : null,
                scopeSource: view.kind == BookmarkViewKind.subtree
                    ? state.mirrors.owners[root]!.source
                    : null,
              ),
            );
        if (unread.contains(member)) unseen.add(recordId);
      }
      if (view.kind == BookmarkViewKind.subtree) {
        pending.addAll(
          state.groupTree.childrenOf(id).reversed.map((group) => group.id),
        );
      }
    }
    return BookmarkReadProjection._(
      Map.unmodifiable({
        for (final entry in memberships.entries)
          entry.key: BookmarkReadTarget(
            groupId: entry.value.first.groupId,
            publisher: publisher,
            source: entry.value.first.source,
            member: entry.value.first.member,
            scopeGroupId: entry.value.first.scopeGroupId,
            scopeSource: entry.value.first.scopeSource,
            additionalTargets: List.unmodifiable(entry.value.skip(1)),
          ),
      }),
      Set.unmodifiable(unseen),
      state.byId,
    );
  }

  const BookmarkReadProjection._(this.targets, this.unseenIds, this._records);
  final Map<int, BookmarkReadTarget> targets;
  final Set<int> unseenIds;
  final Map<int, Bookmark> _records;

  bool showFilter(BookmarkSeenFilter filter) =>
      filter != BookmarkSeenFilter.all ||
      (unseenIds.isNotEmpty && unseenIds.length < targets.length);

  int? recordId(BookmarkGridEntry entry) => switch (entry) {
    BookmarkPostEntry(:final bookmark) => bookmark.id,
    BookmarkNativeGroupEntry(:final bookmark) => bookmark.id,
    BookmarkPoolEntry(:final pool) => _records[pool.bookmarkId]?.id,
  };

  BookmarkReadTarget? target(BookmarkGridEntry entry) =>
      targets[recordId(entry)];
  bool isUnseen(BookmarkGridEntry entry) => unseenIds.contains(recordId(entry));
  bool includes(BookmarkGridEntry entry, BookmarkSeenFilter filter) =>
      switch (filter) {
        BookmarkSeenFilter.all => true,
        BookmarkSeenFilter.unseen => isUnseen(entry),
        BookmarkSeenFilter.seen => target(entry) != null && !isUnseen(entry),
      };
}
