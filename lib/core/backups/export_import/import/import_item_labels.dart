import 'package:i18n/i18n.dart';

import '../../../configs/config/types.dart';
import '../../sources/bookmark_backup_data.dart';
import '../../../groups/folder_tree.dart';
import '../../sources/topic_feed_backup_data.dart';
import '../../sources/following_topic_backup_data.dart';
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
      ...bookmarkExportNodes(bookmarks),
    ],
    final FollowingTopicBackupData searches => followingTopicExportNodes(
      searches,
    ),
    final TopicFeedBackupData feeds => [
      for (final feed in feeds.feeds)
        ExportSelectionNode(id: ExportSelectionIds.topicFeed(feed.id)),
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
      _addBookmarkPresentations(bookmarks, items);
    case final FollowingTopicBackupData searches:
      for (final folder in searches.folders) {
        items[ExportSelectionIds.followingTopicFolder(folder.id)] =
            ExportItemPresentation(label: folder.name);
      }
      for (final search in searches.records) {
        items[ExportSelectionIds.followingTopic(
          search.id,
        )] = ExportItemPresentation(
          label: switch (search.name?.trim()) {
            final name? when name.isNotEmpty => name,
            _ => search.query,
          },
          trailingLabel: search.profile.name,
        );
      }
    case final TopicFeedBackupData feeds:
      for (final feed in feeds.feeds) {
        items[ExportSelectionIds.topicFeed(
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

List<ExportSelectionNode> followingTopicExportNodes(
  FollowingTopicBackupData searches,
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
              ExportSelectionNode(id: ExportSelectionIds.followingTopic(id)),
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
        id: ExportSelectionIds.followingTopicHome,
        canHaveChildren: true,
        children: [
          for (final id in homeIds)
            ExportSelectionNode(id: ExportSelectionIds.followingTopic(id)),
        ],
      ),
    );
  }
  nodes.addAll([
    for (final record in searches.records)
      if (!organizedIds.contains(record.id))
        ExportSelectionNode(
          id: ExportSelectionIds.followingTopic(record.id),
        ),
  ]);
  return nodes;
}

bool _hasUngroupedBookmarks(BookmarkBackupData data) {
  final groupedIds = {
    for (final group in data.groups) ...group.bookmarkIds,
  };
  return data.records.any((record) => !groupedIds.contains(record.id));
}

List<ExportSelectionNode> bookmarkExportNodes(BookmarkBackupData data) {
  if (_hasLegacyGroupIds(data)) return _legacyBookmarkExportNodes(data);

  final groups = normalizeBookmarkBackupGroups(data.groups, data.folders);
  final childrenByParentId = <String?, List<BookmarkGroupBackup>>{};
  for (final group in groups) {
    childrenByParentId.putIfAbsent(group.parentGroupId, () => []).add(group);
  }
  for (final siblings in childrenByParentId.values) {
    siblings.sort((a, b) {
      final positionOrder = a.position.compareTo(b.position);
      return positionOrder != 0 ? positionOrder : a.id!.compareTo(b.id!);
    });
  }

  // Build in preorder, then construct bottom-up so deeply nested hierarchies
  // do not consume the Dart call stack.
  final ordered = <BookmarkGroupBackup>[];
  final pending = (childrenByParentId[null] ?? const <BookmarkGroupBackup>[])
      .reversed
      .toList();
  while (pending.isNotEmpty) {
    final group = pending.removeLast();
    ordered.add(group);
    pending.addAll(
      (childrenByParentId[group.id] ?? const <BookmarkGroupBackup>[]).reversed,
    );
  }

  final nodesById = <String, ExportSelectionNode>{};
  for (final group in ordered.reversed) {
    final children = [
      for (final child in childrenByParentId[group.id] ?? const [])
        nodesById[child.id!]!,
    ];
    nodesById[group.id!] = ExportSelectionNode(
      id: ExportSelectionIds.bookmarkGroup(group.id!),
      directSelectionId: ExportSelectionIds.bookmarkGroupDirect(group.id!),
      children: children,
    );
  }

  return [
    for (final group
        in childrenByParentId[null] ?? const <BookmarkGroupBackup>[])
      nodesById[group.id!]!,
    if (_hasUngroupedBookmarks(data))
      const ExportSelectionNode(id: ExportSelectionIds.ungroupedBookmarks),
  ];
}

bool _hasLegacyGroupIds(BookmarkBackupData data) =>
    data.groups.any((group) => group.id == null);

List<ExportSelectionNode> _legacyBookmarkExportNodes(
  BookmarkBackupData data,
) => [
  ...buildFolderSelectionNodes(
    folders: data.folders,
    folderPrefix: 'group-folder:',
    items: {
      for (final folder in data.folders)
        folder.id: [
          for (final group in data.groups)
            if (group.folderId == folder.id && group.id != null)
              ExportSelectionNode(
                id: ExportSelectionIds.bookmarkGroup(group.id!),
              ),
        ],
    },
  ),
  for (final group in data.groups)
    if (group.folderId == null && group.id != null)
      ExportSelectionNode(id: ExportSelectionIds.bookmarkGroup(group.id!)),
  if (_hasUngroupedBookmarks(data))
    const ExportSelectionNode(id: ExportSelectionIds.ungroupedBookmarks),
];

void _addBookmarkPresentations(
  BookmarkBackupData data,
  Map<String, ExportItemPresentation> items,
) {
  if (_hasLegacyGroupIds(data)) {
    for (final folder in data.folders) {
      items['group-folder:${folder.id}'] = ExportItemPresentation(
        label: folder.name,
      );
    }
    final tree = FolderTree(data.folders);
    for (final group in data.groups) {
      if (group.id == null) continue;
      items[ExportSelectionIds.bookmarkGroup(
        group.id!,
      )] = ExportItemPresentation(
        label: group.isDefault
            ? Translations().bookmark.groups.default_group
            : group.folderId == null
            ? group.name
            : '${tree.path(group.folderId)} / ${group.name}',
      );
    }
    return;
  }

  for (final group in normalizeBookmarkBackupGroups(
    data.groups,
    data.folders,
  )) {
    final id = group.id!;
    items[ExportSelectionIds.bookmarkGroup(id)] = ExportItemPresentation(
      label: group.isDefault
          ? Translations().bookmark.groups.default_group
          : group.name,
    );
  }
}

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
