import '../../../groups/folder_tree.dart';
import '../types/bookmark_group.dart';

List<CollectionFolder> bookmarkFoldersByName(
  Iterable<CollectionFolder> folders,
) => folders.toList()
  ..sort((a, b) {
    final order = _compareNames(a.name, b.name);
    return order == 0 ? a.id.compareTo(b.id) : order;
  });

List<BookmarkGroup> bookmarkGroupsByName(Iterable<BookmarkGroup> groups) =>
    groups.toList()..sort((a, b) {
      final order = _compareNames(a.name, b.name);
      return order == 0 ? a.id.compareTo(b.id) : order;
    });

int _compareNames(String a, String b) {
  return a.toLowerCase().compareTo(b.toLowerCase());
}
