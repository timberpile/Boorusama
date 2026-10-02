import '../../../configs/config/types.dart';
import '../../sources/bookmark_backup_data.dart';
import '../../sources/following_feed_backup_data.dart';
import '../../sources/pinned_search_backup_data.dart';
import '../models/export_selection.dart';
import '../models/import_action.dart';
import 'import_plan.dart';

final class ImportSourceIntegrityValidator {
  const ImportSourceIntegrityValidator();

  List<ImportPlanIssue> validate({
    required String sourceId,
    required int packageSchemaVersion,
    required int supportedSchemaVersion,
    required ExportNodeSelection selection,
    required Map<String, ImportAction> itemRecommendations,
    required Object? data,
  }) {
    final issues = <ImportPlanIssue>[];
    if (packageSchemaVersion > supportedSchemaVersion) {
      issues.add(
        ImportPlanIssue(
          code: 'unsupported_source_version',
          sourceId: sourceId,
        ),
      );
    }

    final itemIds = importedItemIds(data);
    final selectableItemIds = {
      ...itemIds,
      if (data is BookmarkBackupData) 'ungrouped',
    };
    if (selection.kind == ExportNodeSelectionKind.explicit) {
      for (final id in selection.childIds.difference(selectableItemIds)) {
        issues.add(
          ImportPlanIssue(
            code: 'unknown_selected_item',
            sourceId: sourceId,
            itemId: id,
          ),
        );
      }
      final allowedIds = {...selection.childIds};
      if (data case final PinnedSearchBackupData searches) {
        final selectedFolderIds = selection.childIds
            .where((id) => id.startsWith('folder:'))
            .map((id) => id.substring(7))
            .toSet();
        for (final folder in searches.folders) {
          if (selectedFolderIds.contains(folder.id)) {
            allowedIds.addAll(folder.searchIds.map((id) => 'search:$id'));
          }
        }
      }
      for (final id in itemIds.difference(allowedIds)) {
        issues.add(
          ImportPlanIssue(
            code: 'unselected_payload_item',
            sourceId: sourceId,
            itemId: id,
          ),
        );
      }
    }
    for (final id in itemRecommendations.keys.toSet().difference(itemIds)) {
      issues.add(
        ImportPlanIssue(
          code: 'unknown_recommended_item',
          sourceId: sourceId,
          itemId: id,
        ),
      );
    }

    if (data case final BookmarkBackupData bookmarks) {
      final bookmarkIds = bookmarks.bookmarks
          .map((bookmark) => bookmark.id)
          .toSet();
      for (final group in bookmarks.groups) {
        if (!bookmarkIds.containsAll(group.bookmarkIds)) {
          issues.add(
            ImportPlanIssue(
              code: 'missing_bookmark_reference',
              sourceId: sourceId,
              itemId: group.id == null ? null : 'group:${group.id}',
            ),
          );
        }
      }
    }
    return List.unmodifiable(issues);
  }
}

Set<String> importedItemIds(Object? data) => switch (data) {
  final List<BooruConfig> profiles => {
    for (final profile in profiles) 'profile:${profile.id}',
  },
  final BookmarkBackupData bookmarks => {
    if (bookmarks.bookmarks.any(
      (bookmark) => !bookmarks.groups.any(
        (group) => group.bookmarkIds.contains(bookmark.id),
      ),
    ))
      'ungrouped',
    for (final group in bookmarks.groups)
      if (group.id case final id?) 'group:$id',
  },
  final PinnedSearchBackupData searches => {
    for (final folder in searches.folders) 'folder:${folder.id}',
    for (final record in searches.records) 'search:${record.id}',
  },
  final FollowingFeedBackupData feeds => {
    for (final feed in feeds.feeds) 'feed:${feed.id}',
  },
  _ => const <String>{},
};
