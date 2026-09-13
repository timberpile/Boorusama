// Package imports:
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

// Project imports:
import '../types/bookmark.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_view.dart';
import 'bookmark_shuffle_provider.dart';

enum BookmarkSortType { newest, oldest, random }

List<Bookmark> selectBookmarks({
  required BookmarkLibraryState state,
  required BookmarkView view,
  required List<String> selectedTags,
  required BookmarkSortType sortType,
  String? selectedBooruUrl,
  BookmarkShuffleState? shuffleState,
}) {
  final inView = switch (view.kind) {
    BookmarkViewKind.all => state.items,
    BookmarkViewKind.ungrouped =>
      state.items
          .where((bookmark) => state.membershipsFor(bookmark.uniqueId).isEmpty)
          .toList(),
    BookmarkViewKind.group =>
      state.items
          .where(
            (bookmark) =>
                state.membershipsFor(bookmark.uniqueId).contains(view.groupId),
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
  final filtered = selectedBooruUrl == null && selectedTags.isEmpty
      ? bookmarks
      : bookmarks
            .where(
              (bookmark) =>
                  (selectedBooruUrl == null ||
                      bookmark.sourceUrl.contains(selectedBooruUrl)) &&
                  (selectedTags.isEmpty ||
                      selectedTags.every(bookmark.tags.contains)),
            )
            .toList();
  final sorted = filtered.sorted(
    (a, b) => switch (sortType) {
      BookmarkSortType.newest => b.createdAt.compareTo(a.createdAt),
      BookmarkSortType.oldest => a.createdAt.compareTo(b.createdAt),
      BookmarkSortType.random => 0,
    },
  );

  if (sortType != BookmarkSortType.random) return sorted;
  final activeShuffleState = shuffleState?.seed != null
      ? shuffleState!
      : const BookmarkShuffleState().withNewShuffle();
  return activeShuffleState.applyShuffleToList(sorted);
}

class BookmarkMembershipPresentation extends Equatable {
  const BookmarkMembershipPresentation({
    required this.isBookmarked,
    required this.isInActiveTarget,
    required this.namedGroupCount,
  });

  final bool isBookmarked;
  final bool isInActiveTarget;
  final int namedGroupCount;

  @override
  List<Object?> get props => [isBookmarked, isInActiveTarget, namedGroupCount];
}

BookmarkMembershipPresentation selectBookmarkMembershipPresentation(
  BookmarkLibraryState state,
  BookmarkUniqueId bookmarkId,
) {
  final isBookmarked = state.bookmarksByUniqueId.containsKey(bookmarkId);
  final memberships = state.membershipsFor(bookmarkId);
  final activeGroupId = state.activeTarget.groupId;
  return BookmarkMembershipPresentation(
    isBookmarked: isBookmarked,
    isInActiveTarget: activeGroupId == null
        ? isBookmarked && memberships.isEmpty
        : memberships.contains(activeGroupId),
    namedGroupCount: memberships.length,
  );
}

class BulkBookmarkMembershipCounts extends Equatable {
  const BulkBookmarkMembershipCounts({
    required this.selectedCount,
    required this.byGroupId,
    required this.ungroupedCount,
  });

  final int selectedCount;
  final Map<String, int> byGroupId;
  final int ungroupedCount;

  @override
  List<Object?> get props => [selectedCount, byGroupId, ungroupedCount];
}

BulkBookmarkMembershipCounts selectBulkMembershipCounts(
  BookmarkLibraryState state,
  Iterable<BookmarkUniqueId> selection,
) {
  final selected = selection.toSet();
  final counts = <String, int>{};
  var ungrouped = 0;
  for (final bookmarkId in selected) {
    if (!state.bookmarksByUniqueId.containsKey(bookmarkId)) continue;
    final memberships = state.membershipsFor(bookmarkId);
    if (memberships.isEmpty) ungrouped++;
    for (final groupId in memberships) {
      counts.update(groupId, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  return BulkBookmarkMembershipCounts(
    selectedCount: selected.length,
    byGroupId: Map.unmodifiable(counts),
    ungroupedCount: ungrouped,
  );
}
