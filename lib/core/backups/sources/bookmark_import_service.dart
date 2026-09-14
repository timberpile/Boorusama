// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../bookmarks/types.dart';
import '../../posts/post/types.dart';
import 'bookmark_import_plan.dart';

class BookmarkImportResult extends Equatable {
  const BookmarkImportResult({
    required this.totalCount,
    required this.alreadyExistedCount,
    required this.groupCount,
  });

  final int totalCount;
  final int alreadyExistedCount;
  final int groupCount;

  @override
  List<Object?> get props => [totalCount, alreadyExistedCount, groupCount];
}

class BookmarkImportRollbackException implements Exception {
  const BookmarkImportRollbackException({
    required this.importError,
    required this.rollbackErrors,
  });

  final Object importError;
  final List<Object> rollbackErrors;
}

class BookmarkImportService {
  const BookmarkImportService({
    required this.bookmarkRepository,
    required this.groupRepository,
    required this.imageUrlResolver,
  });

  final BookmarkRepository bookmarkRepository;
  final BookmarkGroupRepository groupRepository;
  final ImageUrlResolver Function(int? booruId) imageUrlResolver;

  Future<BookmarkImportResult> apply(BookmarkImportPlan plan) async {
    if (!plan.isResolved) throw StateError('Import conflicts are unresolved.');
    if (plan.groups.any(
      (group) => group.choice == BookmarkGroupConflictChoice.cancel,
    )) {
      throw StateError('A cancelled import cannot be applied.');
    }

    final oldGroups = await groupRepository.getGroups();
    final oldGroupIds = oldGroups.map((group) => group.id).toSet();
    final oldBookmarks = await bookmarkRepository.getAllBookmarksOrThrow(
      imageUrlResolver: imageUrlResolver,
    );
    var addedBookmarks = const <Bookmark>[];
    try {
      if (plan.missingBookmarks.isNotEmpty) {
        addedBookmarks = await bookmarkRepository.addBookmarkWithBookmarks(
          plan.missingBookmarks,
        );
      }
      final localIds = {
        for (final bookmark in [...oldBookmarks, ...addedBookmarks])
          bookmark.uniqueId: bookmark.id,
      };

      for (final imported in plan.groups) {
        final membershipIds = imported.bookmarkIds
            .map((id) => localIds[id])
            .nonNulls
            .toSet();
        final existing = await groupRepository.getGroup(imported.id);
        if (existing == null) {
          await groupRepository.createGroup(imported.name, id: imported.id);
          await groupRepository.replaceMemberships(imported.id, membershipIds);
          continue;
        }
        await groupRepository.renameGroup(imported.id, imported.name);
        final resolvedMemberships = switch (imported.choice) {
          BookmarkGroupConflictChoice.merge => {
            ...existing.bookmarkIds,
            ...membershipIds,
          },
          BookmarkGroupConflictChoice.replace => membershipIds,
          _ => throw StateError('Import conflict is unresolved.'),
        };
        await groupRepository.replaceMemberships(
          imported.id,
          resolvedMemberships,
        );
      }
    } catch (error, stackTrace) {
      final rollbackErrors = await _rollback(
        oldGroups: oldGroups,
        oldGroupIds: oldGroupIds,
        oldBookmarks: oldBookmarks,
        addedBookmarks: addedBookmarks,
      );
      if (rollbackErrors.isNotEmpty) {
        throw BookmarkImportRollbackException(
          importError: error,
          rollbackErrors: List.unmodifiable(rollbackErrors),
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    return BookmarkImportResult(
      totalCount: plan.bookmarks.length,
      alreadyExistedCount: plan.bookmarks.length - plan.missingBookmarks.length,
      groupCount: plan.groups.length,
    );
  }

  Future<List<Object>> _rollback({
    required List<BookmarkGroup> oldGroups,
    required Set<String> oldGroupIds,
    required List<Bookmark> oldBookmarks,
    required List<Bookmark> addedBookmarks,
  }) async {
    final errors = <Object>[];
    try {
      final currentGroups = await groupRepository.getGroups();
      for (final group in currentGroups) {
        if (!oldGroupIds.contains(group.id)) {
          try {
            await groupRepository.deleteGroup(group.id);
          } catch (error) {
            errors.add(error);
          }
        }
      }
    } catch (error) {
      errors.add(error);
    }

    for (final group in oldGroups) {
      try {
        if (await groupRepository.getGroup(group.id) == null) {
          await groupRepository.createGroup(group.name, id: group.id);
        } else {
          await groupRepository.renameGroup(group.id, group.name);
        }
        await groupRepository.replaceMemberships(group.id, group.bookmarkIds);
      } catch (error) {
        errors.add(error);
      }
    }
    final bookmarksToRemove = {
      for (final bookmark in addedBookmarks) bookmark.id: bookmark,
    };
    try {
      final oldIdentities = oldBookmarks
          .map((bookmark) => bookmark.uniqueId)
          .toSet();
      final currentBookmarks = await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: imageUrlResolver,
      );
      for (final bookmark in currentBookmarks.where(
        (bookmark) => !oldIdentities.contains(bookmark.uniqueId),
      )) {
        bookmarksToRemove[bookmark.id] = bookmark;
      }
    } catch (error) {
      errors.add(error);
    }
    if (bookmarksToRemove.isNotEmpty) {
      try {
        await bookmarkRepository.removeBookmarks(bookmarksToRemove.values);
      } catch (error) {
        errors.add(error);
      }
    }
    return errors;
  }
}
