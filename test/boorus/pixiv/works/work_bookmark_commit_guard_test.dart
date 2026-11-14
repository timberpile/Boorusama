import 'dart:async';
import 'dart:io';

import 'package:boorusama/boorus/pixiv/posts/post_codec.dart';
import 'package:boorusama/boorus/pixiv/works/bookmark_targets.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_picker_actions.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_picker_request.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../../support/fakes/bookmark_test_storage.dart';
import 'work_test_fixtures.dart';

void main() {
  for (final page in [false, true]) {
    for (final create in [false, true]) {
      for (final revoke in ['dismiss', 'access', 'profile', 'save']) {
        test(
          'real journal rejects $revoke after preparation, Page=$page, create=$create',
          () async {
            final directory = await Directory.systemTemp.createTemp(
              'pixiv-picker-guard-',
            );
            Hive.init(directory.path);
            if (!Hive.isAdapterRegistered(4)) {
              Hive.registerAdapter(BookmarkHiveObjectAdapter());
            }
            if (!Hive.isAdapterRegistered(5)) {
              Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
            }
            final posts = await Hive.openBox<BookmarkHiveObject>('posts');
            final legacyGroups = await Hive.openBox<BookmarkGroupHiveObject>(
              'groups',
            );
            final organization = await Hive.openBox<dynamic>('organization');
            final storage = await BookmarkTestStorage.open(posts);
            final repository = _GatedRepository(posts, storage);
            final reader = await BookmarkStorageMigration(
              bookmarks: repository,
              legacyGroups: legacyGroups,
              legacyOrganization: organization,
              metadata: storage.metadataBox,
            ).open();
            final groups = UnifiedBookmarkGroupRepository(
              bookmarks: repository,
              reader: reader,
            );
            final destination = await groups.createGroup('Destination');
            final access = workAccess();
            final current = StateProvider<ContentAccessContext?>(
              (ref) => access,
            );
            final container = ProviderContainer(
              overrides: [
                ...storage.overrides,
                booruEngineRegistryProvider.overrideWithValue(_CodecRegistry()),
                postLinkGeneratorProvider.overrideWith(
                  (ref, config) => const NoLinkPostLinkGenerator(),
                ),
                bookmarkRepoProvider.overrideWith((ref) async => repository),
                bookmarkGroupRepoProvider.overrideWith((ref) async => groups),
                bookmarkUrlResolverProvider.overrideWith(
                  (ref, id) => const DefaultImageUrlResolver(),
                ),
                booruConfigProvider.overrideWith(
                  () => BooruConfigNotifier(initialConfigs: [access.config!]),
                ),
                settingsNotifierProvider.overrideWith(
                  () => SettingsNotifier(Settings.defaultSettings),
                ),
                contentAccessContextProvider.overrideWith(
                  (ref, key) => ref.watch(current),
                ),
              ],
            );
            addTearDown(() async {
              container.dispose();
              await Hive.close();
              await directory.delete(recursive: true);
            });
            await container.read(bookmarkProvider.future);
            final dto = work();
            final request = page
                ? PostBookmarkPickerRequest(
                    config: access.config!.auth,
                    source: access.config,
                    access: access.key,
                    post: pixivWorkPagePosts(dto, access).last,
                  )
                : ContentGroupBookmarkPickerRequest(
                    source: access.config!,
                    access: access.key,
                    draft: PixivWorkBookmarkTarget(
                      access: access,
                      summary: pixivWorkSummary(dto, access),
                    ).draft(currentAccess: access, at: DateTime.utc(2026)),
                  );
            var active = true;
            final actions = BookmarkPickerActions(
              container: container,
              request: request,
              isActive: () => active,
            );
            final before = await repository.readRevision();
            final beforeGroups = await groups.getGroups();
            repository.arm();
            final pending = create
                ? actions.createGroup(
                    'Must not be created',
                    null,
                    beforeCommit: () {},
                  )
                : actions.toggle(destination.id, onRemoved: (_) {});
            final assertion = expectLater(
              pending,
              revoke == 'save'
                  ? (create
                        ? completes
                        : completion(BookmarkToggleOutcome.added))
                  : page && !create
                  ? completion(BookmarkToggleOutcome.failed)
                  : throwsStateError,
            );
            await repository.started!.future.timeout(
              const Duration(seconds: 30),
            );
            if (create) {
              expect(repository.pendingRecords, hasLength(1));
              expect(
                repository.pendingGroups.single.bookmarkIds,
                {repository.pendingRecords.single.id},
                reason: 'the first commit must contain the new Group and its target',
              );
            }
            switch (revoke) {
              case 'dismiss':
                active = false;
              case 'access':
                container.read(current.notifier).state = null;
              case 'profile':
                container.read(booruConfigProvider.notifier).state = [];
              case 'save':
                break;
            }
            repository.release!.complete();
            await assertion;
            if (revoke == 'save') {
              final records = await repository.readAll();
              expect(records, hasLength(1));
              final record = records.single;
              if (page) {
                expect(record, isA<PostBookmark>());
                expect((record as PostBookmark).post.pageIndex, 2);
              } else {
                expect(record, isA<ContentGroupBookmark>());
                expect(
                  (record as ContentGroupBookmark).reference.sourceKey,
                  'work:120',
                );
              }
              final allGroups = await groups.getGroups();
              final target = create
                  ? allGroups.singleWhere(
                      (group) => group.name == 'Must not be created',
                    )
                  : allGroups.singleWhere(
                      (group) => group.id == destination.id,
                    );
              expect(target.bookmarkIds, {record.id});
              expect(allGroups.length, beforeGroups.length + (create ? 1 : 0));
              return;
            }
            expect(await repository.readAll(), isEmpty);
            expect(await repository.readRevision(), before);
            expect(
              (await groups.getGroup(destination.id))!.bookmarkIds,
              isEmpty,
            );
            expect(await groups.getGroups(), beforeGroups);
          },
        );
      }
    }
  }
}

/// Pause after the real service has prepared IDs and organization, immediately
/// before entering the production repository's durable commit path.
class _GatedRepository extends BookmarkHiveRepository {
  _GatedRepository(super.posts, BookmarkTestStorage storage)
    : super(
        groupPayloadBox: storage.groupPayloadBox,
        metadataBox: storage.metadataBox,
        coordinator: storage.coordinator,
        postDataCodec: (_) => const PixivPostCodec(),
      );
  Completer<void>? started;
  Completer<void>? release;
  List<Bookmark> pendingRecords = const [];
  List<BookmarkGroup> pendingGroups = const [];
  void arm() {
    started = Completer<void>();
    release = Completer<void>();
  }

  @override
  Future<void> commitOrganization({
    Iterable<Bookmark> records = const [],
    Set<int> removeIds = const {},
    List<BookmarkGroup> groups = const [],
    Set<String> removeGroupIds = const {},
    List<CollectionFolder>? folders,
  }) async {
    final gate = release;
    if (gate != null && !gate.isCompleted) {
      pendingRecords = records.toList();
      pendingGroups = groups;
      started!.complete();
      await gate.future;
    }
    await super.commitOrganization(
      records: records,
      removeIds: removeIds,
      groups: groups,
      removeGroupIds: removeGroupIds,
      folders: folders,
    );
  }
}

class _CodecRegistry extends BooruEngineRegistry {
  @override
  BooruPostCapability<BooruPostData>? getPostCapability(BooruType type) =>
      type == BooruType.pixiv
      ? const BooruPostCapability(
          booruType: BooruType.pixiv,
          codec: PixivPostCodec(),
          presentation: GenericPostPresentation(),
        )
      : null;
}
