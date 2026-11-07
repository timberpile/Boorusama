import 'package:uuid/uuid.dart';

import '../../../groups/folder_tree.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_group_tree.dart';

/// Pure compatibility planning shared by migration and transfer. A folder UUID
/// collision is mapped deterministically and the complete map is persisted by
/// the caller before any hierarchy row is written.
final class BookmarkHierarchyConversion {
  BookmarkHierarchyConversion._(this.groups, this.folderIdMapping);

  factory BookmarkHierarchyConversion.convert({
    required List<BookmarkGroup> groups,
    required List<CollectionFolder> folders,
    Map<String, String>? folderIdMapping,
  }) {
    final legacy = FolderTree(folders);
    legacy.validatePlacements(
      groups.map(
        (group) => FolderPlacement(
          itemId: group.id,
          folderId: group.folderId,
          position: group.position,
        ),
      ),
    );
    if (groups.any(
      (group) =>
          group.parentGroupId != null ||
          (group.isDefault &&
              (group.folderId != null || group.name != 'Default')),
    )) {
      throw const FormatException('Mixed Bookmark organization shapes');
    }
    final groupIds = {for (final group in groups) group.id};
    final occupied = {defaultBookmarkGroupId, ...groupIds};
    final folderIds = legacy.byId.keys.toSet();
    final mapping = <String, String>{};
    // Reserve non-colliding input IDs before assigning replacements so a
    // replacement can never steal a later empty folder's identity.
    occupied.addAll(folderIds.where((id) => !occupied.contains(id)).toList());
    if (folderIdMapping != null &&
        (folderIdMapping.length != folderIds.length ||
            !folderIds.containsAll(folderIdMapping.keys))) {
      throw const FormatException('Incomplete hierarchy collision map');
    }
    for (final id in folderIds.toList()..sort()) {
      final collides = id == defaultBookmarkGroupId || groupIds.contains(id);
      var target = id;
      if (folderIdMapping != null) {
        target = folderIdMapping[id]!;
        if (!Uuid.isValidUUID(fromString: target) ||
            target != target.toLowerCase() ||
            (!collides && target != id) ||
            (collides && occupied.contains(target))) {
          throw const FormatException('Invalid hierarchy collision map');
        }
      } else if (collides) {
        var salt = 0;
        do {
          target = const Uuid().v5(
            Namespace.url.value,
            'boorusama/bookmark-hierarchy/folder/$id/${salt++}',
          );
        } while (occupied.contains(target));
      }
      occupied.add(target);
      mapping[id] = target;
    }
    final converted = <BookmarkGroup>[
      for (final group in groups)
        BookmarkGroup(
          id: group.id,
          name: group.name,
          bookmarkIds: group.bookmarkIds,
          addedAt: group.addedAt,
          position: group.position,
          parentGroupId: mapping[group.folderId],
        ),
      for (final folder in folders)
        BookmarkGroup(
          id: mapping[folder.id]!,
          name: folder.name,
          bookmarkIds: const {},
          position: folder.position,
          parentGroupId: mapping[folder.parentId],
        ),
    ];
    BookmarkGroupTree(converted);
    return BookmarkHierarchyConversion._(
      List.unmodifiable(converted),
      Map.unmodifiable(mapping),
    );
  }

  final List<BookmarkGroup> groups;
  final Map<String, String> folderIdMapping;
}
