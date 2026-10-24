import '../../../groups/folder_tree.dart';

/// Matches the displayed, localized name without changing order or identity.
/// This filter knows nothing about post tags, membership, or remote data.
bool bookmarkGroupNameMatches(String displayName, String query) =>
    displayName.toLowerCase().contains(query.trim().toLowerCase());

/// Keep the path to every matching folder or group visible while browsing.
Set<String> bookmarkMatchingFolderIds({
  required Iterable<CollectionFolder> folders,
  required Iterable<String?> matchingGroupFolderIds,
  required String query,
}) {
  final byId = {for (final folder in folders) folder.id: folder};
  final matches = <String>{};
  for (final start in [
    ...folders
        .where((folder) => bookmarkGroupNameMatches(folder.name, query))
        .map((folder) => folder.id),
    ...matchingGroupFolderIds.nonNulls,
  ]) {
    String? id = start;
    while (id != null && matches.add(id)) {
      id = byId[id]?.parentId;
    }
  }
  return matches;
}
