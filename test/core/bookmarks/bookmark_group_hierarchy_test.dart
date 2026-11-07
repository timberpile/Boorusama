import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_tree.dart';
import 'package:test/test.dart';

BookmarkGroup makeGroup(
  String id, {
  String? parent,
  int position = 0,
  String? name,
  Set<int> bookmarks = const {},
}) => BookmarkGroup(
  id: id,
  name: name ?? id,
  parentGroupId: parent,
  position: position,
  bookmarkIds: bookmarks,
);

void main() {
  group('BookmarkGroupTree', () {
    test('indexes roots and ordered direct children deterministically', () {
      final tree = BookmarkGroupTree([
        makeGroup('root-b'),
        makeGroup('z', parent: 'root-a', position: 1),
        makeGroup('b', parent: 'root-a', position: 0),
        makeGroup('a', parent: 'root-a', position: 0),
        makeGroup('root-a'),
      ]);

      expect(tree.groupsById.keys, containsAll(['root-a', 'root-b']));
      expect(tree.childrenByParentId[null], ['root-a', 'root-b']);
      expect(tree.childrenByParentId['root-a'], ['a', 'b', 'z']);
      expect(tree.childrenOf('root-a').map((child) => child.id), [
        'a',
        'b',
        'z',
      ]);
      expect(tree.childrenOf('missing'), isEmpty);
    });

    test('ancestors are root-first and exclude the requested group', () {
      final tree = BookmarkGroupTree([
        makeGroup('root'),
        makeGroup('middle', parent: 'root'),
        makeGroup('leaf', parent: 'middle'),
      ]);

      expect(tree.ancestors('leaf').map((item) => item.id), ['root', 'middle']);
      expect(tree.ancestors('root'), isEmpty);
      expect(tree.ancestors('missing'), isEmpty);
    });

    test('subtreeIds includes self and only descendants', () {
      final tree = BookmarkGroupTree([
        makeGroup('root'),
        makeGroup('child', parent: 'root'),
        makeGroup('grandchild', parent: 'child'),
        makeGroup('sibling'),
      ]);

      expect(tree.subtreeIds('child'), {'child', 'grandchild'});
      expect(tree.subtreeIds('root'), {'root', 'child', 'grandchild'});
      expect(tree.subtreeIds('missing'), isEmpty);
    });

    test('does not merge names, memberships, or empty groups', () {
      final tree = BookmarkGroupTree([
        makeGroup('one', name: 'Same name', bookmarks: {7, 8}),
        makeGroup('two', name: 'Same name', bookmarks: {7}),
        makeGroup('empty', name: 'Same name'),
      ]);

      expect(tree.groupsById.keys, {'one', 'two', 'empty'});
      expect(tree.groupsById['one']!.bookmarkIds, {7, 8});
      expect(tree.groupsById['two']!.bookmarkIds, {7});
      expect(tree.groupsById['empty']!.bookmarkIds, isEmpty);
    });

    test('exposes immutable indexes and child collections', () {
      final tree = BookmarkGroupTree([
        makeGroup('root'),
        makeGroup('child', parent: 'root'),
      ]);

      expect(
        () => tree.groupsById['other'] = makeGroup('other'),
        throwsUnsupportedError,
      );
      expect(
        () => tree.childrenByParentId['root']!.add('other'),
        throwsUnsupportedError,
      );
      expect(
        () => tree.childrenOf('root').clear(),
        throwsUnsupportedError,
      );
      expect(
        () => tree.subtreeIds('root').add('other'),
        throwsUnsupportedError,
      );
    });

    test('rejects invalid identities and parent relationships', () {
      expect(() => BookmarkGroupTree([makeGroup('')]), throwsArgumentError);
      expect(
        () => BookmarkGroupTree([makeGroup('same'), makeGroup('same')]),
        throwsArgumentError,
      );
      expect(
        () => BookmarkGroupTree([makeGroup('child', parent: 'missing')]),
        throwsArgumentError,
      );
      expect(
        () => BookmarkGroupTree([makeGroup('self', parent: 'self')]),
        throwsArgumentError,
      );
      expect(
        () => BookmarkGroupTree([makeGroup('negative', position: -1)]),
        throwsArgumentError,
      );
    });

    test('rejects cycles and a parented Default group', () {
      expect(
        () => BookmarkGroupTree([
          makeGroup('a', parent: 'b'),
          makeGroup('b', parent: 'a'),
        ]),
        throwsArgumentError,
      );
      expect(
        () => BookmarkGroupTree([
          makeGroup(defaultBookmarkGroupId, parent: 'ordinary'),
          makeGroup('ordinary'),
        ]),
        throwsArgumentError,
      );
    });

    test('walks a deeply nested tree without recursive traversal', () {
      const depth = 10000;
      final groups = [
        for (var i = 0; i < depth; i++)
          makeGroup('g$i', parent: i == 0 ? null : 'g${i - 1}'),
      ];
      final tree = BookmarkGroupTree(groups);

      expect(tree.ancestors('g${depth - 1}'), hasLength(depth - 1));
      expect(tree.subtreeIds('g0'), hasLength(depth));
      expect(tree.subtreeIds('g${depth - 1}'), {'g${depth - 1}'});
    });
  });
}
