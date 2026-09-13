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
    try {
      if (plan.missingBookmarks.isNotEmpty) {
        await bookmarkRepository.addBookmarkWithBookmarks(
          plan.missingBookmarks,
        );
      }
      final localBookmarks = await bookmarkRepository.getAllBookmarksOrEmpty(
        imageUrlResolver: imageUrlResolver,
      );
      final localIds = {
        for (final bookmark in localBookmarks) bookmark.uniqueId: bookmark.id,
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
    } catch (_) {
      final currentGroups = await groupRepository.getGroups();
      for (final group in currentGroups) {
        if (!oldGroupIds.contains(group.id)) {
          await groupRepository.deleteGroup(group.id);
        }
      }
      for (final group in oldGroups) {
        if (await groupRepository.getGroup(group.id) == null) {
          await groupRepository.createGroup(group.name, id: group.id);
        } else {
          await groupRepository.renameGroup(group.id, group.name);
        }
        await groupRepository.replaceMemberships(group.id, group.bookmarkIds);
      }
      if (plan.missingBookmarks.isNotEmpty) {
        final addedIds = plan.missingBookmarks
            .map((bookmark) => bookmark.uniqueId)
            .toSet();
        final current = await bookmarkRepository.getAllBookmarksOrEmpty(
          imageUrlResolver: imageUrlResolver,
        );
        await bookmarkRepository.removeBookmarks(
          current.where((bookmark) => addedIds.contains(bookmark.uniqueId)),
        );
      }
      rethrow;
    }

    return BookmarkImportResult(
      totalCount: plan.bookmarks.length,
      alreadyExistedCount: plan.bookmarks.length - plan.missingBookmarks.length,
      groupCount: plan.groups.length,
    );
  }
}
