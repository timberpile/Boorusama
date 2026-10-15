import 'package:i18n/i18n.dart';
import '../../../configs/config/types.dart';
import '../../sources/bookmark_backup_data.dart';
import '../../../groups/folder_tree.dart';
import '../../sources/following_feed_backup_data.dart';
import '../../sources/pinned_search_backup_data.dart';
import '../models/export_item_presentation.dart';
import '../models/export_selection.dart';
import '../sources/export_selection_ids.dart';

final class ImportItemPresentationResult {
  const ImportItemPresentationResult({
    required this.descriptor,
    required this.presentation,
  });

  final ExportSelectionDescriptor descriptor;
  final ExportSelectionPresentation presentation;

  Map<String, String> get labels => Map.unmodifiable({
    for (final entry in presentation.items.entries)
      entry.key: entry.value.label,
  });
}

ImportItemPresentationResult importItemPresentation(
  String sourceId,
  Object? data,
) {
  final items = <String, ExportItemPresentation>{};
  final children = switch (data) {
    final List<BooruConfig> profiles => [
      for (final profile in profiles)
        ExportSelectionNode(id: ExportSelectionIds.profile(profile.id)),
    ],
    final BookmarkBackupData bookmarks => [
      for (final group in bookmarks.groups)
        if (group.id case final id?)
          ExportSelectionNode(id: ExportSelectionIds.bookmarkGroup(id)),
      if (_hasUngroupedBookmarks(bookmarks))
        const ExportSelectionNode(
          id: ExportSelectionIds.ungroupedBookmarks,
        ),
    ],
    final PinnedSearchBackupData searches => pinnedSearchExportNodes(searches),
    final FollowingFeedBackupData feeds => [
      for (final feed in feeds.feeds)
        ExportSelectionNode(id: ExportSelectionIds.followingFeed(feed.id)),
    ],
    _ => const <ExportSelectionNode>[],
  };

  switch (data) {
    case final List<BooruConfig> profiles:
      for (final profile in profiles) {
        items[ExportSelectionIds.profile(profile.id)] = ExportItemPresentation(
          label: profile.name,
        );
      }
    case final BookmarkBackupData bookmarks:
      for (final f in bookmarks.folders) {
        items['group-folder:${f.id}'] = ExportItemPresentation(label: f.name);
      }
      for (final group in bookmarks.groups) {
        if (group.id case final id?) {
          items[ExportSelectionIds.bookmarkGroup(id)] = ExportItemPresentation(
            label: group.isDefault
                ? Translations().bookmark.groups.default_group
                : group.folderId == null
                ? group.name
                : '${FolderTree(bookmarks.folders).path(group.folderId)} / ${group.name}',
          );
        }
      }
    case final PinnedSearchBackupData searches:
      for (final folder in searches.folders) {
        items[ExportSelectionIds.pinnedSearchFolder(folder.id)] =
            ExportItemPresentation(label: folder.name);
      }
      for (final search in searches.records) {
        items[ExportSelectionIds.pinnedSearch(
          search.id,
        )] = ExportItemPresentation(
          label: switch (search.name?.trim()) {
            final name? when name.isNotEmpty => name,
            _ => search.query,
          },
          trailingLabel: search.profile.name,
        );
      }
    case final FollowingFeedBackupData feeds:
      for (final feed in feeds.feeds) {
        items[ExportSelectionIds.followingFeed(
          feed.id,
        )] = ExportItemPresentation(
          label: feed.name,
          trailingLabel: feed.profile.name,
        );
      }
    default:
      break;
  }

  return ImportItemPresentationResult(
    descriptor: children.isEmpty
        ? ExportSelectionDescriptor.leaf(id: sourceId)
        : ExportSelectionDescriptor.collection(
            id: sourceId,
            children: children,
          ),
    presentation: ExportSelectionPresentation(items: Map.unmodifiable(items)),
  );
}

List<ExportSelectionNode> pinnedSearchExportNodes(
  PinnedSearchBackupData searches,
) {
  final recordsById = {
    for (final record in searches.records) record.id: record,
  };
  final organizedIds = <String>{};
  final nodes = buildFolderSelectionNodes(
    folders: [
      for (final f in searches.folders)
        CollectionFolder(
          id: f.id,
          name: f.name,
          parentId: f.parentId,
          position: f.position,
        ),
    ],
    folderPrefix: 'folder:',
    items: {
      for (final f in searches.folders)
        f.id: [
          for (final id in f.searchIds)
            if (recordsById.containsKey(id))
              ExportSelectionNode(id: ExportSelectionIds.pinnedSearch(id)),
        ],
    },
  );
  organizedIds.addAll(
    searches.folders.expand((folder) => folder.searchIds),
  );
  final homeIds = searches.homeSearchIds
      .where(recordsById.containsKey)
      .toList();
  organizedIds.addAll(homeIds);
  if (homeIds.isNotEmpty) {
    nodes.add(
      ExportSelectionNode(
        id: ExportSelectionIds.pinnedSearchHome,
        canHaveChildren: true,
        children: [
          for (final id in homeIds)
            ExportSelectionNode(id: ExportSelectionIds.pinnedSearch(id)),
        ],
      ),
    );
  }
  nodes.addAll([
    for (final record in searches.records)
      if (!organizedIds.contains(record.id))
        ExportSelectionNode(
          id: ExportSelectionIds.pinnedSearch(record.id),
        ),
  ]);
  return nodes;
}

bool _hasUngroupedBookmarks(BookmarkBackupData data) {
  final groupedIds = {
    for (final group in data.groups) ...group.bookmarkIds,
  };
  return data.bookmarks.any((bookmark) => !groupedIds.contains(bookmark.id));
}

List<ExportSelectionNode> bookmarkExportNodes(BookmarkBackupData data) => [
  ...buildFolderSelectionNodes(
    folders: data.folders,
    folderPrefix: 'group-folder:',
    items: {
      for (final f in data.folders)
        f.id: [
          for (final g in data.groups)
            if (g.folderId == f.id && g.id != null)
              ExportSelectionNode(id: ExportSelectionIds.bookmarkGroup(g.id!)),
        ],
    },
  ),
  for (final g in data.groups)
    if (g.folderId == null && g.id != null)
      ExportSelectionNode(id: ExportSelectionIds.bookmarkGroup(g.id!)),
  if (_hasUngroupedBookmarks(data))
    const ExportSelectionNode(id: ExportSelectionIds.ungroupedBookmarks),
];
List<ExportSelectionNode> buildFolderSelectionNodes({
  required List<CollectionFolder> folders,
  required String folderPrefix,
  required Map<String, List<ExportSelectionNode>> items,
}) {
  final tree = FolderTree(folders);
  final ordered = <CollectionFolder>[];
  final pending = tree.children(null).reversed.toList();
  while (pending.isNotEmpty) {
    final f = pending.removeLast();
    ordered.add(f);
    pending.addAll(tree.children(f.id).reversed);
  }
  final nodes = <String, ExportSelectionNode>{};
  for (final f in ordered.reversed) {
    nodes[f.id] = ExportSelectionNode(
      id: '$folderPrefix${f.id}',
      canHaveChildren: true,
      children: [
        for (final child in tree.children(f.id)) nodes[child.id]!,
        ...?items[f.id],
      ],
    );
  }
  return [for (final f in tree.children(null)) nodes[f.id]!];
}
