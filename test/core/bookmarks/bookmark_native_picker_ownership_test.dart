import 'dart:async';

import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/boorus/nhentai/galleries/mapper.dart';
import 'package:boorusama/boorus/nhentai/nhentai.dart';
import 'package:boorusama/boorus/nhentai/nhentai_repository.dart';
import 'package:boorusama/boorus/nhentai/posts/data.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/related/related_posts_order_value.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../boorus/nhentai/fixtures.dart';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_picker_actions.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_picker_request.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'server_favorites/test_support.dart';

void main() {
  for (final operation in ['save', 'create', 'remove']) {
    for (final revoke in [false, true]) {
      test(
        'queued native $operation preserves Hive when ${revoke ? 'source is revoked' : 'picker is dismissed'}',
        () async {
          final h = FavoriteHarness();
          late ContentAccessContext access;
          var revoked = false;
          await h.open(
            unifiedOrganization: true,
            extraOverrides: (_) => [
              contentAccessContextProvider.overrideWith(
                (ref, key) => revoked ? null : access,
              ),
            ],
          );
          addTearDown(h.close);
          access = ContentAccessContext.profile(
            config: h.profile,
            authEpoch: 1,
            policyEpoch: 1,
          );
          final draft = ContentGroupBookmark(
            id: 0,
            snapshot: StoredGroupSnapshot(
              summary: ContentGroupSummary(
                reference: const ContentReferenceCodec().parse(
                  engine: access.key.engine,
                  site: Uri.parse(h.profile.url),
                  kind: ContentKind.group,
                  sourceKey: 'pool:42',
                ),
                title: 'Fixture group',
                memberCount: 3,
              ),
            ),
            createdAt: DateTime.utc(2026),
            observedAt: DateTime.utc(2026),
            sourceProfileHint: h.profile.id,
          );
          final library = h.container.read(bookmarkLibraryProvider.notifier);
          final target = await library.createGroup('Target');
          if (operation == 'remove') {
            await library.toggleContentGroupTarget(draft, groupId: target.id);
          }
          final before = await library.snapshotForExport();
          final held = Completer<void>();
          final release = Completer<void>();
          addTearDown(() {
            if (!release.isCompleted) release.complete();
          });
          final blocker = h.bookmarkStorage.coordinator.runExclusive(() async {
            held.complete();
            await release.future;
          });
          await held.future.timeout(const Duration(seconds: 10));
          final requested = Completer<void>();
          var active = true;
          final actions = BookmarkPickerActions(
            container: h.container,
            request: ContentGroupBookmarkPickerRequest(
              draft: draft,
              source: h.profile,
              access: access.key,
            ),
            isActive: () {
              if (operation != 'create' && !requested.isCompleted) {
                requested.complete();
              }
              return active;
            },
          );
          addTearDown(actions.dispose);
          final action = operation == 'create'
              ? actions.createGroup(
                  'Must not appear',
                  null,
                  beforeCommit: requested.complete,
                )
              : actions.toggle(target.id, onRemoved: (_) {}).then<void>((_) {});
          final rejected = expectLater(action, throwsStateError);
          await requested.future.timeout(const Duration(seconds: 10));
          // The picker request reached the notifier while another real mutation
          // owns the coordinator; revoke ownership before its queued commit runs.
          if (revoke) {
            revoked = true;
            h.container.invalidate(contentAccessContextProvider(access.key));
          } else {
            active = false;
          }
          release.complete();
          await Future.wait([blocker, rejected])
              .timeout(const Duration(seconds: 10));
          expect(await library.snapshotForExport(), before);
          await library.refresh();
          expect(
            await library.snapshotForExport(),
            before,
            reason: 'The rejected request must preserve persisted records, groups and memberships',
          );
          expect(
            (await library.snapshotForExport()).groupsById.values.any(
              (group) => group.name == 'Must not appear',
            ),
            isFalse,
          );
        },
      );
    }
  }
  for (final operation in ['save', 'create', 'remove']) {
    for (final exit in ['dismissed', 'context_revoked', 'profile_removed']) {
      test(
        'queued actual nhentai Page $operation preserves Hive after $exit',
        () async {
          final h = FavoriteHarness();
          await h.open(unifiedOrganization: true);
          addTearDown(h.close);
          final access = galleryAccess();
          final source = access.config!;
          final profiles = FavoriteTestProfiles([source]);
          var revoked = false;
          final repository = BookmarkHiveRepository(
            h.bookmarkBox,
            groupPayloadBox: h.bookmarkStorage.groupPayloadBox,
            metadataBox: h.bookmarkStorage.metadataBox,
            coordinator: h.bookmarkStorage.coordinator,
            postDataCodec: (type) =>
                type == BooruType.nhentai ? const NhentaiPostCodec() : null,
          );
          final groups = await repository.openOrganization();
          final observedLibrary = _ObservedPageLibrary();
          final container = ProviderContainer(
            parent: h.container,
            overrides: [
              bookmarkLibraryProvider.overrideWith(() => observedLibrary),
              bookmarkRepoProvider.overrideWith((ref) => repository),
              bookmarkGroupRepoProvider.overrideWith((ref) => groups),
              booruConfigRepoProvider.overrideWithValue(profiles),
              booruConfigProvider.overrideWith(
                () => BooruConfigNotifier(initialConfigs: [source]),
              ),
              contentAccessContextProvider.overrideWith(
                (ref, key) => revoked ? null : access,
              ),
              booruEngineRegistryProvider.overrideWith((ref) {
                final components = createNhentai();
                return BooruEngineRegistry()..register(
                  BooruType.nhentai,
                  BooruEngine(
                    booru: components.parser.parse(),
                    builder: components.createBuilder(),
                    repository: components.createRepository(ref),
                  ),
                );
              }),
              postLinkGeneratorProvider.overrideWith(
                (ref, auth) => const NhentaiPostLinkGenerator(),
              ),
            ],
          );
          addTearDown(container.dispose);
          final pages = nhentaiGalleryPosts(
            NhentaiGalleryDetails.fromJson(galleryJson()),
            access,
            galleryPolicy(),
          );
          final page = pages.last;
          expect(page.booruData, isA<NhentaiPostData>());
          expect((page.booruData as NhentaiPostData).pageNumber, 3);
          expect(
            page.originalImageUrl,
            'https://i1.nhentai.net/galleries/7001/3.webp',
          );
          final library = container.read(bookmarkLibraryProvider.notifier);
          await container.read(bookmarkLibraryProvider.future);
          final target = await library.createGroup('Pages');
          // A successful production save proves this fixture has the actual
          // registered Page codec before any ownership rejection is exercised.
          await library.addPostsToGroup(source.auth, [pages.first], target.id);
          if (operation == 'remove') {
            await library.addPostsToGroup(source.auth, [page], target.id);
          }
          final before = await library.snapshotForExport();
          expect(before.items.first.post.booruData, isA<NhentaiPostData>());
          final held = Completer<void>();
          final release = Completer<void>();
          addTearDown(() {
            if (!release.isCompleted) release.complete();
          });
          final blocker = h.bookmarkStorage.coordinator.runExclusive(() async {
            held.complete();
            await release.future;
          });
          await held.future.timeout(const Duration(seconds: 10));
          final requested = Completer<void>();
          var active = true;
          final actions = BookmarkPickerActions(
            container: container,
            request: PostBookmarkPickerRequest(
              config: source.auth,
              post: page,
              source: source,
              access: access.key,
            ),
            isActive: () => active,
          );
          addTearDown(actions.dispose);
          observedLibrary.onQueued = () {
            if (!requested.isCompleted) requested.complete();
          };
          final operationDone = Completer<void>();
          Object? rejected;
          Object? outcome;
          final action = operation == 'create'
              ? actions
                    .createGroup(
                      'Must not appear',
                      null,
                      beforeCommit: () {},
                    )
                    .then<Object?>((_) => null)
              : actions.toggle(target.id, onRemoved: (_) {});
          unawaited(
            action.then(
              (value) {
                outcome = value;
                operationDone.complete();
              },
              onError: (Object error, StackTrace stack) {
                rejected = error;
                operationDone.complete();
              },
            ),
          );
          await requested.future.timeout(const Duration(seconds: 10));
          switch (exit) {
            case 'dismissed':
              active = false;
            case 'context_revoked':
              revoked = true;
              container.invalidate(contentAccessContextProvider(access.key));
            case 'profile_removed':
              profiles.profiles = [];
              await container.read(booruConfigProvider.notifier).fetch();
          }
          release.complete();
          await Future.wait([blocker, operationDone.future])
              .timeout(const Duration(seconds: 10));
          if (operation == 'create') {
            expect(rejected, isA<StateError>());
          } else {
            expect(
              rejected is StateError || outcome == BookmarkToggleOutcome.failed,
              isTrue,
              reason: 'A queued Page rejection may propagate ownership or report the existing failed outcome',
            );
          }
          expect(await library.snapshotForExport(), before);
          await library.refresh();
          expect(
            await library.snapshotForExport(),
            before,
            reason: 'No Page, empty Group, membership or payload write can survive rejected ownership',
          );
          if (operation == 'remove' && exit == 'profile_removed') {
            final savedPage = before.items.singleWhere(
              (saved) =>
                  (saved.post.booruData as NhentaiPostData).pageNumber == 3,
            );
            final offlineActions = BookmarkPickerActions(
              container: container,
              request: SavedBookmarkPickerRequest(
                config: source.auth,
                record: savedPage,
              ),
              isActive: () => true,
            );
            addTearDown(offlineActions.dispose);
            expect(
              await offlineActions.toggle(target.id, onRemoved: (_) {}),
              BookmarkToggleOutcome.removed,
              reason: 'An already saved Page remains editable without its former source profile',
            );
          }
        },
      );
    }
  }
}

// This observer forwards unchanged to the production notifier and signals only
// after its method has synchronously queued the operation. The race cannot pass
// by revoking ownership during the picker's earlier asynchronous draft checks.
class _ObservedPageLibrary extends BookmarkLibraryNotifier {
  void Function()? onQueued;

  @override
  Future<BookmarkToggleOutcome> togglePostTarget(
    BooruConfigAuth config,
    Post post, {
    BookmarkTarget target = const BookmarkTarget.defaultGroup(),
    void Function(BookmarkGroupRemovalResult)? onRemoved,
    void Function()? beforeCommit,
  }) {
    final queued = super.togglePostTarget(
      config,
      post,
      target: target,
      onRemoved: onRemoved,
      beforeCommit: beforeCommit,
    );
    onQueued?.call();
    return queued;
  }

  @override
  Future<({BookmarkGroup group, int addedCount})> createGroupWithPosts(
    String name,
    BooruConfigAuth config,
    Iterable<Post> posts, {
    String? folderId,
    String? parentGroupId,
    List<CollectionBookmark> pools = const [],
    RelatedPostsOrder? initialRelatedOrder,
    void Function()? beforeCommit,
  }) {
    final queued = super.createGroupWithPosts(
      name,
      config,
      posts,
      folderId: folderId,
      parentGroupId: parentGroupId,
      pools: pools,
      initialRelatedOrder: initialRelatedOrder,
      beforeCommit: beforeCommit,
    );
    onQueued?.call();
    return queued;
  }
}
