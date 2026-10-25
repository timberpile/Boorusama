import 'package:boorusama/boorus/szurubooru/pools/bookmarks.dart';
import 'package:boorusama/boorus/szurubooru/pools/types.dart';
import 'package:boorusama/core/backups/export_import/import/bookmark_profile_dependency.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/types.dart';
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
    'a removed hinted account cannot borrow another account on its site',
    () {
      final original = config(poolProfile);
      final other = config(poolGroupB);
      expect(
        resolvePoolBookmarkProfile(testPool(), [original, other]),
        original,
      );
      expect(resolvePoolBookmarkProfile(testPool(), [other]), isNull);
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

  test('Pool-only selected groups contribute dependencies and remap only profile hints', () {
    final pool = testPool();
    final data = BookmarkBackupData(
      bookmarks: const [],
      groups: const [],
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
    expect(selectedProfilePools(data, resolution(ImportAction.skip)), isEmpty);
    expect(
      selectedProfilePools(data, resolution(ImportAction.configureItems)),
      [pool],
    );
    final mapped = poolBookmarkWithProfileHint(pool, poolGroupB);
    expect(mapped.origin.profileIdHint, poolGroupB);
    expect(mapped.identity, pool.identity);
    expect(mapped.localId, pool.localId);
    expect(mapped.groupIds, pool.groupIds);
    expect(poolBookmarkProfileReference(mapped).id, poolGroupB);
  });

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
