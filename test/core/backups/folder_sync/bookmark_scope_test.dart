import 'package:boorusama/core/backups/folder_sync/bookmark_scope.dart';
import 'package:flutter_test/flutter_test.dart';

const publisher = '10000000-0000-4000-8000-000000000001';
const otherPublisher = '10000000-0000-4000-8000-000000000009';
const a = '10000000-0000-4000-8000-000000000002';
const b = '10000000-0000-4000-8000-000000000003';
const c = '10000000-0000-4000-8000-000000000004';
const d = '10000000-0000-4000-8000-000000000005';

SyncBookmarkNode node(String id, {String? parent, int position = 0}) =>
    SyncBookmarkNode(source: id, parent: parent, position: position);

void main() {
  final nodes = [node(a), node(b, parent: a), node(c, parent: a)];

  test(
    'direct child then parent gives one canonical child with two reasons',
    () {
      final scope = BookmarkSyncScope(
        publisher: publisher,
        nodes: nodes,
        directRoots: {a, b},
      );
      expect(scope.covered, {a, b, c});
      expect(scope.directRoots, {a, b});
      expect(scope.reasonsFor(b), {a, b});
      expect(scope.reasonsFor(c), {a});
      expect(scope.childrenOf(a), [b, c]);
      expect(scope.identityFor(b), scope.identityFor(b));
      expect(scope.uncoveredAfterUnsubscribe(a), {a, c});
      expect(scope.uncoveredAfterUnsubscribe(b), isEmpty);
      expect(() => scope.uncoveredAfterUnsubscribe(c), throwsStateError);
    },
  );

  test('future children automatically join every covering root', () {
    final scope = BookmarkSyncScope(
      publisher: publisher,
      nodes: [
        ...nodes,
        node(d, parent: b),
      ],
      directRoots: {a, b},
    );
    expect(scope.reasonsFor(d), {a, b});
    expect(scope.uncoveredAfterUnsubscribe(a), {a, c});
    expect(scope.covered, {a, b, c, d});
  });

  test('reparenting retains direct reason without transient withdrawal', () {
    final before = BookmarkSyncScope(
      publisher: publisher,
      nodes: nodes,
      directRoots: {a, b},
    );
    final after = BookmarkSyncScope(
      publisher: publisher,
      nodes: [
        node(a),
        node(b),
        node(c, parent: a),
      ],
      directRoots: {a, b},
    );
    expect(after.covered, before.covered);
    expect(after.identityFor(b), before.identityFor(b));
    expect(after.reasonsFor(b), {b});
  });

  test('source parent outside published scope is not a local folder', () {
    final scope = BookmarkSyncScope(
      publisher: publisher,
      nodes: [
        node(b, parent: a),
        node(c, parent: b),
      ],
      directRoots: {b},
    );
    expect(scope.covered, {b, c});
    expect(scope.directRoots, {b});
    expect(scope.reasonsFor(c), {b});
  });

  test('publisher identity isolates otherwise identical source UUIDs', () {
    final first = BookmarkSyncScope(
      publisher: publisher,
      nodes: nodes,
      directRoots: {a},
    );
    final second = BookmarkSyncScope(
      publisher: otherPublisher,
      nodes: nodes,
      directRoots: {a},
    );
    expect(first.identityFor(b), isNot(second.identityFor(b)));
  });

  test('duplicate IDs, cycles and unknown roots fail instead of deleting', () {
    for (final broken in [
      [node(a), node(a)],
      [node(a, parent: a)],
      [node(a, parent: b), node(b, parent: a)],
    ]) {
      expect(
        () => BookmarkSyncScope(
          publisher: publisher,
          nodes: broken,
          directRoots: {a},
        ),
        throwsFormatException,
      );
    }
    expect(
      () => BookmarkSyncScope(
        publisher: publisher,
        nodes: nodes,
        directRoots: {d},
      ),
      throwsFormatException,
    );
  });

  test('sibling order is source-owned and snapshots cannot be mutated', () {
    final input = [
      node(a),
      node(b, parent: a, position: 2),
      node(c, parent: a),
    ];
    final roots = {a};
    final scope = BookmarkSyncScope(
      publisher: publisher,
      nodes: input,
      directRoots: roots,
    );
    input.clear();
    roots.clear();
    expect(scope.childrenOf(a), [c, b]);
    expect(scope.covered, {a, b, c});
    expect(() => scope.covered.clear(), throwsUnsupportedError);
    expect(() => scope.directRoots.clear(), throwsUnsupportedError);
  });
}
