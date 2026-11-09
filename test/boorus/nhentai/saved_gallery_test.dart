import 'dart:io';

import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/boorus/nhentai/galleries/mapper.dart';
import 'package:boorusama/boorus/nhentai/posts/data.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_profile_availability.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_grid_entry.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../support/fakes/bookmark_test_storage.dart';
import 'fixtures.dart';

StoredGroupSnapshot snapshot(Map<String, dynamic> json) {
  final details = nhentaiGalleryDetails(
    NhentaiGalleryDetails.fromJson(json),
    galleryAccess(),
    galleryPolicy(),
  );
  return StoredGroupSnapshot(
    summary: details.summary,
    details: details,
    index: details.tags == null
        ? null
        : GroupBookmarkIndex(
            tags: {
              for (final tag in details.tags!.values)
                if (tag.name != null) tag.name!,
            },
            basis: GroupTagIndexBasis.sourceGroup,
            coverage: details.tags!.coverage,
          ),
  );
}

void main() {
  test('real saved Gallery/Page records, filtering, missing tags and empty tags survive restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'nhentai-saved-gallery-',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    Future<BookmarkLibraryService> open() async {
      final posts = await Hive.openBox<BookmarkHiveObject>('posts');
      final groups = await Hive.openBox<BookmarkGroupHiveObject>('groups');
      final organization = await Hive.openBox<dynamic>('organization');
      final storage = await BookmarkTestStorage.open(posts);
      final repository = storage.repository(
        posts,
        postDataCodec: (type) =>
            type == BooruType.nhentai ? const NhentaiPostCodec() : null,
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

    var service = await open();
    await service.load();
    final wholeGroup = await service.createGroup('Galleries');
    final pageGroup = await service.createGroup('Pages');
    final at = DateTime.utc(2026, 11, 8);
    final whole = ContentGroupBookmark(
      id: 0,
      snapshot: snapshot(
        galleryJson(
          tags: [
            {'id': 5, 'type': 'tag', 'name': 'fixture'},
            {'id': 6, 'type': 'tag', 'name': 'retained'},
          ],
        ),
      ),
      createdAt: at,
      observedAt: at,
    );
    await service.saveDraftsToGroup([whole], wholeGroup.id);
    var library = await service.load();
    final gallery = library.records.whereType<ContentGroupBookmark>().single;
    expect(
      library.pools,
      isEmpty,
      reason: 'A Gallery is never projected as a Pool',
    );
    expect(
      library.items,
      isEmpty,
      reason: 'Saving a Gallery never saves Pages',
    );
    final page = nhentaiGalleryPosts(
      NhentaiGalleryDetails.fromJson(galleryJson()),
      galleryAccess(),
      galleryPolicy(),
    ).last;
    final pageDraft = PostBookmark.fromSnapshot(
      id: 0,
      createdAt: at,
      updatedAt: at,
      snapshot: const StoredPostCodec().encode(
        page,
        dataCodec: const NhentaiPostCodec(),
      ),
      post: page,
      postId: page.id,
    );
    await service.saveDraftsToGroup([pageDraft], pageGroup.id);
    library = await service.load();
    expect(library.records, hasLength(2));
    final availability = BookmarkProfileAvailability(
      library,
      const [],
      supportsGroup: (_) => true,
    );
    expect(availability.nativeGroupIds, {gallery.id});
    expect(availability.recordIds, containsAll(library.byId.keys));
    final entries = selectBookmarkGridEntries(
      state: library,
      view: const BookmarkView.all(),
      selectedTags: const [],
      sortType: BookmarkSortType.newest,
      availableNativeGroupIds: availability.nativeGroupIds,
    );
    expect(
      entries.whereType<BookmarkNativeGroupEntry>().single.bookmark.id,
      gallery.id,
    );
    expect(entries.whereType<BookmarkPostEntry>(), hasLength(1));
    expect(
      selectNativeGroupBookmarks(
        state: library,
        view: BookmarkView.group(wholeGroup.id),
        selectedTags: ['fixture'],
      ),
      hasLength(1),
    );
    expect(
      selectNativeGroupBookmarks(
        state: library,
        view: BookmarkView.group(pageGroup.id),
        selectedTags: const [],
      ),
      isEmpty,
    );
    expect(
      selectNativeGroupBookmarks(
        state: library,
        view: const BookmarkView.all(),
        selectedTags: ['missing'],
      ),
      isEmpty,
    );
    expect(
      selectNativeGroupBookmarks(
        state: library,
        view: const BookmarkView.all(),
        selectedTags: ['-fixture'],
      ),
      isEmpty,
    );
    expect(
      selectNativeGroupBookmarks(
        state: library,
        view: const BookmarkView.all(),
        selectedTags: const [],
        selectedBooruUrl: 'nhentai.net.evil.test',
      ),
      isEmpty,
    );

    final initial = library.byId[gallery.id]! as ContentGroupBookmark;
    expect(initial.snapshot.details!.tags!.coverage, MetadataCoverage.complete);
    await service.updateGroupSnapshot(
      gallery.id,
      snapshot(galleryJson(tags: [null])),
    );
    library = await service.load();
    final malformed = library.byId[gallery.id]! as ContentGroupBookmark;
    expect(
      malformed.snapshot.details!.tags!.coverage,
      MetadataCoverage.partial,
    );
    expect(
      malformed.snapshot.details!.tags!.values.map((tag) => tag.name).toSet(),
      {'fixture', 'retained'},
    );
    expect(malformed.snapshot.index!.coverage, MetadataCoverage.partial);
    expect(malformed.snapshot.index!.tags, {'fixture', 'retained'});
    await service.updateGroupSnapshot(
      gallery.id,
      snapshot(
        galleryJson(
          tags: [
            {'id': 5, 'type': 'tag', 'name': 'renamed'},
            null,
          ],
        ),
      ),
    );
    library = await service.load();
    var saved = library.byId[gallery.id]! as ContentGroupBookmark;
    expect(
      saved.snapshot.details!.tags!.values.map((tag) => tag.name).toSet(),
      {'renamed', 'retained'},
    );
    expect(saved.snapshot.details!.tags!.coverage, MetadataCoverage.partial);
    expect(saved.snapshot.index!.tags, {'renamed', 'retained'});
    expect(saved.snapshot.index!.coverage, MetadataCoverage.partial);
    await service.updateGroupSnapshot(
      gallery.id,
      snapshot(galleryJson(omitTags: true)),
    );
    library = await service.load();
    saved = library.byId[gallery.id]! as ContentGroupBookmark;
    expect(
      saved.snapshot.details!.tags!.values.map((tag) => tag.name).toSet(),
      {'renamed', 'retained'},
    );
    expect(saved.snapshot.index!.tags, {'renamed', 'retained'});
    await service.updateGroupSnapshot(
      gallery.id,
      snapshot(galleryJson(tags: [])),
    );
    library = await service.load();
    saved = library.byId[gallery.id] as ContentGroupBookmark;
    expect(saved.snapshot.details!.tags!.coverage, MetadataCoverage.complete);
    expect(saved.snapshot.details!.tags!.values, isEmpty);
    expect(saved.snapshot.index!.tags, isEmpty);

    final savedPage = library.records.whereType<PostBookmark>().single;
    final removed = await service.removeBookmarksFromGroup([
      savedPage,
    ], pageGroup.id);
    expect((await service.load()).records, hasLength(1));
    await service.undoRemoval(removed);
    expect((await service.load()).records, hasLength(2));
    await Hive.close();
    Hive.init(directory.path);
    service = await open();
    library = await service.load();
    expect(
      library.records.whereType<ContentGroupBookmark>().single.id,
      gallery.id,
    );
    expect(
      library.records
          .whereType<ContentGroupBookmark>()
          .single
          .snapshot
          .details!
          .tags!
          .values,
      isEmpty,
    );
    final restoredPage = library.records.whereType<PostBookmark>().single;
    expect((restoredPage.post.booruData as NhentaiPostData).pageNumber, 3);
    expect(restoredPage.post.originalImageUrl, page.originalImageUrl);
    expect(library.groupsById[wholeGroup.id]!.bookmarkIds, {gallery.id});
    expect(library.groupsById[pageGroup.id]!.bookmarkIds, {restoredPage.id});
  });
}
