import 'bookmark_scope.dart';
import 'catalog.dart';
import 'protocol.dart';

/// Informational partial outcome, never deletion or fallback authorization.
final class SyncPartialReceiveFailure implements Exception {
  SyncPartialReceiveFailure(this.sourceKind, Map<String, Object> failures)
    : failures = Map.unmodifiable(failures);
  final String sourceKind;
  final Map<String, Object> failures;
}

/// A newly received member reveals a global record shared with another unit.
/// The caller enlarges the transaction before any of this unit commits.
final class SyncReceiveCoupling implements Exception {
  SyncReceiveCoupling(Iterable<String> sources)
    : sources = Set.unmodifiable(sources);
  final Set<String> sources;
}

/// Old and new overlap/moves must commit together. Common unpublished ancestors
/// do not connect otherwise independent roots. Shared saved identities connect
/// their owning Bookmark roots so a global record is never half-updated.
List<Set<String>> syncReceiveUnits({
  required SyncCatalog catalog,
  required String kind,
  required Set<String> roots,
  required Iterable<SyncBookmarkNode> priorNodes,
  Map<String, Set<String>> members = const {},
  Set<String> checkpoints = const {},
}) {
  final entries = {
    for (final e in catalog.entries)
      if (e.id.kind == kind) e.id.source: e,
  };
  final old = {for (final node in priorNodes) node.source: node};
  final scope = BookmarkSyncScope(
    publisher: catalog.publisher,
    nodes: [
      for (final e in entries.values)
        if (e.state == SyncPublicationState.active)
          SyncBookmarkNode(
            source: e.id.source,
            parent: e.parent,
            position: e.position,
          ),
    ],
    directRoots: {
      for (final root in roots)
        if (entries[root]?.state == SyncPublicationState.active) root,
    },
  );
  final parent = <String, String>{};
  final sizes = <String, int>{};
  void add(String id) {
    parent.putIfAbsent(id, () => id);
    sizes.putIfAbsent(id, () => 1);
    if (parent.length > miteMiteMaxEntries * 3) {
      throw const FormatException('Receive units exceed bounds');
    }
  }

  String find(String id) {
    var root = id;
    while (parent[root] != root) {
      root = parent[root]!;
    }
    var current = id;
    while (parent[current] != root) {
      final next = parent[current]!;
      parent[current] = root;
      current = next;
    }
    return root;
  }

  void join(String a, String b) {
    var left = find(a);
    var right = find(b);
    if (left == right) return;
    if (sizes[left]! < sizes[right]!) {
      final previous = left;
      left = right;
      right = previous;
    }
    parent[right] = left;
    sizes[left] = sizes[left]! + sizes[right]!;
  }

  ({...roots, ...old.keys, ...scope.covered}).forEach(add);
  for (final id in checkpoints) {
    if (entries[id] != null &&
        entries[id]!.state != SyncPublicationState.active) {
      add(id);
    }
  }
  for (final node in old.values) {
    if (old.containsKey(node.parent)) join(node.source, node.parent!);
  }
  for (final id in scope.covered) {
    final sourceParent = entries[id]!.parent;
    if (scope.covered.contains(sourceParent)) join(id, sourceParent!);
  }
  final firstMember = <String, String>{};
  for (final entry in members.entries) {
    if (!parent.containsKey(entry.key)) continue;
    for (final member in entry.value) {
      final prior = firstMember.putIfAbsent(member, () => entry.key);
      join(prior, entry.key);
    }
  }
  final units = <String, Set<String>>{};
  for (final id in parent.keys) {
    (units[find(id)] ??= {}).add(id);
  }
  final result = [
    for (final unit in units.values)
      Set<String>.unmodifiable(unit.toList()..sort()),
  ]..sort((a, b) => a.first.compareTo(b.first));
  return List.unmodifiable(result);
}
