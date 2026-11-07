import '../providers/bookmark_group_selectors.dart';
import '../providers/bookmark_shuffle_provider.dart';
import 'bookmark.dart';
import 'bookmark_library_state.dart';
import 'bookmark_search_token.dart';
import 'bookmark_view.dart';
import 'pool_bookmark.dart';

sealed class BookmarkGridEntry {
  const BookmarkGridEntry();
  Object get key;
  DateTime? uploadDate({required bool oldest});
}

final class BookmarkPostEntry extends BookmarkGridEntry {
  BookmarkPostEntry(this.bookmark) : key = ('post', bookmark.localId);
  final PostBookmark bookmark;
  @override
  final Object key;
  @override
  DateTime? uploadDate({required bool oldest}) => bookmark.post.createdAt;
}

final class BookmarkPoolEntry extends BookmarkGridEntry {
  BookmarkPoolEntry(this.pool) : key = ('pool', pool.localId);
  final CollectionBookmark pool;
  @override
  final Object key;
  @override
  DateTime? uploadDate({required bool oldest}) =>
      oldest ? pool.oldestUpload ?? pool.newestUpload : pool.newestUpload;
}

/// Local, strict matching against each reference's stored union. Coverage never
/// keeps a nonmatch visible, and this selector cannot perform I/O.
List<CollectionBookmark> selectPoolBookmarks({
  required BookmarkLibraryState state,
  required BookmarkView view,
  required List<String> selectedTags,
  String? selectedBooruUrl,
  Set<String>? availableCollectionIds,
}) {
  final filters = selectedTags
      .map(BookmarkSearchToken.parse)
      .where((t) => t.tag.isNotEmpty)
      .toList();
  final groupsInView = view.kind == BookmarkViewKind.all
      ? null
      : state.groupIdsForView(view);
  return state.pools.where((pool) {
    if (availableCollectionIds != null &&
        !availableCollectionIds.contains(pool.localId))
      return false;
    if (groupsInView != null && !pool.groupIds.any(groupsInView.contains))
      return false;
    if (selectedBooruUrl != null &&
        !bookmarkSourceMatchesHost(pool.origin.sourceHost, selectedBooruUrl))
      return false;
    final tags = pool.tags.map(canonicalBookmarkTag).toSet();
    return filters.every(
      (f) => f.isNegative ? !tags.contains(f.tag) : tags.contains(f.tag),
    );
  }).toList();
}

List<BookmarkGridEntry> selectBookmarkGridEntries({
  required BookmarkLibraryState state,
  required BookmarkView view,
  required List<String> selectedTags,
  required BookmarkSortType sortType,
  String? selectedBooruUrl,
  BookmarkShuffleState? shuffleState,
  Set<int>? availablePostIds,
  Set<String>? availableCollectionIds,
}) {
  final pools = selectPoolBookmarks(
    state: state,
    view: view,
    selectedTags: selectedTags,
    selectedBooruUrl: selectedBooruUrl,
    availableCollectionIds: availableCollectionIds,
  );
  final membershipDates = bookmarkMembershipDates(
    state: state,
    view: view,
    sortType: sortType,
  );
  final posts = selectBookmarks(
    state: state,
    view: view,
    selectedTags: selectedTags,
    sortType: pools.isNotEmpty && sortType == BookmarkSortType.random
        ? BookmarkSortType.newest
        : sortType,
    selectedBooruUrl: selectedBooruUrl,
    shuffleState: shuffleState,
    addedAt: membershipDates,
    availablePostIds: availablePostIds,
  );
  final entries = <BookmarkGridEntry>[
    ...posts.map(BookmarkPostEntry.new),
    ...pools.map(BookmarkPoolEntry.new),
  ];
  // Preserve the existing optimized Post-only sort/shuffle and tie behavior.
  if (pools.isEmpty) return entries;
  if (sortType == BookmarkSortType.scoreDescending ||
      sortType == BookmarkSortType.scoreAscending) {
    // Posts already use the shared score comparator. References have no score;
    // retain them after the scored Posts without inventing a member aggregate.
    return entries;
  }
  if (sortType == BookmarkSortType.random) {
    return (shuffleState ?? const BookmarkShuffleState()).applyShuffleToList(
      entries,
    );
  }
  final oldest =
      sortType == BookmarkSortType.oldest ||
      sortType == BookmarkSortType.oldestUpload;
  final uploads =
      sortType == BookmarkSortType.oldestUpload ||
      sortType == BookmarkSortType.newestUpload;
  final poolDates = <String, DateTime>{};
  if (!uploads) {
    for (final pool in pools) {
      final dates = view.kind == BookmarkViewKind.group
          ? [pool.addedAt[view.groupId] ?? pool.createdAt]
          : view.kind == BookmarkViewKind.subtree
          ? pool.addedAt.entries
                .where(
                  (entry) => state.groupIdsForView(view).contains(entry.key),
                )
                .map((entry) => entry.value)
          : pool.addedAt.values;
      poolDates[pool.localId] = dates.isEmpty
          ? pool.createdAt
          : dates.reduce(
              (a, b) => (oldest ? a.isBefore(b) : a.isAfter(b)) ? a : b,
            );
    }
  }
  DateTime savedAt(BookmarkGridEntry entry) => switch (entry) {
    BookmarkPostEntry(:final bookmark) =>
      membershipDates?[bookmark.id] ?? bookmark.createdAt,
    BookmarkPoolEntry(:final pool) => poolDates[pool.localId] ?? pool.createdAt,
  };
  entries.sort((a, b) {
    final ad = uploads ? a.uploadDate(oldest: oldest) : savedAt(a);
    final bd = uploads ? b.uploadDate(oldest: oldest) : savedAt(b);
    if (ad == null && bd != null) return 1;
    if (ad != null && bd == null) return -1;
    if (ad != null && bd != null) {
      final byDate = ad.compareTo(bd);
      if (byDate != 0) return oldest ? byDate : -byDate;
    }
    return a.key.toString().compareTo(b.key.toString());
  });
  return entries;
}
