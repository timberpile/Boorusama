import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/recent_bookmark_groups_provider.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../support/fakes/memory_repositories.dart';
import 'pool_bookmark_test_utils.dart';

void main() {
  test('production scoped Recent observes saved Group and Post memberships across Hive restart', () async {
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
    final reference = const ContentReferenceCodec().parse(
      engine: BooruType.danbooru,
      site: Uri.parse('https://danbooru.donmai.us'),
      kind: ContentKind.group,
      sourceKey: 'pool:42',
    );
    final groupRecord = ContentGroupBookmark(
      id: (await records.reserveIds(1)).single,
      snapshot: StoredGroupSnapshot(
        summary: ContentGroupSummary(reference: reference, title: 'Pool 42'),
      ),
      createdAt: DateTime.utc(2026),
      observedAt: DateTime.utc(2026),
    );
    await records.upsert(groupRecord);
    await container.read(bookmarkProvider.notifier).refresh();
    await container.read(bookmarkProvider.notifier).createGroupWithSavedRecords(
      'Group target',
      [groupRecord],
    );
    final groupId = (await groups.getRecentGroupIds()).single;
    final savedPost = (await records.addBookmarkWithBookmarks([
      testPoolPost(7),
    ])).single;
    await container.read(bookmarkProvider.notifier).refresh();
    final created = await container
        .read(bookmarkProvider.notifier)
        .createGroupWithSavedRecords('Post target', [savedPost]);
    final expected = [created.group.id, groupId];
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
      ['Post target', 'Group target'],
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
