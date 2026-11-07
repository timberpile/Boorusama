import 'bookmark_group.dart';

/// One immutable adjacency index per hierarchy snapshot. Traversal is iterative
/// and visits only the requested branch; descendant unions are not precomputed.
final class BookmarkGroupTree {
  factory BookmarkGroupTree(Iterable<BookmarkGroup> groups) {
    final byId = <String, BookmarkGroup>{};
    final children = <String?, List<String>>{};
    for (final group in groups) {
      if (group.id.trim().isEmpty ||
          byId.containsKey(group.id) ||
          group.name.trim().isEmpty ||
          group.name != group.name.trim() ||
          group.position < 0 ||
          (group.isDefault && group.parentGroupId != null)) {
        throw ArgumentError('Invalid Bookmark Group identity or placement');
      }
      byId[group.id] = group;
      children.putIfAbsent(group.parentGroupId, () => []).add(group.id);
    }
    for (final group in byId.values) {
      if (group.parentGroupId != null &&
          !byId.containsKey(group.parentGroupId)) {
        throw ArgumentError('Missing parent Bookmark Group');
      }
    }
    final complete = <String>{};
    for (final group in byId.values) {
      final path = <String>{};
      String? id = group.id;
      while (id != null && !complete.contains(id)) {
        if (!path.add(id)) throw ArgumentError('Bookmark Group cycle');
        id = byId[id]!.parentGroupId;
      }
      complete.addAll(path);
    }
    for (final ids in children.values) {
      ids.sort((a, b) {
        final position = byId[a]!.position.compareTo(byId[b]!.position);
        return position != 0 ? position : a.compareTo(b);
      });
    }
    return BookmarkGroupTree._(
      Map.unmodifiable(byId),
      Map.unmodifiable({
        for (final entry in children.entries)
          entry.key: List<String>.unmodifiable(entry.value),
      }),
    );
  }

  const BookmarkGroupTree._(this.groupsById, this.childrenByParentId);
  final Map<String, BookmarkGroup> groupsById;
  final Map<String?, List<String>> childrenByParentId;

  List<BookmarkGroup> childrenOf(String? parentId) => List.unmodifiable([
    for (final id in childrenByParentId[parentId] ?? const <String>[])
      groupsById[id]!,
  ]);

  List<BookmarkGroup> ancestors(String groupId) {
    final result = <BookmarkGroup>[];
    var id = groupsById[groupId]?.parentGroupId;
    while (id != null) {
      final group = groupsById[id]!;
      result.add(group);
      id = group.parentGroupId;
    }
    return List.unmodifiable(result.reversed);
  }

  Set<String> subtreeIds(String groupId) {
    if (!groupsById.containsKey(groupId)) return const {};
    final result = <String>{};
    final pending = [groupId];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      result.add(id);
      pending.addAll(childrenByParentId[id] ?? const <String>[]);
    }
    return Set.unmodifiable(result);
  }
}
