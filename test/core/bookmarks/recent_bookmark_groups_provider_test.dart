import 'dart:io';

import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/boorus/nhentai/galleries/mapper.dart';
import 'package:boorusama/boorus/nhentai/posts/data.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/recent_bookmark_groups_provider.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../boorus/nhentai/fixtures.dart';
import '../../support/fakes/memory_repositories.dart';

void main() {
  test('production scoped Recent observes native Gallery/Page saves and survives Hive restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'recent-bookmark-provider-',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    final containers = <ProviderContainer>[];
    late BookmarkHiveRepository records;
    late BookmarkGroupRepository groups;
    late DataMutationCoordinator coordinator;
    Future<void> open() async {
      coordinator = DataMutationCoordinator();
      final posts = await Hive.openBox<BookmarkHiveObject>('posts');
      final payloads = await Hive.openBox<dynamic>('payloads');
      final metadata = await Hive.openBox<dynamic>('metadata');
      await Hive.openBox<BookmarkGroupHiveObject>('groups');
      final organization = await Hive.openBox<dynamic>('organization');
      if (!organization.containsKey('version')) {
        await organization.put('version', 1);
        await organization.put('poolBookmarks', []);
      }
      records = BookmarkHiveRepository(
        posts,
        groupPayloadBox: payloads,
        metadataBox: metadata,
        coordinator: coordinator,
        postDataCodec: (type) =>
            type == BooruType.nhentai ? const NhentaiPostCodec() : null,
        legacyGroupBoxName: 'groups',
        legacyOrganizationBoxName: 'organization',
      );
      groups = await records.openOrganization();
    }

    ProviderContainer scope() {
      final parent = ProviderContainer(
        overrides: [
          miscDataStoreProvider.overrideWithValue(MemoryMiscDataStore()),
        ],
      );
      // Use the real library and Recent providers in a child scope. Only their
      // storage handles are injected; neither provider is replaced by a fake.
      final child = ProviderContainer(
        parent: parent,
        overrides: [
          dataMutationCoordinatorProvider.overrideWithValue(coordinator),
          bookmarkRepoProvider.overrideWith((_) => records),
          bookmarkGroupRepoProvider.overrideWith((_) => groups),
        ],
      );
      containers.addAll([parent, child]);
      return child;
    }

    addTearDown(() async {
      for (final container in containers.reversed) {
        container.dispose();
      }
      await Hive.close();
      await directory.delete(recursive: true);
    });
    await open();
    var container = scope();
    await container.read(bookmarkProvider.future);
    final listen = container.listen(recentBookmarkGroupsProvider, (_, _) {});
    addTearDown(listen.close);
    final dto = NhentaiGalleryDetails.fromJson(galleryJson());
    final details = nhentaiGalleryDetails(
      dto,
      galleryAccess(),
      galleryPolicy(),
    );
    final gallery = ContentGroupBookmark(
      id: 0,
      snapshot: StoredGroupSnapshot(summary: details.summary, details: details),
      createdAt: DateTime.utc(2026),
      observedAt: DateTime.utc(2026),
    );
    await container
        .read(bookmarkProvider.notifier)
        .createGroupWithContentDraft('Gallery target', gallery);
    final galleryId = (await groups.getRecentGroupIds()).single;
    final page = nhentaiGalleryPosts(
      dto,
      galleryAccess(),
      galleryPolicy(),
    ).first;
    final savedPage = (await records.addBookmarkWithBookmarks([
      PostBookmark.fromSnapshot(
        id: 0,
        createdAt: DateTime.utc(2025),
        updatedAt: DateTime.utc(2026),
        postId: page.id,
        post: page,
        snapshot: const StoredPostCodec().encode(
          page,
          dataCodec: const NhentaiPostCodec(),
        ),
      ),
    ])).single;
    await container.read(bookmarkProvider.notifier).refresh();
    final created = await container
        .read(bookmarkProvider.notifier)
        .createGroupWithSavedRecords('Page target', [savedPage]);
    final expected = [created.group.id, galleryId];
    expect(await groups.getRecentGroupIds(), expected);
    expect(
      (await container.read(recentBookmarkGroupsProvider.future))
          .map((group) => group.id),
      expected,
    );
    expect(container.read(recentBookmarkGroupsProvider).hasError, isFalse);
    expect(
      (await container.read(recentBookmarkGroupsProvider.future))
          .map((group) => group.name),
      ['Page target', 'Gallery target'],
    );
    listen.close();
    for (final previous in containers.reversed) {
      previous.dispose();
    }
    containers.clear();
    await Hive.close();
    await open();
    container = scope();
    await container.read(bookmarkProvider.future);
    expect(await groups.getRecentGroupIds(), expected);
    expect(
      (await container.read(recentBookmarkGroupsProvider.future))
          .map((group) => group.id),
      expected,
    );
    expect(container.read(recentBookmarkGroupsProvider).hasError, isFalse);
  });
}
