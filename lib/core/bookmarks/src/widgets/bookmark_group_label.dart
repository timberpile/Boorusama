import '../types/bookmark_group.dart';
import '../../../groups/folder_tree.dart';

Map<String, String> bookmarkGroupLabels(
  Iterable<BookmarkGroup> groups, {
  List<CollectionFolder>? folders,
}) {
  return {
    for (final group in groups)
      group.id: folders == null || group.folderId == null
          ? group.name
          : '${FolderTree(folders).path(group.folderId)} / ${group.name}',
  };
}

String bookmarkGroupConflictLabel(String name, String id) => '$name · $id';
