import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_grid_entry.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pool_bookmark_test_utils.dart';

void main() {
  const root = '11111111-1111-4111-8111-111111111111';
  const child = '22222222-2222-4222-8222-222222222222';
  const grandchild = '33333333-3333-4333-8333-333333333333';
  const siblingBranch = '44444444-4444-4444-8444-444444444444';
  const groupRecordChild = '55555555-5555-4555-8555-555555555555';

  final early = DateTime.utc(2022, 1, 1);
  final middle = DateTime.utc(2023, 1, 1);
  final latest = DateTime.utc(2024, 1, 1);

  late PostBookmark directPost;
  late PostBookmark descendantPost;
  late PostBookmark unaddressablePost;
  late LegacyGroupBookmark opaqueRecord;
  late ContentGroupBookmark descendantGroupRecord;
  late ContentGroupBookmark otherBranchGroupRecord;
  late PostBookmark otherBranchPost;
  late BookmarkLibraryState state;
  late List<BookmarkGroup> groups;

  setUp(() {
    directPost = testPoolPost(1).copyWith(
      id: 1,
      createdAt: DateTime.utc(2019),
    );
    descendantPost = testPoolPost(2).copyWith(
      id: 2,
      createdAt: DateTime.utc(2020),
    );
    unaddressablePost = testPoolPost(3).copyWith(
      id: 3,
      postId: () => null,
      createdAt: DateTime.utc(2021),
    );
    opaqueRecord = LegacyGroupBookmark.fromMetadata(
      id: 4,
      metadata: PoolBookmark(
        localId: 'opaque-pool-4',
        origin: poolOrigin(host: 'legacy.example', type: BooruType.unknown),
        sourceTypeId: 777,
        poolId: 777,
        category: BookmarkedPoolCategory.series,
        title: 'Opaque record',
        createdAt: DateTime.utc(2020),
        observedAt: DateTime.utc(2024),
        groupIds: const {},
        tags: const {'opaque'},
        coverage: PoolTagCoverage.partial,
        total: 1,
      ),
    );
    ContentGroupBookmark groupRecord(int id, String sourceKey) {
      final reference = const ContentReferenceCodec().parse(
        engine: BooruType.danbooru,
        site: Uri.parse('https://danbooru.donmai.us/install'),
        kind: ContentKind.group,
        sourceKey: sourceKey,
      );
      return ContentGroupBookmark(
        id: id,
        snapshot: StoredGroupSnapshot(
          summary: ContentGroupSummary(reference: reference),
        ),
        createdAt: DateTime.utc(2020),
        observedAt: DateTime.utc(2024),
      );
    }

    descendantGroupRecord = groupRecord(6, 'pool:6');
    otherBranchGroupRecord = groupRecord(7, 'pool:7');
    otherBranchPost = testPoolPost(5).copyWith(id: 5);

    groups = [
      BookmarkGroup(
        id: root,
        name: 'Root A',
        bookmarkIds: {directPost.id},
        addedAt: {directPost.id: middle},
      ),
      BookmarkGroup(
        id: child,
        name: 'Child A',
        parentGroupId: root,
        bookmarkIds: {descendantPost.id, unaddressablePost.id},
        addedAt: {
          descendantPost.id: latest,
          unaddressablePost.id: early,
        },
      ),
      BookmarkGroup(
        id: grandchild,
        name: 'Grandchild A',
        parentGroupId: child,
        bookmarkIds: {directPost.id, descendantPost.id, opaqueRecord.id},
        addedAt: {
          directPost.id: early,
          descendantPost.id: middle,
          opaqueRecord.id: latest,
        },
      ),
      BookmarkGroup(
        id: groupRecordChild,
        name: 'Group record child',
        parentGroupId: child,
        bookmarkIds: {descendantGroupRecord.id},
        addedAt: {descendantGroupRecord.id: middle},
      ),
      BookmarkGroup(
        id: siblingBranch,
        name: 'Root B',
        bookmarkIds: {otherBranchPost.id, otherBranchGroupRecord.id},
        addedAt: {
          otherBranchPost.id: latest,
          otherBranchGroupRecord.id: early,
        },
      ),
    ];
    state = BookmarkLibraryState(
      bookmarks: [
        directPost,
        descendantPost,
        unaddressablePost,
        otherBranchPost,
      ],
      records: [
        directPost,
        descendantPost,
        unaddressablePost,
        opaqueRecord,
        descendantGroupRecord,
        otherBranchPost,
        otherBranchGroupRecord,
      ],
      groups: groups,
    );
  });

  test('direct group stays direct while subtree view walks descendants', () {
    final direct = BookmarkView.group(root);
    final subtree = BookmarkView.subtree(root);

    expect(state.bookmarkIdsForView(direct), {directPost.id});
    expect(state.bookmarkIdsForView(subtree), {
      directPost.id,
      descendantPost.id,
      unaddressablePost.id,
      opaqueRecord.id,
      descendantGroupRecord.id,
    });

    final directPosts = selectBookmarks(
      state: state,
      view: direct,
      selectedTags: const [],
      sortType: BookmarkSortType.newestUpload,
    );
    final subtreePosts = selectBookmarks(
      state: state,
      view: subtree,
      selectedTags: const [],
      sortType: BookmarkSortType.newestUpload,
    );
    expect(directPosts.map((bookmark) => bookmark.id), [directPost.id]);
    expect(subtreePosts.map((bookmark) => bookmark.id).toSet(), {
      directPost.id,
      descendantPost.id,
      unaddressablePost.id,
    });
  });

  test('projection deduplicates local IDs and excludes other branches', () {
    final projection = state.subtreeProjection(root);

    expect(projection.includedGroupIds, {
      root,
      child,
      grandchild,
      groupRecordChild,
    });
    expect(projection.bookmarkIds, {
      directPost.id,
      descendantPost.id,
      unaddressablePost.id,
      opaqueRecord.id,
      descendantGroupRecord.id,
    });
    expect(projection.bookmarkIds, isNot(contains(otherBranchPost.id)));
    expect(projection.bookmarkIds, isNot(contains(otherBranchGroupRecord.id)));
    expect(projection.earliestAddedAt, {
      directPost.id: early,
      descendantPost.id: middle,
      unaddressablePost.id: early,
      opaqueRecord.id: latest,
      descendantGroupRecord.id: middle,
    });
    expect(projection.latestAddedAt, {
      directPost.id: middle,
      descendantPost.id: latest,
      unaddressablePost.id: early,
      opaqueRecord.id: latest,
      descendantGroupRecord.id: middle,
    });
  });

  test('subtree sorting uses only membership dates inside the subtree', () {
    final newest = selectBookmarks(
      state: state,
      view: BookmarkView.subtree(root),
      selectedTags: const [],
      sortType: BookmarkSortType.newest,
    );
    final oldest = selectBookmarks(
      state: state,
      view: BookmarkView.subtree(root),
      selectedTags: const [],
      sortType: BookmarkSortType.oldest,
    );

    expect(newest.map((bookmark) => bookmark.id), [
      descendantPost.id,
      directPost.id,
      unaddressablePost.id,
    ]);
    expect(oldest.map((bookmark) => bookmark.id), [
      directPost.id,
      unaddressablePost.id,
      descendantPost.id,
    ]);
    expect(
      bookmarkMembershipDates(
        state: state,
        view: BookmarkView.subtree(root),
        sortType: BookmarkSortType.newest,
      ),
      {
        directPost.id: middle,
        descendantPost.id: latest,
        unaddressablePost.id: early,
        opaqueRecord.id: latest,
        descendantGroupRecord.id: middle,
      },
    );

    expect(
      selectPoolBookmarks(
        state: state,
        view: BookmarkView.subtree(root),
        selectedTags: const [],
      ).map((pool) => pool.bookmarkId),
      [opaqueRecord.id, descendantGroupRecord.id],
    );
    expect(
      selectBookmarkGridEntries(
            state: state,
            view: BookmarkView.subtree(root),
            selectedTags: const [],
            sortType: BookmarkSortType.newestUpload,
          )
          .whereType<BookmarkPostEntry>()
          .map((entry) => entry.bookmark.id)
          .toSet(),
      {directPost.id, descendantPost.id, unaddressablePost.id},
    );
  });

  test('moving a child recomputes both ancestor projections without changing dates', () {
    final before = state.subtreeProjection(root);
    final movedGroups = [
      groups[0],
      groups[1].copyWith(parentGroupId: siblingBranch),
      groups[2],
      groups[3],
      groups[4],
    ];
    final moved = state.applyCommittedChanges(
      groups: movedGroups,
      folders: const [],
    );
    final oldRoot = moved.subtreeProjection(root);
    final newRoot = moved.subtreeProjection(siblingBranch);

    expect(before.bookmarkIds, {
      directPost.id,
      descendantPost.id,
      unaddressablePost.id,
      opaqueRecord.id,
      descendantGroupRecord.id,
    });
    expect(oldRoot.includedGroupIds, {root});
    expect(oldRoot.bookmarkIds, {directPost.id});
    expect(newRoot.includedGroupIds, {
      siblingBranch,
      child,
      grandchild,
      groupRecordChild,
    });
    expect(newRoot.bookmarkIds, {
      descendantPost.id,
      unaddressablePost.id,
      directPost.id,
      opaqueRecord.id,
      otherBranchPost.id,
      descendantGroupRecord.id,
      otherBranchGroupRecord.id,
    });
    expect(moved.groupsById[child]!.addedAt, groups[1].addedAt);
    expect(moved.groupsById[grandchild]!.addedAt, groups[2].addedAt);
    expect(oldRoot.earliestAddedAt[directPost.id], middle);
    expect(newRoot.earliestAddedAt[directPost.id], early);
    expect(newRoot.latestAddedAt[opaqueRecord.id], latest);
  });
}
