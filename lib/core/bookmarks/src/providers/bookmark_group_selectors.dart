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

enum BookmarkSortType { newestUpload, oldestUpload, newest, oldest, random }

List<Bookmark> selectBookmarks({
  required BookmarkLibraryState state,
  required BookmarkView view,
  required List<String> selectedTags,
  required BookmarkSortType sortType,
  String? selectedBooruUrl,
  BookmarkShuffleState? shuffleState,
}) {
  return performanceRecorder.measureSync(PerfOperation.bookmarkSelect, () {
    final groupIds = state.groupsById[view.groupId]?.bookmarkIds;
    final inView = switch (view.kind) {
      BookmarkViewKind.all => state.items,
      BookmarkViewKind.group =>
        state.items
            .where(
              // Keep library order (including seeded shuffle input) without
              // normalizing every post's already indexed bookmark identity.
              (bookmark) =>
                  (groupIds?.contains(bookmark.id) ?? false) &&
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
    );
  }, items: state.items.length);
}

List<Bookmark> selectBookmarkPreviews({
  required BookmarkLibraryState state,
  required BookmarkView view,
  required BookmarkSortType sortType,
  BookmarkShuffleState? shuffleState,
}) => selectBookmarks(
  state: state,
  view: view,
  selectedTags: const [],
  sortType: sortType,
  shuffleState: shuffleState,
).take(4).toList();

List<Bookmark> filterBookmarks({
  required List<Bookmark> bookmarks,
  required List<String> selectedTags,
  required BookmarkSortType sortType,
  String? selectedBooruUrl,
  BookmarkShuffleState? shuffleState,
}) {
  final filters = selectedTags
      .map(BookmarkSearchToken.parse)
      .where((token) => token.tag.isNotEmpty)
      .toList();
  bool matchesTags(Bookmark bookmark) {
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
                      bookmark.sourceUrl.contains(selectedBooruUrl)) &&
                  (filters.isEmpty || matchesTags(bookmark)),
            )
            .toList();
  final sorted = filtered.sorted(
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
      BookmarkSortType.newest => _compareBookmarkDate(b, a),
      BookmarkSortType.oldest => _compareBookmarkDate(a, b),
      BookmarkSortType.random => 0,
    },
  );

  if (sortType != BookmarkSortType.random) return sorted;
  final activeShuffleState = shuffleState?.seed != null
      ? shuffleState!
      : const BookmarkShuffleState().withNewShuffle();
  return activeShuffleState.applyShuffleToList(sorted);
}

int _compareBookmarkDate(Bookmark a, Bookmark b) {
  final byDate = a.createdAt.compareTo(b.createdAt);
  // Several imported bookmarks can share the clock/storage's time precision.
  // Local IDs retain their insertion order without inventing creation times.
  return byDate != 0 ? byDate : a.id.compareTo(b.id);
}

// Known upload dates always precede missing dates in both directions. A
// stable site+post-ID fallback avoids comparing unrelated sites' ID sequences.
int _compareUploadDate(Bookmark a, Bookmark b, {required bool newestFirst}) {
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
    required this.isInActiveTarget,
    required this.namedGroupCount,
    required this.activeTargetUnavailable,
    required this.showNamedGroupCount,
  });

  final bool isBookmarked;
  final bool isInActiveTarget;
  final int namedGroupCount;
  final bool activeTargetUnavailable;
  final bool showNamedGroupCount;

  @override
  List<Object?> get props => [
    isBookmarked,
    isInActiveTarget,
    namedGroupCount,
    activeTargetUnavailable,
    showNamedGroupCount,
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
  final activeGroupId = state.activeTarget.groupId;
  return BookmarkMembershipPresentation(
    isBookmarked: isBookmarked,
    isInActiveTarget: memberships.contains(activeGroupId),
    namedGroupCount: memberships.length,
    activeTargetUnavailable: false,
    showNamedGroupCount:
        memberships.isNotEmpty &&
        (!memberships.contains(activeGroupId) || memberships.length > 1),
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
