import 'protocol.dart';

/// Source-owned hierarchy facts. Names are deliberately not identity or scope.
final class SyncBookmarkNode {
  SyncBookmarkNode({
    required String source,
    String? parent,
    this.position = 0,
  }) : source = syncUuid(source),
       parent = parent == null ? null : syncUuid(parent) {
    if (position < 0 || position > folderSyncMaxSequence) {
      throw const FormatException('Invalid sync sibling order');
    }
  }
  final String source;
  final String? parent;
  final int position;
}

/// Pure complete-snapshot union for Bookmark publication OR subscription rules.
/// No exclusions, per-child toggles or captured-child list. Recompute after a
/// committed hierarchy change to include future children before emitting changes.
/// This does not allocate local IDs, import data, or infer deletion from absence.
final class BookmarkSyncScope {
  factory BookmarkSyncScope({
    required String publisher,
    required Iterable<SyncBookmarkNode> nodes,
    required Set<String> directRoots,
  }) {
    final id = syncUuid(publisher);
    final byId = <String, SyncBookmarkNode>{};
    for (final node in nodes) {
      if (byId.containsKey(node.source)) {
        throw const FormatException('Duplicate source Group');
      }
      byId[node.source] = node;
      if (byId.length > folderSyncMaxEntries) {
        throw const FormatException('Sync hierarchy exceeds entry limit');
      }
    }
    final roots = Set<String>.of(directRoots);
    if (roots.any((root) => !byId.containsKey(root))) {
      // An incomplete incoming scan must not become an empty deletion plan.
      throw const FormatException('Unknown explicit sync root');
    }
    final children = <String?, List<String>>{};
    for (final node in byId.values) {
      // A directly published child may name an unpublished source parent.
      // Do not invent a local parent or a subscription to that parent.
      final parent = byId.containsKey(node.parent) ? node.parent : null;
      children.putIfAbsent(parent, () => []).add(node.source);
    }
    for (final list in children.values) {
      list.sort((a, b) {
        final order = byId[a]!.position.compareTo(byId[b]!.position);
        return order != 0 ? order : a.compareTo(b);
      });
    }
    final pending = <(String, int)>[
      for (final root in children[null] ?? const <String>[]) (root, 0),
    ];
    final counts = <String, int>{};
    while (pending.isNotEmpty) {
      final (source, inherited) = pending.removeLast();
      final count = inherited + (roots.contains(source) ? 1 : 0);
      counts[source] = count;
      for (final child in children[source] ?? const <String>[]) {
        pending.add((child, count));
      }
    }
    if (counts.length != byId.length) {
      throw const FormatException('Source Group hierarchy cycle');
    }
    return BookmarkSyncScope._(
      publisher: id,
      nodes: byId,
      directRoots: roots,
      children: children,
      counts: counts,
    );
  }
  BookmarkSyncScope._({
    required this.publisher,
    required Map<String, SyncBookmarkNode> nodes,
    required Set<String> directRoots,
    required Map<String?, List<String>> children,
    required Map<String, int> counts,
  }) : nodes = Map.unmodifiable(nodes),
       directRoots = Set.unmodifiable(directRoots),
       _children = Map.unmodifiable(
         children.map(
           (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
         ),
       ),
       _counts = Map.unmodifiable(counts),
       covered = Set.unmodifiable(
         counts.entries
             .where((entry) => entry.value > 0)
             .map((entry) => entry.key),
       );

  final String publisher;
  final Map<String, SyncBookmarkNode> nodes;

  /// Device-root links, not duplicate persisted Groups. A nested direct root
  /// remains here while sharing its canonical identity with its parent's child.
  final Set<String> directRoots;
  final Set<String> covered;
  final Map<String?, List<String>> _children;
  final Map<String, int> _counts;

  SyncCollectionId identityFor(String source) {
    if (!nodes.containsKey(source)) {
      throw const FormatException('Unknown Group');
    }
    return SyncCollectionId(
      publisher: publisher,
      kind: 'bookmarks',
      source: source,
    );
  }

  List<String> childrenOf(String source) {
    if (!nodes.containsKey(source)) {
      throw const FormatException('Unknown Group');
    }
    return _children[source] ?? const [];
  }

  /// Compute reasons on demand, avoiding an O(nodes * roots) persisted matrix.
  Set<String> reasonsFor(String source) {
    if (!nodes.containsKey(source)) {
      throw const FormatException('Unknown Group');
    }
    final reasons = <String>{};
    String? current = source;
    while (current != null && nodes.containsKey(current)) {
      if (directRoots.contains(current)) reasons.add(current);
      current = nodes[current]!.parent;
    }
    return Set.unmodifiable(reasons);
  }

  /// Confirmation preview for an explicit user action on this committed graph.
  /// It returns SOURCE IDs only. The transaction must map them to owned mirrors
  /// and preserve every outside membership before deleting any record.
  Set<String> uncoveredAfterUnsubscribe(String source) {
    if (!directRoots.contains(source)) {
      throw StateError('Inherited-only Groups cannot be unsubscribed');
    }
    final uncovered = <String>{};
    final pending = [source];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (_counts[current] == 1) uncovered.add(current);
      pending.addAll(_children[current] ?? const []);
    }
    return Set.unmodifiable(uncovered);
  }
}
