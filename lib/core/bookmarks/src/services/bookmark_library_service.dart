// Package imports:
import 'package:equatable/equatable.dart';

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

  Future<bool> addBookmarkToGroup({
    required String groupId,
    Bookmark? existingBookmark,
    Future<Bookmark> Function()? createBookmark,
  }) async {
    final bookmark = switch (existingBookmark) {
      final bookmark? => bookmark,
      null when createBookmark != null => await createBookmark(),
      _ => throw ArgumentError('A bookmark or creator is required.'),
    };
    final created = existingBookmark == null;
    final group = await groupRepository.getGroup(groupId);
    if (group == null) {
      if (created) await bookmarkRepository.removeBookmark(bookmark);
      throw StateError('Bookmark group $groupId does not exist.');
    }
    if (group.bookmarkIds.contains(bookmark.id)) return false;

    try {
      await groupRepository.addBookmarks(groupId, {bookmark.id});
      return true;
    } catch (_) {
      if (created) await bookmarkRepository.removeBookmark(bookmark);
      rethrow;
    }
  }

  Future<BookmarkGroup> duplicateGroup(String groupId, String name) async {
    final source = await groupRepository.getGroup(groupId);
    if (source == null) {
      throw StateError('Bookmark group $groupId does not exist.');
    }
    final duplicate = await groupRepository.createGroup(name);
    try {
      return await groupRepository.replaceMemberships(
        duplicate.id,
        source.bookmarkIds,
      );
    } catch (_) {
      await groupRepository.deleteGroup(duplicate.id);
      rethrow;
    }
  }

  Future<void> moveBookmarkToUngrouped(Bookmark bookmark) async {
    final affectedGroups = (await groupRepository.getGroups())
        .where((group) => group.bookmarkIds.contains(bookmark.id))
        .toList();
    try {
      await groupRepository.removeBookmarkFromAllGroups(bookmark.id);
    } catch (_) {
      await _restoreMemberships(affectedGroups);
      rethrow;
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

    await groupRepository.removeBookmarks(groupId, affectedIds);
    try {
      if (toDelete.isNotEmpty) {
        await bookmarkRepository.removeBookmarks(toDelete);
      }
    } catch (_) {
      await groupRepository.addBookmarks(groupId, affectedIds);
      rethrow;
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
    } catch (_) {
      await _restoreMemberships(
        groups.where((group) => affectedGroups.containsKey(group.id)),
      );
      rethrow;
    }
    await _clearCaches(bookmarkList);
  }

  Future<BookmarkGroupDeletionPreview> deleteGroup(String groupId) async {
    final state = await load(const BookmarkTarget.ungrouped());
    final preview = await groupRepository.deleteGroup(groupId);
    final orphanBookmarks = preview.orphanBookmarkIds
        .map((id) => state.bookmarksById[id])
        .nonNulls
        .toList();
    try {
      if (orphanBookmarks.isNotEmpty) {
        await bookmarkRepository.removeBookmarks(orphanBookmarks);
      }
    } catch (_) {
      await groupRepository.createGroup(
        preview.group.name,
        id: preview.group.id,
      );
      await groupRepository.replaceMemberships(
        preview.group.id,
        preview.group.bookmarkIds,
      );
      rethrow;
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

  Future<void> _restoreMemberships(Iterable<BookmarkGroup> groups) async {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final group in groups) {
      try {
        await groupRepository.replaceMemberships(group.id, group.bookmarkIds);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
