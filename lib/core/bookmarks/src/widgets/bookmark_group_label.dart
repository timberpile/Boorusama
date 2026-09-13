import '../types/bookmark_group.dart';

Map<String, String> bookmarkGroupLabels(Iterable<BookmarkGroup> groups) {
  final groupList = groups.toList();
  final counts = <String, int>{};
  for (final group in groupList) {
    counts.update(group.name, (count) => count + 1, ifAbsent: () => 1);
  }
  return {
    for (final group in groupList)
      group.id: counts[group.name] == 1
          ? group.name
          : '${group.name} · ${group.id.substring(0, 8)}',
  };
}

String bookmarkGroupConflictLabel(String name, String id) =>
    '$name · ${id.substring(0, 8)}';
