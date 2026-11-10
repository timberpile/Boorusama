import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes/test_post.dart';
import 'pool_bookmark_test_utils.dart';

void main() {
  final site = Uri.parse('https://danbooru.donmai.us/install');
  final firstDate = DateTime.utc(2024, 1, 10, 1, 2, 3, 456, 789);
  final secondDate = DateTime.utc(2025, 2, 11, 4, 5, 6, 123, 456);

  ContentGroupBookmark nativePool({
    required int id,
    BooruType engine = BooruType.danbooru,
    String title = 'Pool title',
    GroupTagIndexBasis indexBasis = GroupTagIndexBasis.sourceGroup,
  }) {
    final reference = const ContentReferenceCodec().parse(
      engine: engine,
      site: site,
      kind: ContentKind.group,
      sourceKey: 'pool:42',
    );
    return ContentGroupBookmark(
      id: id,
      snapshot: StoredGroupSnapshot(
        summary: ContentGroupSummary(reference: reference, title: title),
        index: GroupBookmarkIndex(
          tags: const {'native-source-tag'},
          basis: indexBasis,
          coverage: MetadataCoverage.complete,
        ),
      ),
      createdAt: DateTime.utc(2020, 1, 2),
      observedAt: DateTime.utc(2025, 3, 4),
    );
  }

  RelatedBookmark related({required int id}) {
    final reference = const ContentReferenceCodec().parse(
      engine: BooruType.danbooru,
      site: site,
      kind: ContentKind.group,
      sourceKey: 'related:900',
    );
    return RelatedBookmark(
      id: id,
      snapshot: StoredGroupSnapshot(
        summary: ContentGroupSummary(reference: reference),
        index: GroupBookmarkIndex(
          tags: const {'related-member-tag'},
          basis: GroupTagIndexBasis.memberUnion,
          coverage: MetadataCoverage.partial,
        ),
      ),
      createdAt: DateTime.utc(2021),
      observedAt: DateTime.utc(2025),
    );
  }

  LegacyGroupBookmark unknownLegacy({int id = 3}) =>
      LegacyGroupBookmark.fromMetadata(
        id: id,
        metadata: PoolBookmark(
          localId: 'legacy-source-777',
          origin: poolOrigin(
            host: 'legacy.example',
            type: BooruType.unknown,
          ),
          sourceTypeId: 777,
          poolId: 777,
          category: BookmarkedPoolCategory.series,
          title: 'Legacy unknown engine',
          createdAt: DateTime.utc(2019, 7, 8),
          observedAt: DateTime.utc(2024, 9, 10),
          groupIds: const {},
          tags: const {'archived-tag'},
          coverage: PoolTagCoverage.partial,
          total: 12,
        ),
      );

  late PostBookmark post;
  late ContentGroupBookmark savedPool;
  late RelatedBookmark savedRelated;
  late LegacyGroupBookmark savedLegacy;
  late PostBookmark unaddressablePost;
  late List<Bookmark> records;
  late BookmarkGroup groupA;
  late BookmarkGroup groupB;
  late BookmarkLibraryState state;

  BookmarkGroup makeGroup(
    String id,
    Set<int> ids,
    DateTime Function(int) dateFor,
  ) => BookmarkGroup(
    id: id,
    name: id == poolGroupA ? 'A' : 'B',
    bookmarkIds: ids,
    addedAt: {for (final id in ids) id: dateFor(id)},
  );

  setUp(() {
    post = testPoolPost(7).copyWith(id: 0);
    savedPool = nativePool(id: 1);
    savedRelated = related(id: 2);
    savedLegacy = unknownLegacy();
    unaddressablePost = testPoolPost(8).copyWith(
      id: 4,
      postId: () => null,
    );
    records = [post, savedPool, savedRelated, savedLegacy, unaddressablePost];
    groupA = makeGroup(poolGroupA, {0, 1, 2, 3, 4}, (_) => firstDate);
    groupB = makeGroup(poolGroupB, {1, 3, 4}, (_) => secondDate);
    state = BookmarkLibraryState(
      bookmarks: [post, unaddressablePost],
      records: records,
      groups: [groupA, groupB],
      revision: 41,
    );
  });

  ContentIdentity postContent(PostBookmark value) => (
    siteNamespace: value.identity.site,
    kind: ContentKind.post,
    sourceKey: value.identity.postKey,
  );

  test('local and content indexes cover mixed records with independent memberships', () {
    expect(state.records, records);
    expect(state.byId, {for (final record in records) record.id: record});
    expect(state.byId.keys.toSet(), {0, 1, 2, 3, 4});
    expect(state.idByContent, {
      postContent(post): 0,
      savedPool.reference.identity: 1,
      savedRelated.reference.identity: 2,
    });
    expect(state.revision, 41);
    expect(state.items, [post, unaddressablePost]);
    expect(state.membershipsByBookmarkId, {
      0: {poolGroupA},
      1: {poolGroupA, poolGroupB},
      2: {poolGroupA},
      3: {poolGroupA, poolGroupB},
      4: {poolGroupA, poolGroupB},
    });
    expect(state.groupsById[poolGroupA]!.addedAt, {
      for (final id in groupA.bookmarkIds) id: firstDate,
    });
    expect(state.groupsById[poolGroupB]!.addedAt, {
      for (final id in groupB.bookmarkIds) id: secondDate,
    });
    expect(
      state.pools.singleWhere((pool) => pool.bookmarkId == savedPool.id).tags,
      isEmpty,
      reason: 'Native source tags do not describe sampled member tags.',
    );
    expect(
      state.pools
          .singleWhere((pool) => pool.bookmarkId == savedRelated.id)
          .tags,
      {'related-member-tag'},
    );
  });

  test('membership-only changes preserve canonical record indexes and unaffected reverse sets', () {
    final editedA = groupA.copyWith(
      bookmarkIds: groupA.bookmarkIds.difference({3}),
      addedAt: {
        for (final id in groupA.bookmarkIds.difference({3})) id: firstDate,
      },
    );
    final updated = state.applyCommittedChanges(
      groups: [editedA, groupB],
      folders: state.folders,
      revision: 42,
    );

    expect(identical(updated.records, state.records), isTrue);
    expect(identical(updated.byId, state.byId), isTrue);
    expect(identical(updated.idByContent, state.idByContent), isTrue);
    expect(identical(updated.byId[1], state.byId[1]), isTrue);
    expect(updated.membershipsByBookmarkId[3], {poolGroupB});
    expect(
      identical(
        updated.membershipsByBookmarkId[0],
        state.membershipsByBookmarkId[0],
      ),
      isTrue,
    );
    expect(
      identical(
        updated.membershipsByBookmarkId[1],
        state.membershipsByBookmarkId[1],
      ),
      isTrue,
    );
    expect(updated.groupsById[poolGroupA]!.addedAt.containsKey(3), isFalse);
    expect(updated.groupsById[poolGroupB]!.addedAt[3], secondDate);
    expect(updated.revision, 42);
    expect(identical(updated.items, state.items), isTrue);
  });

  test('revision-only change reuses every record and membership index', () {
    final updated = state.applyCommittedChanges(
      groups: state.groups,
      folders: state.folders,
      revision: 42,
    );

    expect(identical(updated, state), isFalse);
    expect(updated.revision, 42);
    expect(identical(updated.records, state.records), isTrue);
    expect(identical(updated.byId, state.byId), isTrue);
    expect(identical(updated.idByContent, state.idByContent), isTrue);
    expect(
      identical(
        updated.membershipsByBookmarkId,
        state.membershipsByBookmarkId,
      ),
      isTrue,
    );
    expect(identical(updated.items, state.items), isTrue);
    expect(identical(updated.groups, state.groups), isTrue);
    expect(identical(updated.folders, state.folders), isTrue);
    expect(identical(updated.pools, state.pools), isTrue);
  });

  test('canonical records stay in numeric order for cold load and interleaved inserts', () {
    final cold = BookmarkLibraryState(
      bookmarks: [post, unaddressablePost],
      records: records.reversed.toList(),
      groups: [groupA, groupB],
      revision: 41,
    );
    expect(cold.records.map((record) => record.id), [0, 1, 2, 3, 4]);

    BookmarkGroup withoutId4(BookmarkGroup group) => group.copyWith(
      bookmarkIds: group.bookmarkIds.difference({4}),
      addedAt: {
        for (final entry in group.addedAt.entries)
          if (entry.key != 4) entry.key: entry.value,
      },
    );
    final partialA = withoutId4(groupA);
    final partialB = withoutId4(groupB);
    final partial = BookmarkLibraryState(
      bookmarks: [post],
      records: records.where((record) => record.id != 4).toList(),
      groups: [partialA, partialB],
      revision: 41,
    );
    final id6 = testPoolPost(9).copyWith(id: 6);
    final warm = partial.applyCommittedChanges(
      upserts: [id6, unaddressablePost],
      groups: [partialA, partialB],
      folders: partial.folders,
      revision: 42,
    );
    expect(warm.records.map((record) => record.id), [0, 1, 2, 3, 4, 6]);
    expect(warm.byId[4], unaddressablePost);
    expect(warm.byId[6], id6);
  });

  test('delta rejects a cross-engine content collision without changing source state', () {
    final conflicting = nativePool(id: 5, engine: BooruType.szurubooru);
    expect(
      () => state.applyCommittedChanges(
        upserts: [conflicting],
        groups: state.groups,
        folders: state.folders,
        revision: 42,
      ),
      throwsFormatException,
    );
    expect(state.records, records);
    expect(state.byId.keys.toSet(), {0, 1, 2, 3, 4});
    expect(state.idByContent[savedPool.reference.identity], 1);
  });

  test(
    'Group metadata upserts leave media projection and other records untouched',
    () {
      final changedPool = savedPool.copyWith(
        snapshot: savedPool.snapshot.withSummary(
          ContentGroupSummary(
            reference: savedPool.reference,
            title: 'Updated pool title',
          ),
        ),
      );
      final updated = state.applyCommittedChanges(
        upserts: [changedPool],
        groups: [groupA, groupB],
        folders: state.folders,
        revision: 43,
      );

      expect(identical(updated.items, state.items), isTrue);
      expect(identical(updated.byId[0], state.byId[0]), isTrue);
      expect(identical(updated.byId[1], changedPool), isTrue);
      expect(identical(updated.byId[2], state.byId[2]), isTrue);
      expect(identical(updated.byId[3], state.byId[3]), isTrue);
      expect(identical(updated.byId[4], state.byId[4]), isTrue);
      expect(updated.groupsById[poolGroupA]!.addedAt, groupA.addedAt);
      expect(updated.groupsById[poolGroupB]!.addedAt, groupB.addedAt);
      expect(updated.idByContent[savedPool.reference.identity], 1);
      expect(
        updated.pools.singleWhere((pool) => pool.bookmarkId == 1).title,
        'Updated pool title',
      );
      expect(
        updated.pools.singleWhere((pool) => pool.bookmarkId == 1).tags,
        isEmpty,
      );
      expect(updated.revision, 43);
    },
  );

  test('remove and Undo remap preserve legacy source evidence and membership dates', () {
    final removedA = groupA.copyWith(
      bookmarkIds: groupA.bookmarkIds.difference({3}),
      addedAt: {
        for (final id in groupA.bookmarkIds.difference({3})) id: firstDate,
      },
    );
    final removedB = groupB.copyWith(
      bookmarkIds: groupB.bookmarkIds.difference({3}),
      addedAt: {
        for (final id in groupB.bookmarkIds.difference({3})) id: secondDate,
      },
    );
    final removed = state.applyCommittedChanges(
      removedIds: {3},
      groups: [removedA, removedB],
      folders: state.folders,
      revision: 44,
    );
    expect(removed.byId.containsKey(3), isFalse);
    expect(removed.idByContent, state.idByContent);

    final restoredRecord = savedLegacy.copyWith(id: 5);
    final restoredA = removedA.copyWith(
      bookmarkIds: {...removedA.bookmarkIds, 5},
      addedAt: {...removedA.addedAt, 5: firstDate},
    );
    final restoredB = removedB.copyWith(
      bookmarkIds: {...removedB.bookmarkIds, 5},
      addedAt: {
        ...removedB.addedAt,
        5: secondDate,
      },
    );
    final restored = removed.applyCommittedChanges(
      upserts: [restoredRecord],
      groups: [restoredA, restoredB],
      folders: state.folders,
      revision: 45,
    );

    expect(restored.byId.keys.toSet(), {0, 1, 2, 4, 5});
    final remapped = restored.byId[5] as LegacyGroupBookmark;
    expect(remapped.metadata.origin, savedLegacy.metadata.origin);
    expect(remapped.metadata.sourceTypeId, savedLegacy.metadata.sourceTypeId);
    expect(remapped.metadata.referenceId, savedLegacy.metadata.referenceId);
    expect(remapped.metadata.title, savedLegacy.metadata.title);
    expect(remapped.metadata.tags, savedLegacy.metadata.tags);
    expect(remapped.createdAt, savedLegacy.createdAt);
    expect(restored.membershipsByBookmarkId[5], {poolGroupA, poolGroupB});
    expect(restored.groupsById[poolGroupA]!.addedAt[5], firstDate);
    expect(restored.groupsById[poolGroupB]!.addedAt[5], secondDate);
    expect(restored.groupsById[poolGroupA]!.addedAt.containsKey(3), isFalse);
    expect(restored.groupsById[poolGroupB]!.addedAt.containsKey(3), isFalse);
    expect(restored.idByContent.containsValue(3), isFalse);
    expect(restored.byId[4], unaddressablePost);
  });

  test(
    'constructor rejects duplicate IDs and known content identity collisions',
    () {
      BookmarkLibraryState create(List<Bookmark> values) =>
          BookmarkLibraryState(
            bookmarks: [post, unaddressablePost],
            records: values,
            groups: [groupA, groupB],
          );

      expect(
        () => create([...records, savedLegacy.copyWith(id: 1)]),
        throwsFormatException,
      );
      expect(
        () => create([...records, savedPool.copyWith(id: 5)]),
        throwsFormatException,
      );
      expect(
        () => create([
          ...records,
          nativePool(id: 5, engine: BooruType.szurubooru),
        ]),
        throwsFormatException,
        reason: 'Same namespace/key interpreted by two engines is ambiguous.',
      );
    },
  );

  test('Post lookup rejects another engine with the same key and retains exact unknown snapshots', () {
    final otherEnginePost = TestPost(
      id: 7,
      origin: PostOrigin.fromSource(
        booruType: BooruType.szurubooru,
        booruId: BooruType.szurubooru.id,
        source: 'https://danbooru.donmai.us',
      ),
      booruData: const LegacyPostData(
        typeKey: 'legacy_szurubooru',
        custom: {},
      ),
    );
    expect(
      state.isBookmarked(otherEnginePost, BooruType.szurubooru.id),
      isFalse,
    );
    expect(state.bookmarkForPost(otherEnginePost), isNull);

    final retainedPost = TestPost(
      id: 777,
      origin: PostOrigin.fromSource(
        booruType: BooruType.unknown,
        booruId: BooruType.unknown.id,
        source: 'http://legacy.example/install',
      ),
      booruData: const LegacyPostData(
        typeKey: 'retained_unknown_engine',
        custom: {'archive': 'original'},
      ),
    );
    final retainedBookmark = PostBookmark.fromSnapshot(
      id: 5,
      createdAt: DateTime.utc(2018, 3, 4),
      updatedAt: DateTime.utc(2020, 5, 6),
      snapshot: const StoredPostCodec().encode(retainedPost),
      post: retainedPost,
      postId: null,
    );
    final withRetainedPost = BookmarkLibraryState(
      bookmarks: [post, unaddressablePost, retainedBookmark],
      records: [...records, retainedBookmark],
      groups: [groupA, groupB],
      revision: 42,
    );
    expect(withRetainedPost.idByContent.containsValue(5), isFalse);
    expect(withRetainedPost.bookmarkForPost(retainedPost), isNull);
    expect(
      withRetainedPost.storedBookmarkForPost(retainedPost),
      same(retainedBookmark),
    );
    final unrelatedUnknownPost = TestPost(
      id: retainedPost.id,
      origin: retainedPost.origin,
      booruData: retainedPost.booruData,
    );
    expect(
      withRetainedPost.storedBookmarkForPost(unrelatedUnknownPost),
      isNull,
    );
  });
}
