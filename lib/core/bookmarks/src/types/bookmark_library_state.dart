// Dart imports:
import 'dart:collection';

// Package imports:
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

// Project imports:
import '../../../posts/post/types.dart';
import 'bookmark.dart';
import 'pool_bookmark.dart';
import '../../../groups/folder_tree.dart';
import 'bookmark_group.dart';

class BookmarkLibraryState extends Equatable {
  BookmarkLibraryState({
    required List<Bookmark> bookmarks,
    required List<BookmarkGroup> groups,
    List<CollectionFolder> folders = const [],
    List<PoolBookmark> pools = const [],
  }) : pools = List.unmodifiable(pools),
       folders = List.unmodifiable(folders),
       items = List.unmodifiable(bookmarks),
       bookmarks = bookmarks
           .where((bookmark) => bookmark.uniqueId is BookmarkIdentity)
           .map((bookmark) => bookmark.uniqueId)
           .toISet(),
       groups = List.unmodifiable(groups),
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

  const BookmarkLibraryState._derived({
    required this.folders,
    required this.pools,
    required this.items,
    required this.bookmarks,
    required this.groups,
    required this.bookmarksById,
    required this.bookmarksByUniqueId,
    required this.groupsById,
    required this.membershipsByBookmark,
  });

  final List<PoolBookmark> pools;
  final List<CollectionFolder> folders;
  final List<Bookmark> items;
  final ISet<BookmarkUniqueId> bookmarks;
  final List<BookmarkGroup> groups;
  final Map<int, Bookmark> bookmarksById;
  final Map<BookmarkUniqueId, Bookmark> bookmarksByUniqueId;
  final Map<String, BookmarkGroup> groupsById;
  final Map<BookmarkUniqueId, Set<String>> membershipsByBookmark;

  /// Apply confirmed writes, preserving unchanged rows and indexes. Maps and
  /// lists are shallow-copied only when needed; stored post snapshots are never
  /// decoded here. Only affected membership entries are reconstructed.
  BookmarkLibraryState applyCommittedChanges({
    List<PoolBookmark>? pools,
    Iterable<Bookmark> upserts = const [],
    Set<int> removedIds = const {},
    required List<BookmarkGroup> groups,
    required List<CollectionFolder> folders,
  }) {
    final changed = {for (final bookmark in upserts) bookmark.id: bookmark};
    final affectedIds = <int>{...removedIds, ...changed.keys};
    var nextItems = items;
    var nextById = bookmarksById;
    var nextByIdentity = bookmarksByUniqueId;
    var nextIdentities = bookmarks;

    if (affectedIds.isNotEmpty) {
      final byId = Map<int, Bookmark>.of(bookmarksById);
      final byIdentity = Map<BookmarkUniqueId, Bookmark>.of(
        bookmarksByUniqueId,
      );
      for (final id in affectedIds) {
        final previous = byId.remove(id);
        if (previous != null) {
          byIdentity.remove(previous.uniqueId);
          if (previous.uniqueId != changed[id]?.uniqueId) {
            nextIdentities = nextIdentities.remove(previous.uniqueId);
          }
        }
      }
      for (final bookmark in changed.values) {
        if (bookmark.uniqueId is! BookmarkIdentity) continue;
        byId[bookmark.id] = bookmark;
        byIdentity[bookmark.uniqueId] = bookmark;
        if (bookmarksById[bookmark.id]?.uniqueId != bookmark.uniqueId) {
          nextIdentities = nextIdentities.add(bookmark.uniqueId);
        }
      }
      final remaining = Map<int, Bookmark>.of(changed);
      nextItems = List.unmodifiable([
        for (final original in items)
          if (remaining.remove(original.id) case final updated?)
            updated
          else if (!removedIds.contains(original.id))
            original,
        ...remaining.values,
      ]);
      // These local maps have no remaining writers. As with memberships,
      // publish read-only views rather than copying the full indexes again.
      nextById = UnmodifiableMapView(byId);
      nextByIdentity = UnmodifiableMapView(byIdentity);
    }

    final nextGroups =
        this.groups.length == groups.length &&
            groups.indexed.every(
              (entry) => _sameGroup(this.groups[entry.$1], entry.$2),
            )
        ? this.groups
        : List<BookmarkGroup>.unmodifiable([
            for (final group in groups)
              if (_sameGroup(groupsById[group.id], group))
                groupsById[group.id]!
              else
                group,
          ]);
    final nextGroupsById = identical(nextGroups, this.groups)
        ? groupsById
        : Map<String, BookmarkGroup>.unmodifiable({
            for (final group in nextGroups) group.id: group,
          });
    if (!identical(nextGroups, this.groups)) {
      for (final id in {...groupsById.keys, ...nextGroupsById.keys}) {
        final before = groupsById[id]?.bookmarkIds ?? const <int>{};
        final after = nextGroupsById[id]?.bookmarkIds ?? const <int>{};
        if (const SetEquality<int>().equals(before, after)) continue;
        affectedIds.addAll(before.difference(after));
        affectedIds.addAll(after.difference(before));
      }
    }

    Map<BookmarkUniqueId, Set<String>>? memberships;
    // Remove obsolete identities first. A later upsert may reuse an identity
    // under a new storage ID (Undo), or exchange identities with another row.
    for (final id in affectedIds) {
      final previous = bookmarksById[id];
      final next = nextById[id];
      if (previous != null && previous.uniqueId != next?.uniqueId) {
        (memberships ??= Map.of(
          membershipsByBookmark,
        )).remove(previous.uniqueId);
      }
    }
    for (final id in affectedIds) {
      final next = nextById[id];
      if (next == null) continue;
      final updated = {
        for (final group in nextGroups)
          if (group.bookmarkIds.contains(id)) group.id,
      };
      final before = (memberships ?? membershipsByBookmark)[next.uniqueId];
      if (before == null ||
          !const SetEquality<String>().equals(before, updated)) {
        (memberships ??= Map.of(membershipsByBookmark))[next.uniqueId] =
            Set.unmodifiable(updated);
      }
    }
    final nextMemberships = memberships == null
        ? membershipsByBookmark
        // This local map has no remaining writers; avoid copying every
        // bookmark's membership a second time just to make it immutable.
        : UnmodifiableMapView<BookmarkUniqueId, Set<String>>(memberships);
    final nextFolders =
        const ListEquality<CollectionFolder>().equals(
          this.folders,
          folders,
        )
        ? this.folders
        : List<CollectionFolder>.unmodifiable(folders);

    final nextPools =
        pools == null ||
            const ListEquality<PoolBookmark>().equals(this.pools, pools)
        ? this.pools
        : List<PoolBookmark>.unmodifiable(pools);
    if (identical(nextPools, this.pools) &&
        identical(nextItems, items) &&
        identical(nextGroups, this.groups) &&
        identical(nextFolders, this.folders)) {
      return this;
    }
    return BookmarkLibraryState._derived(
      pools: nextPools,
      folders: nextFolders,
      items: nextItems,
      bookmarks: nextIdentities,
      groups: nextGroups,
      bookmarksById: nextById,
      bookmarksByUniqueId: nextByIdentity,
      groupsById: nextGroupsById,
      membershipsByBookmark: nextMemberships,
    );
  }

  /// Publish a successful serialized addition without decoding existing rows or
  /// recomputing their identities. Ambiguous writes use the authoritative recovery path.
  BookmarkLibraryState withAddedGroupMembers({
    required List<Bookmark> createdBookmarks,
    required BookmarkGroup group,
  }) {
    final previousGroup = groupsById[group.id];
    if (previousGroup == null ||
        !_sameGroup(
          previousGroup,
          group.copyWith(bookmarkIds: previousGroup.bookmarkIds),
        ) ||
        !group.bookmarkIds.containsAll(previousGroup.bookmarkIds)) {
      throw StateError(
        'Expected only bookmark additions to an existing group.',
      );
    }
    if (createdBookmarks.isEmpty && _sameGroup(previousGroup, group)) {
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
    return BookmarkLibraryState._derived(
      pools: pools,
      folders: folders,
      items: createdBookmarks.isEmpty
          ? items
          : List.unmodifiable([...items, ...createdBookmarks]),
      bookmarks: identities,
      groups: List.unmodifiable([
        for (final old in groups) old.id == group.id ? group : old,
      ]),
      bookmarksById: createdBookmarks.isEmpty
          ? byId
          : UnmodifiableMapView(byId),
      bookmarksByUniqueId: createdBookmarks.isEmpty
          ? byIdentity
          : UnmodifiableMapView(byIdentity),
      groupsById: Map.unmodifiable({...groupsById, group.id: group}),
      membershipsByBookmark: UnmodifiableMapView(memberships),
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

  /// Legacy rows without an upstream identity can still download their exact
  /// displayed snapshot. Never use this fallback to authorize bookmark writes
  /// or to associate a different Post merely because its numeric ID matches.
  Bookmark? storedBookmarkForPost(Post post) =>
      bookmarkForPost(post) ??
      (BookmarkIdentity.tryFromPost(post) == null
          ? items
                .where((bookmark) => identical(bookmark.post, post))
                .firstOrNull
          : null);

  @override
  List<Object?> get props => [items, groups, folders, pools];
}

// Equatable compares sets with pairwise searches. Re-reading an unchanged large
// group must use hashed membership equality rather than quadratic comparisons.
bool _sameGroup(BookmarkGroup? before, BookmarkGroup after) =>
    identical(before, after) ||
    before != null &&
        before.id == after.id &&
        before.name == after.name &&
        before.folderId == after.folderId &&
        before.position == after.position &&
        const SetEquality<int>().equals(before.bookmarkIds, after.bookmarkIds);

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
