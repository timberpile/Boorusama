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
  DateTime get savedAt;
  DateTime? uploadDate({required bool oldest});
}

final class BookmarkPostEntry extends BookmarkGridEntry {
  BookmarkPostEntry(this.bookmark)
    : key = switch (BookmarkIdentity.tryFromPost(bookmark.post)) {
        final identity? => (identity, 0),
        null => ('legacy-post', bookmark.localId),
      };
  final Bookmark bookmark;
  @override
  final Object key;
  @override
  DateTime get savedAt => bookmark.createdAt;
  @override
  DateTime? uploadDate({required bool oldest}) => bookmark.post.createdAt;
}

final class BookmarkPoolEntry extends BookmarkGridEntry {
  BookmarkPoolEntry(this.pool) : key = ('pool', pool.localId);
  final PoolBookmark pool;
  @override
  final Object key;
  @override
  DateTime get savedAt => pool.createdAt;
  @override
  DateTime? uploadDate({required bool oldest}) =>
      oldest ? pool.oldestUpload ?? pool.newestUpload : pool.newestUpload;
}

/// Local, strict matching against each reference's stored union. Coverage never
/// keeps a nonmatch visible, and this selector cannot perform I/O.
List<PoolBookmark> selectPoolBookmarks({
  required BookmarkLibraryState state,
  required BookmarkView view,
  required List<String> selectedTags,
  String? selectedBooruUrl,
}) {
  final filters = selectedTags
      .map(BookmarkSearchToken.parse)
      .where((t) => t.tag.isNotEmpty)
      .toList();
  return state.pools.where((pool) {
    if (view.kind == BookmarkViewKind.group &&
        !pool.groupIds.contains(view.groupId))
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
}) {
  final pools = selectPoolBookmarks(
    state: state,
    view: view,
    selectedTags: selectedTags,
    selectedBooruUrl: selectedBooruUrl,
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
  );
  final entries = <BookmarkGridEntry>[
    ...posts.map(BookmarkPostEntry.new),
    ...pools.map(BookmarkPoolEntry.new),
  ];
  // Preserve the existing optimized Post-only sort/shuffle and tie behavior.
  if (pools.isEmpty) return entries;
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
  entries.sort((a, b) {
    final ad = uploads ? a.uploadDate(oldest: oldest) : a.savedAt;
    final bd = uploads ? b.uploadDate(oldest: oldest) : b.savedAt;
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
