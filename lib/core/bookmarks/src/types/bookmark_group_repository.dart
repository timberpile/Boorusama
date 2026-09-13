import 'bookmark_group.dart';

abstract interface class BookmarkGroupRepository {
  Future<List<BookmarkGroup>> getGroups();

  Future<BookmarkGroup?> getGroup(String id);

  Future<BookmarkGroup> createGroup(String name, {String? id});

  Future<BookmarkGroup> duplicateGroup(String id);

  Future<BookmarkGroup> renameGroup(String id, String name);

  Future<BookmarkGroup> replaceMemberships(String id, Set<int> bookmarkIds);

  Future<BookmarkGroup> addBookmarks(String id, Set<int> bookmarkIds);

  Future<BookmarkGroup> removeBookmarks(String id, Set<int> bookmarkIds);

  Future<void> removeBookmarkFromAllGroups(int bookmarkId);

  Future<BookmarkGroupDeletionPreview> previewDeleteGroup(String id);

  Future<BookmarkGroupDeletionPreview> deleteGroup(String id);

  Future<bool> repair({required Set<int> validBookmarkIds});
}
