import 'bookmark_group_repository.dart';
import 'pool_bookmark.dart';

/// Typed entries in the same bookmark organization storage. Post storage and
/// its existing integer IDs remain compatible with older libraries.
abstract interface class PoolBookmarkRepository {
  Future<List<PoolBookmark>> readPoolBookmarks();
  Future<void> writePoolBookmarks(List<PoolBookmark> bookmarks);
}

extension PoolBookmarkStorage on BookmarkGroupRepository {
  Future<List<PoolBookmark>> getPoolBookmarks() async =>
      this is PoolBookmarkRepository
      ? (this as PoolBookmarkRepository).readPoolBookmarks()
      : const [];

  Future<void> replacePoolBookmarks(List<PoolBookmark> bookmarks) async {
    if (this is! PoolBookmarkRepository) {
      if (bookmarks.isNotEmpty) {
        throw StateError('Pool bookmark persistence unavailable');
      }
      return;
    }
    await (this as PoolBookmarkRepository).writePoolBookmarks(bookmarks);
  }
}
