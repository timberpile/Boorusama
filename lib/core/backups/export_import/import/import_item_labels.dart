import '../../../configs/config/types.dart';
import '../../sources/bookmark_backup_data.dart';
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
    final PinnedSearchBackupData searches => _pinnedSearchNodes(searches),
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
      for (final group in bookmarks.groups) {
        if (group.id case final id?) {
          items[ExportSelectionIds.bookmarkGroup(id)] = ExportItemPresentation(
            label: group.name,
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

List<ExportSelectionNode> _pinnedSearchNodes(PinnedSearchBackupData searches) {
  final recordsById = {
    for (final record in searches.records) record.id: record,
  };
  final organizedIds = <String>{};
  final nodes = <ExportSelectionNode>[
    for (final folder in searches.folders)
      ExportSelectionNode(
        id: ExportSelectionIds.pinnedSearchFolder(folder.id),
        canHaveChildren: true,
        children: [
          for (final id in folder.searchIds)
            if (recordsById.containsKey(id))
              ExportSelectionNode(id: ExportSelectionIds.pinnedSearch(id)),
        ],
      ),
  ];
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
