import 'package:foundation/performance.dart';

import '../providers/bookmark_group_selectors.dart';
import '../providers/bookmark_shuffle_provider.dart';
import 'bookmark.dart';
import 'bookmark_library_state.dart';
import 'bookmark_search_token.dart';
import 'bookmark_view.dart';
import 'pool_bookmark.dart';
import 'content_group_bookmark.dart';
import 'bookmark_record_fields.dart';

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

/// Native Works/Galleries retain their own Group record, never a Pool cast.
final class BookmarkNativeGroupEntry extends BookmarkGridEntry {
  BookmarkNativeGroupEntry(this.bookmark) : key = ('group', bookmark.id);
  final ContentGroupBookmark bookmark;
  @override
  final Object key;
  @override
  DateTime? uploadDate({required bool oldest}) =>
      bookmark.snapshot.details?.sourceDates?.publishedAt ??
      bookmark.snapshot.details?.sourceDates?.createdAt;
}

List<ContentGroupBookmark> selectNativeGroupBookmarks({
  required BookmarkLibraryState state,
  required BookmarkView view,
  required List<String> selectedTags,
  String? selectedBooruUrl,
  Set<int>? availableRecordIds,
}) {
  final inView = state.bookmarkIdsForView(view);
  final filters = selectedTags
      .map(BookmarkSearchToken.parse)
      .where((token) => token.tag.isNotEmpty)
      .toList();
  return [
    for (final record
        in inView
            .map((id) => state.byId[id])
            .whereType<Bookmark>()
            .whereType<ContentGroupBookmark>())
      if (!record.reference.sourceKey.startsWith('pool:') &&
          !record.reference.sourceKey.startsWith('related:') &&
          (availableRecordIds == null ||
              availableRecordIds.contains(record.id)) &&
          (selectedBooruUrl == null ||
              bookmarkSourceMatchesHost(
                record.reference.siteNamespace,
                selectedBooruUrl,
              )) &&
          _nativeTagsMatch(record, filters))
        record,
  ];
}

bool _nativeTagsMatch(
  ContentGroupBookmark record,
  List<BookmarkSearchToken> filters,
) {
  final tags = nativeGroupBookmarkTags(record);
  return filters.every(
    (filter) => filter.isNegative
        ? !tags.contains(filter.tag)
        : tags.contains(filter.tag),
  );
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
  final groupsInView =
      view.kind == BookmarkViewKind.all && state.mirrors.owners.isEmpty
      ? null
      : state.groupIdsForView(view);
  return state.pools.where((pool) {
    if (availableCollectionIds != null &&
        !availableCollectionIds.contains(pool.localId)) {
      return false;
    }
    if (groupsInView != null && !pool.groupIds.any(groupsInView.contains)) {
      return false;
    }
    if (selectedBooruUrl != null &&
        !bookmarkSourceMatchesHost(pool.origin.sourceHost, selectedBooruUrl)) {
      return false;
    }
    final tags = pool.tags.map(canonicalBookmarkTag).toSet();
    return filters.every(
      (f) => f.isNegative ? !tags.contains(f.tag) : tags.contains(f.tag),
    );
  }).toList();
}

/// Folder covers always use membership dates. Their renderer evaluates live
/// cover access in this order so a missing image cannot hide an eligible one.
List<BookmarkGridEntry> selectBookmarkMosaicEntries({
  required BookmarkLibraryState state,
  required BookmarkView view,
  Set<int>? availablePostIds,
  Set<String>? availableCollectionIds,
  Set<int>? availableNativeGroupIds,
}) {
  final ids = state.bookmarkIdsForView(view);
  return performanceRecorder.measureSync(
    PerfOperation.bookmarkSelect,
    () {
      final dates =
          bookmarkMembershipDates(
            state: state,
            view: view,
            sortType: BookmarkSortType.newest,
          ) ??
          const <int, DateTime>{};
      final groups = state.groupIdsForView(view);
      final entries = <BookmarkGridEntry>[
        for (final id in ids)
          if ((availablePostIds?.contains(id) ?? true) &&
              state.bookmarksById[id] != null)
            BookmarkPostEntry(state.bookmarksById[id]!),
        ...selectNativeGroupBookmarks(
          state: state,
          view: view,
          selectedTags: const [],
          availableRecordIds: availableNativeGroupIds,
        ).map(BookmarkNativeGroupEntry.new),
        for (final pool in state.pools)
          if ((availableCollectionIds?.contains(pool.localId) ?? true) &&
              pool.groupIds.any(groups.contains))
            BookmarkPoolEntry(pool),
      ];
      final poolDates = {
        for (final entry in entries.whereType<BookmarkPoolEntry>())
          entry.pool.localId: _mosaicPoolDate(entry.pool, groups),
      };
      return entries..sort((a, b) {
        final dateOrder = _bookmarkDate(
          b,
          dates,
          poolDates,
        ).compareTo(_bookmarkDate(a, dates, poolDates));
        return dateOrder == 0
            ? a.key.toString().compareTo(b.key.toString())
            : dateOrder;
      });
    },
    items: ids.length,
  );
}

DateTime _mosaicPoolDate(CollectionBookmark pool, Set<String> groups) {
  DateTime? latest;
  for (final group in pool.groupIds) {
    if (!groups.contains(group)) continue;
    final date = pool.addedAt[group] ?? pool.createdAt;
    if (latest == null || date.isAfter(latest)) latest = date;
  }
  return latest ?? pool.createdAt;
}

DateTime _bookmarkDate(
  BookmarkGridEntry entry,
  Map<int, DateTime>? membershipDates,
  Map<String, DateTime> poolDates,
) => switch (entry) {
  BookmarkPostEntry(:final bookmark) =>
    membershipDates?[bookmark.id] ?? bookmark.createdAt,
  BookmarkPoolEntry(:final pool) => poolDates[pool.localId] ?? pool.createdAt,
  BookmarkNativeGroupEntry(:final bookmark) =>
    membershipDates?[bookmark.id] ?? bookmark.createdAt,
};

List<BookmarkGridEntry> selectBookmarkGridEntries({
  required BookmarkLibraryState state,
  required BookmarkView view,
  required List<String> selectedTags,
  required BookmarkSortType sortType,
  String? selectedBooruUrl,
  BookmarkShuffleState? shuffleState,
  Set<int>? availablePostIds,
  Set<String>? availableCollectionIds,
  Set<int>? availableNativeGroupIds,
}) {
  final native = selectNativeGroupBookmarks(
    state: state,
    view: view,
    selectedTags: selectedTags,
    selectedBooruUrl: selectedBooruUrl,
    availableRecordIds: availableNativeGroupIds,
  );
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
    sortType:
        (pools.isNotEmpty || native.isNotEmpty) &&
            sortType == BookmarkSortType.random
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
    ...native.map(BookmarkNativeGroupEntry.new),
  ];
  // Preserve the existing optimized Post-only sort/shuffle and tie behavior.
  if (pools.isEmpty && native.isEmpty) return entries;
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
  entries.sort((a, b) {
    final ad = uploads
        ? a.uploadDate(oldest: oldest)
        : _bookmarkDate(a, membershipDates, poolDates);
    final bd = uploads
        ? b.uploadDate(oldest: oldest)
        : _bookmarkDate(b, membershipDates, poolDates);
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
