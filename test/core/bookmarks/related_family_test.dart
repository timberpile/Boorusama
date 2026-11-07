import 'dart:convert';

import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_capability.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/related/related_family.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pool_bookmark_test_utils.dart';

void main() {
  test(
    'parent, child and siblings share a source-scoped direct-family identity',
    () {
      final family = RelatedFamilyReference.fromPost(testRelatedPost(10));
      expect(
        RelatedFamilyReference.fromPost(testRelatedPost(11, parent: 10)),
        family,
      );
      expect(
        RelatedFamilyReference.fromPost(testRelatedPost(12, parent: 10)),
        family,
      );
      expect(
        RelatedFamilyReference.fromPost(testRelatedPost(10, parent: 0)),
        family,
      );
      expect(family.contains(testRelatedPost(10, parent: 99)), isTrue);
      expect(family.contains(testRelatedPost(11, parent: 10)), isTrue);
      expect(family.contains(testRelatedPost(13, parent: 11)), isFalse);
      expect(
        family.contains(testRelatedPost(11, parent: 10, host: 'other.example')),
        isFalse,
      );
      expect(
        () => RelatedFamilyReference.fromPost(testRelatedPost(0)),
        throwsFormatException,
      );
      expect(family.query, 'parent:10');
    },
  );

  test('repeat families retain separate occurrences in a mixed sequence', () {
    final family = RelatedFamilyReference.fromPost(testRelatedPost(10));
    final sequence = ViewerEntrySequence([
      PostViewerEntry(post: testRelatedPost(1), occurrenceId: 0),
      PoolViewerEntry(
        origin: poolOrigin(),
        pool: const RemoteBookmarkPool(
          id: 1,
          title: '',
          category: BookmarkedPoolCategory.series,
          total: null,
        ),
        occurrenceId: 1,
        source: null,
      ),
      RelatedViewerEntry(family: family, occurrenceId: 2, source: null),
      PoolViewerEntry(
        origin: poolOrigin(),
        pool: const RemoteBookmarkPool(
          id: 2,
          title: '',
          category: BookmarkedPoolCategory.collection,
          total: null,
        ),
        occurrenceId: 3,
        source: null,
      ),
      PostViewerEntry(post: testRelatedPost(2), occurrenceId: 4),
      RelatedViewerEntry(family: family, occurrenceId: 5, source: null),
    ]);
    expect(sequence.entries, hasLength(6));
    expect(
      sequence.entries[2].contentIdentity,
      sequence.entries[5].contentIdentity,
    );
    expect(
      [for (var i = 0; i < 6; i++) sequence.postIndex(i)],
      [0, null, null, null, 1, null],
    );
  });

  test('Related references never borrow another account when removed or imported unbound', () {
    final original = BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: poolOrigin().booruType,
        url: 'https://danbooru.donmai.us',
        customDownloadFileNameFormat: null,
      ).toJson(),
      'id': poolProfile,
    });
    final other = BooruConfig.fromJson({
      ...original.toJson(),
      'id': poolGroupB,
    });
    final pool = testPool();
    final related = RelatedCollectionBookmark(
      family: RelatedFamilyReference(origin: pool.origin, anchorId: 10),
      localId: pool.localId,
      createdAt: pool.createdAt,
      observedAt: pool.observedAt,
      groupIds: pool.groupIds,
    );
    expect(resolvePoolBookmarkProfile(related, [original, other]), original);
    expect(resolvePoolBookmarkProfile(related, [other]), isNull);
    final unbound = related.copyWith(
      origin: PostOrigin.fromSource(
        booruType: pool.origin.booruType,
        booruId: pool.origin.booruId,
        source: pool.origin.sourceHost,
      ),
    );
    expect(resolvePoolBookmarkProfile(unbound, [other]), isNull);
    expect(unbound.identity, related.identity);
    final binding = ViewerSourceBinding(original);
    expect(binding.resolve([other]), isNull);
    expect(
      binding.resolve([
        BooruConfig.fromJson({
          ...original.toJson(),
          'login': 'changed_account',
        }),
      ]),
      isNull,
    );
  });

  test('v7 preserves Related identity and rejects malformed, duplicate and older envelopes', () {
    final pool = testPool();
    final reference = RelatedCollectionBookmark(
      family: RelatedFamilyReference.fromPost(testRelatedPost(10)),
      localId: pool.localId,
      createdAt: pool.createdAt,
      observedAt: pool.observedAt,
      groupIds: pool.groupIds,
    );
    final encoded =
        jsonDecode(jsonEncode(reference.toJson())) as Map<String, dynamic>;
    expect(encoded['kind'], 'related');
    expect(encoded['anchorId'], 10);
    expect(encoded.keys, isNot(contains('poolId')));
    expect(CollectionBookmark.fromJson(encoded), reference);
    expect(reference.identity, isNot(pool.identity));
    expect(reference.total, isNull);
    expect(reference.withGroups({poolGroupB}).family, reference.family);
    final codec = BookmarkBackupCodec();
    final data = BookmarkBackupData(
      bookmarks: [],
      pools: [reference],
      groups: [
        const BookmarkGroupBackup(id: poolGroupA, name: 'A', bookmarkIds: []),
      ],
    );
    ExportDataPayload payload(int version, {List<Object?>? rows}) =>
        ExportDataPayload(
          version: version,
          exportDate: null,
          exportVersion: null,
          data: [],
          extraFields: {
            ...data.extraFields,
            if (version < 9)
              'collectionBookmarks': data.pools
                  .map((pool) => pool.toJson())
                  .toList(),
            if (rows != null) 'collectionBookmarks': rows,
          },
        );
    expect(codec.parse(payload(7)).pools, [reference]);
    expect(codec.parse(payload(8)).pools, [reference]);
    expect(codec.parse(payload(9)).pools, [reference]);
    for (final version in [4, 5, 6, 10]) {
      expect(
        () => codec.parse(payload(version)),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    }
    for (final rows in [
      [encoded, encoded],
      [
        {...encoded, 'anchorId': 0},
      ],
      [
        {...encoded, 'kind': 'future'},
      ],
    ]) {
      expect(
        () => codec.parse(payload(7, rows: rows)),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    }
  });
}
