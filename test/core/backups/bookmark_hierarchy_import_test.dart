import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_plan.dart';
import 'package:boorusama/core/backups/sources/bookmark_unified_import.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bookmarks/pool_bookmark_test_utils.dart';

const root = '11111111-1111-4111-8111-111111111111';
const leaf = '22222222-2222-4222-8222-222222222222';
const other = '33333333-3333-4333-8333-333333333333';
const wrapper = '44444444-4444-4444-8444-444444444444';
const copiedRoot = '55555555-5555-4555-8555-555555555555';
const copiedLeaf = '66666666-6666-4666-8666-666666666666';

void main() {
  final date = DateTime.utc(2020, 1, 2, 3, 4, 5, 123, 456);
  final record = testPoolPost(1).copyWith(id: 0);
  BookmarkGroupImport group(
    String id, {
    String? parent,
    Set<int> ids = const {},
    ImportAction action = ImportAction.copy,
    String? destination,
  }) => BookmarkGroupImport(
    id: id,
    name: 'Same',
    parentGroupId: parent,
    bookmarkIds: ids,
    addedAt: {for (final id in ids) id: date},
    conflicts: false,
    action: action,
    destinationId: destination,
  );
  BookmarkImportPreparation prepare(
    List<BookmarkGroupImport> groups, {
    bool replace = false,
    List<BookmarkGroup> current = const [],
    List<Bookmark> currentRecords = const [],
  }) => BookmarkImportPreparation.prepare(
    plan: BookmarkImportPlan(records: [record], groups: groups),
    currentRecords: currentRecords,
    currentGroups: current,
    currentFolders: const [],
    normalize: (record, {previous}) => record,
    replace: replace,
    newId: () => wrapper,
  );

  test('full Replace restores supplied parents and independent dates with transfer ID remapping', () {
    final prepared = prepare([
      group(root),
      group(leaf, parent: root, ids: {0}),
    ], replace: true);
    final write = prepared.materialize([100]);
    expect(write.groups.singleWhere((g) => g.id == root).bookmarkIds, isEmpty);
    final child = write.groups.singleWhere((g) => g.id == leaf);
    expect(child.parentGroupId, root);
    expect(child.bookmarkIds, {100});
    expect(child.addedAt, {100: date});
    expect(write.folders, isEmpty);
    expect(write.records.single.id, 100);
  });

  test('copy remaps selected subtree parents together under one ordinary wrapper group', () {
    final prepared = prepare(
      [
        group(root, destination: copiedRoot),
        group(leaf, parent: root, ids: {0}, destination: copiedLeaf),
      ],
      current: [
        BookmarkGroup(id: root, name: 'Existing', bookmarkIds: const {}),
      ],
    );
    expect(
      prepared.groups.singleWhere((g) => g.id == copiedRoot).parentGroupId,
      wrapper,
    );
    expect(
      prepared.groups.singleWhere((g) => g.id == copiedLeaf).parentGroupId,
      copiedRoot,
    );
    expect(
      prepared.groups.singleWhere((g) => g.id == root).parentGroupId,
      isNull,
    );
    expect(
      prepared.groups.singleWhere((g) => g.id == wrapper).bookmarkIds,
      isEmpty,
    );
    expect(prepared.groups.singleWhere((g) => g.id == copiedLeaf).addedAt, {
      prepared.newIds.single: date,
    });
  });

  test(
    'per-group Update remains direct and preserves existing descendant rows',
    () {
      final current = [
        BookmarkGroup(
          id: root,
          name: 'Existing',
          bookmarkIds: {0},
          addedAt: {0: date},
        ),
        BookmarkGroup(
          id: leaf,
          name: 'Child',
          parentGroupId: root,
          bookmarkIds: {0},
          addedAt: {0: date},
        ),
      ];
      final prepared = prepare(
        [group(root, action: ImportAction.update)],
        current: current,
        currentRecords: [record],
      );
      expect(prepared.groups.singleWhere((g) => g.id == leaf), current.last);
      expect(
        prepared.groups.singleWhere((g) => g.id == root).bookmarkIds,
        isEmpty,
      );
      expect(
        prepared.removeIds,
        isEmpty,
        reason: 'The child still owns the record',
      );
    },
  );

  test('Merge preserves an existing root placement even if incoming parent is selected', () {
    final current = BookmarkGroup(
      id: leaf,
      name: 'Existing',
      bookmarkIds: const {},
    );
    final prepared = prepare(
      [
        group(root),
        group(leaf, parent: root, ids: {0}, action: ImportAction.merge),
      ],
      current: [current],
    );
    expect(
      prepared.groups.singleWhere((g) => g.id == leaf).parentGroupId,
      isNull,
    );
  });

  test(
    'a copied child with skipped parent resolves explicitly to the wrapper',
    () {
      final prepared = prepare([
        group(root, action: ImportAction.skip),
        group(leaf, parent: root, ids: {0}),
      ]);
      expect(prepared.groups.any((g) => g.id == root), isFalse);
      expect(
        prepared.groups.singleWhere((g) => g.id == leaf).parentGroupId,
        wrapper,
      );
    },
  );

  test('missing parent is rejected rather than silently flattened', () {
    expect(
      () => prepare([
        group(leaf, parent: other, ids: {0}),
      ]),
      throwsArgumentError,
    );
  });
}
