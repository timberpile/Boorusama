import 'dart:io';

import 'package:boorusama/boorus/pixiv/posts/post_codec.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/boorus/pixiv/works/bookmark_targets.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../../support/fakes/bookmark_test_storage.dart';
import 'work_test_fixtures.dart';

void main() {
  test('real unified storage keeps Work/Page membership, removal and Undo independent after restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pixiv-work-bookmark-',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    Future<BookmarkLibraryService> service() async {
      final posts = await Hive.openBox<BookmarkHiveObject>('posts');
      final groups = await Hive.openBox<BookmarkGroupHiveObject>('groups');
      final organization = await Hive.openBox<dynamic>('organization');
      final storage = await BookmarkTestStorage.open(posts);
      final repository = storage.repository(
        posts,
        postDataCodec: (type) =>
            type == BooruType.pixiv ? const PixivPostCodec() : null,
      );
      final reader = await BookmarkStorageMigration(
        bookmarks: repository,
        legacyGroups: groups,
        legacyOrganization: organization,
        metadata: storage.metadataBox,
      ).open();
      return BookmarkLibraryService(
        bookmarkRepository: repository,
        groupRepository: UnifiedBookmarkGroupRepository(
          bookmarks: repository,
          reader: reader,
        ),
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      );
    }

    var library = await service();
    await library.load();
    final a = await library.createGroup('Works');
    final b = await library.createGroup('Pages');
    final access = workAccess();
    final dto = work();
    final at = DateTime.utc(2026, 1, 2);
    final whole = PixivWorkBookmarkTarget(
      access: access,
      summary: pixivWorkSummary(dto, access),
      details: pixivWorkDetails(dto, access),
    ).draft(currentAccess: access, at: at);
    final page = PixivPageBookmarkTarget(
      access: access,
      post: pixivWorkPagePosts(dto, access).last,
    ).draft(currentAccess: access, at: at);
    await library.saveDraftsToGroup([whole], a.id);
    var state = await library.load();
    expect(state.records, hasLength(1));
    expect(state.records.single, isA<ContentGroupBookmark>());
    expect(state.items, isEmpty);
    await library.saveDraftsToGroup([page], b.id);
    state = await library.load();
    final savedWork = state.records.whereType<ContentGroupBookmark>().single;
    final savedPage = state.records.whereType<PostBookmark>().single;
    expect(savedWork.id, isNot(savedPage.id));
    expect(state.groupsById[a.id]!.bookmarkIds, {savedWork.id});
    expect(state.groupsById[b.id]!.bookmarkIds, {savedPage.id});
    final membershipAt = state.groupsById[a.id]!.addedAt[savedWork.id];
    await library.saveDraftsToGroup([whole], b.id);
    state = await library.load();
    expect(state.records, hasLength(2));
    expect(state.groupsById[b.id]!.bookmarkIds, {savedWork.id, savedPage.id});
    expect(state.groupsById[a.id]!.addedAt[savedWork.id], membershipAt);
    final removal = await library.removeBookmarksFromGroup([savedPage], b.id);
    state = await library.load();
    expect(state.records, hasLength(1));
    expect(state.byId[savedWork.id], isA<ContentGroupBookmark>());
    await library.undoRemoval(removal);
    state = await library.load();
    final undoPage = state.records.whereType<PostBookmark>().single;
    expect(undoPage.id, greaterThan(savedPage.id));
    await Hive.close();
    Hive.init(directory.path);
    library = await service();
    state = await library.load();
    final restoredPage = state.records.whereType<PostBookmark>().single;
    expect(restoredPage.id, undoPage.id);
    expect(restoredPage.post.illustId, 120);
    expect(restoredPage.post.pageIndex, 2);
    expect(state.groupsById[a.id]!.bookmarkIds, {savedWork.id});
    expect(state.groupsById[a.id]!.addedAt[savedWork.id], membershipAt);
    expect(state.groupsById[b.id]!.bookmarkIds, {savedWork.id, undoPage.id});
    final restoredWork = state.records.whereType<ContentGroupBookmark>().single;
    expect(restoredWork.reference.sourceKey, 'work:120');
    expect(
      restoredWork.snapshot.details!.description!.text,
      '<p>Work caption</p>',
    );
  });
}
