import 'package:boorusama/core/backups/mitemite/bookmark_scope.dart';
import 'package:boorusama/core/backups/mitemite/catalog.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/backups/mitemite/receive_units.dart';
import 'package:flutter_test/flutter_test.dart';

const publisher = '11111111-1111-4111-8111-111111111111';
String id(int value) =>
    '${value.toString().padLeft(8, '0')}-2222-4222-8222-222222222222';
SyncBookmarkNode node(int source, [int? parent]) => SyncBookmarkNode(
  source: id(source),
  parent: parent == null ? null : id(parent),
);
SyncCatalog catalog(List<SyncBookmarkNode> nodes) => SyncCatalog(
  publisher: publisher,
  sequence: 1,
  name: 'Publisher',
  entries: [
    for (final node in nodes)
      SyncCatalogEntry(
        id: SyncCollectionId(
          publisher: publisher,
          kind: 'bookmarks',
          source: node.source,
        ),
        name: node.source,
        parent: node.parent,
        state: SyncPublicationState.active,
        revision: SyncRevision(
          collection: SyncCollectionId(
            publisher: publisher,
            kind: 'bookmarks',
            source: node.source,
          ),
          revision: 1,
          length: 1,
          sha256: 'a' * 64,
          semanticHash: 'b' * 64,
          schema: 1,
        ),
      ),
  ],
);
void main() {
  List<Set<String>> units(
    List<SyncBookmarkNode> next, {
    List<SyncBookmarkNode> old = const [],
    Set<String>? roots,
    Map<String, Set<String>> members = const {},
  }) => syncReceiveUnits(
    catalog: catalog(next),
    kind: 'bookmarks',
    roots: roots ?? {id(1), id(2)},
    priorNodes: old,
    members: members,
  );
  test(
    'independent roots sharing only an unpublished parent remain independent',
    () {
      expect(units([node(1, 9), node(2, 9)]), [
        {id(1)},
        {id(2)},
      ]);
    },
  );
  test('current/future children and overlapping roots form one unit', () {
    expect(units([node(1), node(2, 1), node(3, 2)]), [
      {id(1), id(2), id(3)},
    ]);
  });
  test('a move connects both old and new owning subtrees', () {
    expect(
      units(
        [node(1), node(2), node(3, 2)],
        old: [node(1), node(2), node(3, 1)],
      ),
      [
        {id(1), id(2), id(3)},
      ],
    );
  });
  test('shared portable memberships connect otherwise independent roots', () {
    expect(
      units(
        [node(1), node(2)],
        old: [node(1), node(2)],
        members: {
          id(1): {'same'},
          id(2): {'same'},
        },
      ),
      [
        {id(1), id(2)},
      ],
    );
  });
  test(
    'missing metadata remains in its old unit without joining a healthy root',
    () {
      expect(units([node(2)], old: [node(1), node(3, 1), node(2)]), [
        {id(1), id(3)},
        {id(2)},
      ]);
    },
  );
  test('deep hierarchy traversal is bounded and does not use recursive stack depth', () {
    final nodes = [
      for (var i = 1; i <= 2000; i++) node(i, i == 1 ? null : i - 1),
    ];
    expect(units(nodes, roots: {id(1)}).single, hasLength(2000));
  });
}
