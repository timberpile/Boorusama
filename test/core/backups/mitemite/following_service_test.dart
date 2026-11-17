import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/search/search/src/pages/search_page.dart';
import 'package:boorusama/core/content/anonymous_access_provider.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';

import '../../../support/fakes/memory_app_file_system.dart';

import 'package:boorusama/foundation/platform.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/src/types/blacklisted_tag.dart';
import 'package:foundation/foundation.dart';
import 'package:boorusama/core/search/following_topics/src/providers/following_topic_config_provider.dart';
import 'package:boorusama/core/search/following_topics/src/refresh/chronological_search_scanner.dart';
import 'package:boorusama/core/search/following_topics/src/refresh/search_refresh_query_adapter.dart';
import 'package:boorusama/core/search/following_topics/src/services/search_refresh_service.dart';
import 'package:boorusama/core/posts/post/types.dart';

import '../../search/following_topics/following_topic_test_utils.dart'
    as topic_harness;
import '../../search/following_topics/topic_query_test_builder.dart';
import '../../search/following_topics/topic_test_utils.dart'
    show TestSearchPostRepository;

import 'package:boorusama/core/backups/mitemite/collection_aliases.dart';
import 'package:boorusama/core/search/following_topics/src/pages/topic_feeds_page.dart';
import 'package:boorusama/core/backups/mitemite/notification_outbox.dart';

import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:boorusama/core/backups/mitemite/catalog.dart';
import 'package:boorusama/core/backups/mitemite/local_events.dart';
import 'package:boorusama/core/backups/mitemite/identity_file.dart';
import 'package:boorusama/core/backups/mitemite/local_change_detection.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/backups/mitemite/service.dart';
import 'package:boorusama/core/backups/mitemite/storage.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_hive_object.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart';
import 'package:boorusama/core/search/following_topics/src/types/following_mirror_state.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:i18n/i18n.dart';
import 'package:oktoast/oktoast.dart';
import 'package:boorusama/core/backups/mitemite/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/search/following_topics/src/data/providers.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:boorusama/core/search/following_topics/src/providers/following_topics_notifier.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:hive_ce/hive.dart';

const rootId = '11111111-1111-4111-8111-111111111111';
const topicId = '22222222-2222-4222-8222-222222222222';
const futureId = '33333333-3333-4333-8333-333333333333';
const aProfile = BackupProfileReference(
  id: '44444444-4444-4444-8444-444444444444',
  booruType: 'danbooru',
  url: 'https://example.test',
  name: 'Private A',
);
const bProfile = BackupProfileReference(
  id: '55555555-5555-4555-8555-555555555555',
  booruType: 'danbooru',
  url: 'https://example.test',
  name: 'Private B',
);

FollowingTopicsState definitionState(FollowingMirrorSnapshot snapshot) =>
    FollowingTopicsState(
      topics: snapshot.topics,
      organization: snapshot.organization,
      mirrors: snapshot.mirrors,
      refreshingIds: const {},
      batchCompleted: 0,
      batchTotal: 0,
    );

final _publicAccessAllowed = StateProvider((ref) => true);
final _publicRouteSupported = StateProvider((ref) => true);

void main() {
  late Directory directory;
  late _Library a;
  late _Library b;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('following_services_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(6))
      Hive.registerAdapter(FollowingTopicHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(7))
      Hive.registerAdapter(SearchPostPreviewHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(8))
      Hive.registerAdapter(RecentSearchPostHiveObjectAdapter());
    a = await _Library.open('${directory.path}/a', aProfile);
    b = await _Library.open('${directory.path}/b', bProfile);
    await a.service.configure('${directory.path}/shared');
    await b.service.configure('${directory.path}/shared');
  });
  tearDown(() async {
    a.service.dispose();
    b.service.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> publishAndReceive() async {
    await a.groups.createGroup('Bookmarks same UUID', id: rootId);
    await a.following.create(
      profileId: aProfile.id,
      query: 'cat',
      name: 'Cats',
      id: topicId,
    );
    await a.following.replaceOrganization(
      TopicOrganization(
        folders: [TopicFolder(id: rootId, name: 'Artists', feedEnabled: true)],
        placements: const [FolderPlacement(itemId: topicId, folderId: rootId)],
      ),
    );
    await a.service.publishGroup(rootId);
    await a.service.publishFollowing(rootId);
    await b.service.synchronize();
    final device = b.service.devices.singleWhere((d) => d.id == a.identity.id);
    expect((await b.following.readMirrorSnapshot()).topics, isEmpty);
    await b.service.approve(device);
    await b.service.subscribe(a.identity.id, {rootId});
    await b.service.subscribeFollowing(a.identity.id, {rootId});
  }

  for (final kind in ['bookmarks', 'following_topics']) {
    test(
      '$kind publication ignores historical withdrawal parent cycles',
      () async {
        const child = futureId;
        Future<void> organize({
          required String? rootParent,
          required String? childParent,
        }) async {
          if (kind == 'bookmarks') {
            final groups = await a.groups.getGroups();
            await a.groups.writeOrganization(const [], [
              for (final group in groups)
                if (group.id == rootId || group.id == child)
                  group.copyWith(
                    parentGroupId: group.id == rootId
                        ? rootParent
                        : childParent,
                    home:
                        (group.id == rootId ? rootParent : childParent) == null,
                  ),
            ]);
          } else {
            await a.following.replaceOrganization(
              TopicOrganization(
                folders: [
                  TopicFolder(id: rootId, name: 'A', parentId: rootParent),
                  TopicFolder(id: child, name: 'B', parentId: childParent),
                ],
              ),
            );
          }
          await a.service.markDirty();
          await a.service.synchronize(trigger: SyncTrigger.localChange);
          expect(a.service.outgoingFailure, isNull);
        }

        if (kind == 'bookmarks') {
          await a.groups.createGroup('A', id: rootId);
          await a.groups.createGroup('B', id: child);
        }
        await organize(rootParent: null, childParent: rootId);
        if (kind == 'bookmarks') {
          await a.service.publishGroup(rootId);
        } else {
          await a.service.publishFollowing(rootId);
        }
        await b.service.synchronize();
        await b.service.approve(
          b.service.devices.singleWhere((d) => d.id == a.identity.id),
        );
        if (kind == 'bookmarks') {
          await b.service.subscribe(a.identity.id, {rootId});
        } else {
          await b.service.subscribeFollowing(a.identity.id, {rootId});
        }
        await organize(rootParent: null, childParent: null);
        await b.service.synchronize();
        final withdrawn = b.service.devices
            .singleWhere((d) => d.id == a.identity.id)
            .catalog!;
        expect(
          withdrawn.entries.singleWhere((e) => e.id.source == child).state,
          SyncPublicationState.withdrawn,
        );
        await organize(rootParent: child, childParent: null);
        await b.service.synchronize();
        final catalog = b.service.devices
            .singleWhere((d) => d.id == a.identity.id)
            .catalog!;
        expect(catalog.sequence, greaterThan(withdrawn.sequence));
        expect(
          catalog.entries.singleWhere((e) => e.id.source == rootId).parent,
          child,
        );
        expect(
          catalog.entries.singleWhere((e) => e.id.source == child).parent,
          rootId,
        );
        if (kind == 'bookmarks') {
          expect(
            b.service.receiverMirrors!.owners.values.map((o) => o.source),
            [rootId],
          );
          expect(
            b.service.receiverMirrors!.checkpoints.values.any(
              (o) => o.source == child && o.retired,
            ),
            isTrue,
          );
        } else {
          final snapshot = await b.following.readMirrorSnapshot();
          expect(snapshot.mirrors.owners.values.map((o) => o.source), [rootId]);
          expect(
            snapshot.mirrors.checkpoints.values.any(
              (o) => o.source == child && o.retired,
            ),
            isTrue,
          );
        }
        // A global catalog must continue to serve unrelated domain changes.
        if (kind == 'bookmarks') {
          await a.following.replaceOrganization(
            TopicOrganization(
              folders: [TopicFolder(id: topicId, name: 'Unrelated')],
            ),
          );
          await a.service.publishFollowing(topicId);
        } else {
          await a.groups.createGroup('Unrelated', id: topicId);
          await a.service.publishGroup(topicId);
        }
        await b.service.synchronize();
        expect(a.service.outgoingFailure, isNull);
        expect(
          b.service.devices
              .singleWhere((d) => d.id == a.identity.id)
              .catalog!
              .offeredEntries,
          hasLength(2),
        );
      },
    );
  }

  test('same-named Following source children retain independent roots through restart and ancestor unsubscribe', () async {
    const parentB = '66666666-6666-4666-8666-666666666666';
    const childA = futureId;
    const childB = '77777777-7777-4777-8777-777777777777';
    Future<void> organize({
      String nameA = 'Favorites',
      bool reparent = false,
    }) async {
      await a.following.replaceOrganization(
        TopicOrganization(
          folders: [
            TopicFolder(id: rootId, name: 'Artist A'),
            TopicFolder(id: parentB, name: 'Artist B'),
            TopicFolder(
              id: childA,
              name: nameA,
              parentId: reparent ? parentB : rootId,
              position: 4,
            ),
            TopicFolder(
              id: childB,
              name: 'Favorites',
              parentId: parentB,
              position: 9,
            ),
          ],
        ),
      );
      await a.service.markDirty();
      await a.service.synchronize(trigger: SyncTrigger.localChange);
    }

    await organize();
    await a.service.publishFollowing(childA);
    await a.service.publishFollowing(childB);
    await b.service.synchronize();
    await b.service.approve(
      b.service.devices.singleWhere((d) => d.id == a.identity.id),
    );
    await b.service.subscribeFollowing(a.identity.id, {childA, childB});
    final original = await b.following.readMirrorSnapshot();
    final idA = original.mirrors.localIdFor(a.identity.id, childA)!;
    final idB = original.mirrors.localIdFor(a.identity.id, childB)!;
    expect(original.organization.folders.map((f) => f.name), [
      'Favorites',
      'Favorites',
    ]);
    expect(original.organization.tree.children(null).map((f) => f.id), [
      idA,
      idB,
    ]);
    final aIdentity = a.identity;
    final bIdentity = b.identity;
    final aPreferences = Map.of(a.preferences.values);
    final bPreferences = Map.of(b.preferences.values);
    a.service.dispose();
    b.service.dispose();
    await Hive.close();
    a = await _Library.open(
      '${directory.path}/a',
      aProfile,
      identity: aIdentity,
    );
    b = await _Library.open(
      '${directory.path}/b',
      bProfile,
      identity: bIdentity,
    );
    a.preferences.values.addAll(aPreferences);
    b.preferences.values.addAll(bPreferences);
    a.service.dispose();
    b.service.dispose();
    a.recreateService();
    b.recreateService();
    expect((await b.following.getOrganization()).folders.map((f) => f.name), [
      'Favorites',
      'Favorites',
    ]);
    await organize(nameA: 'Renamed', reparent: true);
    await b.service.synchronize();
    expect(
      (await b.following.getOrganization()).tree
          .children(null)
          .map((f) => f.name),
      ['Renamed', 'Favorites'],
    );
    await a.service.publishFollowing(parentB);
    await b.service.synchronize();
    await b.service.subscribeFollowing(a.identity.id, {parentB});
    await b.service.unsubscribeFollowing(a.identity.id, parentB);
    final surviving = await b.following.readMirrorSnapshot();
    expect(surviving.mirrors.localIdFor(a.identity.id, childA), idA);
    expect(surviving.mirrors.localIdFor(a.identity.id, childB), idB);
    expect(
      surviving.organization.folders.every((f) => f.parentId == null),
      isTrue,
    );
    await b.service.unsubscribeFollowing(a.identity.id, childA);
    expect((await b.following.getOrganization()).folders.single.id, idB);
  });

  // Upgrade fixture: old direct Topic rules remain legal to serve and withdraw.
  // New application publication APIs must never be used to create this state.
  Future<void> seedLegacyTopicPublication(String id) async {
    final settings = jsonDecode(
      a.preferences.get('mitemite.v1.settings')!,
    ) as Map<String, dynamic>;
    settings['followingRoots'] = {
      ...a.service.publishedFollowingRoots,
      id,
    }.toList();
    a.service.dispose();
    await a.preferences.put('mitemite.v1.settings', jsonEncode(settings));
    a.recreateService();
    await a.service.synchronize(trigger: SyncTrigger.localChange);
  }

  for (final kind in ['bookmarks', 'following_topics']) {
    test(
      '$kind pending subscriptions isolate roots, capture batches and recover failures',
      () async {
        await publishAndReceive();
        await a.groups.createGroup('Other bookmarks', id: futureId);
        await a.following.replaceOrganization(
          TopicOrganization(
            folders: [
              TopicFolder(id: rootId, name: 'Artists', feedEnabled: true),
              TopicFolder(id: futureId, name: 'Other Following'),
            ],
            placements: const [
              FolderPlacement(itemId: topicId, folderId: rootId),
            ],
          ),
        );
        await a.service.publishGroup(futureId);
        await a.service.publishFollowing(futureId);
        await b.service.synchronize();
        Future<void> subscribe(Set<String> roots) => kind == 'bookmarks'
            ? b.service.subscribe(a.identity.id, roots)
            : b.service.subscribeFollowing(a.identity.id, roots);
        Future<void> unsubscribe(String source) => kind == 'bookmarks'
            ? b.service.unsubscribe(a.identity.id, source)
            : b.service.unsubscribeFollowing(a.identity.id, source);
        Future<Set<String>> subscriptions() async => kind == 'bookmarks'
            ? (await b.bookmarks.readMirrorState()).subscriptions[a
                      .identity
                      .id] ??
                  {}
            : (await b.following.readMirrorSnapshot()).mirrors.subscriptions[a
                      .identity
                      .id] ??
                  {};
        SyncCollectionId collection(
          String source, {
          String? sourceKind,
          String? publisher,
        }) => SyncCollectionId(
          publisher: publisher ?? a.identity.id,
          kind: sourceKind ?? kind,
          source: source,
        );
        await unsubscribe(rootId);
        final entered = List.generate(4, (_) => Completer<void>());
        final resume = List.generate(4, (_) => Completer<void>());
        final started = <Future<void>>[];
        var hold = false;
        var opens = 0;
        b.service.dispose();
        b.recreateService(
          storageFor: (path) async {
            if (hold) {
              final index = opens++;
              entered[index].complete();
              await resume[index].future;
              if (index == 3) {
                throw StateError('Controlled batch storage failure');
              }
            }
            return DirectoryMiteMiteStorage(path);
          },
        );
        await b.service.synchronize();
        await b.service.maintenanceCompletion;
        hold = true;
        try {
          final requested = {rootId};
          final first = subscribe(requested);
          started.add(first);
          await entered[0].future.timeout(const Duration(seconds: 30));
          requested.add(topicId);
          expect(b.service.isSubscriptionPending(collection(rootId)), isTrue);
          expect(
            b.service.isSubscriptionPending(collection(futureId)),
            isFalse,
          );
          expect(
            b.service.isSubscriptionPending(
              collection(
                rootId,
                sourceKind: kind == 'bookmarks'
                    ? 'following_topics'
                    : 'bookmarks',
              ),
            ),
            isFalse,
          );
          expect(
            b.service.isSubscriptionPending(
              collection(rootId, publisher: b.identity.id),
            ),
            isFalse,
          );
          final second = subscribe({futureId});
          started.add(second);
          expect(b.service.isSubscriptionPending(collection(futureId)), isTrue);
          expect(entered[1].isCompleted, isFalse);
          resume[0].complete();
          await first;
          await entered[1].future.timeout(const Duration(seconds: 30));
          expect(b.service.isSubscriptionPending(collection(rootId)), isFalse);
          expect(b.service.isSubscriptionPending(collection(futureId)), isTrue);
          resume[1].complete();
          await second;
          expect(await subscriptions(), {rootId, futureId});
          expect(b.service.hasPendingActions, isFalse);

          final scanning = b.service.synchronize();
          started.add(scanning);
          await entered[2].future.timeout(const Duration(seconds: 30));
          final removed = unsubscribe(rootId);
          started.add(removed);
          final batch = subscribe({rootId, futureId});
          started.add(batch);
          final failure = expectLater(batch, throwsStateError);
          expect(b.service.isSubscriptionPending(collection(rootId)), isTrue);
          expect(b.service.isSubscriptionPending(collection(futureId)), isTrue);
          resume[2].complete();
          await scanning;
          await removed;
          await entered[3].future.timeout(const Duration(seconds: 30));
          expect(
            b.service.isSubscriptionPending(collection(rootId)),
            isTrue,
            reason:
                'Finishing Unsubscribe must retain the overlapping batch count',
          );
          resume[3].complete();
          await failure;
          expect(b.service.hasPendingActions, isFalse);
          expect(b.service.isSubscriptionPending(collection(rootId)), isFalse);
          expect(
            b.service.isSubscriptionPending(collection(futureId)),
            isFalse,
          );
          expect(await subscriptions(), {futureId});
          hold = false;
          await subscribe({rootId, futureId});
          expect(await subscriptions(), {rootId, futureId});
          expect(b.service.hasPendingActions, isFalse);
        } finally {
          for (final gate in resume) {
            if (!gate.isCompleted) gate.complete();
          }
          await Future.wait(
            started.map((f) => f.then<void>((_) {}, onError: (Object _) {})),
          );
        }
      },
    );
  }

  test('new Topic publication is rejected while legacy roots remain serveable and removable', () async {
    await publishAndReceive();
    await expectLater(
      a.service.publishFollowing(topicId),
      throwsA(isA<FollowingMirrorReadOnly>()),
    );
    expect(a.service.publishedFollowingRoots, {rootId});
    await seedLegacyTopicPublication(topicId);
    expect(a.service.publishedFollowingRoots, {rootId, topicId});
    await a.service.publishFollowing(topicId);
    await b.service.synchronize();
    await b.service.subscribeFollowing(a.identity.id, {topicId});
    await a.service.stopPublishingFollowing(topicId);
    expect(a.service.publishedFollowingRoots, {rootId});
    expect((await b.following.readMirrorSnapshot()).topics, hasLength(1));
  });

  test('only newly introduced Topics in established folders notify, with durable overlap and rename deduplication', () async {
    await publishAndReceive();
    expect(
      b.service.events.pendingNotifications.where(
        (notice) => notice.kind == SyncNoticeKind.topics,
      ),
      isEmpty,
    );
    await a.following.create(
      profileId: aProfile.id,
      query: 'dog',
      name: 'Dogs',
      id: futureId,
    );
    await a.following.replaceOrganization(
      TopicOrganization(
        folders: [TopicFolder(id: rootId, name: 'Artists', feedEnabled: true)],
        placements: const [
          FolderPlacement(itemId: topicId, folderId: rootId),
          FolderPlacement(itemId: futureId, folderId: rootId),
        ],
      ),
    );
    await a.service.synchronize(trigger: SyncTrigger.localChange);
    await b.service.synchronize();
    final notices = b.service.events.pendingNotifications
        .where((notice) => notice.kind == SyncNoticeKind.topics)
        .toList();
    expect(notices, hasLength(1));
    expect(notices.single.postCount, 1);
    expect(notices.single.items.single.member, futureId);
    expect(
      (await b.following.readMirrorSnapshot()).mirrors.activity.pendingPosts,
      isEmpty,
    );
    await b.service.events.acknowledgeNotification(notices.single);
    await a.following.rename(futureId, 'Renamed Dogs');
    await a.service.synchronize(trigger: SyncTrigger.localChange);
    await b.service.synchronize();
    b.service.dispose();
    b.recreateService();
    await b.service.synchronize();
    expect(
      b.service.events.pendingNotifications.where(
        (notice) => notice.kind == SyncNoticeKind.topics,
      ),
      isEmpty,
    );
    final snapshot = await b.following.readMirrorSnapshot();
    expect(
      snapshot.mirrors.owners.values
          .where((owner) => owner.kind == FollowingMirrorKind.topic)
          .every((owner) => owner.hasDefinitionChange),
      isTrue,
    );
  });

  test('recursive UNSEEN follows Topic receipts across stale revisions and restart', () async {
    await publishAndReceive();
    var snapshot = await b.following.readMirrorSnapshot();
    final folder = snapshot.mirrors.localIdFor(a.identity.id, rootId)!;
    final topic = snapshot.topics.single.id;
    final firstDigest = snapshot.mirrors.owners[topic]!.definitionDigest;
    expect(
      unseenFollowingTopicDefinitions(
        snapshot.mirrors,
        snapshot.organization,
        folder,
      ),
      {topic: firstDigest},
    );
    await b.service.acknowledgeFollowingDefinitions({topic: firstDigest});
    snapshot = await b.following.readMirrorSnapshot();
    expect(snapshot.mirrors.owners[folder]!.hasDefinitionChange, isTrue);
    expect(
      unseenFollowingTopicDefinitions(
        snapshot.mirrors,
        snapshot.organization,
        folder,
      ),
      isEmpty,
    );
    await a.following.rename(topicId, 'Changed definition');
    await a.service.synchronize(trigger: SyncTrigger.localChange);
    await b.service.synchronize();
    await b.service.acknowledgeFollowingDefinitions({topic: firstDigest});
    snapshot = await b.following.readMirrorSnapshot();
    expect(
      unseenFollowingTopicDefinitions(
        snapshot.mirrors,
        snapshot.organization,
        folder,
      ).keys,
      [topic],
    );
    final changedDigest = snapshot.mirrors.owners[topic]!.definitionDigest;
    expect(changedDigest, isNot(firstDigest));
    b.service.dispose();
    b.recreateService();
    await b.service.synchronize();
    snapshot = await b.following.readMirrorSnapshot();
    expect(
      unseenFollowingTopicDefinitions(
        snapshot.mirrors,
        snapshot.organization,
        folder,
      ),
      {topic: changedDigest},
    );
    await b.service.acknowledgeFollowing(
      topic,
      definitionDigest: changedDigest,
    );
    snapshot = await b.following.readMirrorSnapshot();
    expect(
      unseenFollowingTopicDefinitions(
        snapshot.mirrors,
        snapshot.organization,
        folder,
      ),
      isEmpty,
    );
  });

  test('new nested Topics aggregate UNSEEN without counting empty Folders or duplicate roots', () async {
    await publishAndReceive();
    const nested = '66666666-6666-4666-8666-666666666666';
    const empty = '77777777-7777-4777-8777-777777777777';
    await a.following.create(
      profileId: aProfile.id,
      query: 'dog',
      name: 'Dogs',
      id: futureId,
    );
    await a.following.replaceOrganization(
      TopicOrganization(
        folders: [
          TopicFolder(id: rootId, name: 'Artists', feedEnabled: true),
          TopicFolder(
            id: nested,
            name: 'Nested',
            parentId: rootId,
            feedEnabled: true,
          ),
          TopicFolder(id: empty, name: 'Empty', parentId: rootId),
        ],
        placements: const [
          FolderPlacement(itemId: topicId, folderId: rootId),
          FolderPlacement(itemId: futureId, folderId: nested),
        ],
      ),
    );
    await a.service.synchronize(trigger: SyncTrigger.localChange);
    await b.service.synchronize();
    var snapshot = await b.following.readMirrorSnapshot();
    final parent = snapshot.mirrors.localIdFor(a.identity.id, rootId)!;
    final child = snapshot.mirrors.localIdFor(a.identity.id, nested)!;
    final emptyLocal = snapshot.mirrors.localIdFor(a.identity.id, empty)!;
    expect(
      unseenFollowingTopicDefinitions(
        snapshot.mirrors,
        snapshot.organization,
        parent,
      ),
      hasLength(2),
    );
    expect(
      unseenFollowingTopicDefinitions(
        snapshot.mirrors,
        snapshot.organization,
        child,
      ),
      hasLength(1),
    );
    expect(
      unseenFollowingTopicDefinitions(
        snapshot.mirrors,
        snapshot.organization,
        emptyLocal,
      ),
      isEmpty,
    );
    await a.service.publishFollowing(nested);
    await b.service.synchronize();
    await b.service.subscribeFollowing(a.identity.id, {nested});
    snapshot = await b.following.readMirrorSnapshot();
    final captured = unseenFollowingTopicDefinitions(
      snapshot.mirrors,
      snapshot.organization,
      parent,
    );
    expect(captured, hasLength(2));
    final epoch = snapshot.mirrors.epoch;
    final runtime = snapshot.topics;
    await b.service.acknowledgeFollowingDefinitions(captured);
    snapshot = await b.following.readMirrorSnapshot();
    expect(snapshot.mirrors.epoch, epoch + 1);
    expect(snapshot.topics, runtime);
    await b.service.acknowledgeFollowingDefinitions(captured);
    expect((await b.following.readMirrorSnapshot()).mirrors.epoch, epoch + 1);
    await b.service.unsubscribeFollowing(a.identity.id, rootId);
    snapshot = await b.following.readMirrorSnapshot();
    expect(snapshot.mirrors.localIdFor(a.identity.id, nested), child);
    expect(
      unseenFollowingTopicDefinitions(
        snapshot.mirrors,
        snapshot.organization,
        child,
      ),
      isEmpty,
    );
  });

  test('received folder aliases preserve definitions and NEW, survive rename/restart and reject Topic edits', () async {
    await publishAndReceive();
    final folderId = SyncCollectionId(
      publisher: a.identity.id,
      kind: 'following_topics',
      source: rootId,
    );
    final bookmarkId = SyncCollectionId(
      publisher: a.identity.id,
      kind: 'bookmarks',
      source: rootId,
    );
    final original = await b.following.readMirrorSnapshot();
    final bm = await b.bookmarks.readMirrorState();
    final history = b.service.events.history;
    await b.service.setCollectionAlias(folderId, 'My Artists');
    await b.service.setCollectionAlias(bookmarkId, 'My Bookmark');
    expect(
      (await b.following.readMirrorSnapshot()).structureDigest,
      original.structureDigest,
    );
    expect((await b.following.readMirrorSnapshot()).mirrors, original.mirrors);
    expect(await b.bookmarks.readMirrorState(), bm);
    expect(b.service.events.history, history);
    await expectLater(
      b.service.setCollectionAlias(
        SyncCollectionId(
          publisher: a.identity.id,
          kind: 'following_topics',
          source: topicId,
        ),
        'Topic alias',
      ),
      throwsA(isA<SyncConflict>()),
    );
    final organization = (await a.following.readMirrorSnapshot()).organization;
    await a.following.replaceOrganization(
      TopicOrganization(
        folders: [
          organization.folders.single.copyWith(
            name: 'Renamed publisher folder',
          ),
        ],
        placements: organization.placements,
      ),
    );
    await a.service.synchronize(trigger: SyncTrigger.localChange);
    await b.service.synchronize();
    expect(b.service.collectionAliases[folderId], 'My Artists');
    expect(
      (await b.following.readMirrorSnapshot()).organization.folders.single.name,
      'Renamed publisher folder',
    );
    b.service.dispose();
    b.recreateService();
    expect(b.service.collectionAliases[folderId], 'My Artists');
    await b.service.setCollectionAlias(folderId, '');
    expect(b.service.collectionAliases.containsKey(folderId), isFalse);
    await b.service.setCollectionAlias(folderId, 'Temporary');
    await b.service.unsubscribeFollowing(a.identity.id, rootId);
    expect(b.service.collectionAliases, {bookmarkId: 'My Bookmark'});
    await b.service.forget(a.identity.id);
    expect(b.service.collectionAliases, isEmpty);
  });

  test(
    'verified withdrawal removes aliases while retaining subscription rules',
    () async {
      await publishAndReceive();
      final bookmark = SyncCollectionId(
        publisher: a.identity.id,
        kind: 'bookmarks',
        source: rootId,
      );
      final folder = SyncCollectionId(
        publisher: a.identity.id,
        kind: 'following_topics',
        source: rootId,
      );
      await b.service.setCollectionAlias(bookmark, 'BM');
      await b.service.setCollectionAlias(folder, 'Folder');
      await a.service.stopPublishingGroup(rootId);
      await a.service.stopPublishingFollowing(rootId);
      await b.service.synchronize();
      expect(b.service.collectionAliases, isEmpty);
      expect(
        (await b.bookmarks.readMirrorState()).subscriptions[a.identity.id],
        {rootId},
      );
      expect(
        (await b.following.readMirrorSnapshot()).mirrors.subscriptions[a
            .identity
            .id],
        {rootId},
      );
    },
  );

  test('failed alias cleanup retries after committed removal without repeating a domain transaction', () async {
    await publishAndReceive();
    final folder = SyncCollectionId(
      publisher: a.identity.id,
      kind: 'following_topics',
      source: rootId,
    );
    await b.service.setCollectionAlias(folder, 'Retain until confirmed');
    b.preferences.failAlias = true;
    await expectLater(
      b.service.unsubscribeFollowing(a.identity.id, rootId),
      throwsStateError,
    );
    final committed = await b.following.readMirrorSnapshot();
    expect(committed.mirrors.owners, isEmpty);
    expect(b.service.collectionAliases[folder], 'Retain until confirmed');
    // The unsubscribe already committed. The next update recovers preference
    // cleanup without repeating the domain transaction or removing another root.
    await b.service.synchronize();
    expect(b.service.collectionAliases, isEmpty);
    expect((await b.following.readMirrorSnapshot()).mirrors, committed.mirrors);
    expect(SyncCollectionAliases(b.preferences).values, isEmpty);
  });

  test('nested folder alias follows one source across overlap and publisher reparent', () async {
    await publishAndReceive();
    final initial = (await a.following.readMirrorSnapshot()).organization;
    await a.following.replaceOrganization(
      TopicOrganization(
        folders: [
          ...initial.folders,
          TopicFolder(id: futureId, name: 'Nested', parentId: rootId),
        ],
        placements: const [
          FolderPlacement(itemId: topicId, folderId: futureId),
        ],
      ),
    );
    await a.service.synchronize(trigger: SyncTrigger.localChange);
    await a.service.publishFollowing(futureId);
    await b.service.synchronize();
    await b.service.subscribeFollowing(a.identity.id, {futureId});
    final child = SyncCollectionId(
      publisher: a.identity.id,
      kind: 'following_topics',
      source: futureId,
    );
    await b.service.setCollectionAlias(child, 'One child alias');
    final before = await b.following.readMirrorSnapshot();
    final local = before.mirrors.localIdFor(a.identity.id, futureId)!;
    expect(
      before.organization.folders.where((f) => f.id == local),
      hasLength(1),
    );
    await b.service.unsubscribeFollowing(a.identity.id, rootId);
    expect(b.service.collectionAliases[child], 'One child alias');
    expect(
      (await b.following.readMirrorSnapshot()).mirrors.localIdFor(
        a.identity.id,
        futureId,
      ),
      local,
    );
    final current = (await a.following.readMirrorSnapshot()).organization;
    await a.following.replaceOrganization(
      TopicOrganization(
        folders: [
          for (final f in current.folders)
            f.id == futureId
                ? f.copyWith(name: 'New canonical', home: true)
                : f,
        ],
        placements: current.placements,
      ),
    );
    await a.service.synchronize(trigger: SyncTrigger.localChange);
    await b.service.synchronize();
    expect(b.service.collectionAliases[child], 'One child alias');
    expect(
      (await b.following.readMirrorSnapshot()).organization.folders
          .singleWhere((f) => f.id == local)
          .name,
      'New canonical',
    );
    await b.service.unsubscribeFollowing(a.identity.id, futureId);
    expect(b.service.collectionAliases, isEmpty);
  });

  test('quiet source and receiver checks read metadata without payloads or presentation reloads', () async {
    await publishAndReceive();
    final transport = _CountingStorage(
      DirectoryMiteMiteStorage('${directory.path}/shared'),
    );
    final projected = <Set<SyncDomain>>[];
    for (final library in [a, b]) {
      library.service.dispose();
      library.recreateService(
        storageFor: (_) async => transport,
        onDomainsApplied: (domains) async => projected.add(domains),
      );
      await library.service.synchronize(trigger: SyncTrigger.audit);
      await library.service.maintenanceCompletion;
    }
    await b.service.setCollectionAlias(
      SyncCollectionId(
        publisher: a.identity.id,
        kind: 'bookmarks',
        source: rootId,
      ),
      'Quiet alias',
    );
    await b.service.setCollectionAlias(
      SyncCollectionId(
        publisher: a.identity.id,
        kind: 'following_topics',
        source: rootId,
      ),
      'Quiet folder alias',
    );
    transport.clear();
    projected.clear();
    await a.service.synchronize();
    await b.service.synchronize();
    expect(transport.reads.keys.where((p) => p.endsWith('.bsexport')), isEmpty);
    expect(transport.lists.where((p) => p.contains('/collections/')), isEmpty);
    expect(transport.writes, isEmpty);
    expect(transport.deleted, isEmpty);
    expect(projected, isEmpty);
    for (final publisher in [a.identity.id, b.identity.id]) {
      final catalogs = transport.reads.entries.where(
        (e) => e.key.startsWith('devices/$publisher/catalog/'),
      );
      expect(
        catalogs.fold<int>(0, (n, e) => n + e.value),
        2,
        reason: 'One current catalog read per publisher on each of two checks',
      );
    }
  });

  test(
    'integrity audit counts foreground time and repairs at fresh revisions',
    () async {
      await publishAndReceive();
      var clock = DateTime.utc(2026, 11, 15);
      final transport = _CountingStorage(
        DirectoryMiteMiteStorage('${directory.path}/shared'),
      );
      a.service.dispose();
      a.recreateService(
        storageFor: (_) async => transport,
        now: () => clock,
        elapsed: () => clock.difference(DateTime.utc(2026, 11, 15)),
      );
      await a.service.synchronize(trigger: SyncTrigger.audit);
      final catalog = b.service.devices
          .singleWhere((d) => d.id == a.identity.id)
          .catalog!;
      final original = catalog.entries
          .firstWhere((e) => e.id.kind == 'bookmarks')
          .revision!;
      await File('${directory.path}/shared/v1/${original.payloadPath}')
          .delete();
      a.service.setForeground(false);
      clock = clock.add(const Duration(hours: 1));
      a.service.setForeground(true);
      transport.clear();
      await a.service.synchronize();
      await a.service.maintenanceCompletion;
      expect(
        transport.reads.keys.where((p) => p.endsWith('.bsexport')),
        isEmpty,
      );
      clock = clock.add(const Duration(minutes: 14));
      await a.service.synchronize();
      await a.service.maintenanceCompletion;
      expect(
        transport.reads.keys.where((p) => p.endsWith('.bsexport')),
        isEmpty,
      );
      clock = clock.add(const Duration(minutes: 1));
      await a.service.synchronize();
      await a.service.maintenanceCompletion;
      expect(
        transport.reads.keys.where((p) => p.endsWith('.bsexport')),
        isNotEmpty,
      );
      await b.service.synchronize();
      final repaired = b.service.devices
          .singleWhere((d) => d.id == a.identity.id)
          .catalog!
          .entries
          .firstWhere((e) => e.id.kind == 'bookmarks')
          .revision!;
      expect(repaired.revision, greaterThan(original.revision));
      expect(repaired.semanticHash, original.semanticHash);
      expect(a.service.outgoingFailure, isNull);
    },
  );

  test(
    'resume during a lightweight check retains source reconciliation',
    () async {
      await publishAndReceive();
      final transport = _CountingStorage(
        DirectoryMiteMiteStorage('${directory.path}/shared'),
      );
      a.service.dispose();
      a.recreateService(storageFor: (_) async => transport);
      await a.service.synchronize(trigger: SyncTrigger.audit);
      transport.pauseNextDevices = true;
      final first = a.service.synchronize();
      await transport.entered.future;
      try {
        await a.groups.renameGroup(rootId, 'Changed during poll');
        final resumed = a.service.synchronize(trigger: SyncTrigger.resume);
        transport.release.complete();
        await Future.wait([first, resumed]);
      } finally {
        if (!transport.release.isCompleted) transport.release.complete();
      }
      await b.service.synchronize();
      expect(
        b.service.devices
            .singleWhere((d) => d.id == a.identity.id)
            .catalog!
            .entries
            .firstWhere((e) => e.id.kind == 'bookmarks')
            .name,
        'Changed during poll',
      );
    },
  );

  test('cached catalog verification never hides changed bytes or same-sequence equivocation', () async {
    await publishAndReceive();
    final aliasId = SyncCollectionId(
      publisher: a.identity.id,
      kind: 'bookmarks',
      source: rootId,
    );
    await b.service.setCollectionAlias(aliasId, 'Trusted local label');
    await b.service.synchronize();
    final catalog = b.service.devices
        .singleWhere((d) => d.id == a.identity.id)
        .catalog!;
    final file = File('${directory.path}/shared/v1/${catalog.path}');
    final original = await file.readAsBytes();
    final before = await b.bookmarks.readMirrorState();
    final envelope = jsonDecode(utf8.decode(original)) as Map<String, dynamic>;
    final content = Map<String, dynamic>.from(envelope['content'] as Map)
      ..['deviceName'] = 'Conflicting name';
    try {
      await file.writeAsString(jsonEncode({...envelope, 'content': content}));
      await b.service.synchronize();
      expect(
        b.service.deviceFailures[a.identity.id],
        isA<SyncInvalidSignature>(),
      );
      expect(await b.bookmarks.readMirrorState(), before);
      await file.writeAsBytes(await a.identity.sign(content));
      await b.service.synchronize();
      expect(
        b.service.deviceFailures[a.identity.id],
        isA<SyncReplayRejected>(),
      );
      expect(await b.bookmarks.readMirrorState(), before);
      expect(b.service.collectionAliases[aliasId], 'Trusted local label');
    } finally {
      await file.writeAsBytes(original);
    }
    await b.service.synchronize();
    expect(b.service.deviceFailures, isEmpty);
    expect(await b.bookmarks.readMirrorState(), before);
  });

  test('real service baselines existing trusted offers and notifies only authenticated new direct roots without subscription', () async {
    await a.groups.createGroup('Existing', id: rootId);
    await a.service.publishGroup(rootId);
    await b.service.synchronize();
    expect(
      b.service.events.pendingNotifications.where(
        (n) => n.kind == SyncNoticeKind.followingOffers,
      ),
      isEmpty,
    );
    await b.service.approve(
      b.service.devices.singleWhere((device) => device.id == a.identity.id),
    );
    expect(
      b.service.events.pendingNotifications.where(
        (n) => n.kind == SyncNoticeKind.followingOffers,
      ),
      isEmpty,
    );
    await a.groups.renameGroup(rootId, 'Renamed');
    await a.service.synchronize(trigger: SyncTrigger.localChange);
    await b.service.synchronize();
    expect(
      b.service.events.pendingNotifications.where(
        (n) => n.kind == SyncNoticeKind.followingOffers,
      ),
      isEmpty,
    );
    await a.following.replaceOrganization(
      TopicOrganization(
        folders: [TopicFolder(id: futureId, name: 'New Folder')],
        placements: const [],
      ),
    );
    await a.service.publishFollowing(futureId);
    await b.service.synchronize();
    final notice = b.service.events.pendingNotifications.singleWhere(
      (n) => n.kind == SyncNoticeKind.followingOffers,
    );
    expect(notice.items.single.sourceKind, 'following_topics');
    expect(notice.items.single.source, futureId);
    expect(notice.items.single.publisher, a.identity.id);
    expect((await b.bookmarks.readMirrorState()).subscriptions, isEmpty);
    expect((await b.following.readMirrorSnapshot()).topics, isEmpty);
    await b.service.events.acknowledgeNotification(notice);
    b.service.dispose();
    b.recreateService();
    await b.service.synchronize();
    expect(
      b.service.events.pendingNotifications.where(
        (n) => n.kind == SyncNoticeKind.followingOffers,
      ),
      isEmpty,
    );
  });

  test('real Bookmark service projects and records healthy independent progress beside a missing sibling payload', () async {
    await a.groups.createGroup('Healthy', id: rootId);
    await a.groups.createGroup('Unavailable', id: futureId);
    await a.service.publishGroup(rootId);
    await a.service.publishGroup(futureId);
    await b.service.synchronize();
    await b.service.approve(
      b.service.devices.singleWhere((device) => device.id == a.identity.id),
    );
    await b.service.subscribe(a.identity.id, {rootId, futureId});
    final before = await b.bookmarks.readMirrorState();
    final healthyId = before.localIdFor(a.identity.id, rootId)!;
    final failedId = before.localIdFor(a.identity.id, futureId)!;
    await a.groups.renameGroup(rootId, 'Healthy updated');
    await a.groups.renameGroup(futureId, 'Unavailable updated');
    await a.service.synchronize(trigger: SyncTrigger.localChange);
    final intent = a.preferences.get(
      'mitemite.v1.outgoing.${a.identity.id}.catalog_intent',
    )!;
    final published = SyncCatalog.fromJson(
      (jsonDecode(intent) as Map<String, dynamic>)['catalog']
          as Map<String, dynamic>,
    );
    final entry = published.entries.singleWhere(
      (entry) => entry.id.source == futureId,
    );
    final bad = SyncRevision.fromJson({
      ...entry.revision!.toJson(),
      'revision': entry.revision!.revision + 1,
    });
    final incomplete = SyncCatalog(
      publisher: published.publisher,
      sequence: published.sequence + 1,
      name: published.name,
      publicationRoots: published.publicationRoots,
      entries: [
        for (final item in published.entries)
          item.id == entry.id
              ? SyncCatalogEntry(
                  id: item.id,
                  name: item.name,
                  parent: item.parent,
                  position: item.position,
                  state: item.state,
                  revision: bad,
                )
              : item,
      ],
    );
    final transport = DirectoryMiteMiteStorage('${directory.path}/shared');
    // A complete authentic descriptor/catalog with its new payload still absent.
    await transport.writeImmutable(
      bad.descriptorPath,
      await a.identity.sign(bad.toJson()),
    );
    await transport.writeImmutable(
      incomplete.path,
      await a.identity.sign(incomplete.toJson()),
    );
    final history = b.service.events.history.length;
    await b.service.synchronize();
    expect(
      (await b.groups.getGroups())
          .singleWhere((group) => group.id == healthyId)
          .name,
      'Healthy updated',
    );
    expect(
      (await b.groups.getGroups())
          .singleWhere((group) => group.id == failedId)
          .name,
      'Unavailable',
    );
    expect(b.service.deviceFailures, contains(a.identity.id));
    expect(
      b.service.receiverMirrors!.owners[healthyId],
      (await b.bookmarks.readMirrorState()).owners[healthyId],
    );
    expect(
      b.service.events.history
          .skip(0)
          .take(b.service.events.history.length - history)
          .where((event) => event.source == rootId),
      hasLength(1),
    );
  });

  test('an incomplete own identity offers relocation while preserving incoming subscriptions, keys and monotonic catalogs', () async {
    await publishAndReceive();
    await b.groups.createGroup('Incoming', id: futureId);
    await b.service.publishGroup(futureId);
    final transport = DirectoryMiteMiteStorage('${directory.path}/shared');
    final original = (await transport.read(
      'devices/${a.identity.id}/identity.json',
    ))!;
    final path = File(
      '${transport.root.path}/devices/${a.identity.id}/identity.json',
    );
    await path.writeAsBytes([123], flush: true);
    final oldSuccess = a.service.lastSuccess;
    await a.service.synchronize(trigger: SyncTrigger.localChange);
    expect(a.service.outgoingFailure, isA<SyncOwnIdentityUnavailable>());
    expect(a.service.lastSuccess, oldSuccess);
    await a.service.approve(
      a.service.devices.singleWhere((device) => device.id == b.identity.id),
    );
    await a.service.subscribe(b.identity.id, {futureId});
    final before = await a.bookmarks.readMirrorState();
    expect(before.localIdFor(b.identity.id, futureId), isNotNull);
    final settings = a.preferences.get('mitemite.v1.settings');
    final previous = jsonDecode(
      a.preferences.get(
        'mitemite.v1.outgoing.${a.identity.id}.catalog_intent',
      )!,
    ) as Map<String, dynamic>;
    final previousCatalog = SyncCatalog.fromJson(
      previous['catalog'] as Map<String, dynamic>,
    );
    final sameIdentity = a.identity.publicJson();
    await expectLater(
      a.service.configure('${directory.path}/shared'),
      throwsA(isA<SyncOwnIdentityUnavailable>()),
    );
    expect(a.preferences.get('mitemite.v1.settings'), settings);
    final relocation = '${directory.path}/relocated';
    await a.service.configure(relocation);
    expect(a.service.outgoingFailure, isNull);
    expect(a.identity.publicJson(), sameIdentity);
    expect(await a.bookmarks.readMirrorState(), before);
    expect(a.service.gate.approvedKey(b.identity.id), b.identity.publicKey);
    expect(
      await DirectoryMiteMiteStorage(relocation)
          .read('devices/${a.identity.id}/identity.json'),
      original,
    );
    expect(await path.readAsBytes(), [123]);
    final after = jsonDecode(
      a.preferences.get(
        'mitemite.v1.outgoing.${a.identity.id}.catalog_intent',
      )!,
    ) as Map<String, dynamic>;
    expect(
      SyncCatalog.fromJson(after['catalog'] as Map<String, dynamic>).sequence,
      greaterThan(previousCatalog.sequence),
    );
    expect(
      a.service.deviceFailures[b.identity.id],
      isA<SyncPublisherUnavailable>(),
    );
    expect(a.service.lastSuccess, oldSuccess);
  });

  test('an offline receiver catches up after own retention prunes its old advertised revision', () async {
    await publishAndReceive();
    final before = await b.following.readMirrorSnapshot();
    final local = before.topics.single.id;
    await b.following.setAutoUpdate([local], false);
    await b.service.acknowledgeFollowing(local);
    final first = SyncCatalog.fromJson(
      (jsonDecode(
            a.preferences.get(
              'mitemite.v1.outgoing.${a.identity.id}.catalog_intent',
            )!,
          ) as Map<String, dynamic>)['catalog']
          as Map<String, dynamic>,
    );
    final old = first.entries
        .singleWhere(
          (entry) =>
              entry.id.kind == 'following_topics' && entry.id.source == topicId,
        )
        .revision!;
    for (var version = 1; version <= 5; version++) {
      await a.following.rename(topicId, 'Version $version');
      await a.service.synchronize(trigger: SyncTrigger.localChange);
      expect(a.service.retentionFailure, isNull);
    }
    await a.service.synchronize(trigger: SyncTrigger.audit);
    final shared = DirectoryMiteMiteStorage('${directory.path}/shared');
    expect(await shared.read(old.payloadPath), isNull);
    expect(await shared.list('devices/${a.identity.id}/catalog'), hasLength(2));
    await b.service.synchronize();
    final after = await b.following.readMirrorSnapshot();
    expect(after.topics.single.id, local);
    expect(after.topics.single.name, 'Version 5');
    expect(after.topics.single.autoUpdateEnabled, isFalse);
    expect(
      after.mirrors.owners[local]!.revision,
      greaterThan(before.mirrors.owners[local]!.revision),
    );
    expect(after.mirrors.owners[local]!.hasDefinitionChange, isTrue);
    await b.service.acknowledgeFollowing(
      local,
      definitionDigest: before.mirrors.owners[local]!.definitionDigest,
    );
    expect(
      (await b.following.readMirrorSnapshot())
          .mirrors
          .owners[local]!
          .hasDefinitionChange,
      isTrue,
    );
  });

  for (final following in [false, true]) {
    test(
      'completed ${following ? 'Following' : 'Bookmark'} publication recovers history after interrupted delivery',
      () async {
        if (following) {
          await a.following.create(
            profileId: aProfile.id,
            query: 'cat',
            name: 'Cats',
            id: topicId,
          );
        } else {
          await a.groups.createGroup('Bookmarks', id: topicId);
        }
        a.preferences.failEvents = true;
        if (following) {
          await seedLegacyTopicPublication(topicId);
        } else {
          await a.service.publishGroup(topicId);
        }
        expect(
          a.preferences.get('mitemite.v1.completed_publications'),
          contains(topicId),
        );
        expect(
          a.service.events.history.where((event) => event.source == topicId),
          isEmpty,
        );
        expect(a.service.activityFailure, isNotNull);
        a.preferences.failEvents = false;
        a.service.dispose();
        a.recreateService();
        await a.service.synchronize(trigger: SyncTrigger.localChange);
        final delivered = a.service.events.history
            .where((event) => event.source == topicId)
            .toList();
        expect(delivered, hasLength(1));
        expect(delivered.single.kind.name, 'published');
        expect(
          delivered.single.sourceKind,
          following ? 'following_topics' : 'bookmarks',
        );
        expect(a.service.activityFailure, isNull);
        await a.service.synchronize(trigger: SyncTrigger.localChange);
        expect(
          a.service.events.history.where((event) => event.source == topicId),
          hasLength(1),
        );
      },
    );
  }

  test('a broken Following history reader cannot block an offline Bookmark alias commit', () async {
    await publishAndReceive();
    b.mirrors.failRead = true;
    await b.service.setDeviceAlias(a.identity.id, 'Local alias');
    expect(
      (await b.bookmarks.readMirrorState()).aliases[a.identity.id],
      'Local alias',
    );
    expect(b.service.receiverMirrors!.aliases[a.identity.id], 'Local alias');
    expect(b.service.activityFailure, isNotNull);
    expect(
      b.service.reloadFailure,
      isNull,
      reason: 'A Bookmark-only alias commit does not reload Following',
    );
    b.mirrors.failRead = false;
    await b.service.retryActivity();
    await b.service.retryProjection();
    expect(b.service.activityFailure, isNull);
    expect(b.service.reloadFailure, isNull);
  });

  for (final following in [false, true]) {
    test(
      'committed ${following ? 'Following' : 'Bookmark'} changes recover Activity after interruption before history persistence',
      () async {
        await publishAndReceive();
        final beforeHistory = b.service.events.history.length;
        if (following) {
          await a.following.rename(topicId, 'After interruption');
        } else {
          await a.groups.renameGroup(rootId, 'After interruption');
        }
        await a.service.synchronize(trigger: SyncTrigger.localChange);
        b.preferences.failEvents = true;
        try {
          await b.service.synchronize();
        } catch (_) {
          /* Expected interrupted informational write after domain commit. */
        }
        final followingSnapshot = await b.following.readMirrorSnapshot();
        final bookmarks = await b.bookmarks.readMirrorState();
        if (following) {
          expect(followingSnapshot.topics.single.name, 'After interruption');
        } else {
          expect(
            (await b.groups.getGroups())
                .singleWhere(
                  (group) =>
                      group.id == bookmarks.localIdFor(a.identity.id, rootId),
                )
                .name,
            'After interruption',
          );
        }
        expect(b.service.events.history, hasLength(beforeHistory));
        b.preferences.failEvents = false;
        b.service.dispose();
        b.recreateService();
        await b.service.synchronize();
        final recovered = b.service.events.history;
        expect(recovered, hasLength(beforeHistory + 1));
        expect(recovered.first.source, following ? topicId : rootId);
        expect(
          recovered.first.sourceKind,
          following ? 'following_topics' : 'bookmarks',
        );
        if (following)
          await b.service.acknowledgeFollowing(
            followingSnapshot.topics.single.id,
          );
        await b.service.synchronize();
        expect(
          b.service.events.history.map((event) => event.toJson()).toList(),
          recovered.map((event) => event.toJson()).toList(),
        );
      },
    );
  }

  test('private folder digest upgrades neither invent Activity nor acknowledge source changes', () async {
    await publishAndReceive();
    final before = await b.following.readMirrorSnapshot();
    final id = before.mirrors.localIdFor(a.identity.id, rootId)!;
    final owner = before.mirrors.owners[id]!;
    final digest = followingDefinitionDigest(
      kind: owner.kind,
      parentSource: owner.parentSource,
      position: owner.position,
      folder: before.organization.folders.single,
      version: 2,
    );
    final json = before.mirrors.toJson();
    (json['owners']! as Map)[id] = {
      ...owner.toJson(),
      'definitionVersion': 2,
      'definitionDigest': digest,
      'seenDefinitionDigest': digest,
    };
    await Hive.box<dynamic>('b_following_metadata')
        .put('search:sync_mirrors', json);
    final history = b.service.events.history
        .map((event) => event.toJson())
        .toList();
    await b.service.synchronize();
    final upgraded =
        (await b.following.readMirrorSnapshot()).mirrors.owners[id]!;
    expect(upgraded.definitionVersion, 3);
    expect(upgraded.hasDefinitionChange, isFalse);
    expect(
      b.service.events.history.map((event) => event.toJson()).toList(),
      history,
    );
    await a.following.create(
      profileId: aProfile.id,
      query: 'dog',
      name: 'Dogs',
      id: futureId,
    );
    await a.following.replaceOrganization(
      TopicOrganization(
        folders: [TopicFolder(id: rootId, name: 'Artists', feedEnabled: true)],
        placements: const [
          FolderPlacement(itemId: topicId, folderId: rootId),
          FolderPlacement(itemId: futureId, folderId: rootId, position: 1),
        ],
      ),
    );
    await a.service.synchronize(trigger: SyncTrigger.localChange);
    await b.service.synchronize();
    expect(
      (await b.following.readMirrorSnapshot())
          .mirrors
          .owners[id]!
          .hasDefinitionChange,
      isTrue,
    );
    final updates = b.service.events.history.take(
      b.service.events.history.length - history.length,
    );
    expect(updates.where((event) => event.source == rootId), hasLength(1));
    expect(updates.where((event) => event.source == futureId), hasLength(1));
  });

  test('real independent libraries publish typed roots, include future Topics and never echo received definitions', () async {
    await publishAndReceive();
    final publisher = b.service.devices
        .singleWhere((d) => d.id == a.identity.id)
        .catalog!;
    expect(
      publisher.entries.where((e) => e.state == SyncPublicationState.active),
      hasLength(3),
    );
    expect(publisher.publicationRoots, hasLength(2));
    final received = await b.following.readMirrorSnapshot();
    final localTopic = received.topics.single.id;
    expect(received.topics.single.profileId, bProfile.id);
    expect((await b.bookmarks.readMirrorState()).subscriptions[a.identity.id], {
      rootId,
    });
    await b.following.setAutoUpdate([localTopic], false);
    expect(
      hasLocalFollowingSyncChanges(
        definitionState(received),
        definitionState(await b.following.readMirrorSnapshot()),
      ),
      isFalse,
    );
    await b.service.synchronize();
    await a.service.synchronize(trigger: SyncTrigger.localChange);
    final receiverCatalog = a.service.devices
        .singleWhere((d) => d.id == b.identity.id)
        .catalog!;
    expect(receiverCatalog.entries, isEmpty);
    await a.following.create(
      profileId: aProfile.id,
      query: 'dog',
      name: 'Dogs',
      id: futureId,
    );
    await a.following.replaceOrganization(
      TopicOrganization(
        folders: [TopicFolder(id: rootId, name: 'Artists', feedEnabled: true)],
        placements: const [
          FolderPlacement(itemId: topicId, folderId: rootId),
          FolderPlacement(itemId: futureId, folderId: rootId, position: 1),
        ],
      ),
    );
    await a.service.synchronize(trigger: SyncTrigger.localChange);
    await b.service.synchronize();
    final withFuture = await b.following.readMirrorSnapshot();
    expect(withFuture.topics, hasLength(2));
    expect(
      hasLocalFollowingSyncChanges(
        definitionState(received),
        definitionState(withFuture),
      ),
      isFalse,
    );
    expect((await b.following.getById(localTopic))!.autoUpdateEnabled, isFalse);
    await seedLegacyTopicPublication(topicId);
    await b.service.synchronize();
    await b.service.subscribeFollowing(a.identity.id, {topicId});
    await b.service.unsubscribeFollowing(a.identity.id, rootId);
    expect(
      (await b.following.readMirrorSnapshot()).topics.single.id,
      localTopic,
    );
    expect((await b.bookmarks.readMirrorState()).subscriptions[a.identity.id], {
      rootId,
    });
    await a.service.stopPublishingFollowing(rootId);
    await a.service.synchronize(trigger: SyncTrigger.localChange);
    final catalog = b.service.devices
        .singleWhere((d) => d.id == a.identity.id)
        .catalog!;
    // Poll observes the new signed state without conflating a Bookmark root
    // bearing the exact same source UUID with a Following withdrawal.
    await b.service.synchronize();
    final fresh = b.service.devices
        .singleWhere((d) => d.id == a.identity.id)
        .catalog!;
    expect(fresh.sequence, greaterThanOrEqualTo(catalog.sequence));
    expect(
      fresh.entries.singleWhere((e) => e.id.kind == 'bookmarks').state,
      SyncPublicationState.active,
    );
    expect(
      fresh.entries
          .singleWhere(
            (e) => e.id.kind == 'following_topics' && e.id.source == rootId,
          )
          .state,
      SyncPublicationState.withdrawn,
    );
  });

  test('Forget recovers both domains before reapproval after an interrupted second-domain cleanup', () async {
    await publishAndReceive();
    final received = await b.following.readMirrorSnapshot();
    final copy = await b.service.localFollowingCopy(
      received.organization.folders.single.id,
    );
    final forgottenBefore = b.service.events.history
        .where((event) => event.kind == SyncEventKind.forgotten)
        .length;
    b.mirrors.failCommit = true;
    await expectLater(b.service.forget(a.identity.id), throwsStateError);
    expect(
      b.service.events.history.where(
        (event) => event.kind == SyncEventKind.forgotten,
      ),
      hasLength(forgottenBefore),
    );
    expect(b.service.gate.approvedKey(a.identity.id), isNull);
    expect((await b.bookmarks.readMirrorState()).owners, isEmpty);
    expect((await b.following.readMirrorSnapshot()).mirrors.owners, isNotEmpty);
    expect(
      b.preferences.get('mitemite.v1.pending_forgets'),
      contains(a.identity.id),
    );
    b.service.dispose();
    b.mirrors.failCommit = false;
    b.recreateService();
    await b.service.synchronize();
    final after = await b.following.readMirrorSnapshot();
    expect(after.mirrors.owners, isEmpty);
    expect(after.mirrors.checkpoints, hasLength(2));
    expect(after.organization.folders.single.id, copy);
    expect(after.topics.single.name, 'Cats');
    expect(b.service.gate.approvedKey(a.identity.id), isNull);
    expect(b.preferences.get('mitemite.v1.pending_forgets'), '[]');
    expect(
      b.service.events.history.where(
        (event) => event.kind == SyncEventKind.forgotten,
      ),
      hasLength(forgottenBefore + 1),
    );
  });
  testWidgets(
    'received public Topic and Folder Feed acknowledge captured definitions on actual routes with zero profiles',
    (tester) async {
      final reads = <BooruConfig>[];
      Completer<void>? refreshGate;
      var refreshDispatched = false;
      late topic_harness.FollowingTopicHarness harness;
      await tester.runAsync(() async {
        a.service.dispose();
        a = await _Library.open(
          '${directory.path}/public_a',
          const BackupProfileReference(
            id: '44444444-4444-4444-8444-444444444444',
            booruType: 'danbooru',
            url: 'https://safebooru.donmai.us',
            name: 'Public source',
          ),
        );
        await a.service.configure('${directory.path}/shared');
        // Use the production Hive repository with memory Box adapters for UI
        // scheduling; separate service tests cover real on-disk receipt restart.
        final diskReceiver = b;
        diskReceiver.service.dispose();
        final uiFs = MemoryAppFileSystem();
        b = _Library(
          diskReceiver.bookmarks,
          diskReceiver.groups,
          HiveFollowingTopicRepository(
            box: _UiSubscriptionBox(uiFs),
            organizationBox: _UiOrganizationBox(uiFs),
            fs: uiFs,
          ),
          diskReceiver.identity,
          diskReceiver.profile,
        );
        b.preferences.values.addAll(diskReceiver.preferences.values);
        b.recreateService();
        await publishAndReceive();
      });
      harness = topic_harness.FollowingTopicHarness(
        profiles: [],
        booruBuilder: (_) => TopicQueryTestBuilder(
          onFetch: (config, query) => reads.add(config),
        ),
        overrides: [
          appPlatformProvider.overrideWithValue(AppPlatform.android),
          booruBuilderProvider.overrideWith(
            (ref, auth) => ref.watch(_publicRouteSupported)
                ? TopicQueryTestBuilder(
                    onFetch: (config, query) => reads.add(config),
                  )
                : null,
          ),
          anonymousSourcePolicyProvider.overrideWith(
            (ref) =>
                AnonymousSourcePolicy(enabled: ref.watch(_publicAccessAllowed)),
          ),
          followingTopicRepositoryProvider.overrideWith(
            () => _Repository(b.following),
          ),
          globalBlacklistedTagsProvider.overrideWith(_PublicBlacklist.new),
          miteMiteServiceProvider.overrideWith((_) async => b.service),
          followingTopicsProvider.overrideWith(
            () => FollowingTopicsNotifier(
              refreshService: SearchRefreshService(
                repository: b.following,
                resolvePostRepository: (config) => TestSearchPostRepository((
                  query,
                  page,
                  limit,
                ) async {
                  reads.add(config);
                  refreshDispatched = true;
                  await refreshGate?.future;
                  return Either.of(const PostResult<Post>(posts: [], total: 0));
                }),
                resolveQueryAdapter: (_) =>
                    const DefaultSearchRefreshQueryAdapter(),
                scanner: ChronologicalSearchScanner(),
              ),
            ),
          ),
        ],
      );
      addTearDown(harness.dispose);
      b.service.dispose();
      b.recreateService(
        onApplied: () => harness.container
            .read(followingTopicsProvider.notifier)
            .reloadFromStorage(),
      );
      Future<void> until(bool Function() done) async {
        final guard = Stopwatch()..start();
        while (!done()) {
          final frameworkError = tester.takeException();
          if (frameworkError != null) throw frameworkError;
          if (guard.elapsed > const Duration(seconds: 30))
            fail('Received route did not complete');
          await tester.runAsync(() => Future<void>(() {}));
          await tester.pump();
        }
        await topic_harness.drain(tester);
        await topic_harness.settle(tester);
      }

      await tester.runAsync(() async {
        await harness.container.read(followingTopicsProvider.future);
        await harness.container.read(globalBlacklistedTagsProvider.future);
      });
      await pumpTopicQueryRouter(harness, tester, const FollowingTopicsPage());
      await until(() => find.text('Artists').evaluate().isNotEmpty);
      final snapshot = (await tester.runAsync(b.following.readMirrorSnapshot))!;
      final local = snapshot.topics.single.id;
      final folder = snapshot.mirrors.localIdFor(a.identity.id, rootId)!;
      final provider = followingTopicConfigProvider(local);
      expect(harness.container.read(provider)!.anonymousReadScope, isNotNull);
      expect(harness.container.read(booruConfigProvider), isEmpty);
      await tester.tap(find.text('Artists'));
      await until(() => find.text('Cats').evaluate().isNotEmpty);
      expect(
        (await tester.runAsync(b.following.readMirrorSnapshot))!
            .mirrors
            .owners[local]!
            .hasDefinitionChange,
        isTrue,
      );
      expect(find.text('UNSEEN'), findsWidgets);
      harness.container.read(_publicRouteSupported.notifier).state = false;
      await tester.tap(find.text('Cats'));
      await until(() => find.byType(SearchPage).evaluate().isNotEmpty);
      expect(
        harness.container
            .read(followingTopicsProvider)
            .requireValue
            .mirrors
            .owners[local]!
            .hasDefinitionChange,
        isTrue,
        reason: 'Unsupported search routes cannot acknowledge definitions',
      );
      expect(reads, isEmpty);
      harness.router.go('/');
      await topic_harness.drain(tester);
      harness.container.read(_publicRouteSupported.notifier).state = true;
      await topic_harness.settle(tester);
      await tester.tap(find.text('Artists'));
      await until(() => find.text('Cats').evaluate().isNotEmpty);
      await tester.tap(find.text('Cats'));
      await until(
        () =>
            !b.service.busy &&
            b
                    .service
                    .receiverFollowing
                    ?.mirrors
                    .owners[local]
                    ?.hasDefinitionChange ==
                false,
      );
      expect(reads, isNotEmpty);
      expect(reads.last.anonymousReadScope!.isCurrent, isTrue);
      expect(reads.last.auth.apiKey, isNull);
      expect(reads.last.auth.login, isNull);
      expect(harness.container.read(booruConfigProvider), isEmpty);
      var current = b.service.receiverFollowing!;
      expect(
        unseenFollowingTopicDefinitions(
          current.mirrors,
          current.organization,
          folder,
        ),
        isEmpty,
      );
      await tester.runAsync(() async {
        await a.following.rename(topicId, 'Revised Cats');
        await a.service.synchronize(trigger: SyncTrigger.localChange);
      });
      var synchronized = false;
      Object? synchronizationError;
      unawaited(
        b.service.synchronize().then(
          (_) => synchronized = true,
          onError: (Object error) {
            synchronizationError = error;
            synchronized = true;
          },
        ),
      );
      await until(() => synchronized);
      expect(synchronizationError, isNull);
      await topic_harness.drain(tester);
      await topic_harness.settle(tester);
      expect(
        b.service.receiverFollowing!.mirrors.owners[local]!.hasDefinitionChange,
        isTrue,
        reason: 'An already open route cannot acknowledge later definitions',
      );
      harness.router.go('/');
      await topic_harness.drain(tester);
      await topic_harness.settle(tester);
      await tester.tap(find.text('Artists'));
      await until(() => find.text('Revised Cats').evaluate().isNotEmpty);
      var refreshDone = false;
      Object? refreshError;
      unawaited(
        harness.container
            .read(followingTopicsProvider.notifier)
            .refresh(local)
            .then(
              (_) => refreshDone = true,
              onError: (Object error) {
                refreshError = error;
                refreshDone = true;
              },
            ),
      );
      await until(() => refreshDone);
      expect(refreshError, isNull);
      expect(reads.last.anonymousReadScope, isNotNull);
      expect(
        harness.container
            .read(followingTopicsProvider)
            .requireValue
            .topics
            .single
            .lastSuccessfulCheckAt,
        isNotNull,
      );
      expect(
        harness.container
            .read(followingTopicsProvider)
            .requireValue
            .mirrors
            .owners[local]!
            .hasDefinitionChange,
        isTrue,
        reason: 'Refreshing cannot acknowledge UNSEEN definitions',
      );
      await tester.tap(find.byTooltip('Open Feed'));
      await until(
        () =>
            find.byType(TopicFeedPage).evaluate().isNotEmpty &&
            !b.service.busy &&
            b
                    .service
                    .receiverFollowing
                    ?.mirrors
                    .owners[local]
                    ?.hasDefinitionChange ==
                false,
      );
      current = b.service.receiverFollowing!;
      expect(
        unseenFollowingTopicDefinitions(
          current.mirrors,
          current.organization,
          folder,
        ),
        isEmpty,
      );
      expect(harness.container.read(booruConfigProvider), isEmpty);
      final beforeRevocation = harness.container
          .read(followingTopicsProvider)
          .requireValue
          .topics
          .single;
      refreshGate = Completer<void>();
      refreshDispatched = false;
      refreshDone = false;
      unawaited(
        harness.container
            .read(followingTopicsProvider.notifier)
            .refresh(local)
            .then(
              (_) => refreshDone = true,
              onError: (Object error) {
                refreshError = error;
                refreshDone = true;
              },
            ),
      );
      await until(() => refreshDispatched);
      final grant = reads.last.anonymousReadScope!;
      harness.container.read(_publicAccessAllowed.notifier).state = false;
      expect(grant.isCurrent, isFalse);
      refreshGate.complete();
      await until(() => refreshDone);
      expect(refreshError, isNull);
      expect(
        harness.container
            .read(followingTopicsProvider)
            .requireValue
            .topics
            .single,
        beforeRevocation,
        reason: 'Revoked requests cannot commit cache/checkpoint/read state',
      );
      expect(harness.container.read(provider), isNull);
      harness.container.read(_publicAccessAllowed.notifier).state = true;
      expect(
        harness.container.read(provider)!.anonymousReadScope!.key,
        isNot(grant.key),
      );
      expect(harness.container.read(booruConfigProvider), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await topic_harness.drain(tester);
    },
  );

  testWidgets(
    'production Following renders read-only received sections and preserves unbound local copies',
    (tester) async {
      final semantics = tester.ensureSemantics();
      Future<void> pumpUntil(bool Function() done) async {
        final guard = Stopwatch()..start();
        while (guard.elapsed < const Duration(seconds: 30)) {
          await tester.runAsync(() => Future<void>(() {}));
          await tester.pump();
          if (done()) {
            await tester.pumpAndSettle();
            return;
          }
        }
        fail('Following UI operation did not complete');
      }

      ProviderContainer? container;
      try {
        await tester.runAsync(() async {
          await publishAndReceive();
          await b.following.create(
            profileId: bProfile.id,
            query: 'bird',
            name: 'Local bird',
          );
          container = ProviderContainer(
            overrides: [
              followingTopicRepositoryProvider.overrideWith(
                () => _Repository(b.following),
              ),
              bookmarkRepoProvider.overrideWith((_) async => b.bookmarks),
              bookmarkGroupRepoProvider.overrideWith((_) async => b.groups),
              booruConfigProvider.overrideWith(
                () => BooruConfigNotifier(initialConfigs: []),
              ),
              settingsNotifierProvider.overrideWith(() => _Settings()),
              miscDataStoreProvider.overrideWithValue(b.preferences),
              dataMutationCoordinatorProvider.overrideWithValue(
                b.bookmarks.coordinator,
              ),
              miteMiteServiceProvider.overrideWith((_) async => b.service),
            ],
          );
          b.service.dispose();
          b.recreateService(
            onApplied: () => container!
                .read(followingTopicsProvider.notifier)
                .reloadFromStorage(),
          );
          await container!.read(followingTopicsProvider.future);
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container!,
            child: BooruLocalization(
              child: MaterialApp(
                builder: (context, child) => KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: child!,
                ),
                home: const FollowingTopicsPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Local'), findsOneWidget);
        expect(find.text('Boorusama'), findsOneWidget);
        expect(find.text('Local bird'), findsOneWidget);
        final deviceEdit = find.byKey(
          ValueKey(('following-device-edit', a.identity.id)),
        );
        expect(deviceEdit, findsOneWidget);
        expect(
          find.descendant(
            of: deviceEdit,
            matching: find.byIcon(Icons.edit_outlined),
          ),
          findsOneWidget,
        );
        final row = find
            .ancestor(of: deviceEdit, matching: find.byType(Row))
            .first;
        final divider = find.descendant(
          of: row,
          matching: find.byType(Divider),
        );
        expect(tester.getRect(divider).width, greaterThan(0));
        expect(tester.getRect(deviceEdit).right, tester.getRect(row).right);
        final folderId = SyncCollectionId(
          publisher: a.identity.id,
          kind: 'following_topics',
          source: rootId,
        );
        final folderCard = find.byKey(
          ValueKey(
            'following-topic-folder-${(await tester.runAsync(b.following.readMirrorSnapshot))!.mirrors.localIdFor(a.identity.id, rootId)}',
          ),
        );
        await tester.tap(
          find.descendant(
            of: folderCard,
            matching: find.bySemanticsLabel(RegExp(r'^(More|Mehr)$')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set Alias'));
        await tester.pumpAndSettle();
        expect(find.text('Original Name: Artists'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'My Artists');
        await tester.tap(find.text('Save'));
        await pumpUntil(
          () => b.service.collectionAliases[folderId] == 'My Artists',
        );
        expect(find.text('My Artists'), findsOneWidget);
        await tester.tap(find.text('My Artists'));
        await tester.pumpAndSettle();
        expect(find.text('My Artists'), findsOneWidget);
        expect(find.text('Cats'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        final localFolderId = (await tester.runAsync(
          b.following.readMirrorSnapshot,
        ))!.mirrors.localIdFor(a.identity.id, rootId)!;
        final navigator = Navigator.of(
          tester.element(find.byType(FollowingTopicsPage)),
        );
        final route = navigator.push<void>(
          MaterialPageRoute(
            builder: (_) =>
                TopicFeedPage(feedId: localFolderId, profileId: bProfile.id),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('My Artists'),
          findsOneWidget,
          reason: 'The owning Feed uses the same private alias.',
        );
        await tester.tap(find.bySemanticsLabel(RegExp(r'^(More|Mehr)$')).last);
        await tester.pumpAndSettle();
        expect(find.text('Edit Alias'), findsOneWidget);
        await tester.tap(find.text('Edit Alias'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '');
        tester.testTextInput.hide();
        await tester.tap(find.text('Save'));
        await pumpUntil(
          () => !b.service.collectionAliases.containsKey(folderId),
        );
        expect(find.text('Artists'), findsOneWidget);
        await tester.pageBack();
        await route;
        await tester.pumpAndSettle();
        await tester.tap(find.text('Artists'));
        await tester.pumpAndSettle();
        await pumpUntil(() => !b.service.busy);
        expect(find.text('Cats'), findsOneWidget);
        expect(
          find.text(
            'No unambiguous compatible local profile. Add a compatible profile and retry Sync.',
          ),
          findsOneWidget,
        );
        final card = find.ancestor(
          of: find.text('Cats'),
          matching: find.byType(FollowingTopicCard),
        );
        await tester.tap(
          find.descendant(
            of: card,
            matching: find.bySemanticsLabel(RegExp(r'^(More|Mehr)$')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Create Local Copy'), findsOneWidget);
        expect(
          find.semantics.byLabel('Create Local Copy'),
          findsOneWidget,
          reason: 'Visible popup actions must reach the platform accessibility tree.',
        );
        expect(
          find.bySemanticsLabel(RegExp('Create Local Copy')),
          findsOneWidget,
        );
        for (final text in [
          'Edit',
          'Remove',
          'Publish to MiteMite',
          'Set Alias',
          'Edit Alias',
          'Remove Alias',
          'Move Up',
          'Move Down',
        ]) {
          expect(find.text(text), findsNothing);
        }
        await tester.ensureVisible(find.text('Disable Auto-Update'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Disable Auto-Update'));
        await pumpUntil(
          () =>
              container!
                  .read(followingTopicsProvider)
                  .valueOrNull
                  ?.topics
                  .where((t) => t.name == 'Cats')
                  .single
                  .autoUpdateEnabled ==
              false,
        );
        final state = container!.read(followingTopicsProvider).requireValue;
        final sourceId = state.topics.singleWhere((t) => t.name == 'Cats').id;
        expect(state.mirrors.owners[sourceId]!.hasDefinitionChange, isTrue);
        final folderLocal = state.mirrors.localIdFor(a.identity.id, rootId)!;
        expect(
          state.mirrors.owners[folderLocal]!.hasDefinitionChange,
          isTrue,
          reason: 'Opening a folder never acknowledges its definition notice',
        );
        expect(find.byTooltip('Sort By'), findsNothing);
        expect(find.byTooltip('Definition Updated'), findsNothing);
        expect(find.text('UNSEEN'), findsWidgets);
        expect(
          unseenFollowingTopicDefinitions(
            state.mirrors,
            state.organization,
            folderLocal,
          ),
          {sourceId: state.mirrors.owners[sourceId]!.definitionDigest},
        );
        expect(
          (await tester.runAsync(b.following.readMirrorSnapshot))!
              .mirrors
              .owners[sourceId]!
              .hasDefinitionChange,
          isTrue,
        );

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(find.textContaining('selected'), findsNothing);
        await tester.tap(
          find.descendant(
            of: card,
            matching: find.bySemanticsLabel(RegExp(r'^(More|Mehr)$')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create Local Copy'));
        await pumpUntil(
          () =>
              !b.service.busy &&
              container!
                      .read(followingTopicsProvider)
                      .valueOrNull
                      ?.topics
                      .length ==
                  3,
        );
        final copied = container!.read(followingTopicsProvider).requireValue;
        expect(copied.mirrors.owners, hasLength(2));
        expect(
          copied.topics.where(
            (t) => t.name == 'Cats' && !copied.mirrors.isReceived(t.id),
          ),
          hasLength(1),
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          find.text('Cats'),
          findsOneWidget,
          reason: 'An unbound Local Copy remains visible for editing.',
        );
        final beforeEdits = await tester.runAsync(
          () => b.following.readMirrorSnapshot(),
        );
        final localNotifier = container!.read(followingTopicsProvider.notifier);
        final bird = copied.topics.singleWhere((t) => t.name == 'Local bird');
        var edited = false;
        final editing = () async {
          final folder = await localNotifier.createSharedFolder('Local folder');
          await localNotifier.moveTopicToSharedFolder(bird.id, folder.id);
          await localNotifier.renameSharedFolder(
            folder.id,
            'Renamed local',
            parentId: null,
          );
          await localNotifier.reorderSharedFolders(0, 0);
        }().whenComplete(() => edited = true);
        await pumpUntil(() => edited);
        await editing;
        await tester.pumpAndSettle();
        final afterEdits = await tester.runAsync(
          () => b.following.readMirrorSnapshot(),
        );
        expect(
          hasLocalFollowingSyncChanges(
            definitionState(beforeEdits!),
            definitionState(afterEdits!),
          ),
          isTrue,
        );
        expect(
          afterEdits.mirrors,
          beforeEdits.mirrors,
          reason: 'Ordinary Local edits preserve exact received definitions and receipts.',
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        dismissAllToast();
        await tester.pumpWidget(const SizedBox());
        container?.dispose();
        var closed = false;
        final closing = Hive.close().whenComplete(() => closed = true);
        await pumpUntil(() => closed);
        await closing;
      }
    },
  );
}

class _Repository extends FollowingTopicRepositoryNotifier {
  _Repository(this.repository);
  final FollowingTopicRepository repository;
  @override
  Future<FollowingTopicRepository> build() async => repository;
}

class _Settings extends SettingsNotifier {
  _Settings() : super(Settings.defaultSettings);
}

class _Library {
  _Library(
    this.bookmarks,
    this.groups,
    this.following,
    this.identity,
    this.profile,
  ) : mirrors = _FailingStore(following);
  final BookmarkHiveRepository bookmarks;
  final UnifiedBookmarkGroupRepository groups;
  final HiveFollowingTopicRepository following;
  final SyncSigningIdentity identity;
  final BackupProfileReference profile;
  final _FailingStore mirrors;
  final preferences = _Store();
  late MiteMiteService service;
  void recreateService({
    Future<void> Function()? onApplied,
    Future<void> Function(Set<SyncDomain>)? onDomainsApplied,
    SyncStorageFactory? storageFor,
    DateTime Function()? now,
    Duration Function()? elapsed,
  }) => service = MiteMiteService(
    preferences: preferences,
    store: bookmarks,
    groups: groups,
    fs: const IoFileSystem(),
    codec: BookmarkBackupCodec(),
    identity: identity,
    mutations: bookmarks.coordinator,
    followingStore: () async => mirrors,
    onApplied: onApplied,
    onDomainsApplied: onDomainsApplied,
    now: now,
    elapsed: elapsed,
    profiles: () => [profile],
    storageFor: storageFor ?? (path) async => DirectoryMiteMiteStorage(path),
  );
  static Future<_Library> open(
    String path,
    BackupProfileReference profile, {
    SyncSigningIdentity? identity,
  }) async {
    await Directory(path).create(recursive: true);
    final prefix = path.split('/').last;
    Future<Box<T>> box<T>(String name) =>
        Hive.openBox<T>('${prefix}_$name', path: path);
    final metadata = await box<dynamic>('metadata');
    final bookmarks = BookmarkHiveRepository(
      await box<BookmarkHiveObject>('posts'),
      groupPayloadBox: await box<dynamic>('payloads'),
      metadataBox: metadata,
      coordinator: DataMutationCoordinator(),
    );
    final reader = await BookmarkStorageMigration(
      bookmarks: bookmarks,
      legacyGroups: await box<BookmarkGroupHiveObject>('legacy'),
      legacyOrganization: await box<dynamic>('organization'),
      metadata: metadata,
    ).open();
    final groups = UnifiedBookmarkGroupRepository(
      bookmarks: bookmarks,
      reader: reader,
    );
    final following = HiveFollowingTopicRepository(
      box: await box<FollowingTopicHiveObject>('topics'),
      organizationBox: await box<dynamic>('following_metadata'),
    );
    final library = _Library(
      bookmarks,
      groups,
      following,
      identity ?? await SyncSigningIdentity.create(),
      profile,
    );
    library.recreateService();
    return library;
  }
}

class _Store implements MiscDataStore {
  bool failEvents = false;
  bool failAlias = false;
  final values = <String, String>{};
  @override
  String? get(String key) => values[key];
  @override
  Future<void> put(String key, String value) async {
    if (failEvents && key == 'mitemite.v1.local_events')
      throw StateError('Injected history persistence interruption');
    values[key] = value;
    if (failAlias && key == SyncCollectionAliases.key) {
      failAlias = false;
      throw StateError('Injected cached alias persistence failure');
    }
  }
}

class _FailingStore
    implements
        FollowingMirrorStore,
        FollowingDefinitionReceiptStore,
        FollowingNotificationReceiptStore {
  _FailingStore(this.delegate);
  final FollowingMirrorStore delegate;
  bool failCommit = false;
  bool failRead = false;
  @override
  Future<void> acknowledgeMirrorNotifications(int cursor) =>
      (delegate as FollowingNotificationReceiptStore)
          .acknowledgeMirrorNotifications(cursor);

  @override
  Future<FollowingMirrorSnapshot> readMirrorSnapshot() {
    if (failRead) throw StateError('Injected Following history read failure');
    return delegate.readMirrorSnapshot();
  }

  @override
  Future<void> acknowledgeMirrorDefinitions(
    Map<String, String> captured,
  ) async {
    final store = delegate;
    if (store is FollowingDefinitionReceiptStore) {
      await (store as FollowingDefinitionReceiptStore)
          .acknowledgeMirrorDefinitions(captured);
    } else {
      for (final entry in captured.entries) {
        await store.acknowledgeMirrorDefinition(
          entry.key,
          definitionDigest: entry.value,
        );
      }
    }
  }

  @override
  Future<void> acknowledgeMirrorDefinition(
    String id, {
    String? definitionDigest,
  }) => delegate.acknowledgeMirrorDefinition(
    id,
    definitionDigest: definitionDigest,
  );
  @override
  Future<void> commitMirrorDefinitions({
    required FollowingMirrorState expected,
    required String expectedStructureDigest,
    required FollowingMirrorState next,
    required List<FollowingTopic> topics,
    required TopicOrganization organization,
    Set<String> removeTopicIds = const {},
  }) {
    if (failCommit) throw StateError('Injected second-domain interruption');
    return delegate.commitMirrorDefinitions(
      expected: expected,
      expectedStructureDigest: expectedStructureDigest,
      next: next,
      topics: topics,
      organization: organization,
      removeTopicIds: removeTopicIds,
    );
  }
}

class _CountingStorage implements MiteMiteStorage {
  _CountingStorage(this.delegate);
  final MiteMiteStorage delegate;
  final reads = <String, int>{};
  final lists = <String>[];
  final writes = <String>[];
  final deleted = <String>[];
  var pauseNextDevices = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  void clear() {
    reads.clear();
    lists.clear();
    writes.clear();
    deleted.clear();
  }

  @override
  Future<List<String>> list(String path) async {
    lists.add(path);
    if (path == 'devices' && pauseNextDevices) {
      pauseNextDevices = false;
      entered.complete();
      await release.future;
    }
    return delegate.list(path);
  }

  @override
  Future<Uint8List?> read(String path, {int maxBytes = miteMiteMaxBytes}) {
    reads.update(path, (n) => n + 1, ifAbsent: () => 1);
    return delegate.read(path, maxBytes: maxBytes);
  }

  @override
  Future<void> writeImmutable(String path, Uint8List bytes) {
    writes.add(path);
    return delegate.writeImmutable(path, bytes);
  }

  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) {
    deleted.add(path);
    return delegate.deleteOwnedRevision(path, owner: owner);
  }
}

class _PublicBlacklist extends GlobalBlacklistedTagsNotifier {
  @override
  IList<BlacklistedTag> build() => <BlacklistedTag>[].lock;
}

class _UiBox<T> implements Box<T> {
  _UiBox(this.fs, this.path);
  final MemoryAppFileSystem fs;
  @override
  final String path;
  final _values = <dynamic, T>{};
  @override
  Iterable<T> get values => _values.values;
  @override
  Iterable<dynamic> get keys => _values.keys;
  @override
  int get length => _values.length;
  @override
  bool get isEmpty => _values.isEmpty;
  @override
  bool get isNotEmpty => _values.isNotEmpty;
  @override
  bool get isOpen => true;
  @override
  T? get(dynamic key, {T? defaultValue}) => _values[key] ?? defaultValue;
  @override
  bool containsKey(dynamic key) => _values.containsKey(key);
  @override
  Future<void> put(dynamic key, T value) async => _values[key] = value;
  @override
  Future<void> putAll(Map<dynamic, T> values) async => _values.addAll(values);
  @override
  Future<void> delete(dynamic key) async => _values.remove(key);
  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    for (final key in keys.toList()) {
      _values.remove(key);
    }
  }

  @override
  Future<int> clear() async {
    final count = length;
    _values.clear();
    return count;
  }

  @override
  Map<dynamic, T> toMap() => Map.of(_values);
  @override
  Future<void> flush() => fs.writeBytes(path, Uint8List(0));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UiSubscriptionBox extends _UiBox<FollowingTopicHiveObject> {
  _UiSubscriptionBox(MemoryAppFileSystem fs)
    : super(fs, '/memory/ui_topics.hive');
}

class _UiOrganizationBox extends _UiBox<dynamic> {
  _UiOrganizationBox(MemoryAppFileSystem fs)
    : super(fs, '/memory/ui_metadata.hive');
}
