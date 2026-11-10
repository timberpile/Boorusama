import 'package:foundation/performance.dart';

// Package imports:
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

// Project imports:
import '../types/bookmark.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_search_token.dart';
import '../types/bookmark_view.dart';
import 'bookmark_shuffle_provider.dart';

// Append choices so any existing ordinal consumers retain their meaning.
enum BookmarkSortType {
  newestUpload,
  oldestUpload,
  newest,
  oldest,
  random,
  scoreDescending,
  scoreAscending,
}

/// The source picker supplies hosts, independent of URL paths and ports.
bool bookmarkSourceMatchesHost(String source, String selectedHost) {
  final uri = Uri.tryParse(source.contains('://') ? source : 'https://$source');
  final target = selectedHost.contains('://')
      ? Uri.tryParse(selectedHost)?.host
      : selectedHost;
  return uri != null &&
      uri.host.isNotEmpty &&
      uri.host.toLowerCase() == target?.toLowerCase();
}

/// Resolve dates once before sorting, rather than scanning groups in every
/// comparison. All uses current memberships: latest for Newest, earliest for
/// Oldest. Missing legacy dates retain their creation-time migration fallback.
Map<int, DateTime>? bookmarkMembershipDates({
  required BookmarkLibraryState state,
  required BookmarkView view,
  required BookmarkSortType sortType,
}) {
  if (sortType != BookmarkSortType.newest &&
      sortType != BookmarkSortType.oldest) {
    return null;
  }
  if (view.kind == BookmarkViewKind.group) {
    return state.groupsById[view.groupId]?.addedAt;
  }
  final oldest = sortType == BookmarkSortType.oldest;
  if (view.kind == BookmarkViewKind.subtree) {
    final projection = state.subtreeProjection(view.groupId!);
    return oldest ? projection.earliestAddedAt : projection.latestAddedAt;
  }
  final dates = <int, DateTime>{};
  for (final group in state.groups) {
    for (final id in group.bookmarkIds) {
      final date = group.addedAt[id] ?? state.bookmarksById[id]?.createdAt;
      if (date == null) continue;
      final previous = dates[id];
      if (previous == null ||
          (oldest ? date.isBefore(previous) : date.isAfter(previous))) {
        dates[id] = date;
      }
    }
  }
  return dates;
}

List<PostBookmark> selectBookmarks({
  required BookmarkLibraryState state,
  required BookmarkView view,
  required List<String> selectedTags,
  required BookmarkSortType sortType,
  String? selectedBooruUrl,
  BookmarkShuffleState? shuffleState,
  Map<int, DateTime>? addedAt,
}) {
  return performanceRecorder.measureSync(PerfOperation.bookmarkSelect, () {
    final groupIds = view.kind == BookmarkViewKind.all
        ? const <int>{}
        : state.bookmarkIdsForView(view);
    final inView = switch (view.kind) {
      BookmarkViewKind.all => state.items,
      BookmarkViewKind.group || BookmarkViewKind.subtree =>
        state.items
            .where(
              // Keep library order (including seeded shuffle input) without
              // normalizing every post's already indexed bookmark identity.
              (bookmark) =>
                  groupIds.contains(bookmark.id) &&
                  state.bookmarksById.containsKey(bookmark.id),
            )
            .toList(),
    };

    return filterBookmarks(
      bookmarks: inView,
      selectedTags: selectedTags,
      sortType: sortType,
      selectedBooruUrl: selectedBooruUrl,
      shuffleState: shuffleState,
      addedAt:
          addedAt ??
          bookmarkMembershipDates(
            state: state,
            view: view,
            sortType: sortType,
          ),
    );
  }, items: state.items.length);
}

List<PostBookmark> selectBookmarkPreviews({
  required BookmarkLibraryState state,
  required BookmarkView view,
  required BookmarkSortType sortType,
  BookmarkShuffleState? shuffleState,
}) {
  // Malformed rows retain the full selector's legacy behavior. All-view random
  // ordering still belongs to the full selector; group covers sample members.
  if ((sortType == BookmarkSortType.random &&
          view.kind == BookmarkViewKind.all) ||
      state.bookmarksById.length != state.items.length) {
    return selectBookmarks(
      state: state,
      view: view,
      selectedTags: const [],
      sortType: sortType,
      shuffleState: shuffleState,
    ).take(4).toList();
  }

  final groupIds = view.kind == BookmarkViewKind.all
      ? const <int>{}
      : state.bookmarkIdsForView(view);
  final candidates = switch (view.kind) {
    BookmarkViewKind.all => state.items,
    BookmarkViewKind.group || BookmarkViewKind.subtree =>
      groupIds.map((id) => state.bookmarksById[id]).whereType<PostBookmark>(),
  };
  return performanceRecorder.measureSync(
    PerfOperation.bookmarkSelect,
    () {
      if (sortType == BookmarkSortType.random) {
        return _sampleGroupPreviews(
          candidates,
          shuffleState?.seed ?? _defaultPreviewShuffle.seed!,
        );
      }
      final compare = _bookmarkComparator(
        sortType,
        addedAt: bookmarkMembershipDates(
          state: state,
          view: view,
          sortType: sortType,
        ),
      );
      final best = <PostBookmark>[];
      for (final candidate in candidates) {
        var index = 0;
        while (index < best.length && compare(best[index], candidate) <= 0) {
          index++;
        }
        if (index >= 4) continue;
        best.insert(index, candidate);
        if (best.length > 4) best.removeLast();
      }
      return best;
    },
    items: view.kind == BookmarkViewKind.all
        ? state.items.length
        : groupIds.length,
  );
}

// Keep unseeded group covers stable for this session, including after unrelated
// library publications. An explicit Shuffle supplies a new seed.
final _defaultPreviewShuffle = const BookmarkShuffleState().withNewShuffle();

List<PostBookmark> _sampleGroupPreviews(
  Iterable<PostBookmark> candidates,
  int seed,
) {
  final best = <({int rank, int id, PostBookmark bookmark})>[];
  for (final bookmark in candidates) {
    final id = bookmark.id;
    final rank = _previewRank(id, seed);
    // Once full, almost every later rank loses. Avoid walking all four entries
    // merely to reject it; insertion still handles the occasional better rank.
    if (best.length == 4 &&
        (rank > best.last.rank ||
            (rank == best.last.rank && id > best.last.id))) {
      continue;
    }
    var index = 0;
    while (index < best.length &&
        (best[index].rank < rank ||
            (best[index].rank == rank && best[index].id < id))) {
      index++;
    }
    if (index >= 4) continue;
    best.insert(index, (rank: rank, id: id, bookmark: bookmark));
    if (best.length > 4) best.removeLast();
  }
  return [for (final entry in best) entry.bookmark];
}

int _previewRank(int id, int seed) {
  // Jenkins mixing with bounded shifts keeps native and Web integer behavior
  // identical. Rank by local ID so set iteration order cannot change covers.
  var hash = (id ^ seed) & 0x1fffffff;
  hash = (hash + ((hash & 0x0007ffff) << 10)) & 0x1fffffff;
  hash ^= hash >> 6;
  hash = (hash + ((hash & 0x03ffffff) << 3)) & 0x1fffffff;
  hash ^= hash >> 11;
  return (hash + ((hash & 0x00003fff) << 15)) & 0x1fffffff;
}

List<PostBookmark> filterBookmarks({
  required List<PostBookmark> bookmarks,
  required List<String> selectedTags,
  required BookmarkSortType sortType,
  String? selectedBooruUrl,
  BookmarkShuffleState? shuffleState,
  Map<int, DateTime>? addedAt,
}) {
  final filters = selectedTags
      .map(BookmarkSearchToken.parse)
      .where((token) => token.tag.isNotEmpty)
      .toList();
  bool matchesTags(PostBookmark bookmark) {
    final tags = bookmark.tags.map(canonicalBookmarkTag).toSet();
    return filters.every(
      (token) => tags.contains(token.tag) != token.isNegative,
    );
  }

  final filtered = selectedBooruUrl == null && selectedTags.isEmpty
      ? bookmarks
      : bookmarks
            .where(
              (bookmark) =>
                  (selectedBooruUrl == null ||
                      bookmarkSourceMatchesHost(
                        bookmark.sourceUrl,
                        selectedBooruUrl,
                      )) &&
                  (filters.isEmpty || matchesTags(bookmark)),
            )
            .toList();
  final sorted = filtered.sorted(
    _bookmarkComparator(sortType, addedAt: addedAt),
  );

  if (sortType != BookmarkSortType.random) return sorted;
  final activeShuffleState = shuffleState?.seed != null
      ? shuffleState!
      : const BookmarkShuffleState().withNewShuffle();
  return activeShuffleState.applyShuffleToList(sorted);
}

Comparator<PostBookmark> _bookmarkComparator(
  BookmarkSortType sortType, {
  Map<int, DateTime>? addedAt,
}) =>
    (a, b) => switch (sortType) {
      BookmarkSortType.newestUpload => _compareUploadDate(
        a,
        b,
        newestFirst: true,
      ),
      BookmarkSortType.oldestUpload => _compareUploadDate(
        a,
        b,
        newestFirst: false,
      ),
      BookmarkSortType.newest => _compareBookmarkDate(b, a, addedAt),
      BookmarkSortType.oldest => _compareBookmarkDate(a, b, addedAt),
      BookmarkSortType.random => 0,
      BookmarkSortType.scoreDescending => _compareScore(a, b, descending: true),
      BookmarkSortType.scoreAscending => _compareScore(a, b, descending: false),
    };

int _compareScore(PostBookmark a, PostBookmark b, {required bool descending}) {
  // Legacy bookmarks without score metadata already decode to zero. Do not
  // fetch posts to improve local sorting or rewrite their stored snapshots.
  final score = a.post.score.compareTo(b.post.score);
  if (score != 0) return descending ? -score : score;
  return a.id.compareTo(b.id);
}

int _compareBookmarkDate(
  PostBookmark a,
  PostBookmark b,
  Map<int, DateTime>? addedAt,
) {
  final byDate = (addedAt?[a.id] ?? a.createdAt).compareTo(
    addedAt?[b.id] ?? b.createdAt,
  );
  // Several imported bookmarks can share the clock/storage's time precision.
  // Local IDs retain their insertion order without inventing creation times.
  return byDate != 0 ? byDate : a.id.compareTo(b.id);
}

// Known upload dates always precede missing dates in both directions. A
// stable site+post-ID fallback avoids comparing unrelated sites' ID sequences.
int _compareUploadDate(
  PostBookmark a,
  PostBookmark b, {
  required bool newestFirst,
}) {
  final aDate = a.post.createdAt;
  final bDate = b.post.createdAt;
  if (aDate == null && bDate != null) return 1;
  if (aDate != null && bDate == null) return -1;
  if (aDate != null && bDate != null) {
    final byDate = aDate.compareTo(bDate);
    if (byDate != 0) return newestFirst ? -byDate : byDate;
  }

  final bySite = a.post.origin.sourceHost.compareTo(b.post.origin.sourceHost);
  if (bySite != 0) return newestFirst ? -bySite : bySite;

  final byPostId = a.post.id.compareTo(b.post.id);
  if (byPostId != 0) return newestFirst ? -byPostId : byPostId;

  return a.id.compareTo(b.id);
}

class BookmarkMembershipPresentation extends Equatable {
  const BookmarkMembershipPresentation({
    required this.isBookmarked,
    required this.namedGroupCount,
  });

  final bool isBookmarked;
  final int namedGroupCount;

  @override
  List<Object?> get props => [
    isBookmarked,
    namedGroupCount,
  ];
}

BookmarkMembershipPresentation selectBookmarkMembershipPresentation(
  BookmarkLibraryState state,
  BookmarkUniqueId bookmarkId, {
  bool? bookmarked,
  Set<String>? groupMemberships,
}) {
  final isBookmarked =
      bookmarked ?? state.bookmarksByUniqueId.containsKey(bookmarkId);
  final memberships = groupMemberships ?? state.membershipsFor(bookmarkId);
  return BookmarkMembershipPresentation(
    isBookmarked: isBookmarked,
    namedGroupCount: memberships.length,
  );
}

class BulkBookmarkMembershipCounts extends Equatable {
  const BulkBookmarkMembershipCounts({
    required this.selectedCount,
    required this.byGroupId,
  });

  final int selectedCount;
  final Map<String, int> byGroupId;

  @override
  List<Object?> get props => [selectedCount, byGroupId];
}

BulkBookmarkMembershipCounts selectBulkMembershipCounts(
  BookmarkLibraryState state,
  Iterable<BookmarkUniqueId> selection,
) {
  final selected = selection.toSet();
  final counts = <String, int>{};
  for (final bookmarkId in selected) {
    if (!state.bookmarksByUniqueId.containsKey(bookmarkId)) continue;
    final memberships = state.membershipsFor(bookmarkId);
    for (final groupId in memberships) {
      counts.update(groupId, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  return BulkBookmarkMembershipCounts(
    selectedCount: selected.length,
    byGroupId: Map.unmodifiable(counts),
  );
}
