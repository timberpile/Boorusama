import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root = '11111111-1111-4111-8111-111111111111';
  const child = '22222222-2222-4222-8222-222222222222';
  const emptyChild = '33333333-3333-4333-8333-333333333333';
  const collidingId = '44444444-4444-4444-8444-444444444444';

  final postAtRoot = PostBookmark.empty.copyWith(
    id: 1,
    originalUrl: 'https://example.com/1.jpg',
  );
  final postInChild = PostBookmark.empty.copyWith(
    id: 2,
    originalUrl: 'https://example.com/2.jpg',
  );
  final postOutside = PostBookmark.empty.copyWith(
    id: 4,
    originalUrl: 'https://example.com/4.jpg',
  );
  final savedGroup = ContentGroupBookmark(
    id: 3,
    snapshot: StoredGroupSnapshot(
      summary: ContentGroupSummary(
        reference: const ContentReferenceCodec().parse(
          engine: BooruType.danbooru,
          site: Uri.parse('https://danbooru.donmai.us/install'),
          kind: ContentKind.group,
          sourceKey: 'pool:42',
        ),
      ),
      index: null,
    ),
    createdAt: DateTime.utc(2021),
    observedAt: DateTime.utc(2024),
  );
  final records = <Bookmark>[postAtRoot, postInChild, savedGroup, postOutside];
  final groups = [
    BookmarkGroup(
      id: root,
      name: 'Root',
      bookmarkIds: {postAtRoot.id},
      addedAt: {postAtRoot.id: DateTime.utc(2020)},
    ),
    BookmarkGroup(
      id: child,
      name: 'Child',
      parentGroupId: root,
      bookmarkIds: {postInChild.id, savedGroup.id},
      addedAt: {
        postInChild.id: DateTime.utc(2021),
        savedGroup.id: DateTime.utc(2022),
      },
    ),
    BookmarkGroup(
      id: emptyChild,
      name: 'Empty child',
      parentGroupId: root,
      bookmarkIds: const {},
    ),
  ];

  test('canonical export consumes common records without interpreting numeric-ID compatibility Pool views', () {
    final state = BookmarkLibraryState(
      bookmarks: const [],
      records: records,
      groups: groups,
    );
    expect(state.pools.single.localId, '${savedGroup.id}');
    final data = buildBookmarkBackupData(
      records: state.records,
      bookmarks: state.items,
      pools: state.pools,
      groups: state.groups,
      scope: const BookmarkExportScope.all(),
    );
    expect(data.records, records);
    expect(
      data.records.whereType<ContentGroupBookmark>().single,
      same(savedGroup),
    );
  });

  test('selected child exports empty ancestors without ancestor members', () {
    final data = buildBookmarkBackupData(
      records: records,
      groups: groups,
      scope: BookmarkExportScope.selected(groupIds: {child}),
    );

    expect(data.records.map((record) => record.id), [2, 3]);
    expect(data.records.map((record) => record.runtimeType), [
      PostBookmark,
      ContentGroupBookmark,
    ]);
    expect(data.groups.map((group) => group.id), [root, child]);
    expect(data.groups.first.bookmarkIds, isEmpty);
    expect(data.groups.last.bookmarkIds, [2, 3]);
    expect(data.groups.first.parentGroupId, isNull);
    expect(data.groups.last.parentGroupId, root);
  });

  test(
    'selected parent exports its subtree once and retains empty structure',
    () {
      final data = buildBookmarkBackupData(
        records: records,
        groups: groups,
        scope: BookmarkExportScope.selected(groupIds: {root}),
      );

      expect(data.records.map((record) => record.id), [1, 2, 3]);
      expect(data.records.map((record) => record.id).toSet(), {1, 2, 3});
      expect(data.groups.map((group) => group.id), [root, child, emptyChild]);
      expect(data.groups[0].bookmarkIds, [1]);
      expect(data.groups[1].bookmarkIds, [2, 3]);
      expect(data.groups[2].bookmarkIds, isEmpty);
      expect(data.groups.map((group) => group.parentGroupId), [
        null,
        root,
        root,
      ]);
    },
  );

  test(
    'legacy folder scope resolves its remapped ID, not a colliding group',
    () {
      final data = buildBookmarkBackupData(
        records: [postAtRoot],
        groups: [
          BookmarkGroup(
            id: collidingId,
            name: 'Existing group',
            bookmarkIds: {postAtRoot.id},
            addedAt: {postAtRoot.id: DateTime.utc(2020)},
          ),
        ],
        folders: const [
          CollectionFolder(id: collidingId, name: 'Converted folder'),
        ],
        scope: BookmarkExportScope.selected(
          groupIds: const [],
          folderIds: {collidingId},
        ),
      );

      expect(data.records, isEmpty);
      expect(data.groups, hasLength(1));
      expect(data.groups.single.id, isNot(collidingId));
      expect(data.groups.single.name, 'Converted folder');
      expect(data.groups.single.bookmarkIds, isEmpty);
    },
  );
}
