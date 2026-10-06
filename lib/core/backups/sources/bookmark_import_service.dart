// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../export_import/models/import_action.dart';
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
    final oldGroups = await groupRepository.getGroups();
    final oldGroupIds = oldGroups.map((group) => group.id).toSet();
    final oldBookmarks = await bookmarkRepository.getAllBookmarksOrThrow(
      imageUrlResolver: imageUrlResolver,
    );
    var addedBookmarks = const <Bookmark>[];
    final orphanCandidates = <int>{};
    try {
      if (plan.missingBookmarks.isNotEmpty) {
        addedBookmarks = await bookmarkRepository.addBookmarkWithBookmarks(
          plan.missingBookmarks,
        );
      }
      final localIds = {
        for (final bookmark in [...oldBookmarks, ...addedBookmarks])
          bookmark.transferIdentity: bookmark.id,
      };

      for (final imported in plan.groups) {
        final action = imported.resolvedAction!;
        if (action == ImportAction.skip) continue;
        final membershipIds = imported.bookmarkIds
            .map((id) => localIds[id])
            .nonNulls
            .toSet();
        final existingId = action == ImportAction.mergeIntoTarget
            ? imported.targetId
            : imported.id;
        if (existingId == null) {
          throw StateError('Merge target is unresolved.');
        }
        final existing = await groupRepository.getGroup(existingId);
        if (action == ImportAction.mergeIntoTarget && existing == null) {
          throw StateError('Merge target is unavailable.');
        }
        if (existing == null) {
          final destinationId = imported.destinationId ?? imported.id;
          await groupRepository.createGroup(imported.name, id: destinationId);
          await groupRepository.replaceMemberships(
            destinationId,
            membershipIds,
          );
          continue;
        }
        switch (action) {
          case ImportAction.update:
          case ImportAction.replace:
            orphanCandidates.addAll(
              existing.bookmarkIds.difference(membershipIds),
            );
            if (action == ImportAction.replace) {
              await groupRepository.renameGroup(imported.id, imported.name);
            }
            await groupRepository.replaceMemberships(
              imported.id,
              membershipIds,
            );
          case ImportAction.merge:
            await groupRepository.replaceMemberships(imported.id, {
              ...existing.bookmarkIds,
              ...membershipIds,
            });
          case ImportAction.mergeIntoTarget:
            await groupRepository.replaceMemberships(existingId, {
              ...existing.bookmarkIds,
              ...membershipIds,
            });
          case ImportAction.copy:
            final destinationId = imported.destinationId;
            if (destinationId == null || destinationId == imported.id) {
              throw StateError('Copy identity is unresolved.');
            }
            await groupRepository.createGroup(
              imported.name,
              id: destinationId,
            );
            await groupRepository.replaceMemberships(
              destinationId,
              membershipIds,
            );
          case ImportAction.skip:
          case ImportAction.configureItems:
            throw StateError('Import action cannot be applied to a group.');
        }
      }

      if (orphanCandidates.isNotEmpty) {
        final memberships = {
          for (final group in await groupRepository.getGroups())
            ...group.bookmarkIds,
        };
        final bookmarksById = {
          for (final bookmark in [...oldBookmarks, ...addedBookmarks])
            bookmark.id: bookmark,
        };
        final orphanBookmarks = orphanCandidates
            .difference(memberships)
            .map((id) => bookmarksById[id])
            .nonNulls
            .toList();
        if (orphanBookmarks.isNotEmpty) {
          await bookmarkRepository.removeBookmarks(orphanBookmarks);
        }
      }
    } catch (error, stackTrace) {
      final rollbackErrors = await _rollback(
        oldGroups: oldGroups,
        oldGroupIds: oldGroupIds,
        oldBookmarks: oldBookmarks,
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

    final currentByIdentity = <BookmarkUniqueId, Bookmark>{};
    try {
      final oldIdentities = oldBookmarks
          .map((bookmark) => bookmark.uniqueId)
          .toSet();
      final currentBookmarks = await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: imageUrlResolver,
      );
      final extras = currentBookmarks
          .where((bookmark) => !oldIdentities.contains(bookmark.uniqueId))
          .toList();
      if (extras.isNotEmpty) await bookmarkRepository.removeBookmarks(extras);
      currentByIdentity.addEntries(
        currentBookmarks
            .where((bookmark) => oldIdentities.contains(bookmark.uniqueId))
            .map((bookmark) => MapEntry(bookmark.uniqueId, bookmark)),
      );
      final missing = oldBookmarks
          .where(
            (bookmark) => !currentByIdentity.containsKey(bookmark.uniqueId),
          )
          .toList();
      if (missing.isNotEmpty) {
        final restored = await bookmarkRepository.addBookmarkWithBookmarks(
          missing,
        );
        currentByIdentity.addEntries(
          restored.map((bookmark) => MapEntry(bookmark.uniqueId, bookmark)),
        );
      }
    } catch (error) {
      errors.add(error);
    }
    final restoredIds = {
      for (final bookmark in oldBookmarks)
        bookmark.id: currentByIdentity[bookmark.uniqueId]?.id ?? bookmark.id,
    };
    for (final group in oldGroups) {
      try {
        if (await groupRepository.getGroup(group.id) == null) {
          await groupRepository.createGroup(group.name, id: group.id);
        } else {
          await groupRepository.renameGroup(group.id, group.name);
        }
        await groupRepository.replaceMemberships(group.id, {
          for (final id in group.bookmarkIds) restoredIds[id] ?? id,
        });
      } catch (error) {
        errors.add(error);
      }
    }
    return errors;
  }
}
