import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_cover.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/related/related_family.dart';
import 'package:flutter_test/flutter_test.dart';

import 'server_favorites/test_support.dart';

void main() {
  late FavoriteHarness h;
  setUp(() async {
    h = FavoriteHarness();
    await h.open();
  });
  tearDown(() => h.close());

  test(
    'mixed disk fixture preserves IDs, dates, folders and unknown legacy media',
    () async {
      var library = h.container.read(bookmarkLibraryProvider.notifier);
      final a = await library.createGroup('A');
      final b = await library.createGroup('B');
      final outer = await library.createFolder('Outer');
      final inner = await library.createFolder('Inner', parentId: outer.id);
      await library.moveFolderItems(groupIds: {a.id}, destination: inner.id);
      await library.moveFolderItems(groupIds: {b.id}, destination: outer.id);
      await library.addPostsToGroup(h.profile.auth, [h.post(7)], a.id);
      await library.addPostsToGroup(h.profile.auth, [h.post(7)], b.id);
      final post = (await library.snapshotForExport()).items.single;
      expect(
        post.id,
        0,
        reason: 'The first durable local Post ID includes zero',
      );
      final created = DateTime.utc(2025, 1, 1);
      final firstAdded = DateTime.utc(2025, 2, 1);
      final secondAdded = DateTime.utc(2025, 3, 1);
      await h.groups.replaceMemberships(
        a.id,
        {post.id},
        addedAt: {post.id: firstAdded},
      );
      await h.groups.replaceMemberships(
        b.id,
        {post.id},
        addedAt: {post.id: secondAdded},
      );
      final origin = postOriginFromConfig(h.profile);
      final cover = PoolBookmarkCover(
        thumbnail: 'https://fixture.test/thumb.jpg',
        sample: 'https://fixture.test/sample.jpg',
        original: 'https://fixture.test/original.jpg',
        variants: const {'thumbnail': 'https://fixture.test/thumb.jpg'},
      );
      await h.groups.writePoolBookmarks([
        PoolBookmark(
          localId: '00000000-0000-4000-8000-000000000042',
          poolId: 42,
          origin: origin,
          category: BookmarkedPoolCategory.series,
          title: 'Cached series',
          createdAt: created,
          observedAt: secondAdded,
          groupIds: {a.id, b.id},
          addedAt: {a.id: firstAdded, b.id: secondAdded},
          tags: const {'sampled_tag'},
          coverage: PoolTagCoverage.partial,
          cover: cover,
          coverPolicy: 'fixture-restricted-policy',
          total: 20,
          oldestUpload: created,
          newestUpload: secondAdded,
        ),
        RelatedBookmark(
          localId: '00000000-0000-4000-8000-000000000099',
          family: RelatedFamilyReference(origin: origin, anchorId: 99),
          createdAt: created,
          observedAt: firstAdded,
          groupIds: {a.id},
          addedAt: {a.id: firstAdded},
        ),
      ]);
      // Restore a validated unaddressable snapshot through the central allocator.
      // Ordinary UI creation still requires a stable upstream identity.
      final legacy = PostBookmark.empty.copyWith(
        createdAt: created,
        updatedAt: created,
        originalUrl: 'https://fixture.test/legacy.jpg',
        sourceUrl: '',
        postId: () => null,
      );
      final legacyId = (await h.bookmarks.reserveIds(1)).single;
      await h.bookmarks.upsert(legacy.copyWith(id: legacyId));
      await h.restart();
      library = h.container.read(bookmarkLibraryProvider.notifier);
      final before = await library.snapshotForExport();
      expect(before.items.map((entry) => entry.id), [0, 1]);
      expect(before.items.last.uniqueId, isA<UnbookmarkablePostIdentity>());
      expect(
        before.bookmarksByUniqueId.values.map((entry) => entry.id),
        isNot(contains(1)),
      );
      expect(before.groupsById[defaultBookmarkGroupId]!.bookmarkIds, {1});
      expect(before.groupsById[a.id]!.addedAt, {0: firstAdded});
      expect(before.groupsById[b.id]!.addedAt, {0: secondAdded});
      expect(before.groupsById[a.id]!.folderId, inner.id);
      expect(
        before.folders.singleWhere((folder) => folder.id == inner.id).parentId,
        outer.id,
      );
      expect(before.pools, hasLength(2));
      expect(before.pools.first.coverage, PoolTagCoverage.partial);
      expect(before.pools.first.coverPolicy, 'fixture-restricted-policy');
      expect(before.pools.first.addedAt, {a.id: firstAdded, b.id: secondAdded});
      final settings = h.container.read(
        serverFavoriteSettingsProvider.notifier,
      );
      await settings.setGlobal(a.id);
      await settings.setGlobal(b.id);
      expect(await library.snapshotForExport(), before);
      expect(h.source.calls, 0);
      await h.restart();
      library = h.container.read(bookmarkLibraryProvider.notifier);
      expect(await library.snapshotForExport(), before);
      expect(
        (await h.container.read(serverFavoriteSettingsProvider.future))
            .globalGroupId,
        b.id,
      );

      final service = BookmarkLibraryService(
        bookmarkRepository: h.bookmarks,
        groupRepository: h.groups,
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      );
      final removal = await service.removeBookmarksFromGroup([
        before.items.first,
      ], a.id);
      expect(removal.deletedBookmarks, isEmpty);
      expect((await service.load()).groupsById[b.id]!.addedAt, {
        0: secondAdded,
      });
      await service.undoRemoval(removal);
      await h.restart();
      expect(await h.container.read(bookmarkLibraryProvider.future), before);
      expect(h.source.calls, 0);
    },
  );
}
