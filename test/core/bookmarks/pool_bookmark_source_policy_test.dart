import 'package:boorusama/boorus/szurubooru/pools/bookmarks.dart';
import 'package:boorusama/boorus/szurubooru/pools/types.dart';
import 'package:boorusama/core/backups/export_import/import/bookmark_profile_dependency.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_record_fields.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_tag_index.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pool_bookmark_test_utils.dart';

void main() {
  BooruConfig config(
    String id, {
    String host = 'danbooru.donmai.us',
    int rating = 0,
  }) => BooruConfig.fromJson({
    ...BooruConfig.empty.toJson(),
    'id': id,
    'url': 'https://$host',
    'booruId': 0,
    'booruIdHint': testPool().origin.booruType.id,
    'ratingFilter': rating,
  });

  test(
    'a saved Pool read uses a unique compatible profile after hint removal',
    () {
      final original = config(poolProfile);
      final other = config(poolGroupB);
      expect(
        resolvePoolBookmarkProfile(testPool(), [original, other]),
        original,
      );
      expect(resolvePoolBookmarkProfile(testPool(), [other]), other);
      expect(
        resolvePoolBookmarkProfile(testPool(), [
          config(poolProfile, host: 'other.example'),
        ]),
        isNull,
      );
      final future = PoolBookmark.fromJson({
        ...testPool().toJson(),
        'origin': {
          ...testPool().origin.toSnapshot().toJson(),
          'booruTypeId': 99999,
        },
      });
      expect(resolvePoolBookmarkProfile(future, [original]), isNull);
    },
  );

  test('cover policy changes for visibility and blacklist but contains no account identity', () {
    final first = config(poolProfile);
    final second = config(poolGroupB);
    expect(
      poolCoverPolicy(first, {'b', 'a'}),
      poolCoverPolicy(second, {'a', 'b'}),
    );
    expect(poolCoverPolicy(first, {'a'}), isNot(poolCoverPolicy(first, {'b'})));
    expect(
      poolCoverPolicy(first, {}),
      isNot(poolCoverPolicy(config(poolProfile, rating: 1), {})),
    );
  });

  test('custom rating changes invalidate covers even when the filter mode stays custom', () {
    BooruConfig custom(String allowed) => BooruConfig.fromJson({
      ...config(poolProfile).toJson(),
      'ratingFilter': BooruConfigRatingFilter.custom.index,
      'granularRatingFilterString': allowed,
    });
    final safe = custom('g');
    final explicit = custom('e');
    expect(safe.granularRatingFilters, isNot(explicit.granularRatingFilters));
    expect(poolCoverPolicy(safe, {}), isNot(poolCoverPolicy(explicit, {})));
  });

  test('Pool-only selected groups contribute dependencies and remap only profile hints', () {
    final pool = testPool();
    final data = BookmarkBackupData(
      bookmarks: const [],
      groups: const [
        BookmarkGroupBackup(
          id: poolGroupA,
          name: 'Pool only',
          bookmarkIds: [],
        ),
      ],
      pools: [pool],
    );
    ResolvedImportSource resolution(ImportAction action) =>
        ResolvedImportSource(
          id: 'bookmarks',
          action: action,
          items: [
            ResolvedImportItem(
              id: 'group:$poolGroupA',
              action: ImportAction.update,
            ),
          ],
        );
    expect(
      selectedProfileRecords(data, resolution(ImportAction.skip)),
      isEmpty,
    );
    final record = data.records.single;
    expect(
      selectedProfileRecords(data, resolution(ImportAction.configureItems)),
      [record],
    );
    final mapped = bookmarkRecordWithProfileHint(record, poolGroupB);
    expect(bookmarkRecordProfileHint(mapped), poolGroupB);
    expect(bookmarkContentIdentity(mapped), bookmarkContentIdentity(record));
    expect(mapped.id, record.id);
    expect(bookmarkCreatedAt(mapped), bookmarkCreatedAt(record));
    expect(bookmarkRecordProfileReference(mapped).id, poolGroupB);
    expect(data.groups.single.bookmarkIds, [record.id]);
    expect(data.groups.single.addedAt[record.id], pool.addedAt[poolGroupA]);
  });

  test(
    'a native Work without a legacy Pool view contributes its own profile hint',
    () {
      final snapshot = StoredGroupSnapshot(
        summary: ContentGroupSummary(
          reference: const ContentReferenceCodec().parse(
            engine: BooruType.pixiv,
            site: Uri.parse('https://www.pixiv.net'),
            kind: ContentKind.group,
            sourceKey: 'work:120',
          ),
          title: 'Saved Work',
        ),
      );
      final record = ContentGroupBookmark(
        id: 10,
        snapshot: snapshot,
        createdAt: DateTime.utc(2020),
        observedAt: DateTime.utc(2026),
      );
      final data = BookmarkBackupData.unified(
        records: [record],
        groups: [
          BookmarkGroupBackup(
            id: poolGroupA,
            name: 'Work',
            bookmarkIds: [10],
            addedAt: {10: DateTime.utc(2021)},
          ),
        ],
      );
      final selected = selectedProfileRecords(
        data,
        ResolvedImportSource(
          id: 'bookmarks',
          action: ImportAction.configureItems,
          items: [
            ResolvedImportItem(
              id: 'group:$poolGroupA',
              action: ImportAction.merge,
            ),
          ],
        ),
      );
      expect(data.pools, isEmpty);
      expect(selected, [record]);
      final reference = bookmarkRecordProfileReference(selected.single);
      expect(reference.booruType, BooruType.pixiv.name);
      expect(reference.url, 'www.pixiv.net');
      final mapped = bookmarkRecordWithProfileHint(
        record,
        poolGroupB,
      ) as ContentGroupBookmark;
      expect(mapped.snapshot, same(snapshot));
      expect(mapped.reference, record.reference);
      expect(mapped.sourceProfileHint, poolGroupB);
      expect(data.groups.single.addedAt[10], DateTime.utc(2021));
    },
  );

  test(
    'Pool tag overlay counts a reference once and retains the Post base index',
    () {
      final base = BookmarkTagIndex([
        BookmarkTagEntry(tag: 'alpha', count: 2, sources: const {}),
        BookmarkTagEntry(tag: 'post', count: 1, sources: const {}),
      ]);
      final mixed = base.withPoolBookmarks([
        testPool(),
        testPool(id: 11, tags: {'alpha'}),
      ]);
      expect(mixed.byName['alpha']!.count, 4);
      expect(mixed.byName['beta']!.count, 1);
      expect(mixed.entries.first.tag, 'alpha');
      expect(base.byName['alpha']!.count, 2);
      expect(base.byName.containsKey('beta'), isFalse);
    },
  );

  test('Szurubooru projection requires explicit Series category and full remote count', () {
    SzurubooruPool remote(String? category) => SzurubooruPool(
      id: 10,
      names: const ['A'],
      category: category,
      description: null,
      postCount: 500,
      postIds: const [1, 2],
      thumbnailUrls: const [],
      createdAt: DateTime.utc(2000),
      updatedAt: DateTime.utc(2026),
    );
    expect(
      szurubooruBookmarkPool(remote('series')).category,
      BookmarkedPoolCategory.series,
    );
    expect(
      szurubooruBookmarkPool(remote(null)).category,
      BookmarkedPoolCategory.unknown,
    );
    expect(
      szurubooruBookmarkPool(remote('collection')).category,
      BookmarkedPoolCategory.collection,
    );
    expect(szurubooruBookmarkPool(remote('series')).total, 500);
    expect(
      szurubooruBookmarkPool(remote('series')).supportsUploadOrder,
      isFalse,
    );
  });
}
