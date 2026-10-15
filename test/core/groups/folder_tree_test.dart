import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root = CollectionFolder(id: 'root', name: 'Cookie');
  const child = CollectionFolder(
    id: 'child',
    name: 'Artists',
    parentId: 'root',
  );
  const grandchild = CollectionFolder(
    id: 'grandchild',
    name: 'Empty',
    parentId: 'child',
  );
  test(
    'moves subtrees once without changing identities or descendant parents',
    () {
      final moved = FolderTree(
        FolderTree([
          root,
          child,
          grandchild,
        ]).move({'child', 'grandchild'}, null),
      );
      expect(moved.byId['child']!.parentId, isNull);
      expect(moved.byId['grandchild']!.parentId, 'child');
      expect(moved.subtree('child'), {'child', 'grandchild'});
    },
  );
  test('rejects self and descendant destinations before changing the tree', () {
    final tree = FolderTree([root, child, grandchild]);
    for (final destination in ['root', 'child', 'grandchild']) {
      expect(() => tree.move({'root'}, destination), throwsFormatException);
    }
    expect(tree.ancestors('grandchild'), [root, child, grandchild]);
  });
  test(
    'sibling names collide case insensitively but different branches coexist',
    () {
      expect(
        () => FolderTree([
          root,
          const CollectionFolder(id: 'other', name: 'cookie'),
        ]),
        throwsFormatException,
      );
      expect(
        FolderTree([
          root,
          const CollectionFolder(id: 'other', name: 'Cookie', parentId: 'root'),
        ]).folders,
        hasLength(2),
      );
    },
  );
  final malformed = [
    (label: 'duplicate IDs', folders: [root, root]),
    (
      label: 'missing parents',
      folders: [const CollectionFolder(id: 'a', name: 'A', parentId: 'absent')],
    ),
    (
      label: 'cycles',
      folders: [
        const CollectionFolder(id: 'a', name: 'A', parentId: 'b'),
        const CollectionFolder(id: 'b', name: 'B', parentId: 'a'),
      ],
    ),
    (
      label: 'empty names',
      folders: [const CollectionFolder(id: 'a', name: ' ')],
    ),
  ];
  for (final c in malformed) {
    test(
      'rejects ${c.label}',
      () => expect(() => FolderTree(c.folders), throwsFormatException),
    );
  }
  test('rejects duplicate item assignments and missing destinations', () {
    final tree = FolderTree([root]);
    expect(
      () => tree.validatePlacements([
        const FolderPlacement(itemId: 'a'),
        const FolderPlacement(itemId: 'a', folderId: 'root'),
      ]),
      throwsFormatException,
    );
    expect(
      () => tree.validatePlacements([
        const FolderPlacement(itemId: 'a', folderId: 'absent'),
      ]),
      throwsFormatException,
    );
  });
  test('traverses deep trees without imposing a depth limit', () {
    final folders = [
      for (var i = 0; i < 1500; i++)
        CollectionFolder(
          id: '$i',
          name: 'Level $i',
          parentId: i == 0 ? null : '${i - 1}',
        ),
    ];
    final tree = FolderTree(folders);
    expect(tree.ancestors('1499'), hasLength(1500));
    expect(tree.subtree('0'), hasLength(1500));
  });
  test(
    'copies only required ancestors with fresh IDs and one unique wrapper',
    () {
      var id = 0;
      final copy = planFolderHierarchyCopy(
        current: [const CollectionFolder(id: 'local', name: 'Imported Groups')],
        incoming: [root, child, grandchild],
        itemFolders: ['child', 'child', null],
        wrapperName: 'Imported Groups',
        newId: () => 'copy-${id++}',
      );
      final tree = FolderTree(copy.folders);
      expect(copy.folderIds.keys, {'root', 'child'});
      expect(tree.byId[copy.wrapperId]!.name, 'Imported Groups (2)');
      expect(
        tree.path(copy.folderIds['child']),
        'Imported Groups (2) / Cookie / Artists',
      );
    },
  );
}
