// Package imports:
import 'package:equatable/equatable.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

// Project imports:
import '../../../posts/post/types.dart';
import 'bookmark.dart';
import 'bookmark_group.dart';
import 'bookmark_target.dart';

class BookmarkLibraryState extends Equatable {
  BookmarkLibraryState({
    required List<Bookmark> bookmarks,
    required List<BookmarkGroup> groups,
    required BookmarkTarget activeTarget,
  }) : items = List.unmodifiable(bookmarks),
       bookmarks = bookmarks.map((bookmark) => bookmark.uniqueId).toISet(),
       groups = List.unmodifiable(groups),
       activeTarget = _effectiveTarget(groups, activeTarget),
       bookmarksById = Map.unmodifiable({
         for (final bookmark in bookmarks) bookmark.id: bookmark,
       }),
       bookmarksByUniqueId = Map.unmodifiable({
         for (final bookmark in bookmarks) bookmark.uniqueId: bookmark,
       }),
       groupsById = Map.unmodifiable({
         for (final group in groups) group.id: group,
       }),
       membershipsByBookmark = Map.unmodifiable(
         _buildMemberships(bookmarks, groups),
       );

  final List<Bookmark> items;
  final ISet<BookmarkUniqueId> bookmarks;
  final List<BookmarkGroup> groups;
  final BookmarkTarget activeTarget;
  final Map<int, Bookmark> bookmarksById;
  final Map<BookmarkUniqueId, Bookmark> bookmarksByUniqueId;
  final Map<String, BookmarkGroup> groupsById;
  final Map<BookmarkUniqueId, Set<String>> membershipsByBookmark;

  Set<String> membershipsFor(BookmarkUniqueId bookmarkId) =>
      membershipsByBookmark[bookmarkId] ?? const {};

  bool isBookmarked(Post post, int booruId) =>
      bookmarks.contains(BookmarkUniqueId.fromPost(post, booruId));

  Bookmark? bookmarkForPost(Post post, {int fallbackBooruId = -1}) =>
      bookmarksByUniqueId[BookmarkUniqueId.fromPost(
        post,
        post.origin.booruType.id,
      )];

  @override
  List<Object?> get props => [items, groups, activeTarget];
}

BookmarkTarget _effectiveTarget(
  List<BookmarkGroup> groups,
  BookmarkTarget requested,
) {
  return switch (requested.groupId) {
    null => requested,
    final id when groups.any((group) => group.id == id) => requested,
    _ => const BookmarkTarget.ungrouped(),
  };
}

Map<BookmarkUniqueId, Set<String>> _buildMemberships(
  List<Bookmark> bookmarks,
  List<BookmarkGroup> groups,
) {
  final byBookmarkKey = <int, Set<String>>{};
  for (final group in groups) {
    for (final bookmarkId in group.bookmarkIds) {
      byBookmarkKey.putIfAbsent(bookmarkId, () => {}).add(group.id);
    }
  }

  return {
    for (final bookmark in bookmarks)
      bookmark.uniqueId: Set.unmodifiable(byBookmarkKey[bookmark.id] ?? {}),
  };
}
