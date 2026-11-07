import 'dart:convert';

import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/content/groups/group_details.dart';
import 'package:boorusama/core/content/groups/group_metadata.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/posts/related/related_posts_order.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bookmarks/pool_bookmark_test_utils.dart';

void main() {
  const groupA = poolGroupA;
  const groupB = poolGroupB;
  const folderRoot = '550e8400-e29b-41d4-a716-446655440010';
  const folderChild = '550e8400-e29b-41d4-a716-446655440011';
  const groupC = '550e8400-e29b-41d4-a716-446655440012';
  const sourceSite = 'https://danbooru.donmai.us/install';
  final earlyA = DateTime.utc(2020, 1, 2, 3, 4, 5, 123, 456);
  final lateA = DateTime.utc(2022, 3, 4);
  final lateB = DateTime.utc(2023, 7, 8);
  final codec = BookmarkBackupCodec();

  ContentReference reference(String key) => const ContentReferenceCodec().parse(
    engine: BooruType.danbooru,
    site: Uri.parse(sourceSite),
    kind: ContentKind.group,
    sourceKey: key,
  );

  ContentGroupBookmark nativePool({required int id}) => ContentGroupBookmark(
    id: id,
    snapshot: StoredGroupSnapshot(
      summary: ContentGroupSummary(
        reference: reference('pool:42'),
        title: 'Native pool',
      ),
      details: ContentGroupDetails(
        summary: ContentGroupSummary(
          reference: reference('pool:42'),
          title: 'Native pool',
        ),
        description: const GroupDescription(
          text: 'private details fixture',
          format: GroupTextFormat.plainText,
        ),
      ),
      index: GroupBookmarkIndex(
        tags: const {'member-only-tag'},
        basis: GroupTagIndexBasis.memberUnion,
        coverage: MetadataCoverage.complete,
      ),
    ),
    createdAt: DateTime.utc(2019, 1, 1),
    observedAt: DateTime.utc(2024, 1, 1),
  );

  RelatedBookmark related({required int id}) => RelatedBookmark(
    id: id,
    snapshot: StoredGroupSnapshot(
      summary: ContentGroupSummary(reference: reference('related:900')),
    ),
    createdAt: DateTime.utc(2018, 1, 1),
    observedAt: DateTime.utc(2024, 1, 2),
    preferredOrder: RelatedPostsOrder.newest,
  );

  LegacyGroupBookmark unknownEngine({required int id}) =>
      LegacyGroupBookmark.fromMetadata(
        id: id,
        metadata: PoolBookmark(
          localId: 'legacy-source-777',
          origin: poolOrigin(host: 'legacy.example', type: BooruType.unknown),
          sourceTypeId: 777,
          poolId: 777,
          category: BookmarkedPoolCategory.series,
          title: 'Unaddressable legacy pool',
          createdAt: DateTime.utc(2017, 1, 1),
          observedAt: DateTime.utc(2024, 2, 1),
          groupIds: const {},
          tags: const {'archived-tag'},
          coverage: PoolTagCoverage.unknown,
          total: 12,
        ),
      );

  List<Bookmark> records() => [
    testPoolPost(7).copyWith(
      id: 0,
      sourceUrl: 'https://account:secret@example.test/post/7?token=private',
    ),
    nativePool(id: 1),
    related(id: 2),
    unknownEngine(id: 3),
    PostBookmark.empty.copyWith(id: 4, sourceUrl: '', postId: () => null),
  ];

  List<BookmarkGroup> groups() => [
    BookmarkGroup(
      id: groupA,
      name: 'A',
      bookmarkIds: const {0, 1, 2, 3, 4},
      addedAt: {0: earlyA, 1: earlyA, 2: earlyA, 3: earlyA, 4: earlyA},
      folderId: folderChild,
      position: 2,
    ),
    BookmarkGroup(
      id: groupB,
      name: 'B',
      bookmarkIds: const {0, 1, 4},
      addedAt: {0: lateB, 1: lateB, 4: lateB},
      folderId: folderChild,
      position: 1,
    ),
    BookmarkGroup(
      id: groupC,
      name: 'C',
      bookmarkIds: const {2, 3},
      addedAt: {2: lateA, 3: lateA},
    ),
  ];

  List<CollectionFolder> folders() => const [
    CollectionFolder(id: folderRoot, name: 'Root', position: 0),
    CollectionFolder(
      id: folderChild,
      name: 'Nested',
      parentId: folderRoot,
      position: 1,
    ),
  ];

  Map<String, dynamic> payload(BookmarkBackupData data, {int version = 10}) => {
    'version': version,
    'data': codec.encode(data),
    ...data.extraFields,
  };

  BookmarkBackupData read(Map<String, dynamic> json) => codec.parse(
    decodeData(data: jsonEncode(json)),
  );

  test(
    'v10 stores all Bookmark kinds in one tagged array and excludes secrets',
    () {
      final inputRecords = records();
      final input = BookmarkBackupData.unified(
        records: inputRecords,
        groups: [
          for (final group in groups())
            BookmarkGroupBackup(
              id: group.id,
              name: group.name,
              bookmarkIds: group.bookmarkIds.toList(),
              addedAt: group.addedAt,
              folderId: group.folderId,
              position: group.position,
            ),
        ],
        folders: folders(),
      );
      final json = payload(input);
      final rows = json['data'] as List;
      expect(rows.map((row) => (row as Map)['kind']), [
        'post',
        'group',
        'related',
        'group',
        'post',
      ]);
      expect(json.containsKey('collectionBookmarks'), isFalse);
      expect(jsonEncode(json), isNot(contains('account:secret')));
      expect(jsonEncode(json), isNot(contains('token=private')));
      expect((rows.first as Map).containsKey('sourceUrl'), isFalse);

      final restored = read(json);
      expect(restored.records, [
        for (final record in inputRecords)
          if (record is PostBookmark)
            record.copyWith(
              sourceUrl: '',
              createdAt: record.createdAt.toUtc(),
              updatedAt: record.updatedAt.toUtc(),
            )
          else
            record,
      ]);
      expect(restored.groups, input.groups);
      expect(restored.folders, input.folders);
      expect(restored.records.map((record) => record.id), [0, 1, 2, 3, 4]);
      expect(restored.groups[0].addedAt[0], earlyA);
      expect(restored.groups[1].addedAt[0], lateB);
      expect(
        restored.groups[0].addedAt[0],
        isNot(restored.groups[1].addedAt[0]),
      );
      expect(
        (restored.records[1] as ContentGroupBookmark).reference.site.toString(),
        sourceSite,
      );
      expect(
        (restored.records[2] as RelatedBookmark).preferredOrder,
        RelatedPostsOrder.newest,
      );
      final legacy = restored.records[3] as LegacyGroupBookmark;
      expect(legacy.metadata.sourceTypeId, 777);
      expect(
        legacy.tryReferenceForProvenSite(Uri.parse('https://legacy.example')),
        isNull,
      );
      expect((restored.records[4] as PostBookmark).postId, isNull);
      expect((restored.records[4] as PostBookmark).sourceUrl, isEmpty);
      expect(
        (restored.records[1] as ContentGroupBookmark)
            .snapshot
            .details
            ?.description
            ?.text,
        'private details fixture',
      );
      expect(
        (restored.records[1] as ContentGroupBookmark).snapshot.index?.tags,
        {'member-only-tag'},
      );
      expect(jsonEncode(json), isNot(contains('memberManifest')));
      expect(jsonEncode(json), isNot(contains('postSnapshots')));
    },
  );

  test(
    'transfer normalizes local Post dates to UTC without changing the instants',
    () {
      final sourceRecords = records();
      final localCreatedAt = DateTime(2022, 4, 5, 6, 7, 8, 901, 234);
      final localUpdatedAt = DateTime(2024, 8, 9, 10, 11, 12, 345, 678);
      final post = (sourceRecords.first as PostBookmark).copyWith(
        createdAt: localCreatedAt,
        updatedAt: localUpdatedAt,
        sourceUrl: 'https://account:secret@example.test/post/7?token=private',
      );
      final allRecords = [post, sourceRecords[1], sourceRecords[2]];
      final data = BookmarkBackupData.unified(
        records: allRecords,
        groups: [
          BookmarkGroupBackup(
            id: groupA,
            name: 'A',
            bookmarkIds: [0, 1, 2],
            addedAt: {0: earlyA, 1: earlyA, 2: earlyA},
          ),
        ],
      );

      final rows = codec.encode(data);
      final postRow = rows.first as Map;
      expect(postRow['createdAt'], localCreatedAt.toUtc().toIso8601String());
      expect(postRow['updatedAt'], localUpdatedAt.toUtc().toIso8601String());
      final restored = read(payload(data));
      final restoredPost = restored.records.first as PostBookmark;
      expect(restoredPost.createdAt.isAtSameMomentAs(localCreatedAt), isTrue);
      expect(restoredPost.updatedAt.isAtSameMomentAs(localUpdatedAt), isTrue);
    },
  );

  test('local recovery retains Post source URL while transfer omits it', () {
    final sourceRecords = records();
    final post = (sourceRecords.first as PostBookmark).copyWith(
      sourceUrl: 'https://account:secret@example.test/post/7?token=private',
    );
    final allRecords = [post, sourceRecords[1], sourceRecords[2]];
    final data = BookmarkBackupData.unified(
      records: allRecords,
      groups: [
        BookmarkGroupBackup(
          id: groupA,
          name: 'A',
          bookmarkIds: [0, 1, 2],
          addedAt: {0: earlyA, 1: earlyA, 2: earlyA},
        ),
      ],
    );

    final transferRows = codec.encode(data);
    final recoveryRows = codec.encodeLocalRecovery(data);
    expect((transferRows.first as Map).containsKey('sourceUrl'), isFalse);
    expect((recoveryRows.first as Map)['sourceUrl'], post.sourceUrl);
    for (var index = 1; index < allRecords.length; index++) {
      final expected = allRecords[index] as ContentGroupBookmark;
      final transfer = transferRows[index] as Map;
      final recovery = recoveryRows[index] as Map;
      expect(recovery['createdAt'], transfer['createdAt']);
      expect(recovery['observedAt'], transfer['observedAt']);
      expect(
        recovery['createdAt'],
        expected.createdAt.toUtc().toIso8601String(),
      );
      expect(
        recovery['observedAt'],
        expected.observedAt.toUtc().toIso8601String(),
      );
    }
  });

  test(
    'selected nested Group exports selected members of every record kind',
    () {
      final data = buildBookmarkBackupData(
        records: records(),
        groups: groups(),
        folders: folders(),
        scope: BookmarkExportScope.selected(groupIds: {groupB}),
      );
      final restored = read(payload(data));
      expect(restored.records.map((record) => record.id), [0, 1, 4]);
      expect(restored.records.map((record) => record.runtimeType), [
        PostBookmark,
        ContentGroupBookmark,
        PostBookmark,
      ]);
      expect(restored.groups.map((group) => group.id), [groupB]);
      expect(restored.groups.single.bookmarkIds, [0, 1, 4]);
      expect(restored.groups.single.addedAt[0], lateB);
      expect(restored.groups.single.addedAt[1], lateB);
      expect(restored.groups.single.folderId, folderChild);
      expect(restored.folders.map((folder) => folder.id), [
        folderRoot,
        folderChild,
      ]);
    },
  );

  test('v10 rejects malformed kinds, unsupported versions and mismatched Related rows', () {
    final base = payload(
      BookmarkBackupData.unified(
        records: records(),
        groups: [
          BookmarkGroupBackup(
            id: groupA,
            name: 'A',
            bookmarkIds: [0, 1, 2, 3, 4],
            addedAt: {0: earlyA, 1: earlyA, 2: earlyA, 3: earlyA, 4: earlyA},
          ),
        ],
      ),
    );
    final badKind = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
    (badKind['data'] as List)[0]['kind'] = 'future-kind';
    expect(() => read(badKind), throwsA(isA<InvalidBackupFormatException>()));

    expect(
      () => read({...base, 'version': 11}),
      throwsA(isA<InvalidBackupFormatException>()),
    );

    final negativeId = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
    (negativeId['data'] as List)[0]['id'] = -1;
    expect(
      () => read(negativeId),
      throwsA(isA<InvalidBackupFormatException>()),
    );

    final repeatedId = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
    (repeatedId['data'] as List)[1]['id'] = 0;
    expect(
      () => read(repeatedId),
      throwsA(isA<InvalidBackupFormatException>()),
    );

    final badSnapshot = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
    (badSnapshot['data'] as List)[1]['snapshot']['schemaVersion'] = 99;
    expect(
      () => read(badSnapshot),
      throwsA(isA<InvalidBackupFormatException>()),
    );

    final badOrder = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
    final relatedRow = (badOrder['data'] as List)[1] as Map;
    relatedRow['kind'] = 'related';
    relatedRow['preferredOrder'] = 'newest';
    expect(() => read(badOrder), throwsA(isA<InvalidBackupFormatException>()));
  });

  test('transfer profile hints cannot contain arbitrary private strings', () {
    const secret = 'private-token-is-not-a-profile-uuid';
    final post = testPoolPost(7);
    final snapshot = post.snapshot;
    final privatePost = post.copyWith(
      snapshot: StoredPostSnapshot(
        origin: PostOriginSnapshot(
          booruTypeId: snapshot.origin.booruTypeId,
          booruId: snapshot.origin.booruId,
          sourceHost: snapshot.origin.sourceHost,
          profileIdHint: secret,
        ),
        common: snapshot.common,
        custom: snapshot.custom,
        codecVersion: snapshot.codecVersion,
      ),
    );
    final legacy = LegacyGroupBookmark.fromMetadata(
      id: 1,
      metadata: testPool(id: 88, groups: {}).copyWith(
        origin: PostOrigin.fromSource(
          booruType: BooruType.danbooru,
          booruId: BooruType.danbooru.id,
          source: 'https://danbooru.donmai.us',
          profileIdHint: secret,
        ),
      ),
    );
    final data = BookmarkBackupData.unified(
      records: [privatePost, legacy],
      groups: [],
    );
    expect(jsonEncode(codec.encode(data)), isNot(contains(secret)));
    expect(privatePost.snapshot.origin.profileIdHint, secret);
    expect(legacy.sourceProfileHint, secret);
  });

  test('explicit legacy v9 Post and collection fixture migrates dates and local IDs', () {
    final legacyPost = testPoolPost(7);
    final postWire = <String, dynamic>{
      'localId': 7,
      'updatedAt': legacyPost.updatedAt.toIso8601String(),
      'snapshot': legacyPost.snapshot.toJson(),
      'postId': 7,
      'identity': {'site': 'danbooru.donmai.us', 'postKey': 'id:7'},
    };
    final oldPool = testPool(
      id: 88,
      groups: {groupA, groupB},
      host: 'legacy.example',
    ).toJson()..remove('createdAt');
    oldPool['localId'] = poolProfile;
    (oldPool['origin'] as Map<String, Object?>)['booruTypeId'] = 777;
    oldPool['addedAt'] = {
      groupA: earlyA.toIso8601String(),
      groupB: lateB.toIso8601String(),
    };
    final v9 = <String, dynamic>{
      'version': 9,
      'data': [postWire],
      'groups': [
        {
          'id': groupA,
          'name': 'A',
          'bookmarkIds': [7],
          'addedAt': {'7': earlyA.toIso8601String()},
        },
        {
          'id': groupB,
          'name': 'B',
          'bookmarkIds': [7],
          'addedAt': {'7': lateB.toIso8601String()},
        },
      ],
      'collectionBookmarks': [oldPool],
    };

    final migrated = read(v9);
    expect(migrated.records.length, 2);
    expect(migrated.records.map((record) => record.id).toSet().length, 2);
    final post = migrated.records.whereType<PostBookmark>().single;
    expect(post.createdAt, earlyA);
    expect(migrated.groups[0].addedAt[7], earlyA);
    expect(migrated.groups[1].addedAt[7], lateB);
    final retained = migrated.records.whereType<LegacyGroupBookmark>().single;
    expect(retained.metadata.sourceTypeId, 777);
    expect(retained.metadata.origin.booruType, BooruType.unknown);
    expect(retained.metadata.sourceSite, isNull);
    expect(
      retained.tryReferenceForProvenSite(Uri.parse('https://legacy.example')),
      isNull,
    );
    expect(migrated.groups.map((group) => group.id), [groupA, groupB]);
    final legacyId = retained.id;
    expect(legacyId, isNot(7));
    expect(migrated.groups[0].bookmarkIds, containsAll([7, legacyId]));
    expect(migrated.groups[1].bookmarkIds, containsAll([7, legacyId]));
    expect(migrated.groups[0].addedAt[legacyId], earlyA);
    expect(migrated.groups[1].addedAt[legacyId], lateB);
  });
}
