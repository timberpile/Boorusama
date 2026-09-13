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
          : '${group.name} · ${_uniqueIdPrefix(group, groupList)}',
  };
}

String _uniqueIdPrefix(BookmarkGroup group, List<BookmarkGroup> groups) {
  final peers = groups.where(
    (other) => other.name == group.name && other.id != group.id,
  );
  var length = group.id.length < 8 ? group.id.length : 8;
  while (length < group.id.length &&
      peers.any(
        (other) => other.id.startsWith(group.id.substring(0, length)),
      )) {
    length++;
  }
  return group.id.substring(0, length);
}

String bookmarkGroupConflictLabel(String name, String id) =>
    '$name · ${id.substring(0, 8)}';
