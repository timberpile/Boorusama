import 'bookmark_group.dart';

abstract interface class BookmarkGroupRepository {
  Future<List<BookmarkGroup>> getGroups();

  Future<BookmarkGroup> createGroup(String name);

  Future<BookmarkGroup> duplicateGroup(int groupId);

  Future<BookmarkGroup> renameGroup(int groupId, String name);

  Future<BookmarkGroupDeletionPreview> previewDeleteGroup(int groupId);

  Future<Set<int>> deleteGroup(int groupId);

  Future<Map<int, Set<int>>> getMembershipsByBookmark();

  Future<Set<int>> getBookmarkIdsForGroup(int groupId);

  Future<void> addBookmarkToGroup({
    required int bookmarkId,
    required int groupId,
  });

  Future<void> removeBookmarkFromGroup({
    required int bookmarkId,
    required int groupId,
  });

  Future<void> removeBookmarkFromAllGroups(int bookmarkId);

  Future<void> pruneStaleMemberships({required Set<int> bookmarkIds});
}
