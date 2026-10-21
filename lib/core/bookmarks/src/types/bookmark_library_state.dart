// Package imports:
import 'package:equatable/equatable.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

// Project imports:
import '../../../posts/post/types.dart';
import 'bookmark.dart';
import '../../../groups/folder_tree.dart';
import 'bookmark_group.dart';
import 'bookmark_target.dart';

class BookmarkLibraryState extends Equatable {
  BookmarkLibraryState({
    required List<Bookmark> bookmarks,
    required List<BookmarkGroup> groups,
    required BookmarkTarget activeTarget,
    List<CollectionFolder> folders = const [],
  }) : folders = List.unmodifiable(folders),
       items = List.unmodifiable(bookmarks),
       bookmarks = bookmarks
           .where((bookmark) => bookmark.uniqueId is BookmarkIdentity)
           .map((bookmark) => bookmark.uniqueId)
           .toISet(),
       groups = List.unmodifiable(groups),
       activeTarget = _effectiveTarget(groups, activeTarget),
       bookmarksById = Map.unmodifiable({
         for (final bookmark in bookmarks)
           if (bookmark.uniqueId is BookmarkIdentity) bookmark.id: bookmark,
       }),
       bookmarksByUniqueId = Map.unmodifiable({
         for (final bookmark in bookmarks)
           if (bookmark.uniqueId is BookmarkIdentity)
             bookmark.uniqueId: bookmark,
       }),
       groupsById = Map.unmodifiable({
         for (final group in groups) group.id: group,
       }),
       membershipsByBookmark = Map.unmodifiable(
         _buildMemberships(bookmarks, groups),
       );

  const BookmarkLibraryState._({
    required this.folders,
    required this.items,
    required this.bookmarks,
    required this.groups,
    required this.activeTarget,
    required this.bookmarksById,
    required this.bookmarksByUniqueId,
    required this.groupsById,
    required this.membershipsByBookmark,
  });

  final List<CollectionFolder> folders;
  final List<Bookmark> items;
  final ISet<BookmarkUniqueId> bookmarks;
  final List<BookmarkGroup> groups;
  final BookmarkTarget activeTarget;
  final Map<int, Bookmark> bookmarksById;
  final Map<BookmarkUniqueId, Bookmark> bookmarksByUniqueId;
  final Map<String, BookmarkGroup> groupsById;
  final Map<BookmarkUniqueId, Set<String>> membershipsByBookmark;

  /// Publish a successful serialized addition without decoding existing rows or
  /// recomputing their identities. Recovery and other mutations still reload.
  BookmarkLibraryState withAddedGroupMembers({
    required List<Bookmark> createdBookmarks,
    required BookmarkGroup group,
    required BookmarkTarget requestedTarget,
  }) {
    final previousGroup = groupsById[group.id];
    if (previousGroup == null ||
        group.copyWith(bookmarkIds: previousGroup.bookmarkIds) !=
            previousGroup ||
        !group.bookmarkIds.containsAll(previousGroup.bookmarkIds)) {
      throw StateError(
        'Expected only bookmark additions to an existing group.',
      );
    }
    final target = _effectiveTarget(groups, requestedTarget);
    if (createdBookmarks.isEmpty &&
        group == previousGroup &&
        target == activeTarget) {
      return this;
    }

    final byId = createdBookmarks.isEmpty
        ? bookmarksById
        : <int, Bookmark>{...bookmarksById};
    final byIdentity = createdBookmarks.isEmpty
        ? bookmarksByUniqueId
        : <BookmarkUniqueId, Bookmark>{...bookmarksByUniqueId};
    var identities = bookmarks;
    for (final bookmark in createdBookmarks) {
      final identity = bookmark.uniqueId;
      if (identity is! BookmarkIdentity || byId.containsKey(bookmark.id)) {
        throw StateError('Expected a new bookmark with a stable identity.');
      }
      byId[bookmark.id] = bookmark;
      byIdentity[identity] = bookmark;
      identities = identities.add(identity);
    }
    final memberships = {...membershipsByBookmark};
    for (final id in group.bookmarkIds.difference(previousGroup.bookmarkIds)) {
      final bookmark = byId[id];
      if (bookmark == null) {
        throw StateError('The group contains an unknown bookmark.');
      }
      final identity = bookmark.uniqueId;
      memberships[identity] = Set.unmodifiable({
        ...?memberships[identity],
        group.id,
      });
    }
    return BookmarkLibraryState._(
      folders: folders,
      items: createdBookmarks.isEmpty
          ? items
          : List.unmodifiable([...items, ...createdBookmarks]),
      bookmarks: identities,
      groups: List.unmodifiable([
        for (final old in groups) old.id == group.id ? group : old,
      ]),
      activeTarget: target,
      bookmarksById: createdBookmarks.isEmpty ? byId : Map.unmodifiable(byId),
      bookmarksByUniqueId: createdBookmarks.isEmpty
          ? byIdentity
          : Map.unmodifiable(byIdentity),
      groupsById: Map.unmodifiable({...groupsById, group.id: group}),
      membershipsByBookmark: Map.unmodifiable(memberships),
    );
  }

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
  List<Object?> get props => [items, groups, activeTarget, folders];
}

BookmarkTarget _effectiveTarget(
  List<BookmarkGroup> groups,
  BookmarkTarget requested,
) {
  return switch (requested.groupId) {
    final id when groups.any((group) => group.id == id) => requested,
    _ => const BookmarkTarget.defaultGroup(),
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
      if (bookmark.uniqueId is BookmarkIdentity)
        bookmark.uniqueId: Set.unmodifiable(byBookmarkKey[bookmark.id] ?? {}),
  };
}
