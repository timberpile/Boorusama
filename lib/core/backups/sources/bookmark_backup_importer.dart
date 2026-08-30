// Project imports:
import '../../bookmarks/types.dart';
import '../../posts/post/types.dart';
import 'bookmark_backup_data.dart';
import '../types/types.dart';

Future<BackupOperationResult> importBookmarkBackup({
  required BookmarkBackupData data,
  required BookmarkRepository bookmarkRepository,
  required BookmarkGroupRepository bookmarkGroupRepository,
  required ImageUrlResolver Function(int? booruId) imageUrlResolver,
}) async {
  Future<List<Bookmark>> getBookmarks() =>
      bookmarkRepository.getAllBookmarksOrEmpty(
        imageUrlResolver: imageUrlResolver,
      );

  final currentBookmarks = await getBookmarks();
  final currentBookmarkIds = currentBookmarks
      .map((bookmark) => bookmark.uniqueId)
      .toSet();
  final missingBookmarks = data.bookmarks
      .where((bookmark) => !currentBookmarkIds.contains(bookmark.uniqueId))
      .toList();
  final result = BackupOperationResult(
    totalCount: data.bookmarks.length,
    alreadyExistedCount: data.bookmarks.length - missingBookmarks.length,
  );

  if (missingBookmarks.isNotEmpty) {
    await bookmarkRepository.addBookmarkWithBookmarks(missingBookmarks);
  }

  final localBookmarksByUniqueId = {
    for (final bookmark in await getBookmarks()) bookmark.uniqueId: bookmark,
  };
  final importedBookmarksById = {
    for (final bookmark in data.bookmarks) bookmark.id: bookmark,
  };
  final groupsByName = {
    for (final group in await bookmarkGroupRepository.getGroups())
      _normalizeGroupName(group.name): group,
  };

  for (final importedGroup in data.groups) {
    final normalizedName = _normalizeGroupName(importedGroup.name);
    final group = groupsByName[normalizedName] ??= await bookmarkGroupRepository
        .createGroup(importedGroup.name);

    for (final exportedBookmarkId in importedGroup.bookmarkIds) {
      final importedBookmark = importedBookmarksById[exportedBookmarkId];
      final localBookmark = importedBookmark == null
          ? null
          : localBookmarksByUniqueId[importedBookmark.uniqueId];
      if (localBookmark == null) continue;

      await bookmarkGroupRepository.addBookmarkToGroup(
        bookmarkId: localBookmark.id,
        groupId: group.id,
      );
    }
  }

  return result;
}

String _normalizeGroupName(String name) => name.trim().toLowerCase();
