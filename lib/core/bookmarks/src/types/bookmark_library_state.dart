// Dart imports:
import 'dart:collection';

// Package imports:
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

// Project imports:
import '../../../posts/post/types.dart';
import 'bookmark.dart';
import 'bookmark_record_index.dart';
import 'bookmark_record_fields.dart';
import 'pool_bookmark.dart';
import '../../../content/types.dart';
import '../data/bookmark_collection_projection.dart';
import '../../../groups/folder_tree.dart';
import 'bookmark_group.dart';
import 'bookmark_group_tree.dart';
import 'bookmark_view.dart';
import 'bookmark_subtree_projection.dart';

class BookmarkLibraryState extends Equatable {
  factory BookmarkLibraryState({
    required List<PostBookmark> bookmarks,
    required List<BookmarkGroup> groups,
    List<CollectionFolder> folders = const [],
    Map<String, String> legacyFolderGroupIds = const {},
    List<CollectionBookmark> pools = const [],
    List<Bookmark>? records,
    int revision = 0,
  }) {
    final index = BookmarkRecordIndex.build(
      records: records ?? bookmarks,
      groups: groups,
      revision: revision,
      strict: records != null,
    );
    final media = records == null ? bookmarks : _mediaRecords(index.records);
    return BookmarkLibraryState._initial(
      index: index,
      canonical: records != null,
      media: media,
      groups: groups,
      folders: folders,
      legacyFolderGroupIds: legacyFolderGroupIds,
      pools: records == null ? pools : _projectAllPools(index, groups),
    );
  }

  BookmarkLibraryState._initial({
    required BookmarkRecordIndex index,
    required bool canonical,
    required List<PostBookmark> media,
    required List<BookmarkGroup> groups,
    required List<CollectionFolder> folders,
    required Map<String, String> legacyFolderGroupIds,
    required List<CollectionBookmark> pools,
  }) : _canonical = canonical,
       _recordIndex = index,
       revision = index.revision,
       pools = List.unmodifiable(pools),
       folders = List.unmodifiable(folders),
       legacyFolderGroupIds = Map.unmodifiable(legacyFolderGroupIds),
       items = List.unmodifiable(media),
       bookmarks = media
           .where(
             (bookmark) =>
                 bookmark.uniqueId is BookmarkIdentity &&
                 (!canonical || bookmarkContentIdentity(bookmark) != null),
           )
           .map((bookmark) => bookmark.uniqueId)
           .toISet(),
       groups = List.unmodifiable(groups),
       bookmarksById = Map.unmodifiable({
         for (final bookmark in media)
           if (canonical || bookmark.uniqueId is BookmarkIdentity)
             bookmark.id: bookmark,
       }),
       bookmarksByUniqueId = Map.unmodifiable({
         for (final bookmark in media)
           if (bookmark.uniqueId is BookmarkIdentity &&
               (!canonical || bookmarkContentIdentity(bookmark) != null))
             bookmark.uniqueId: bookmark,
       }),
       groupsById = Map.unmodifiable({
         for (final group in groups) group.id: group,
       }),
       membershipsByBookmark = Map.unmodifiable(
         _buildMemberships(
           canonical
               ? media
                     .where((record) => bookmarkContentIdentity(record) != null)
                     .toList()
               : media,
           groups,
         ),
       );

  BookmarkLibraryState._derived({
    required this.folders,
    required this.legacyFolderGroupIds,
    required this.pools,
    required this.items,
    required this.bookmarks,
    required this.groups,
    required this.bookmarksById,
    required this.bookmarksByUniqueId,
    required this.groupsById,
    required this.membershipsByBookmark,
    required BookmarkRecordIndex recordIndex,
    required bool canonical,
    required this.revision,
  }) : _recordIndex = recordIndex,
       _canonical = canonical;

  final BookmarkRecordIndex _recordIndex;
  final bool _canonical;
  bool get hasUnifiedRecords => _canonical;
  List<Bookmark> get records => _recordIndex.records;
  Map<int, Bookmark> get byId => _recordIndex.byId;
  Map<ContentIdentity, int> get idByContent => _recordIndex.idByContent;
  Map<int, Set<String>> get membershipsByBookmarkId =>
      _recordIndex.membershipsByBookmarkId;
  final int revision;

  final List<CollectionBookmark> pools;
  final List<CollectionFolder> folders;
  final Map<String, String> legacyFolderGroupIds;
  final List<PostBookmark> items;
  final ISet<BookmarkUniqueId> bookmarks;
  final List<BookmarkGroup> groups;
  final Map<int, PostBookmark> bookmarksById;
  final Map<BookmarkUniqueId, PostBookmark> bookmarksByUniqueId;
  final Map<String, BookmarkGroup> groupsById;
  final Map<BookmarkUniqueId, Set<String>> membershipsByBookmark;

  late final BookmarkGroupTree groupTree = BookmarkGroupTree(groups);
  final _subtreeProjections =
      LinkedHashMap<String, BookmarkSubtreeProjection>();

  BookmarkSubtreeProjection subtreeProjection(String groupId) {
    final cached = _subtreeProjections.remove(groupId);
    final projection =
        cached ??
        BookmarkSubtreeProjection(
          groupId: groupId,
          tree: groupTree,
          byId: byId,
        );
    _subtreeProjections[groupId] = projection;
    // Only recently visited views are retained, within this immutable snapshot.
    if (_subtreeProjections.length > 8)
      _subtreeProjections.remove(_subtreeProjections.keys.first);
    return projection;
  }

  Set<int> bookmarkIdsForView(BookmarkView view) => switch (view.kind) {
    BookmarkViewKind.all => Set.unmodifiable(byId.keys),
    BookmarkViewKind.group => groupsById[view.groupId]?.bookmarkIds ?? const {},
    BookmarkViewKind.subtree => subtreeProjection(view.groupId!).bookmarkIds,
  };

  Set<String> groupIdsForView(BookmarkView view) => switch (view.kind) {
    BookmarkViewKind.all => Set.unmodifiable(groupsById.keys),
    BookmarkViewKind.group =>
      groupsById.containsKey(view.groupId) ? {view.groupId!} : const {},
    BookmarkViewKind.subtree => subtreeProjection(
      view.groupId!,
    ).includedGroupIds,
  };

  /// Apply confirmed writes, preserving unchanged rows and indexes. Maps and
  /// lists are shallow-copied only when needed; stored post snapshots are never
  /// decoded here. Only affected membership entries are reconstructed.
  BookmarkLibraryState applyCommittedChanges({
    List<CollectionBookmark>? pools,
    Iterable<Bookmark> upserts = const [],
    Set<int> removedIds = const {},
    required List<BookmarkGroup> groups,
    required List<CollectionFolder> folders,
    int? revision,
  }) {
    if (_canonical) {
      return _applyCanonicalChanges(
        upserts: upserts,
        removedIds: removedIds,
        groups: groups,
        folders: folders,
        revision: revision,
      );
    }
    final changed = {
      for (final bookmark in upserts)
        if (bookmark is PostBookmark) bookmark.id: bookmark,
    };
    final affectedIds = <int>{...removedIds, ...changed.keys};
    var nextItems = items;
    var nextById = bookmarksById;
    var nextByIdentity = bookmarksByUniqueId;
    var nextIdentities = bookmarks;

    if (affectedIds.isNotEmpty) {
      final byId = Map<int, PostBookmark>.of(bookmarksById);
      final byIdentity = Map<BookmarkUniqueId, PostBookmark>.of(
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
      final remaining = Map<int, PostBookmark>.of(changed);
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
            const ListEquality<CollectionBookmark>().equals(this.pools, pools)
        ? this.pools
        : List<CollectionBookmark>.unmodifiable(pools);
    if (identical(nextPools, this.pools) &&
        identical(nextItems, items) &&
        identical(nextGroups, this.groups) &&
        identical(nextFolders, this.folders) &&
        (revision == null || revision == this.revision)) {
      return this;
    }
    return BookmarkLibraryState._derived(
      legacyFolderGroupIds: legacyFolderGroupIds,
      pools: nextPools,
      folders: nextFolders,
      items: nextItems,
      bookmarks: nextIdentities,
      groups: nextGroups,
      bookmarksById: nextById,
      bookmarksByUniqueId: nextByIdentity,
      groupsById: nextGroupsById,
      membershipsByBookmark: nextMemberships,
      recordIndex: _recordIndex.apply(
        upserts: changed.values,
        removedIds: removedIds,
        previousGroups: groupsById,
        groups: nextGroups,
        revision: revision,
      ),
      canonical: false,
      revision: revision ?? this.revision,
    );
  }

  BookmarkLibraryState _applyCanonicalChanges({
    required Iterable<Bookmark> upserts,
    required Set<int> removedIds,
    required List<BookmarkGroup> groups,
    required List<CollectionFolder> folders,
    int? revision,
  }) {
    final changed = {for (final record in upserts) record.id: record};
    final nextGroups = _canonicalGroups(groups, groupsById, this.groups);
    final previousGroups = groupsById;
    final nextGroupsById = identical(nextGroups, this.groups)
        ? groupsById
        : Map<String, BookmarkGroup>.unmodifiable({
            for (final group in nextGroups) group.id: group,
          });
    final nextIndex = _recordIndex.apply(
      upserts: changed.values,
      removedIds: removedIds,
      previousGroups: previousGroups,
      groups: nextGroups,
      revision: revision,
    );
    final affected = <int>{...changed.keys, ...removedIds};
    for (final id in {...previousGroups.keys, ...nextGroupsById.keys}) {
      final before = previousGroups[id];
      final after = nextGroupsById[id];
      if (_sameGroupNullable(before, after)) continue;
      final oldMembers = before?.bookmarkIds ?? const <int>{};
      final newMembers = after?.bookmarkIds ?? const <int>{};
      affected.addAll(oldMembers.difference(newMembers));
      affected.addAll(newMembers.difference(oldMembers));
      for (final memberId in oldMembers.intersection(newMembers)) {
        if (before?.addedAt[memberId] != after?.addedAt[memberId]) {
          affected.add(memberId);
        }
      }
    }

    final mediaChanged = <int>{
      for (final id in {...changed.keys, ...removedIds})
        if (_isPost(_recordIndex.byId[id]) || _isPost(nextIndex.byId[id])) id,
    };
    final updateMedia = mediaChanged.isNotEmpty;
    var nextItems = items;
    var nextById = bookmarksById;
    var nextByIdentity = bookmarksByUniqueId;
    var nextIdentities = bookmarks;
    if (updateMedia) {
      final byId = Map<int, PostBookmark>.of(bookmarksById);
      final byIdentity = Map<BookmarkUniqueId, PostBookmark>.of(
        bookmarksByUniqueId,
      );
      for (final id in mediaChanged) {
        final old = byId.remove(id);
        if (old != null) {
          byIdentity.remove(old.uniqueId);
          final next = nextIndex.byId[id];
          if (next is! PostBookmark || old.uniqueId != next.uniqueId) {
            nextIdentities = nextIdentities.remove(old.uniqueId);
          }
        }
      }
      for (final id in mediaChanged) {
        final next = nextIndex.byId[id];
        if (next is! PostBookmark) continue;
        byId[id] = next;
        if (bookmarkContentIdentity(next) != null) {
          byIdentity[next.uniqueId] = next;
          if (bookmarksById[id]?.uniqueId != next.uniqueId) {
            nextIdentities = nextIdentities.add(next.uniqueId);
          }
        }
      }
      nextById = UnmodifiableMapView(byId);
      nextByIdentity = UnmodifiableMapView(byIdentity);
      nextItems = List.unmodifiable(
        nextIndex.records.whereType<PostBookmark>(),
      );
    }

    Map<BookmarkUniqueId, Set<String>>? reverse;
    for (final id in affected) {
      final previous = _recordIndex.byId[id];
      final next = nextIndex.byId[id];
      if (previous is PostBookmark &&
          (next is! PostBookmark || previous.uniqueId != next.uniqueId)) {
        (reverse ??= Map.of(membershipsByBookmark)).remove(previous.uniqueId);
      }
      if (next is PostBookmark && bookmarkContentIdentity(next) != null) {
        final membership = nextIndex.membershipsByBookmarkId[id] ?? const {};
        final before = (reverse ?? membershipsByBookmark)[next.uniqueId];
        if (before == null ||
            !const SetEquality<String>().equals(before, membership)) {
          (reverse ??= Map.of(membershipsByBookmark))[next.uniqueId] =
              Set.unmodifiable(membership);
        }
      }
    }
    final nextReverse = reverse == null
        ? membershipsByBookmark
        : UnmodifiableMapView<BookmarkUniqueId, Set<String>>(reverse);
    final nextFolders =
        const ListEquality<CollectionFolder>().equals(
          this.folders,
          folders,
        )
        ? this.folders
        : List<CollectionFolder>.unmodifiable(folders);
    final nextPools = _projectPoolDelta(
      index: nextIndex,
      groups: nextGroups,
      changedIds: affected,
      previous: pools,
    );
    if (identical(nextIndex, _recordIndex) &&
        identical(nextItems, items) &&
        identical(nextGroups, this.groups) &&
        identical(nextFolders, this.folders) &&
        identical(nextPools, pools)) {
      return this;
    }
    return BookmarkLibraryState._derived(
      legacyFolderGroupIds: legacyFolderGroupIds,
      pools: nextPools,
      folders: nextFolders,
      items: nextItems,
      bookmarks: nextIdentities,
      groups: nextGroups,
      bookmarksById: nextById,
      bookmarksByUniqueId: nextByIdentity,
      groupsById: nextGroupsById,
      membershipsByBookmark: nextReverse,
      recordIndex: nextIndex,
      canonical: true,
      revision: nextIndex.revision,
    );
  }

  /// Publish a successful serialized addition without decoding existing rows or
  /// recomputing their identities. Ambiguous writes use the authoritative recovery path.
  BookmarkLibraryState withAddedGroupMembers({
    required List<PostBookmark> createdBookmarks,
    required BookmarkGroup group,
    int? revision,
  }) {
    if (_canonical) {
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
      if (createdBookmarks.isEmpty &&
          _sameGroup(previousGroup, group) &&
          (revision == null || revision == this.revision)) {
        return this;
      }
      for (final record in createdBookmarks) {
        if (bookmarkContentIdentity(record) == null ||
            byId.containsKey(record.id)) {
          throw StateError('Expected a new bookmark with a stable identity.');
        }
      }
      return _applyCanonicalChanges(
        upserts: createdBookmarks,
        removedIds: const {},
        groups: [for (final old in groups) old.id == group.id ? group : old],
        folders: folders,
        revision: revision,
      );
    }
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
    if (createdBookmarks.isEmpty &&
        _sameGroup(previousGroup, group) &&
        (revision == null || revision == this.revision)) {
      return this;
    }

    final mediaById = createdBookmarks.isEmpty
        ? bookmarksById
        : <int, PostBookmark>{...bookmarksById};
    final mediaByIdentity = createdBookmarks.isEmpty
        ? bookmarksByUniqueId
        : <BookmarkUniqueId, PostBookmark>{...bookmarksByUniqueId};
    var identities = bookmarks;
    for (final bookmark in createdBookmarks) {
      final identity = bookmark.uniqueId;
      if (identity is! BookmarkIdentity || mediaById.containsKey(bookmark.id)) {
        throw StateError('Expected a new bookmark with a stable identity.');
      }
      mediaById[bookmark.id] = bookmark;
      mediaByIdentity[identity] = bookmark;
      identities = identities.add(identity);
    }
    final memberships = {...membershipsByBookmark};
    for (final id in group.bookmarkIds.difference(previousGroup.bookmarkIds)) {
      final bookmark = mediaById[id];
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
      legacyFolderGroupIds: legacyFolderGroupIds,
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
          ? mediaById
          : UnmodifiableMapView(mediaById),
      bookmarksByUniqueId: createdBookmarks.isEmpty
          ? mediaByIdentity
          : UnmodifiableMapView(mediaByIdentity),
      groupsById: Map.unmodifiable({...groupsById, group.id: group}),
      membershipsByBookmark: UnmodifiableMapView(memberships),
      recordIndex: _recordIndex.apply(
        upserts: createdBookmarks,
        removedIds: const {},
        previousGroups: groupsById,
        groups: [for (final old in groups) old.id == group.id ? group : old],
        revision: revision,
      ),
      canonical: false,
      revision: revision ?? this.revision,
    );
  }

  Set<String> membershipsFor(BookmarkUniqueId bookmarkId) =>
      membershipsByBookmark[bookmarkId] ?? const {};

  Set<String> membershipsForId(int bookmarkId) =>
      membershipsByBookmarkId[bookmarkId] ?? const {};

  bool isBookmarked(Post post, int booruId) => bookmarkForPost(post) != null;

  PostBookmark? bookmarkForPost(Post post, {int fallbackBooruId = -1}) {
    final identity = BookmarkIdentity.tryFromPost(post);
    if (identity == null) return null;
    if (!_canonical) return bookmarksByUniqueId[identity];
    final id =
        idByContent[(
          siteNamespace: identity.site,
          kind: ContentKind.post,
          sourceKey: identity.postKey,
        )];
    final record = byId[id];
    return record is PostBookmark &&
            record.post.origin.booruType == post.origin.booruType
        ? record
        : null;
  }

  /// Retained media without proven source facts can still use their exact
  /// displayed snapshot. This never authorizes associating another Post.
  late final Map<Post, PostBookmark> _storedByPostObject =
      Map<Post, PostBookmark>.identity()..addEntries(
        items.map((bookmark) => MapEntry(bookmark.post, bookmark)),
      );

  PostBookmark? storedBookmarkForPost(Post post) =>
      _storedByPostObject[post] ?? bookmarkForPost(post);

  @override
  List<Object?> get props => _canonical
      ? [records, groups, folders, pools, revision]
      : [items, groups, folders, pools];
}

bool _isPost(Bookmark? record) => record is PostBookmark;

List<PostBookmark> _mediaRecords(Iterable<Bookmark> records) => [
  for (final record in records)
    if (record is PostBookmark) record,
];

List<BookmarkGroup> _canonicalGroups(
  List<BookmarkGroup> incoming,
  Map<String, BookmarkGroup> previous,
  List<BookmarkGroup> previousList,
) {
  final result = [
    for (final group in incoming)
      _sameGroup(previous[group.id], group) ? previous[group.id]! : group,
  ];
  if (result.length == previousList.length &&
      result.indexed.every(
        (entry) => identical(entry.$2, previousList[entry.$1]),
      )) {
    return previousList;
  }
  return List<BookmarkGroup>.unmodifiable(result);
}

bool _sameGroupNullable(BookmarkGroup? before, BookmarkGroup? after) =>
    before == null ? after == null : after != null && _sameGroup(before, after);

List<CollectionBookmark> _projectAllPools(
  BookmarkRecordIndex index,
  List<BookmarkGroup> groups,
) {
  return _projectPoolDelta(
    index: index,
    groups: groups,
    changedIds: index.byId.keys.toSet(),
    previous: const [],
  );
}

List<CollectionBookmark> _projectPoolDelta({
  required BookmarkRecordIndex index,
  required List<BookmarkGroup> groups,
  required Set<int> changedIds,
  List<CollectionBookmark>? previous,
}) {
  final old = previous ?? const <CollectionBookmark>[];
  final byId = <int, CollectionBookmark>{
    for (final pool in old)
      if (pool.bookmarkId case final id?) id: pool,
  };
  for (final id in changedIds) {
    final record = index.byId[id];
    if (record == null) {
      byId.remove(id);
      continue;
    }
    final memberships = <String, DateTime>{};
    for (final groupId
        in index.membershipsByBookmarkId[id] ?? const <String>{}) {
      final group = groups.firstWhereOrNull((item) => item.id == groupId);
      if (group != null) {
        memberships[groupId] =
            group.addedAt[id] ?? bookmarkCreatedAt(record).toUtc();
      }
    }
    final projection = bookmarkCollectionProjection(
      record,
      memberships: memberships,
    );
    if (projection == null) {
      byId.remove(id);
    } else {
      byId[id] = projection;
    }
  }
  final next = byId.values.toList()
    ..sort((a, b) => a.bookmarkId!.compareTo(b.bookmarkId!));
  if (old.length == next.length &&
      Iterable<int>.generate(old.length).every(
        (i) => identical(old[i], next[i]),
      )) {
    return old;
  }
  return List.unmodifiable(next);
}

// Equatable compares sets with pairwise searches. Re-reading an unchanged large
// group must use hashed membership equality rather than quadratic comparisons.
bool _sameGroup(BookmarkGroup? before, BookmarkGroup after) =>
    identical(before, after) ||
    before != null &&
        before.id == after.id &&
        before.name == after.name &&
        before.folderId == after.folderId &&
        before.parentGroupId == after.parentGroupId &&
        before.position == after.position &&
        const SetEquality<int>().equals(
          before.bookmarkIds,
          after.bookmarkIds,
        ) &&
        const MapEquality<int, DateTime>().equals(
          before.addedAt,
          after.addedAt,
        );

Map<BookmarkUniqueId, Set<String>> _buildMemberships(
  List<PostBookmark> bookmarks,
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
