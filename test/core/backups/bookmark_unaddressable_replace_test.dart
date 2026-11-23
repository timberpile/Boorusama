import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_planner.dart';
import 'package:boorusama/core/backups/sources/bookmark_unified_import.dart';
import 'package:boorusama/core/bookmarks/src/data/stored_bookmark_codec.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_record_fields.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:flutter_test/flutter_test.dart';

const _group = '10000000-0000-4000-8000-000000000001';
const _other = '10000000-0000-4000-8000-000000000002';
const _copy = '10000000-0000-4000-8000-000000000003';
final _date = DateTime.utc(2024, 2, 3);
const _codec = StoredBookmarkCodec();

PostBookmark _opaque(int id) => PostBookmark.empty
    .copyWith(
      id: id,
      md5: 'opaque',
      createdAt: DateTime.utc(2020),
      updatedAt: DateTime.utc(2021),
    )
    .copyWith(sourceUrl: 'local-only-$id');

Bookmark _transfer(Bookmark local, int id) => bookmarkWithId(
  _codec.decode(_codec.encodeForTransfer(local)),
  id,
);

List<BookmarkGroup> _groups(Iterable<int> ids) => [
  BookmarkGroup(
    id: defaultBookmarkGroupId,
    name: 'Default',
    bookmarkIds: const {},
  ),
  BookmarkGroup(
    id: _group,
    name: 'Saved',
    bookmarkIds: ids.toSet(),
    addedAt: {for (final id in ids) id: _date},
  ),
];

BookmarkImportPreparation _prepare({
  required List<Bookmark> local,
  required List<Bookmark> incoming,
  List<BookmarkGroup>? localGroups,
  List<BookmarkGroup>? incomingGroups,
  bool replace = true,
  ImportAction action = ImportAction.merge,
}) {
  final before = localGroups ?? _groups(local.map((r) => r.id));
  final after = incomingGroups ?? _groups(incoming.map((r) => r.id));
  final data = BookmarkBackupData.unified(
    records: incoming,
    groups: [
      for (final group in after)
        BookmarkGroupBackup(
          id: group.id,
          name: group.name,
          bookmarkIds: group.bookmarkIds.toList(),
          addedAt: group.addedAt,
        ),
    ],
  );
  final plan = const BookmarkImportPlanner().plan(
    data: data,
    currentBookmarks: local,
    currentGroups: before,
  );
  final resolved = plan.resolveActions({
    for (final group in plan.groups)
      group.id: group.resolveAction(
        replace ? ImportAction.replace : action,
        destinationId: action == ImportAction.copy && !group.isDefault
            ? _copy
            : null,
      ),
  });
  return BookmarkImportPreparation.prepare(
    plan: resolved,
    currentRecords: local,
    currentGroups: before,
    currentFolders: const [],
    replace: replace,
    normalize: (record, {previous}) => record,
  );
}

void main() {
  for (final counts in [(2, 2), (2, 3), (3, 2)]) {
    test(
      'opaque Replace preserves multiset cardinality ${counts.$1} to ${counts.$2}',
      () {
        final local = [
          for (var i = 0; i < counts.$1; i++)
            _opaque(10).copyWith(id: 10 + i, sourceUrl: 'local-only-${10 + i}'),
        ];
        final incoming = [
          for (var i = 0; i < counts.$2; i++) _transfer(local.first, 900 + i),
        ];
        final prepared = _prepare(local: local, incoming: incoming);
        expect(
          prepared.newIds,
          hasLength(counts.$2 > counts.$1 ? counts.$2 - counts.$1 : 0),
        );
        expect(prepared.removeIds, {
          for (var i = counts.$2; i < counts.$1; i++) local[i].id,
        });
        final retained = prepared.records
            .where((r) => !prepared.newIds.contains(r.id))
            .toList();
        expect(
          retained.map((r) => r.id),
          local.take(counts.$2).map((r) => r.id),
        );
        for (final record in retained) {
          expect(
            _codec.encode(record),
            _codec.encode(local.firstWhere((r) => r.id == record.id)),
          );
        }
        final materialized = prepared.materialize([
          for (var i = 0; i < prepared.newIds.length; i++) 1000 + i,
        ]);
        expect(
          materialized.groups.singleWhere((g) => g.id == _group).bookmarkIds,
          hasLength(counts.$2),
        );
      },
    );
  }

  test('opaque self-copy ignores relabelled file IDs and record order without swapping local fields', () {
    final a = _opaque(10);
    final b = a.copyWith(id: 20, sourceUrl: 'local-only-20');
    final localGroups = [
      ..._groups([a.id]),
      BookmarkGroup(
        id: _other,
        name: 'Other',
        bookmarkIds: {b.id},
        addedAt: {b.id: _date.add(const Duration(days: 1))},
      ),
    ];
    final incoming = [_transfer(b, 10), _transfer(a, 900)];
    final importedGroups = [
      ..._groups([900]),
      BookmarkGroup(
        id: _other,
        name: 'Other',
        bookmarkIds: {10},
        addedAt: {10: _date.add(const Duration(days: 1))},
      ),
    ];
    final prepared = _prepare(
      local: [a, b],
      incoming: incoming,
      localGroups: localGroups,
      incomingGroups: importedGroups,
    );
    expect(prepared.newIds, isEmpty);
    expect(prepared.removeIds, isEmpty);
    expect(
      {for (final r in prepared.records) r.id: _codec.encode(r)},
      {a.id: _codec.encode(a), b.id: _codec.encode(b)},
    );
    expect(prepared.groups.singleWhere((g) => g.id == _group).bookmarkIds, {
      a.id,
    });
    expect(prepared.groups.singleWhere((g) => g.id == _other).bookmarkIds, {
      b.id,
    });
  });

  for (final mutation in [
    'snapshot',
    'created date',
    'updated date',
    'source',
    'membership date',
  ]) {
    test(
      'opaque $mutation changes remain visible despite a colliding file ID',
      () {
        final local = _opaque(10);
        var incoming = _transfer(local, local.id) as PostBookmark;
        incoming = switch (mutation) {
          'snapshot' => incoming.copyWith(tags: const {'changed'}),
          'created date' => incoming.copyWith(createdAt: DateTime.utc(2022)),
          'updated date' => incoming.copyWith(updatedAt: DateTime.utc(2022)),
          'source' => incoming.copyWith(
            sourceUrl: 'https://different.example',
            tags: incoming.tags,
          ),
          _ => incoming,
        };
        final groups = _groups([incoming.id]);
        final prepared = _prepare(
          local: [local],
          incoming: [incoming],
          incomingGroups: mutation == 'membership date'
              ? [
                  groups.first,
                  groups.last.copyWith(
                    addedAt: {incoming.id: _date.add(const Duration(days: 1))},
                  ),
                ]
              : groups,
        );
        expect(prepared.newIds, hasLength(1));
        expect(prepared.removeIds, {local.id});
      },
    );
  }

  for (final action in [
    ImportAction.merge,
    ImportAction.copy,
    ImportAction.update,
  ]) {
    test(
      'opaque $action imports retain fresh-record semantics outside category Replace',
      () {
        final local = _opaque(10);
        final prepared = _prepare(
          local: [local],
          incoming: [_transfer(local, local.id)],
          replace: false,
          action: action,
        );
        expect(prepared.newIds, hasLength(1));
        expect(prepared.records.single.id, isNot(local.id));
      },
    );
  }
}
