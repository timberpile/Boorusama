// Package imports:
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

// Project imports:
import '../../../posts/post/types.dart';
import '../types/bookmark.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_group_repository.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_repository.dart';
import '../types/bookmark_target.dart';

typedef BookmarkCacheCleaner = Future<void> Function(Bookmark bookmark);

class BookmarkGroupRemovalResult extends Equatable {
  const BookmarkGroupRemovalResult({
    required this.removedCount,
    required this.movedToNoGroupCount,
  });

  final int removedCount;
  final int movedToNoGroupCount;

  @override
  List<Object?> get props => [removedCount, movedToNoGroupCount];
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
    this.clearBookmarkCache,
  });

  final BookmarkRepository bookmarkRepository;
  final BookmarkGroupRepository groupRepository;
  final ImageUrlResolver Function(int? booruId) imageUrlResolver;
  final BookmarkCacheCleaner? clearBookmarkCache;

  Future<BookmarkLibraryState> load(BookmarkTarget activeTarget) async {
    final bookmarks = await bookmarkRepository.getAllBookmarksOrThrow(
      imageUrlResolver: imageUrlResolver,
    );
    await groupRepository.repair(
      validBookmarkIds: bookmarks.map((bookmark) => bookmark.id).toSet(),
    );
    return BookmarkLibraryState(
      bookmarks: bookmarks,
      groups: await groupRepository.getGroups(),
      activeTarget: activeTarget,
    );
  }

  Future<Bookmark> upgradeBookmarkSnapshot({
    required Bookmark bookmark,
    required UnifiedPost post,
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
      (final bookmark?, _, _) => (bookmark: bookmark, created: false),
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
    final ids = bookmarks.map((bookmark) => bookmark.id).toSet();
    final addedIds = ids.difference(group.bookmarkIds);
    if (addedIds.isEmpty) return 0;
    try {
      await groupRepository.addBookmarks(groupId, addedIds);
      return addedIds.length;
    } catch (error, stackTrace) {
      _throwWithRollback(
        error,
        stackTrace,
        await _restoreMemberships([group]),
      );
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

  Future<void> moveBookmarkToUngrouped(Bookmark bookmark) async {
    final affectedGroups = (await groupRepository.getGroups())
        .where((group) => group.bookmarkIds.contains(bookmark.id))
        .toList();
    try {
      await groupRepository.removeBookmarkFromAllGroups(bookmark.id);
    } catch (error, stackTrace) {
      _throwWithRollback(
        error,
        stackTrace,
        await _restoreMemberships(affectedGroups),
      );
    }
  }

  Future<BookmarkGroupRemovalResult> removeBookmarksFromGroup(
    Iterable<Bookmark> bookmarks,
    String groupId, {
    bool deleteWhenMembershipBecomesEmpty = false,
  }) async {
    final groups = await groupRepository.getGroups();
    final target = groups.where((group) => group.id == groupId).firstOrNull;
    if (target == null) {
      throw StateError('Bookmark group $groupId does not exist.');
    }
    final selectedById = {
      for (final bookmark in bookmarks) bookmark.id: bookmark,
    };
    final affectedIds = target.bookmarkIds.intersection(
      selectedById.keys.toSet(),
    );
    if (affectedIds.isEmpty) {
      return const BookmarkGroupRemovalResult(
        removedCount: 0,
        movedToNoGroupCount: 0,
      );
    }

    final otherMembershipIds = <int>{};
    for (final group in groups.where((group) => group.id != groupId)) {
      otherMembershipIds.addAll(group.bookmarkIds);
    }
    final finalMembershipIds = affectedIds.difference(otherMembershipIds);
    final toDelete = deleteWhenMembershipBecomesEmpty
        ? finalMembershipIds.map((id) => selectedById[id]!).toList()
        : const <Bookmark>[];

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
    await _clearCaches(toDelete);

    return BookmarkGroupRemovalResult(
      removedCount: affectedIds.length,
      movedToNoGroupCount: deleteWhenMembershipBecomesEmpty
          ? 0
          : finalMembershipIds.length,
    );
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
    await _clearCaches(bookmarkList);
  }

  Future<BookmarkGroupDeletionPreview> deleteGroup(String groupId) async {
    final state = await load(const BookmarkTarget.ungrouped());
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
      _throwWithRollback(error, stackTrace, rollbackErrors);
    }
    await _clearCaches(orphanBookmarks);
    return preview;
  }

  Future<void> _clearCaches(Iterable<Bookmark> bookmarks) async {
    if (clearBookmarkCache case final cleaner?) {
      for (final bookmark in bookmarks) {
        try {
          await cleaner(bookmark);
        } catch (_) {}
      }
    }
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
