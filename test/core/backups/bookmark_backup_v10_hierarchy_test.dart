import 'dart:convert';

import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bookmarks/pool_bookmark_test_utils.dart';

const root = '11111111-1111-4111-8111-111111111111';
const leaf = '22222222-2222-4222-8222-222222222222';

void main() {
  final codec = BookmarkBackupCodec();
  BookmarkBackupData parse(Map<String, dynamic> value) =>
      codec.parse(decodeData(data: jsonEncode(value)));

  test('v10 writer converts empty legacy folders to nested groups without a folders authority', () {
    final data = BookmarkBackupData.unified(
      records: const [],
      groups: const [
        BookmarkGroupBackup(
          id: leaf,
          name: 'Leaf',
          bookmarkIds: [],
          folderId: root,
        ),
      ],
      folders: const [
        CollectionFolder(id: root, name: 'Empty structural root'),
      ],
    );
    final wire = {
      'version': 10,
      'data': codec.encode(data),
      ...data.extraFields,
    };
    expect(wire.containsKey('folders'), isFalse);
    expect(wire['organizationSchema'], 'nestedGroups');
    final groups = wire['groups']! as List;
    expect(groups, hasLength(2));
    expect(
      groups.singleWhere((g) => (g as Map)['id'] == leaf)['parentGroupId'],
      root,
    );
    expect(groups.every((g) => !(g as Map).containsKey('folderId')), isTrue);
    final restored = parse(wire);
    expect(restored.groups, hasLength(2));
    expect(restored.folders, isEmpty);
    expect(restored.extraFields, data.extraFields);
  });

  test('canonical v10 rejects duplicate direct membership references', () {
    final data = BookmarkBackupData.unified(
      records: [testPoolPost(1).copyWith(id: 0)],
      groups: [
        BookmarkGroupBackup(
          id: root,
          name: 'Root',
          bookmarkIds: const [0],
          addedAt: {0: DateTime.utc(2020)},
        ),
      ],
    );
    final fields = data.extraFields;
    ((fields['groups'] as List).single as Map)['bookmarkIds'] = [0, 0];
    expect(
      () => parse({'version': 10, 'data': codec.encode(data), ...fields}),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });

  test('v10 rejects mixed and unmarked ambiguous organization shapes', () {
    final canonical = <String, dynamic>{
      'version': 10,
      'data': [],
      'organizationSchema': 'nestedGroups',
      'groups': [
        {
          'id': root,
          'name': 'Root',
          'bookmarkIds': [],
          'addedAt': {},
          'position': 0,
          'parentGroupId': null,
        },
      ],
    };
    expect(
      () => parse({...canonical, 'folders': []}),
      throwsA(isA<InvalidBackupFormatException>()),
    );
    expect(
      () => parse({...canonical}..remove('organizationSchema')),
      throwsA(isA<InvalidBackupFormatException>()),
    );
    expect(
      () => parse({...canonical, 'organizationSchema': 'future'}),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });

  test(
    'v10 validates missing parents, cycles and Default placement before import',
    () {
      Map<String, dynamic> row(String id, String? parent) => {
        'id': id,
        'name': 'Group',
        'bookmarkIds': [],
        'addedAt': {},
        'parentGroupId': parent,
        'position': 0,
      };
      for (final rows in [
        [row(leaf, root)],
        [row(root, leaf), row(leaf, root)],
        [row('00000000-0000-0000-0000-000000000000', root), row(root, null)],
      ]) {
        expect(
          () => parse({
            'version': 10,
            'data': [],
            'organizationSchema': 'nestedGroups',
            'groups': rows,
          }),
          throwsA(isA<InvalidBackupFormatException>()),
        );
      }
    },
  );

  test('explicit #155 transitional v10 folder shape remains readable and converts losslessly on export', () {
    final restored = parse({
      'version': 10,
      'data': [],
      'folders': [
        {'id': root, 'name': 'Legacy root', 'parentId': null, 'position': 3},
      ],
      'groups': [
        {
          'id': leaf,
          'name': 'Leaf',
          'bookmarkIds': [],
          'addedAt': {},
          'folderId': root,
          'position': 7,
        },
      ],
    });
    expect(restored.extraFields.containsKey('folders'), isFalse);
    final roundtrip = parse({
      'version': 10,
      'data': codec.encode(restored),
      ...restored.extraFields,
    });
    expect(roundtrip.groups.map((g) => g.id), containsAll([root, leaf]));
  });
}
