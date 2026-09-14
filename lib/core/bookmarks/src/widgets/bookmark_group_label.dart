import '../types/bookmark_group.dart';

Map<String, String> bookmarkGroupLabels(Iterable<BookmarkGroup> groups) {
  return {
    for (final group in groups) group.id: group.name,
  };
}

String bookmarkGroupConflictLabel(String name, String id) => '$name · $id';
