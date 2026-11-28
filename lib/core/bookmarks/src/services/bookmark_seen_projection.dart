import '../../../backups/mitemite/seen_state.dart';
import '../types/bookmark.dart';
import '../types/bookmark_grid_entry.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_view.dart';

export '../../../backups/mitemite/seen_state.dart' show BookmarkSeenTarget;

enum BookmarkSeenFilter { all, unseen, seen }

/// Read-only projection of complete memberships, independent of search, media
/// availability and sorting. Combined subtrees capture all canonical memberships
/// for a collapsed occurrence; normal Group views retain one reading target.
final class BookmarkSeenProjection {
  factory BookmarkSeenProjection(
    BookmarkLibraryState state,
    BookmarkView view,
  ) {
    final root = view.groupId;
    final publisher = state.mirrors.owners[root]?.publisher;
    if (root == null || publisher == null) {
      return const BookmarkSeenProjection._({}, {}, {});
    }
    final memberships = <int, List<BookmarkSeenTarget>>{};
    final unseen = <int>{};
    final pending = [root];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      final owner = state.mirrors.owners[id];
      if (owner == null ||
          owner.publisher != publisher ||
          owner.reading.isEmpty) {
        continue;
      }
      final reading = SyncGroupSeenState.fromJson(owner.reading);
      final unread = reading.unseenMembers;
      for (final recordId in state.groupsById[id]?.bookmarkIds ?? <int>{}) {
        final record = state.byId[recordId];
        if (record == null) continue;
        final member = syncBookmarkMemberKey(record);
        if (!reading.members.contains(member)) continue;
        memberships
            .putIfAbsent(recordId, () => [])
            .add(
              BookmarkSeenTarget(
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
    return BookmarkSeenProjection._(
      Map.unmodifiable({
        for (final entry in memberships.entries)
          entry.key: BookmarkSeenTarget(
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

  const BookmarkSeenProjection._(this.targets, this.unseenIds, this._records);
  final Map<int, BookmarkSeenTarget> targets;
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

  BookmarkSeenTarget? target(BookmarkGridEntry entry) =>
      targets[recordId(entry)];
  bool isUnseen(BookmarkGridEntry entry) => unseenIds.contains(recordId(entry));
  bool includes(BookmarkGridEntry entry, BookmarkSeenFilter filter) =>
      switch (filter) {
        BookmarkSeenFilter.all => true,
        BookmarkSeenFilter.unseen => isUnseen(entry),
        BookmarkSeenFilter.seen => target(entry) != null && !isUnseen(entry),
      };
}
