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
  final related = RelatedCollectionBookmark(
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
  Map<String, dynamic> currentWire(BookmarkBackupData data) => {
    'version': kBookmarksBackupVersion,
    'data': codec.encode(data),
    ...data.extraFields,
  };
  BookmarkBackupData read(Map<String, dynamic> data) =>
      codec.parse(decodeData(data: jsonEncode(data)));
  BookmarkLibraryState library(BookmarkBackupData data) => BookmarkLibraryState(
    records: data.records,
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
    'v6 round trip preserves both directional All orders and group dates',
    () {
      final decoded = read(currentWire(data));
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

  test('v6 compatibility projections do not create phantom import changes', () {
    final incoming = read(currentWire(data));
    final state = library(data);
    final summary = const ImportPlannedChangeProjector().bookmarks(
      local: BookmarkImportLocalSnapshot(
        records: state.records,
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

  test('v6 rejects missing membership dates and ungrouped records', () {
    final missingDates = currentWire(data);
    ((missingDates['groups'] as List).first as Map).remove('addedAt');
    expect(
      () => read(missingDates),
      throwsA(isA<InvalidBackupFormatException>()),
    );
    expect(
      () => read(currentWire(data)..['groups'] = []),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });

  test(
    're-export of legacy ungrouped data assigns a dated Default membership',
    () {
      final legacy = BookmarkBackupData(bookmarks: [post], groups: const []);
      final decoded = read(currentWire(legacy));
      expect(legacy.groups, isEmpty);
      expect(decoded.groups.single.id, defaultBookmarkGroupId);
      expect(decoded.groups.single.addedAt[post.id], post.createdAt);
      expect(decoded.bookmarks.single.createdAt, post.createdAt);
    },
  );

  for (final version in [4, 5]) {
    test(
      'legacy v$version reads global dates and transfers them to memberships',
      () {
        final json = <String, dynamic>{
          'version': version,
          'data': [
            for (final bookmark in data.bookmarks)
              {
                'localId': bookmark.id,
                'createdAt': bookmark.createdAt.toIso8601String(),
                'updatedAt': bookmark.updatedAt.toIso8601String(),
                'snapshot': bookmark.snapshot.toJson(),
                'postId': bookmark.postId,
                'identity': BookmarkIdentity.tryFromPost(
                  bookmark.post,
                )!.toJson(),
              },
          ],
          'groups': [
            for (final group in data.groups)
              if (group.bookmarkIds.contains(post.id))
                BookmarkGroupBackup(
                  id: group.id,
                  name: group.name,
                  bookmarkIds: [post.id],
                ).toJson()..remove('addedAt'),
          ],
        };
        final decoded = read(json);
        final plan = BookmarkImportPlanner().plan(
          data: decoded,
          currentBookmarks: [],
          currentGroups: [],
        );
        for (final group in plan.groups) {
          if (group.bookmarkIds.contains(post.id)) {
            expect(group.addedAt[post.id], post.createdAt);
          }
        }
        final rewritten = currentWire(decoded);
        expect(rewritten['version'], 6);
        expect(
          (rewritten['data'] as List).every(
            (row) => (row as Map).containsKey('createdAt'),
          ),
          isTrue,
        );
        expect(read(rewritten).groups.first.addedAt[post.id], post.createdAt);
      },
    );
  }
}
