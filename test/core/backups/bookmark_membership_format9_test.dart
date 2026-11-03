import 'dart:convert';

import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_planned_change_projector.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_planner.dart';
import 'package:boorusama/core/backups/sources/bookmarks_source.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_grid_entry.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/posts/related/related_family.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bookmarks/pool_bookmark_test_utils.dart';

void main() {
  final codec = BookmarkBackupCodec();
  final early = DateTime.utc(2020, 1, 1, 0, 0, 0, 123, 456);
  final first = DateTime.utc(2021);
  final later = DateTime.utc(2025);
  final post = testPoolPost(1);
  final pool = testPool(groups: {poolGroupA, poolGroupB}).copyWith(
    addedAt: {poolGroupA: DateTime.utc(2022), poolGroupB: DateTime.utc(2023)},
  );
  final related = RelatedBookmark(
    family: RelatedFamilyReference(origin: poolOrigin(), anchorId: 42),
    localId: poolProfile,
    createdAt: DateTime.utc(2027),
    observedAt: DateTime.utc(2027),
    groupIds: {poolGroupA, poolGroupB},
    addedAt: {poolGroupA: early, poolGroupB: DateTime.utc(2024)},
  );
  final data = BookmarkBackupData(
    bookmarks: [post],
    pools: [pool, related],
    groups: [
      BookmarkGroupBackup(
        id: poolGroupA,
        name: 'A',
        bookmarkIds: [post.id],
        addedAt: {post.id: first},
      ),
      BookmarkGroupBackup(
        id: poolGroupB,
        name: 'B',
        bookmarkIds: [post.id],
        addedAt: {post.id: later},
      ),
    ],
  );
  Map<String, dynamic> wire(BookmarkBackupData data) => {
    'version': kBookmarksBackupVersion,
    'data': codec.encode(data),
    ...data.extraFields,
  };
  BookmarkBackupData read(Map<String, dynamic> data) =>
      codec.parse(decodeData(data: jsonEncode(data)));
  BookmarkLibraryState library(BookmarkBackupData data) => BookmarkLibraryState(
    bookmarks: data.bookmarks,
    pools: data.pools,
    groups: [
      for (final group in data.groups)
        BookmarkGroup(
          id: group.id!,
          name: group.name,
          bookmarkIds: group.bookmarkIds.toSet(),
          addedAt: group.addedAt,
        ),
    ],
  );

  test(
    'v9 writes only membership dates for Posts and collection references',
    () {
      expect(kBookmarksBackupVersion, 9);
      final json = wire(data);
      for (final row in [
        ...json['data'] as List,
        ...json['collectionBookmarks'] as List,
      ]) {
        expect((row as Map).containsKey('createdAt'), isFalse);
      }
      final decoded = read(json);
      expect(decoded.bookmarks.single.createdAt, first);
      expect(decoded.pools.first.createdAt, DateTime.utc(2022));
      expect(decoded.pools.last.createdAt, early);
      expect(decoded.pools.last.addedAt[poolGroupA], early);
      expect(decoded.bookmarks.single.updatedAt, post.updatedAt);
      expect(decoded.pools.last.observedAt, related.observedAt);
    },
  );

  test(
    'v9 round trip preserves both directional All orders and group dates',
    () {
      final decoded = read(wire(data));
      for (final sort in [BookmarkSortType.newest, BookmarkSortType.oldest]) {
        List<Object> keys(BookmarkBackupData data) => selectBookmarkGridEntries(
          state: library(data),
          view: const BookmarkView.all(),
          selectedTags: [],
          sortType: sort,
        ).map((e) => e.key).toList();
        expect(keys(decoded), keys(data));
      }
      expect(
        decoded.groups.map((g) => g.addedAt),
        data.groups.map((g) => g.addedAt),
      );
    },
  );

  test('v9 compatibility projections do not create phantom import changes', () {
    final incoming = read(wire(data));
    final state = library(data);
    final summary = const ImportPlannedChangeProjector().bookmarks(
      local: BookmarkImportLocalSnapshot(
        bookmarks: state.items,
        groups: state.groups,
        pools: state.pools,
      ),
      incoming: incoming,
      resolution: ResolvedImportSource(
        id: 'bookmarks',
        action: ImportAction.replace,
        items: const [],
      ),
    )!;
    expect(summary.hasMutations, isFalse);
    expect(summary.previewRows, isEmpty);
  });

  test('v9 ignores a legacy global date when memberships are supplied', () {
    final json = wire(data);
    (json['data'] as List).first['createdAt'] = '1900-01-01T00:00:00.000Z';
    (json['collectionBookmarks'] as List).first['createdAt'] =
        '1900-01-01T00:00:00.000Z';
    final decoded = read(json);
    expect(decoded.bookmarks.single.createdAt, first);
    expect(decoded.pools.first.createdAt, DateTime.utc(2022));
  });

  test('v9 rejects missing Post or reference membership dates', () {
    for (final reference in [false, true]) {
      final json = wire(data);
      final row =
          ((json[reference ? 'collectionBookmarks' : 'groups'] as List).first
              as Map);
      row.remove('addedAt');
      expect(() => read(json), throwsA(isA<InvalidBackupFormatException>()));
    }
  });

  test(
    'v9 rejects ungrouped payload rows instead of inventing a timestamp',
    () {
      final json = wire(data)
        ..['groups'] = []
        ..remove('collectionBookmarks');
      expect(() => read(json), throwsA(isA<InvalidBackupFormatException>()));
    },
  );

  test(
    're-export of legacy ungrouped data assigns a dated Default membership',
    () {
      final legacy = BookmarkBackupData(bookmarks: [post], groups: const []);
      final decoded = read(wire(legacy));
      expect(legacy.groups, isEmpty);
      expect(decoded.groups.single.id, defaultBookmarkGroupId);
      expect(decoded.groups.single.addedAt[post.id], post.createdAt);
      expect(decoded.bookmarks.single.createdAt, post.createdAt);
    },
  );

  for (final version in [4, 5, 6, 7, 8]) {
    test(
      'legacy v$version reads global dates and transfers them to memberships',
      () {
        final legacyPools = version < 6
            ? <CollectionBookmark>[]
            : version < 7
            ? [pool]
            : [pool, related];
        final json = <String, dynamic>{
          'version': version,
          'data': [
            for (final bookmark in data.bookmarks)
              {
                ...codec.encode(data).single as Map,
                'createdAt': bookmark.createdAt.toIso8601String(),
              },
          ],
          'groups': [
            for (final group in data.groups) group.toJson()..remove('addedAt'),
          ],
          if (legacyPools.isNotEmpty)
            'collectionBookmarks': [
              for (final value in legacyPools)
                value.toJson()..remove('addedAt'),
            ],
        };
        final decoded = read(json);
        final plan = BookmarkImportPlanner().plan(
          data: decoded,
          currentBookmarks: [],
          currentGroups: [],
        );
        for (final group in plan.groups) {
          expect(group.addedAt[post.transferIdentity], post.createdAt);
        }
        for (final pool in decoded.pools) {
          expect(pool.addedAt.values, everyElement(pool.createdAt));
        }
        final rewritten = wire(decoded);
        expect(
          (rewritten['data'] as List).single.containsKey('createdAt'),
          isFalse,
        );
        expect(read(rewritten).groups.first.addedAt[post.id], post.createdAt);
      },
    );
  }
}
