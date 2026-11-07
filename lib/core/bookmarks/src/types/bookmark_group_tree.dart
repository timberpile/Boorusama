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

  List<BookmarkGroup> selectionRoots(Set<String> selectedIds) {
    if (!groupsById.keys.toSet().containsAll(selectedIds))
      throw ArgumentError('Unknown Group selection');
    final covered = <String, bool>{};
    final result = <BookmarkGroup>[];
    for (final id in selectedIds) {
      final path = <String>[];
      var parent = groupsById[id]!.parentGroupId;
      while (parent != null &&
          !selectedIds.contains(parent) &&
          !covered.containsKey(parent)) {
        path.add(parent);
        parent = groupsById[parent]!.parentGroupId;
      }
      final hasSelectedAncestor =
          parent != null && (selectedIds.contains(parent) || covered[parent]!);
      for (final entry in path) covered[entry] = hasSelectedAncestor;
      if (!hasSelectedAncestor) result.add(groupsById[id]!);
    }
    result.sort((a, b) {
      final order = a.position.compareTo(b.position);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return List.unmodifiable(result);
  }

  /// Preserve surviving descendants when deleting local containers. Only
  /// changed parent/order fields are returned; membership dates stay exact.
  List<BookmarkGroup> promotedChildrenFor(Set<String> removedIds) {
    if (!groupsById.keys.toSet().containsAll(removedIds) ||
        removedIds.contains(defaultBookmarkGroupId)) {
      throw ArgumentError('Invalid Bookmark Group deletion');
    }
    final affected =
        groupsById.values
            .where(
              (group) =>
                  !removedIds.contains(group.id) &&
                  removedIds.contains(group.parentGroupId),
            )
            .toList()
          ..sort((a, b) {
            final order = a.position.compareTo(b.position);
            return order != 0 ? order : a.id.compareTo(b.id);
          });
    final positions = <String?, int>{};
    for (final group in groupsById.values) {
      if (removedIds.contains(group.id) ||
          removedIds.contains(group.parentGroupId))
        continue;
      final next = positions[group.parentGroupId] ?? 0;
      if (group.position >= next)
        positions[group.parentGroupId] = group.position + 1;
    }
    final result = <BookmarkGroup>[];
    final survivingParents = <String, String?>{};
    for (final group in affected) {
      var parent = group.parentGroupId;
      final path = <String>[];
      while (parent != null &&
          removedIds.contains(parent) &&
          !survivingParents.containsKey(parent)) {
        path.add(parent);
        parent = groupsById[parent]!.parentGroupId;
      }
      if (parent != null && survivingParents.containsKey(parent))
        parent = survivingParents[parent];
      for (final id in path) survivingParents[id] = parent;
      final position = positions[parent] ?? 0;
      positions[parent] = position + 1;
      result.add(
        group.copyWith(
          parentGroupId: parent,
          home: parent == null,
          position: position,
        ),
      );
    }
    return List.unmodifiable(result);
  }
}
