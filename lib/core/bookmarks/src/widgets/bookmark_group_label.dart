import 'package:flutter/widgets.dart';
import 'package:i18n/i18n.dart';
import '../types/bookmark_group.dart';
import '../../../groups/folder_tree.dart';

Map<String, String> bookmarkGroupLabels(
  Iterable<BookmarkGroup> groups, {
  List<CollectionFolder>? folders,
  String? defaultGroupName,
}) {
  return {
    for (final group in groups)
      group.id: group.isDefault
          ? defaultGroupName ?? group.name
          : folders == null || group.folderId == null
          ? group.name
          : '${FolderTree(folders).path(group.folderId)} / ${group.name}',
  };
}

String bookmarkGroupConflictLabel(String name, String id) => '$name · $id';

extension BookmarkGroupDisplay on BookmarkGroup {
  String displayName(BuildContext context) =>
      isDefault ? context.t.bookmark.groups.default_group : name;
}
