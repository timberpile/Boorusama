// Package imports:
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

// Project imports:
import '../../../posts/post/types.dart';
import '../types/bookmark.dart';
import '../../../groups/folder_tree.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_group_repository.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_repository.dart';
import '../types/bookmark_target.dart';

class BookmarkGroupRemovalResult extends Equatable {
  const BookmarkGroupRemovalResult({
    required this.removedCount,
    this.deletedBookmarks = const [],
    this.removedBookmarks = const [],
    this.groupId,
  });

  final List<Bookmark> deletedBookmarks;
  final List<Bookmark> removedBookmarks;
  final String? groupId;
  int get deletedCount => deletedBookmarks.length;
  final int removedCount;

  @override
  List<Object?> get props => [
    groupId,
    removedBookmarks,
    deletedBookmarks,
    removedCount,
  ];
}

class BookmarkLibraryRollbackException implements Exception {
  const BookmarkLibraryRollbackException({
    required this.operationError,
    required this.rollbackErrors,
  });

  final Object operationError;
  final List<Object> rollbackErrors;
}

class BookmarkLibraryService {
  const BookmarkLibraryService({
    required this.bookmarkRepository,
    required this.groupRepository,
    required this.imageUrlResolver,
  });

  final BookmarkRepository bookmarkRepository;
  final BookmarkGroupRepository groupRepository;
  final ImageUrlResolver Function(int? booruId) imageUrlResolver;

  Future<BookmarkLibraryState> load(BookmarkTarget activeTarget) async {
    final bookmarks = await bookmarkRepository.getAllBookmarksOrThrow(
      imageUrlResolver: imageUrlResolver,
    );
    await groupRepository.repair(
      validBookmarkIds: bookmarks.map((bookmark) => bookmark.id).toSet(),
    );
    await ensureDefaultMemberships(bookmarks);
    final groups = await groupRepository.getGroups();
    final folders = await groupRepository.getFolders();
    FolderTree(folders).validatePlacements([
      for (final g in groups)
        FolderPlacement(
          itemId: g.id,
          folderId: g.folderId,
          position: g.position,
        ),
    ]);
    return BookmarkLibraryState(
      bookmarks: bookmarks,
      groups: groups,
      folders: folders,
      activeTarget: activeTarget,
    );
  }

  /// Idempotent repair is also used after legacy import and full replacement.
  Future<void> ensureDefaultMemberships(List<Bookmark> bookmarks) async {
    var groups = await groupRepository.getGroups();
    if (!groups.any((g) => g.isDefault)) {
      try {
        await groupRepository.createGroup(
          'Default',
          id: defaultBookmarkGroupId,
        );
      } catch (_) {
        if (await groupRepository.getGroup(defaultBookmarkGroupId) == null) {
          rethrow;
        }
      }
      groups = await groupRepository.getGroups();
    }
    final members = {for (final g in groups) ...g.bookmarkIds};
    final missing = bookmarks.map((b) => b.id).toSet().difference(members);
    if (missing.isNotEmpty) {
      try {
        await groupRepository.addBookmarks(defaultBookmarkGroupId, missing);
      } catch (_) {
        final saved = await groupRepository.getGroup(defaultBookmarkGroupId);
        if (saved == null || !saved.bookmarkIds.containsAll(missing)) rethrow;
      }
    }
  }

  Future<CollectionFolder> createFolder(String name, {String? parentId}) async {
    final folders = await groupRepository.getFolders();
    final tree = FolderTree(folders);
    if (parentId != null && !tree.byId.containsKey(parentId)) {
      throw const FormatException('Unknown parent');
    }
    final folder = CollectionFolder(
      id: const Uuid().v4(),
      name: name.trim(),
      parentId: parentId,
      position: tree.children(parentId).length,
    );
    await groupRepository.replaceFolderOrganization([
      ...folders,
      folder,
    ], await groupRepository.getGroups());
    return folder;
  }

  Future<void> renameFolder(String id, String name) async {
    final folders = await groupRepository.getFolders();
    if (!folders.any((f) => f.id == id)) {
      throw const FormatException('Unknown folder');
    }
    await groupRepository.replaceFolderOrganization([
      for (final f in folders) f.id == id ? f.copyWith(name: name.trim()) : f,
    ], await groupRepository.getGroups());
  }

  Future<void> moveFolderItems({
    Set<String> folderIds = const {},
    Set<String> groupIds = const {},
    required String? destination,
  }) async {
    final folders = await groupRepository.getFolders();
    final tree = FolderTree(folders);
    final moved = tree.move(folderIds, destination);
    final groups = await groupRepository.getGroups();
    if (!groups.map((g) => g.id).toSet().containsAll(groupIds)) {
      throw const FormatException('Unknown group');
    }
    if (groupIds.contains(defaultBookmarkGroupId)) {
      throw StateError('Default cannot be moved.');
    }
    final contained = {for (final id in folderIds) ...tree.subtree(id)};
    var position = groups
        .where((g) => g.folderId == destination)
        .fold(0, (n, g) => g.position >= n ? g.position + 1 : n);
    await groupRepository.replaceFolderOrganization(moved, [
      for (final g in groups)
        groupIds.contains(g.id) &&
                !contained.contains(g.folderId) &&
                g.folderId != destination
            ? g.copyWith(
                folderId: destination,
                home: destination == null,
                position: position++,
              )
            : g,
    ]);
  }

  Future<BookmarkFolderDeletionPreview> previewDeleteFolder(String id) async {
    final snapshot = await load(const BookmarkTarget.defaultGroup());
    return BookmarkFolderDeletionPreview.from(snapshot, id);
  }

  Future<void> deleteFolder(BookmarkFolderDeletionPreview expected) async {
    final current = await previewDeleteFolder(expected.folderId);
    if (current != expected) throw BookmarkFolderChangedException(current);
    final deletedGroups = current.groupIds;
    final old = current.snapshot;
    final orphans = [
      for (final id in current.orphanBookmarkIds) old.bookmarksById[id]!,
    ];
    try {
      for (final id in deletedGroups) {
        await groupRepository.deleteGroup(id);
      }
      if (orphans.isNotEmpty) await bookmarkRepository.removeBookmarks(orphans);
      await groupRepository.replaceFolderOrganization(
        old.folders.where((f) => !current.folderIds.contains(f.id)).toList(),
        old.groups.where((g) => !deletedGroups.contains(g.id)).toList(),
      );
    } catch (error, stack) {
      final errors = await _restoreBookmarks(orphans);
      try {
        for (final g in old.groups) {
          if (await groupRepository.getGroup(g.id) == null) {
            await groupRepository.createGroup(g.name, id: g.id);
          }
          await groupRepository.replaceMemberships(g.id, g.bookmarkIds);
        }
        await groupRepository.replaceFolderOrganization(
          old.folders,
          old.groups,
        );
      } catch (e) {
        errors.add(e);
      }
      _throwWithRollback(error, stack, errors);
    }
  }

  Future<Bookmark> upgradeBookmarkSnapshot({
    required Bookmark bookmark,
    required Post post,
    required BooruPostDataCodec? dataCodec,
    DateTime? updatedAt,
  }) async {
    final snapshot = const StoredPostCodec().encode(
      post,
      dataCodec: dataCodec,
    );
    final upgraded = Bookmark.fromSnapshot(
      id: bookmark.id,
      createdAt: bookmark.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      snapshot: snapshot,
      post: post,
      postId: post.id,
      sourceUrl: bookmark.sourceUrl,
    );
    await bookmarkRepository.updateBookmark(upgraded);
    return upgraded;
  }

  Future<bool> addBookmarkToGroup({
    required String groupId,
    Bookmark? existingBookmark,
    BookmarkUniqueId? createBookmarkIdentity,
    Future<Bookmark> Function()? createBookmark,
  }) async {
    final group = await groupRepository.getGroup(groupId);
    if (group == null) {
      throw StateError('Bookmark group $groupId does not exist.');
    }
    final (:bookmark, :created) = switch ((
      existingBookmark,
      createBookmarkIdentity,
      createBookmark,
    )) {
      (final bookmark?, _, _) => await _resolveStoredBookmark(bookmark),
      (null, final identity?, final creator?) => await _createBookmark(
        identity,
        creator,
      ),
      _ => throw ArgumentError('A bookmark or creator identity is required.'),
    };
    if (group.bookmarkIds.contains(bookmark.id)) return false;

    try {
      await groupRepository.addBookmarks(groupId, {bookmark.id});
      return true;
    } catch (error, stackTrace) {
      final rollbackErrors = await _restoreMemberships([group]);
      if (created) {
        try {
          await bookmarkRepository.removeBookmark(bookmark);
        } catch (rollbackError) {
          rollbackErrors.add(rollbackError);
        }
      }
      _throwWithRollback(error, stackTrace, rollbackErrors);
    }
  }

  Future<BookmarkGroup> duplicateGroup(String groupId, String name) async {
    final source = await groupRepository.getGroup(groupId);
    if (source == null) {
      throw StateError('Bookmark group $groupId does not exist.');
    }
    final duplicate = await createGroup(name);
    try {
      return await groupRepository.replaceMemberships(
        duplicate.id,
        source.bookmarkIds,
      );
    } catch (error, stackTrace) {
      final rollbackErrors = <Object>[];
      try {
        await groupRepository.deleteGroup(duplicate.id);
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
      _throwWithRollback(error, stackTrace, rollbackErrors);
    }
  }

  Future<int> addBookmarksToGroup(
    Iterable<Bookmark> bookmarks,
    String groupId,
  ) async {
    final group = await groupRepository.getGroup(groupId);
    if (group == null) {
      throw StateError('Bookmark group $groupId does not exist.');
    }
    final stored = {
      for (final b in await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: imageUrlResolver,
      ))
        b.uniqueId: b,
    };
    final created = <Bookmark>[];
    try {
      final ids = <int>{};
      for (final snapshot in bookmarks) {
        final existing = stored[snapshot.uniqueId];
        if (existing != null) {
          ids.add(existing.id);
          continue;
        }
        final resolved = await _createBookmark(
          snapshot.uniqueId,
          () async => (await bookmarkRepository.addBookmarkWithBookmarks([
            snapshot,
          ])).single,
        );
        ids.add(resolved.bookmark.id);
        stored[snapshot.uniqueId] = resolved.bookmark;
        if (resolved.created) created.add(resolved.bookmark);
      }
      final addedIds = ids.difference(group.bookmarkIds);
      if (addedIds.isEmpty) return 0;
      await groupRepository.addBookmarks(groupId, addedIds);
      return addedIds.length;
    } catch (error, stackTrace) {
      final errors = await _restoreMemberships([group]);
      try {
        await bookmarkRepository.removeBookmarks(created);
      } catch (e) {
        errors.add(e);
      }
      _throwWithRollback(error, stackTrace, errors);
    }
  }

  Future<BookmarkGroup> createGroup(String name) async {
    final id = const Uuid().v4().toLowerCase();
    try {
      return await groupRepository.createGroup(name, id: id);
    } catch (error, stackTrace) {
      try {
        if (await groupRepository.getGroup(id) case final committed?) {
          return committed;
        }
      } catch (_) {}
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<BookmarkGroupRemovalResult> removeBookmarksFromGroup(
    Iterable<Bookmark> bookmarks,
    String groupId,
  ) async {
    final groups = await groupRepository.getGroups();
    final target = groups.where((group) => group.id == groupId).firstOrNull;
    if (target == null) {
      throw StateError('Bookmark group $groupId does not exist.');
    }
    final selected = bookmarks.map((b) => b.uniqueId).toSet();
    final selectedById = {
      for (final bookmark in await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: imageUrlResolver,
      ))
        if (selected.contains(bookmark.uniqueId)) bookmark.id: bookmark,
    };
    final affectedIds = target.bookmarkIds.intersection(
      selectedById.keys.toSet(),
    );
    if (affectedIds.isEmpty) {
      return const BookmarkGroupRemovalResult(
        removedCount: 0,
      );
    }

    final otherMembershipIds = <int>{};
    for (final group in groups.where((group) => group.id != groupId)) {
      otherMembershipIds.addAll(group.bookmarkIds);
    }
    final finalMembershipIds = affectedIds.difference(otherMembershipIds);
    final toDelete = finalMembershipIds.map((id) => selectedById[id]!).toList();

    try {
      await groupRepository.removeBookmarks(groupId, affectedIds);
    } catch (error, stackTrace) {
      _throwWithRollback(
        error,
        stackTrace,
        await _restoreMemberships([target]),
      );
    }
    try {
      if (toDelete.isNotEmpty) {
        await bookmarkRepository.removeBookmarks(toDelete);
      }
    } catch (error, stackTrace) {
      final rollbackErrors = await _restoreBookmarks(toDelete);
      rollbackErrors.addAll(await _restoreMemberships([target]));
      _throwWithRollback(error, stackTrace, rollbackErrors);
    }

    return BookmarkGroupRemovalResult(
      removedCount: affectedIds.length,
      groupId: groupId,
      removedBookmarks: List.unmodifiable(
        affectedIds.map((id) => selectedById[id]!),
      ),
      deletedBookmarks: List.unmodifiable(toDelete),
    );
  }

  Future<void> undoRemoval(BookmarkGroupRemovalResult removal) async {
    final groupId = removal.groupId;
    if (groupId == null || removal.removedCount == 0) return;
    final target = await groupRepository.getGroup(groupId);
    if (target == null) throw StateError('The source group no longer exists.');
    final current = await bookmarkRepository.getAllBookmarksOrThrow(
      imageUrlResolver: imageUrlResolver,
    );
    final byIdentity = {for (final b in current) b.uniqueId: b};
    final deleted = removal.deletedBookmarks.map((b) => b.uniqueId).toSet();
    final created = <Bookmark>[];
    final members = <int>{};
    try {
      for (final old in removal.removedBookmarks) {
        final existing = byIdentity[old.uniqueId];
        if (existing != null) {
          members.add(existing.id);
        } else if (deleted.contains(old.uniqueId)) {
          final restored = await _createBookmark(
            old.uniqueId,
            () async => (await bookmarkRepository.addBookmarkWithBookmarks([
              old,
            ])).single,
          );
          if (restored.created) created.add(restored.bookmark);
          members.add(restored.bookmark.id);
        }
      }
      await groupRepository.addBookmarks(groupId, members);
    } catch (error, stack) {
      final errors = await _restoreMemberships([target]);
      try {
        await bookmarkRepository.removeBookmarks(created);
      } catch (e) {
        errors.add(e);
      }
      _throwWithRollback(error, stack, errors);
    }
  }

  Future<void> deleteBookmarks(Iterable<Bookmark> bookmarks) async {
    final bookmarkList = bookmarks.toList();
    if (bookmarkList.isEmpty) return;
    final groups = await groupRepository.getGroups();
    final ids = bookmarkList.map((bookmark) => bookmark.id).toSet();
    final affectedGroups = {
      for (final group in groups)
        if (group.bookmarkIds.any(ids.contains)) group.id: group.bookmarkIds,
    };

    try {
      for (final groupId in affectedGroups.keys) {
        await groupRepository.removeBookmarks(groupId, ids);
      }
      await bookmarkRepository.removeBookmarks(bookmarkList);
    } catch (error, stackTrace) {
      final rollbackErrors = await _restoreBookmarks(bookmarkList);
      rollbackErrors.addAll(
        await _restoreMemberships(
          groups.where((group) => affectedGroups.containsKey(group.id)),
        ),
      );
      _throwWithRollback(
        error,
        stackTrace,
        rollbackErrors,
      );
    }
  }

  Future<BookmarkGroupDeletionPreview> deleteGroup(String groupId) async {
    final state = await load(const BookmarkTarget.defaultGroup());
    final preview = await groupRepository.previewDeleteGroup(groupId);
    try {
      await groupRepository.deleteGroup(groupId);
    } catch (error, stackTrace) {
      BookmarkGroup? remaining;
      try {
        remaining = await groupRepository.getGroup(groupId);
      } catch (_) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (remaining != null) Error.throwWithStackTrace(error, stackTrace);
    }
    final orphanBookmarks = preview.orphanBookmarkIds
        .map((id) => state.bookmarksById[id])
        .nonNulls
        .toList();
    try {
      if (orphanBookmarks.isNotEmpty) {
        await bookmarkRepository.removeBookmarks(orphanBookmarks);
      }
    } catch (error, stackTrace) {
      final rollbackErrors = await _restoreBookmarks(orphanBookmarks);
      try {
        await groupRepository.createGroup(
          preview.group.name,
          id: preview.group.id,
        );
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
      try {
        await groupRepository.replaceMemberships(
          preview.group.id,
          preview.group.bookmarkIds,
        );
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
      try {
        await groupRepository.replaceFolderOrganization(
          state.folders,
          state.groups,
        );
      } catch (e) {
        rollbackErrors.add(e);
      }
      _throwWithRollback(error, stackTrace, rollbackErrors);
    }
    return preview;
  }

  Future<List<Object>> _restoreMemberships(
    Iterable<BookmarkGroup> groups,
  ) async {
    final errors = <Object>[];
    for (final group in groups) {
      try {
        await groupRepository.replaceMemberships(group.id, group.bookmarkIds);
      } catch (error) {
        errors.add(error);
      }
    }
    return errors;
  }

  Future<List<Object>> _restoreBookmarks(
    Iterable<Bookmark> bookmarks,
  ) async {
    final errors = <Object>[];
    for (final bookmark in bookmarks) {
      try {
        await bookmarkRepository.updateBookmark(bookmark);
      } catch (error) {
        errors.add(error);
      }
    }
    return errors;
  }

  Future<({Bookmark bookmark, bool created})> _resolveStoredBookmark(
    Bookmark snapshot,
  ) async {
    final stored = await _findBookmark(snapshot.uniqueId);
    if (stored != null) return (bookmark: stored, created: false);
    return _createBookmark(
      snapshot.uniqueId,
      () async => (await bookmarkRepository.addBookmarkWithBookmarks([
        snapshot,
      ])).single,
    );
  }

  Future<({Bookmark bookmark, bool created})> _createBookmark(
    BookmarkUniqueId identity,
    Future<Bookmark> Function() creator,
  ) async {
    try {
      return (bookmark: await creator(), created: true);
    } catch (error, stackTrace) {
      try {
        if (await _findBookmark(identity) case final committed?) {
          return (bookmark: committed, created: true);
        }
      } catch (_) {}
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<Bookmark?> _findBookmark(BookmarkUniqueId identity) async =>
      (await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: imageUrlResolver,
      )).where((bookmark) => bookmark.uniqueId == identity).firstOrNull;
}

Never _throwWithRollback(
  Object operationError,
  StackTrace operationStackTrace,
  List<Object> rollbackErrors,
) {
  if (rollbackErrors.isNotEmpty) {
    throw BookmarkLibraryRollbackException(
      operationError: operationError,
      rollbackErrors: List.unmodifiable(rollbackErrors),
    );
  }
  Error.throwWithStackTrace(operationError, operationStackTrace);
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class BookmarkFolderDeletionPreview extends Equatable {
  BookmarkFolderDeletionPreview.from(this.snapshot, this.folderId) {
    folderIds = FolderTree(snapshot.folders).subtree(folderId);
    groupIds = {
      for (final g in snapshot.groups)
        if (folderIds.contains(g.folderId)) g.id,
    };
    final outside = {
      for (final g in snapshot.groups)
        if (!groupIds.contains(g.id)) ...g.bookmarkIds,
    };
    orphanBookmarkIds = {
      for (final g in snapshot.groups)
        if (groupIds.contains(g.id)) ...g.bookmarkIds,
    }.difference(outside).intersection(snapshot.bookmarksById.keys.toSet());
  }
  final BookmarkLibraryState snapshot;
  final String folderId;
  late final Set<String> folderIds;
  late final Set<String> groupIds;
  late final Set<int> orphanBookmarkIds;
  @override
  List<Object?> get props => [snapshot, folderId];
}

class BookmarkFolderChangedException implements Exception {
  const BookmarkFolderChangedException(this.preview);
  final BookmarkFolderDeletionPreview preview;
}
