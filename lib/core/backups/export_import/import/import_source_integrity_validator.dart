import '../../../configs/config/types.dart';
import '../../../groups/folder_tree.dart';
import '../../../bookmarks/types.dart';
import '../sources/export_selection_ids.dart';
import '../../sources/bookmark_backup_data.dart';
import '../../sources/topic_feed_backup_data.dart';
import '../../sources/following_topic_backup_data.dart';
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
    final validatedData = data is BookmarkBackupData
        ? data.asHierarchy()
        : data;
    final issues = <ImportPlanIssue>[];
    if (packageSchemaVersion > supportedSchemaVersion) {
      issues.add(
        ImportPlanIssue(
          code: 'unsupported_source_version',
          sourceId: sourceId,
        ),
      );
    }

    final itemIds = importedItemIds(validatedData);
    final selectableItemIds = {
      ...itemIds,
      if (validatedData is BookmarkBackupData) ...[
        'ungrouped',
        for (final group in validatedData.groups)
          if (group.id != null) 'group-direct:${group.id}',
        for (final id in validatedData.legacyFolderGroupIds.keys)
          'group-folder:$id',
        for (final f in validatedData.folders) 'group-folder:${f.id}',
      ],
      if (validatedData is FollowingTopicBackupData) 'home',
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
      if (validatedData case final BookmarkBackupData bookmarks) {
        if (bookmarks.groups.every((group) => group.id != null)) {
          final tree = BookmarkGroupTree([
            for (final group in bookmarks.groups)
              BookmarkGroup(
                id: group.id!,
                name: group.name,
                bookmarkIds: group.bookmarkIds.toSet(),
                parentGroupId: group.parentGroupId,
                position: group.position,
              ),
          ]);
          final selected = <String>{};
          for (final key in selection.childIds) {
            final direct = ExportSelectionIds.bookmarkGroupDirectId(key);
            if (direct != null) {
              selected.add(direct);
              continue;
            }
            final id =
                ExportSelectionIds.bookmarkGroupId(key) ??
                bookmarks
                    .legacyFolderGroupIds[ExportSelectionIds.bookmarkFolderId(
                  key,
                )];
            if (id != null) selected.addAll(tree.subtreeIds(id));
          }
          allowedIds.addAll(selected.map((id) => 'group:$id'));
          for (final id in selected) {
            for (final ancestor in tree.ancestors(id)) {
              if (ancestor.bookmarkIds.isEmpty)
                allowedIds.add('group:${ancestor.id}');
            }
          }
        }
      }
      if (validatedData case final FollowingTopicBackupData searches) {
        final selectedFolderIds = selection.childIds
            .where((id) => id.startsWith('folder:'))
            .map((id) => id.substring(7))
            .toSet();
        final tree = FolderTree([
          for (final f in searches.folders)
            CollectionFolder(
              id: f.id,
              name: f.name,
              parentId: f.parentId,
              position: f.position,
            ),
        ]);
        final descendantIds = {
          for (final id in selectedFolderIds) ...tree.subtree(id),
        };
        for (final id in descendantIds) {
          allowedIds.addAll(tree.ancestors(id).map((f) => 'folder:${f.id}'));
        }
        for (final folder in searches.folders) {
          if (descendantIds.contains(folder.id)) {
            allowedIds.addAll(folder.searchIds.map((id) => 'search:$id'));
          }
          if (folder.searchIds.any(
            (id) => selection.childIds.contains('search:$id'),
          )) {
            allowedIds.addAll([
              for (final ancestor in tree.ancestors(folder.id))
                'folder:${ancestor.id}',
            ]);
          }
        }
        if (selection.childIds.contains('home')) {
          allowedIds.addAll(
            searches.homeSearchIds.map((id) => 'search:$id'),
          );
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

    if (validatedData case final List<BooruConfig> profiles) {
      final seenIds = <String>{};
      final duplicateIds = <String>{};
      for (final profile in profiles) {
        if (!seenIds.add(profile.id)) duplicateIds.add(profile.id);
      }
      for (final id in duplicateIds) {
        issues.add(
          ImportPlanIssue(
            code: 'duplicate_profile_id',
            sourceId: sourceId,
            itemId: 'profile:$id',
          ),
        );
      }
    }
    if (validatedData case final BookmarkBackupData bookmarks) {
      final bookmarkIds = bookmarks.records.map((record) => record.id).toSet();
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
    if (bookmarks.records.any(
      (bookmark) => !bookmarks.groups.any(
        (group) => group.bookmarkIds.contains(bookmark.id),
      ),
    ))
      'ungrouped',
    for (final group in bookmarks.groups)
      if (group.id case final id?) 'group:$id',
  },
  final FollowingTopicBackupData searches => {
    for (final folder in searches.folders) 'folder:${folder.id}',
    for (final record in searches.records) 'search:${record.id}',
  },
  final TopicFeedBackupData feeds => {
    for (final feed in feeds.feeds) 'feed:${feed.id}',
  },
  _ => const <String>{},
};
