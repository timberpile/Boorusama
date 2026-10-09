import 'bookmark_group.dart';
import '../../../groups/folder_tree.dart';

abstract interface class BookmarkGroupRepository {
  Future<List<BookmarkGroup>> getGroups();

  Future<BookmarkGroup?> getGroup(String id);

  Future<BookmarkGroup> createGroup(String name, {String? id});

  Future<BookmarkGroup> duplicateGroup(String id, {String? name});

  Future<BookmarkGroup> renameGroup(String id, String name);

  Future<BookmarkGroup> replaceMemberships(String id, Set<int> bookmarkIds);

  Future<BookmarkGroup> addBookmarks(String id, Set<int> bookmarkIds);

  Future<BookmarkGroup> removeBookmarks(String id, Set<int> bookmarkIds);

  Future<void> removeBookmarkFromAllGroups(int bookmarkId);

  Future<BookmarkGroupDeletionPreview> previewDeleteGroup(String id);

  Future<BookmarkGroupDeletionPreview> deleteGroup(String id);

  Future<bool> repair({required Set<int> validBookmarkIds});
}

/// Additional persistence capability; old flat repository implementations remain compatible.
abstract interface class BookmarkFolderRepository {
  Future<List<CollectionFolder>> readFolders();
  Future<void> writeOrganization(
    List<CollectionFolder> folders,
    List<BookmarkGroup> groups,
  );
}

extension BookmarkFolderStorage on BookmarkGroupRepository {
  Future<List<CollectionFolder>> getFolders() async =>
      this is BookmarkFolderRepository
      ? (this as BookmarkFolderRepository).readFolders()
      : [];
  Future<void> replaceFolderOrganization(
    List<CollectionFolder> folders,
    List<BookmarkGroup> groups,
  ) async {
    FolderTree(folders).validatePlacements(
      groups.map(
        (g) => FolderPlacement(
          itemId: g.id,
          folderId: g.folderId,
          position: g.position,
        ),
      ),
    );
    if (this is BookmarkFolderRepository) {
      await (this as BookmarkFolderRepository).writeOrganization(
        folders,
        groups,
      );
    } else if (folders.isNotEmpty || groups.any((g) => g.folderId != null)) {
      throw StateError('Folder persistence unavailable');
    }
  }
}
