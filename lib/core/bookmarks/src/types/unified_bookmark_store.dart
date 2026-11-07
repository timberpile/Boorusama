import 'bookmark.dart';

/// The shared payload/ID authority for Posts, Groups and Related families.
/// Transfer IDs must be remapped before writing reserved local slots.
abstract interface class UnifiedBookmarkStore {
  Future<List<int>> reserveIds(int count);
  Future<List<Bookmark>> readAll();
  Future<Bookmark?> read(int id);
  Future<void> upsert(Bookmark bookmark);
  Future<void> upsertAll(Iterable<Bookmark> bookmarks);
  Future<void> delete(int id);
  Future<void> durableSync();
}
