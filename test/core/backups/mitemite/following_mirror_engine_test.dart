import 'package:clock/clock.dart';
import 'package:boorusama/core/backups/export_import/import/search_runtime_snapshot.dart';
import 'package:boorusama/core/backups/mitemite/following_publication.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/src/types/blacklisted_tag.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/search/following_topics/src/data/providers.dart';
import 'package:boorusama/core/search/following_topics/src/providers/following_topic_config_provider.dart';
import 'package:boorusama/core/search/following_topics/src/providers/following_topics_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

import 'dart:io';

import 'package:boorusama/core/backups/mitemite/catalog.dart';
import 'package:boorusama/core/backups/mitemite/bookmark_mirror_engine.dart'
    show SyncRevisionUnavailable;
import 'package:boorusama/core/backups/mitemite/catalog_gate.dart';
import 'package:boorusama/core/backups/mitemite/following_mirror_engine.dart';
import 'package:boorusama/core/backups/mitemite/following_package.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/backups/mitemite/publication.dart';
import 'package:boorusama/core/backups/mitemite/receive_preparation.dart';
import 'package:boorusama/core/backups/mitemite/storage.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/following_topic_backup_data.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_hive_object.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart';
import 'package:boorusama/core/search/following_topics/src/types/following_mirror_state.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const folderId = '11111111-1111-4111-8111-111111111111';
const topicId = '22222222-2222-4222-8222-222222222222';
const futureId = '33333333-3333-4333-8333-333333333333';
const profileId = '44444444-4444-4444-8444-444444444444';
const otherProfileId = '55555555-5555-4555-8555-555555555555';
const sourceProfile = BackupProfileReference(
  id: profileId,
  booruType: 'danbooru',
  url: 'https://example.test',
  name: 'Source',
);
const publicProfile = BackupProfileReference(
  id: profileId,
  booruType: 'gelbooruV2',
  url: 'https://safebooru.org',
  name: 'Public',
);
const localProfile = BackupProfileReference(
  id: otherProfileId,
  booruType: 'danbooru',
  url: 'https://example.test',
  name: 'Local',
);

void main() {
  late Directory root;
  late HiveFollowingTopicRepository repository;
  late SyncSigningIdentity identity;
  late DirectoryMiteMiteStorage storage;
  late SyncPublicationWriter writer;
  late SyncCatalogGate gate;
  late SyncFollowingMirrorEngine engine;
  var profiles = <BackupProfileReference>[localProfile];
  var publicEnabled = true;
  final at = DateTime.utc(2026, 11, 14);

  Future<SyncRevision> publish(
    String id, {
    String name = 'Cats',
    String query = 'cat',
    bool folder = false,
    BackupProfileReference profile = sourceProfile,
  }) async {
    final collection = SyncCollectionId(
      publisher: identity.id,
      kind: 'following_topics',
      source: id,
    );
    final package = await const SyncFollowingPackageBuilder(fs: IoFileSystem())
        .build(
          collection: collection,
          appVersion: 'test',
          createdAt: at,
          data: FollowingTopicBackupData(
            records: [
              if (!folder)
                FollowingTopicBackupRecord(
                  id: id,
                  name: name,
                  query: query,
                  position: 0,
                  profile: profile,
                ),
            ],
            folders: [
              if (folder)
                FollowingTopicFolderBackupRecord(
                  id: id,
                  name: name,
                  position: 0,
                  searchIds: const [],
                  feedEnabled: true,
                ),
            ],
            homeSearchIds: [if (!folder) id],
          ),
        );
    return writer.publishFollowingRevision(package);
  }

  Future<VerifiedSyncCatalog> advertise(
    List<SyncRevision> revisions, {
    Set<String> direct = const {folderId, topicId},
    Set<String> withdrawn = const {},
    String topicName = 'Cats',
    String folderName = 'Artists',
    int topicPosition = 0,
    Map<String, String?> parents = const {},
  }) async {
    final catalog = await writer.publishCatalog(
      name: 'Publisher',
      publicationRoots: {
        for (final r in revisions)
          if (direct.contains(r.collection.source) &&
              !withdrawn.contains(r.collection.source))
            r.collection,
      },
      entries: [
        for (final r in revisions)
          SyncCatalogEntry(
            id: r.collection,
            name: r.collection.source == folderId ? folderName : topicName,
            parent: parents.containsKey(r.collection.source)
                ? parents[r.collection.source]
                : r.collection.source == folderId
                ? null
                : folderId,
            position: r.collection.source == futureId
                ? 1
                : r.collection.source == topicId
                ? topicPosition
                : 0,
            state: withdrawn.contains(r.collection.source)
                ? SyncPublicationState.withdrawn
                : SyncPublicationState.active,
            revision: r,
          ),
      ],
    );
    return gate.verifyAndCheckpoint(
      publisher: identity.id,
      expectedSequence: catalog.sequence,
      bytes: (await storage.read(catalog.path))!,
    );
  }

  Future<void> receive(VerifiedSyncCatalog ticket, [Set<String>? roots]) =>
      engine.receive(
        ticket: ticket,
        publisherKey: identity.publicKey,
        directRoots: roots,
      );

  test('source profile changes have independent definition receipts and stale acknowledgements cannot consume them', () async {
    final folder = await publish(folderId, name: 'Artists', folder: true);
    final topic = await publish(topicId);
    await receive(await advertise([folder, topic]), {folderId});
    final before = await repository.readMirrorSnapshot();
    final id = before.topics.single.id;
    final original = before.mirrors.owners[id]!;
    await repository.acknowledgeMirrorDefinition(
      id,
      definitionDigest: original.definitionDigest,
    );
    await repository.setAutoUpdate([id], false);
    final changed = await publish(
      topicId,
      profile: const BackupProfileReference(
        id: profileId,
        booruType: 'danbooru',
        url: 'https://other.test',
        name: 'Other',
      ),
    );
    await receive(await advertise([folder, changed]));
    final after = await repository.readMirrorSnapshot();
    final owner = after.mirrors.owners[id]!;
    expect(owner.definitionDigest, isNot(original.definitionDigest));
    expect(owner.hasDefinitionChange, isTrue);
    expect(after.topics.single.autoUpdateEnabled, isFalse);
    expect(after.topics.single.profileId, isNot(localProfile.id));
    await repository.acknowledgeMirrorDefinition(
      id,
      definitionDigest: original.definitionDigest,
    );
    expect(
      (await repository.readMirrorSnapshot())
          .mirrors
          .owners[id]!
          .hasDefinitionChange,
      isTrue,
    );
    await repository.acknowledgeMirrorDefinition(
      id,
      definitionDigest: owner.definitionDigest,
    );
    expect(
      (await repository.readMirrorSnapshot())
          .mirrors
          .owners[id]!
          .hasDefinitionChange,
      isFalse,
    );
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('following_receive_');
    Hive.init('${root.path}/local');
    if (!Hive.isAdapterRegistered(6))
      Hive.registerAdapter(FollowingTopicHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(7))
      Hive.registerAdapter(SearchPostPreviewHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(8))
      Hive.registerAdapter(RecentSearchPostHiveObjectAdapter());
    repository = HiveFollowingTopicRepository(
      box: await Hive.openBox<FollowingTopicHiveObject>('topics'),
      organizationBox: await Hive.openBox<dynamic>('metadata'),
      clock: Clock.fixed(at),
    );
    identity = await SyncSigningIdentity.create();
    storage = DirectoryMiteMiteStorage('${root.path}/shared');
    final mutations = DataMutationCoordinator();
    gate = SyncCatalogGate(store: _Store(), mutations: mutations);
    await gate.approvePublisher(
      publisher: identity.id,
      publicKey: identity.publicKey,
    );
    writer = SyncPublicationWriter(
      identity: identity,
      storage: storage,
      sequences: SyncPublicationSequences(
        store: _Store(),
        mutations: DataMutationCoordinator(),
      ),
    );
    profiles = [localProfile];
    publicEnabled = true;
    engine = SyncFollowingMirrorEngine(
      store: repository,
      gate: gate,
      preparation: SyncReceivePreparation(
        storage: storage,
        fs: const IoFileSystem(),
        codec: BookmarkBackupCodec(),
      ),
      profiles: () => profiles,
      anonymousPolicy: () => AnonymousSourcePolicy(enabled: publicEnabled),
      now: () => at,
    );
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  test('recursive future coverage, canonical overlap and offline unsubscribe retain local operation', () async {
    final folder = await publish(folderId, name: 'Artists', folder: true);
    final topic = await publish(topicId);
    var ticket = await advertise([folder, topic]);
    await receive(ticket, {folderId, topicId});
    var snapshot = await repository.readMirrorSnapshot();
    final topicLocal = snapshot.mirrors.localIdFor(identity.id, topicId)!;
    final folderLocal = snapshot.mirrors.localIdFor(identity.id, folderId)!;
    expect(snapshot.topics.single.profileId, otherProfileId);
    expect(snapshot.organization.folders.single.feedEnabled, isTrue);
    expect(snapshot.organization.placements.single.folderId, folderLocal);
    await repository.setAutoUpdate([topicLocal], false);
    await repository.acknowledgeMirrorDefinition(topicLocal);
    final epoch = (await repository.readMirrorSnapshot()).mirrors.epoch;
    await receive(ticket);
    expect((await repository.readMirrorSnapshot()).mirrors.epoch, epoch);
    final future = await publish(futureId);
    ticket = await advertise([folder, topic, future]);
    await receive(ticket);
    snapshot = await repository.readMirrorSnapshot();
    expect(snapshot.topics, hasLength(2));
    expect(snapshot.mirrors.localIdFor(identity.id, topicId), topicLocal);
    expect(
      snapshot.topics.firstWhere((t) => t.id == topicLocal).autoUpdateEnabled,
      isFalse,
    );
    await engine.unsubscribe(identity.id, folderId);
    snapshot = await repository.readMirrorSnapshot();
    expect(snapshot.topics.single.id, topicLocal);
    expect(snapshot.organization.folders, isEmpty);
    expect(snapshot.organization.placements.single.folderId, isNull);
    expect(snapshot.mirrors.owners[topicLocal]!.hasDefinitionChange, isFalse);
    expect(snapshot.mirrors.checkpoints, hasLength(3));
    await expectLater(
      repository.rename(topicLocal, 'Writable?'),
      throwsA(isA<FollowingMirrorReadOnly>()),
    );
  });

  test('Following folder definition notices include future children, order and withdrawal without changing Post runtime', () async {
    final folder = await publish(folderId, name: 'Artists', folder: true);
    final topic = await publish(topicId);
    await receive(await advertise([folder, topic]), {folderId});
    var snapshot = await repository.readMirrorSnapshot();
    final rootLocal = snapshot.mirrors.localIdFor(identity.id, folderId)!;
    final topicLocal = snapshot.mirrors.localIdFor(identity.id, topicId)!;
    await repository.setAutoUpdate([topicLocal], false);
    await repository.acknowledgeMirrorDefinition(rootLocal);
    final unchanged =
        (await repository.readMirrorSnapshot()).mirrors.owners[rootLocal]!;
    final future = await publish(futureId);
    await receive(await advertise([folder, topic, future]));
    snapshot = await repository.readMirrorSnapshot();
    var owner = snapshot.mirrors.owners[rootLocal]!;
    expect(owner.hasDefinitionChange, isTrue);
    expect(owner.definitionDigest, isNot(unchanged.definitionDigest));
    expect(
      owner.revision,
      unchanged.revision,
      reason: 'Catalog membership changes do not require rewriting the folder payload',
    );
    expect((await repository.getById(topicLocal))!.autoUpdateEnabled, isFalse);
    expect((await repository.getById(topicLocal))!.runtimeRevision, 0);
    await repository.acknowledgeMirrorDefinition(
      rootLocal,
      definitionDigest: unchanged.definitionDigest,
    );
    expect(
      (await repository.readMirrorSnapshot())
          .mirrors
          .owners[rootLocal]!
          .hasDefinitionChange,
      isTrue,
    );
    await repository.acknowledgeMirrorDefinition(
      rootLocal,
      definitionDigest: owner.definitionDigest,
    );
    await receive(await advertise([folder, topic, future], topicPosition: 3));
    snapshot = await repository.readMirrorSnapshot();
    owner = snapshot.mirrors.owners[rootLocal]!;
    expect(owner.hasDefinitionChange, isTrue);
    await repository.acknowledgeMirrorDefinition(
      rootLocal,
      definitionDigest: owner.definitionDigest,
    );
    await receive(
      await advertise(
        [folder, topic, future],
        topicPosition: 3,
        withdrawn: {futureId},
      ),
    );
    snapshot = await repository.readMirrorSnapshot();
    expect(snapshot.mirrors.owners[rootLocal]!.hasDefinitionChange, isTrue);
    expect(snapshot.topics.single.id, topicLocal);
    expect(snapshot.topics.single.autoUpdateEnabled, isFalse);
    expect(snapshot.topics.single.runtimeRevision, 0);
  });

  test(
    'obsolete definition formats fail closed and preserve stored ownership',
    () async {
      final folder = await publish(folderId, name: 'Artists', folder: true);
      final topic = await publish(topicId);
      await receive(await advertise([folder, topic]), {folderId});
      final before = await repository.readMirrorSnapshot();
      final id = before.mirrors.localIdFor(identity.id, folderId)!;
      final json = before.mirrors.toJson();
      final old = before.mirrors.owners[id]!.toJson()
        ..remove('definitionSchema')
        ..['definitionVersion'] = 2;
      (json['owners']! as Map)[id] = old;
      final metadata = Hive.box<dynamic>('metadata');
      await metadata.put('search:sync_mirrors', json);
      await expectLater(repository.readMirrorSnapshot(), throwsFormatException);
      expect(metadata.get('search:sync_mirrors'), json);
    },
  );

  test('rename preserves local settings, query edit resets only affected runtime and unavailable payload retains data', () async {
    final folder = await publish(folderId, name: 'Artists', folder: true);
    final topic = await publish(topicId);
    await receive(await advertise([folder, topic]), {folderId});
    var snapshot = await repository.readMirrorSnapshot();
    final id = snapshot.topics.single.id;
    await repository.setAutoUpdate([id], false);
    await repository.acknowledgeMirrorDefinition(id);
    final renamed = await publish(topicId, name: 'Felines');
    await receive(await advertise([folder, renamed], topicName: 'Felines'));
    snapshot = await repository.readMirrorSnapshot();
    expect(snapshot.topics.single.name, 'Felines');
    expect(snapshot.topics.single.runtimeRevision, 0);
    expect(snapshot.topics.single.autoUpdateEnabled, isFalse);
    expect(snapshot.mirrors.owners[id]!.hasDefinitionChange, isTrue);
    final edited = await publish(topicId, name: 'Felines', query: 'dog');
    final ticket = await advertise([folder, edited], topicName: 'Felines');
    await receive(ticket);
    snapshot = await repository.readMirrorSnapshot();
    expect(snapshot.topics.single.query, 'dog');
    expect(snapshot.topics.single.runtimeRevision, 1);
    expect(snapshot.topics.single.autoUpdateEnabled, isFalse);
    final missing = await publish(topicId, name: 'Felines', query: 'bird');
    final incomplete = await advertise([folder, missing], topicName: 'Felines');
    await storage.deleteOwnedRevision(missing.payloadPath, owner: identity.id);
    await expectLater(
      receive(incomplete),
      throwsA(isA<SyncRevisionUnavailable>()),
    );
    expect((await repository.readMirrorSnapshot()).mirrors, snapshot.mirrors);
    await expectLater(receive(ticket), throwsA(isA<SyncReplayRejected>()));
  });

  test('an unavailable independent Topic retains its state while a healthy sibling updates and retry catches up', () async {
    final first = await publish(topicId, query: 'cat');
    final second = await publish(futureId, query: 'dog');
    const parents = <String, String?>{topicId: null, futureId: null};
    await receive(
      await advertise(
        [first, second],
        direct: {topicId, futureId},
        parents: parents,
      ),
      {topicId, futureId},
    );
    final before = await repository.readMirrorSnapshot();
    final failedId = before.mirrors.localIdFor(identity.id, topicId)!;
    final healthyId = before.mirrors.localIdFor(identity.id, futureId)!;
    await repository.setAutoUpdate([failedId, healthyId], false);
    await repository.acknowledgeMirrorDefinition(failedId);
    final failedBefore =
        (await repository.readMirrorSnapshot()).mirrors.owners[failedId]!;
    final bad = await publish(topicId, query: 'fox');
    final good = await publish(futureId, query: 'bird');
    final ticket = await advertise(
      [bad, good],
      direct: {topicId, futureId},
      parents: parents,
    );
    final missingBytes = (await storage.read(bad.payloadPath))!;
    await storage.deleteOwnedRevision(bad.payloadPath, owner: identity.id);
    await expectLater(receive(ticket), throwsA(anything));
    expect((await repository.getById(healthyId))!.query, 'bird');
    expect((await repository.getById(failedId))!.query, 'cat');
    expect(
      (await repository.readMirrorSnapshot()).mirrors.owners[failedId],
      failedBefore,
    );
    expect((await repository.getById(healthyId))!.autoUpdateEnabled, isFalse);
    final healthyOwner =
        (await repository.readMirrorSnapshot()).mirrors.owners[healthyId]!;
    await storage.writeImmutable(bad.payloadPath, missingBytes);
    await receive(ticket);
    expect((await repository.getById(failedId))!.query, 'fox');
    expect(
      (await repository.readMirrorSnapshot()).mirrors.owners[healthyId],
      healthyOwner,
    );
  });

  for (final names in [
    <String>['favorites'],
    <String>['favorites', 'FAVORITES (2)'],
    <String>['Favorites'],
  ]) {
    test(
      'local folder copy allocates a case-insensitive name beside $names',
      () async {
        final folder = await publish(folderId, name: 'Favorites', folder: true);
        await receive(await advertise([folder], folderName: 'Favorites'), {
          folderId,
        });
        final before = await repository.readMirrorSnapshot();
        await repository.replaceOrganization(
          TopicOrganization(
            folders: [
              ...before.organization.folders,
              for (final (i, name) in names.indexed)
                TopicFolder(id: i == 0 ? futureId : profileId, name: name),
              TopicFolder(id: otherProfileId, name: 'Destination'),
              TopicFolder(
                id: topicId,
                name: 'Favorites (3)',
                parentId: otherProfileId,
              ),
            ],
          ),
        );
        final source = before.organization.folders.single.id;
        final copy = await engine.createLocalCopy(source);
        final expected = names.length == 2 ? 'Favorites (3)' : 'Favorites (2)';
        expect(
          (await repository.getOrganization()).folders
              .singleWhere((f) => f.id == copy)
              .name,
          expected,
        );
        expect(
          (await repository.getOrganization()).folders
              .singleWhere((f) => f.id == source)
              .name,
          'Favorites',
        );
        await Hive.close();
        repository = HiveFollowingTopicRepository(
          box: await Hive.openBox<FollowingTopicHiveObject>('topics'),
          organizationBox: await Hive.openBox<dynamic>('metadata'),
        );
        expect(
          (await repository.getOrganization()).folders
              .singleWhere((f) => f.id == copy)
              .name,
          expected,
        );
      },
    );
  }

  test('a public local Topic copy resolves after Forget and repository restart without profiles', () async {
    profiles = [];
    final topic = await publish(
      topicId,
      profile: const BackupProfileReference(
        id: profileId,
        booruType: 'gelbooruV2',
        url: 'https://safebooru.org',
        name: 'Public',
      ),
    );
    await receive(await advertise([topic]), {topicId});
    ProviderContainer access() => ProviderContainer(
      overrides: [
        followingTopicRepositoryProvider.overrideWith(
          () => _Repository(repository),
        ),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: []),
        ),
        globalBlacklistedTagsProvider.overrideWith(_Blacklist.new),
      ],
    );
    var container = access();
    await container.read(followingTopicsProvider.future);
    final original = (await repository.getAll()).single.id;
    expect(container.read(followingTopicConfigProvider(original)), isNotNull);
    final copy = await engine.createLocalCopy(original);
    await engine.unsubscribe(identity.id, topicId, forget: true);
    container.dispose();
    await Hive.close();
    repository = HiveFollowingTopicRepository(
      box: await Hive.openBox<FollowingTopicHiveObject>('topics'),
      organizationBox: await Hive.openBox<dynamic>('metadata'),
    );
    container = access();
    addTearDown(container.dispose);
    await container.read(followingTopicsProvider.future);
    expect((await repository.readMirrorSnapshot()).mirrors.owners, isEmpty);
    final config = container.read(followingTopicConfigProvider(copy));
    expect(config, isNotNull);
    expect(config!.anonymousReadScope!.isCurrent, isTrue);
    expect(config.auth.apiKey, isNull);
    expect(container.read(booruConfigProvider), isEmpty);
  });

  test('local copies have independent definitions and survive offline Forget cleanup', () async {
    final folder = await publish(folderId, name: 'Artists', folder: true);
    final topic = await publish(topicId);
    await receive(await advertise([folder, topic]), {folderId});
    var snapshot = await repository.readMirrorSnapshot();
    final original = snapshot.topics.single.id;
    final sourceRoot = snapshot.organization.folders.single.id;
    final copyRoot = await engine.createLocalCopy(sourceRoot);
    final secondCopy = await engine.createLocalCopy(sourceRoot);
    snapshot = await repository.readMirrorSnapshot();
    final copiedId = snapshot.organization.directIds(copyRoot).single;
    expect(
      snapshot.organization.folders.firstWhere((f) => f.id == secondCopy).name,
      'Artists (2)',
    );
    expect(snapshot.mirrors.isReceived(copiedId), isFalse);
    expect(
      snapshot.topics.firstWhere((t) => t.id == copiedId).hasBaseline,
      isFalse,
    );
    await repository.rename(copiedId, 'Independent');
    expect((await repository.getById(original))!.name, 'Cats');
    await engine.unsubscribe(identity.id, folderId, forget: true);
    snapshot = await repository.readMirrorSnapshot();
    expect(snapshot.mirrors.owners, isEmpty);
    expect(snapshot.mirrors.subscriptions, isEmpty);
    expect(snapshot.mirrors.checkpoints, hasLength(2));
    expect(snapshot.topics, hasLength(2));
    expect((await repository.getById(copiedId))!.name, 'Independent');
  });

  for (final scenario in [
    'private',
    'unsupported',
    'ambiguous',
    'revoked',
    'mixed nested',
  ]) {
    test(
      '$scenario source cannot produce a partial or unusable local copy',
      () async {
        profiles = scenario == 'ambiguous'
            ? [
                localProfile,
                const BackupProfileReference(
                  id: futureId,
                  booruType: 'danbooru',
                  url: 'https://example.test',
                  name: 'Other',
                ),
              ]
            : [];
        final reference = switch (scenario) {
          'unsupported' => const BackupProfileReference(
            id: profileId,
            booruType: 'pixiv',
            url: 'https://www.pixiv.net',
            name: 'Private',
          ),
          'revoked' || 'mixed nested' => publicProfile,
          _ => sourceProfile,
        };
        final folder = await publish(folderId, name: 'Artists', folder: true);
        final topic = await publish(topicId, profile: reference);
        final second = scenario == 'mixed nested'
            ? await publish(futureId)
            : null;
        await receive(
          await advertise([folder, topic, if (second != null) second]),
          {folderId},
        );
        if (scenario == 'revoked') publicEnabled = false;
        final before = await repository.readMirrorSnapshot();
        await expectLater(
          engine.createLocalCopy(before.organization.folders.single.id),
          throwsA(isA<FollowingLocalCopySourceUnavailable>()),
        );
        final after = await repository.readMirrorSnapshot();
        expect(after.mirrors, before.mirrors);
        expect(after.structureDigest, before.structureDigest);
        expect(after.topics, before.topics);
        expect(after.organization, before.organization);
      },
    );
  }

  test('public nested copies retain source identity through runtime snapshots, edits and publication without an account', () async {
    profiles = [];
    final folder = await publish(folderId, name: 'Artists', folder: true);
    final topic = await publish(topicId, profile: publicProfile);
    await receive(await advertise([folder, topic]), {folderId});
    final before = await repository.readMirrorSnapshot();
    final root = await engine.createLocalCopy(
      before.organization.folders.single.id,
    );
    var copy = (await repository.getAll()).singleWhere(
      (t) => !before.mirrors.isReceived(t.id),
    );
    final source = copy.localSource;
    expect(source?.toJson(), {
      'booruType': 'gelbooruV2',
      'url': 'https://safebooru.org',
    });
    await repository.rename(copy.id, 'Independent');
    await repository.edit(
      copy.id,
      profileId: copy.profileId,
      query: 'dog',
      name: 'Dogs',
    );
    copy = (await repository.getById(copy.id))!;
    expect(copy.localSource, source);
    final snapshots = SearchRuntimeSnapshotService(repository);
    final codec = const SearchRuntimeSnapshotCodec();
    final saved = codec.decode(codec.encode(await snapshots.capture()));
    await repository.delete(copy.id);
    await snapshots.restore(saved);
    copy = (await repository.getById(copy.id))!;
    expect(copy.localSource, source);
    final publication = SyncFollowingDefinitions(
      snapshot: await repository.readMirrorSnapshot(),
      publisher: identity.id,
      roots: {root},
      profiles: const [],
    );
    final portable = publication.definitions[copy.id]!.records.single;
    expect(portable.profile.booruType, 'gelbooruV2');
    expect(portable.profile.url, 'https://safebooru.org');
    expect(portable.profile.id, copy.id);
    expect(portable.query, 'dog');
    await engine.unsubscribe(identity.id, folderId, forget: true);
    await Hive.close();
    repository = HiveFollowingTopicRepository(
      box: await Hive.openBox<FollowingTopicHiveObject>('topics'),
      organizationBox: await Hive.openBox<dynamic>('metadata'),
    );
    expect((await repository.getById(copy.id))!.localSource, source);
    expect(
      (await repository.getOrganization()).folders.single.feedEnabled,
      isTrue,
    );
  });

  for (final interrupted in [false, true]) {
    test(
      'copy Undo ${interrupted ? 'recovers an interrupted transaction' : 'restores one Topic'} without touching same-profile history',
      () async {
        final topic = await publish(topicId);
        await receive(await advertise([topic]), {topicId});
        final original = (await repository.getAll()).single;
        final copiedId = await engine.createLocalCopy(original.id);
        await repository.setAutoUpdate([copiedId], false);
        final copied = (await repository.getById(copiedId))!;
        await repository.recordHistoryEnd(
          copied,
          const FeedHistoryEnd(oldestPostIdentity: 'copied-end'),
        );
        final undo = (await repository.getById(copiedId))!;
        final sibling = await repository.create(
          profileId: undo.profileId,
          query: 'unrelated',
          name: 'Unrelated',
        );
        await repository.recordHistoryEnd(
          sibling,
          const FeedHistoryEnd(oldestPostIdentity: 'sibling-end'),
        );
        final metadata = Hive.box<dynamic>('metadata');
        final historyBefore = metadata.get('history:${sibling.id}');
        await repository.delete(copiedId);
        final siblingBefore = await repository.getById(sibling.id);
        final before = await repository.readMirrorSnapshot();
        if (interrupted)
          repository = HiveFollowingTopicRepository(
            box: Hive.box<FollowingTopicHiveObject>('topics'),
            organizationBox: metadata,
            fs: _InterruptedCopyStorage(
              () =>
                  Hive.box<FollowingTopicHiveObject>('topics')
                      .containsKey(copiedId),
            ),
          );
        final container = ProviderContainer(
          overrides: [
            followingTopicRepositoryProvider.overrideWith(
              () => _Repository(repository),
            ),
          ],
        );
        await container.read(followingTopicsProvider.future);
        final notifier = container.read(followingTopicsProvider.notifier);
        if (interrupted) {
          await expectLater(
            notifier.restoreIndependentTopic(undo),
            throwsA(anything),
          );
        } else {
          await notifier.restoreIndependentTopic(undo);
          final restored = (await repository.getById(copiedId))!;
          expect(restored.localSource, undo.localSource);
          expect(restored.autoUpdateEnabled, isFalse);
          expect(restored.historyEnd, undo.historyEnd);
          expect(
            (await repository.getOrganization()).homeSearchIds,
            contains(copiedId),
          );
        }
        container.dispose();
        await Hive.close();
        repository = HiveFollowingTopicRepository(
          box: await Hive.openBox<FollowingTopicHiveObject>('topics'),
          organizationBox: await Hive.openBox<dynamic>('metadata'),
        );
        final after = await repository.readMirrorSnapshot();
        expect(await repository.getById(sibling.id), siblingBefore);
        expect(
          Hive.box<dynamic>('metadata').get('history:${sibling.id}'),
          historyBefore,
        );
        expect(after.mirrors.owners, before.mirrors.owners);
        if (interrupted) {
          expect(await repository.getById(copiedId), isNull);
          expect(after.organization, before.organization);
          expect(after.mirrors, before.mirrors);
        } else {
          expect(
            (await repository.getById(copiedId))!.localSource,
            undo.localSource,
          );
        }
      },
    );
  }

  test('sparse signed sibling positions survive snapshot projection and no-op receive', () async {
    final folder = await publish(folderId, name: 'Artists', folder: true);
    final topic = await publish(topicId);
    final ticket = await advertise([folder, topic], topicPosition: 17);
    await receive(ticket, {folderId});
    final before = await repository.readMirrorSnapshot();
    expect(before.organization.placements.single.position, 17);
    await repository.acknowledgeMirrorDefinition(before.topics.single.id);
    final epoch = (await repository.readMirrorSnapshot()).mirrors.epoch;
    await receive(ticket);
    expect((await repository.readMirrorSnapshot()).mirrors.epoch, epoch);
    expect((await repository.getOrganization()).placements.single.position, 17);
  });

  test('ambiguous profiles pause until one compatible profile exists, without creating profiles', () async {
    profiles = [
      localProfile,
      const BackupProfileReference(
        id: futureId,
        booruType: 'danbooru',
        url: 'https://example.test',
        name: 'Second account',
      ),
    ];
    final topic = await publish(topicId);
    final ticket = await advertise([topic], direct: {topicId});
    await receive(ticket, {topicId});
    var snapshot = await repository.readMirrorSnapshot();
    expect(snapshot.topics.single.profileId, snapshot.topics.single.id);
    profiles = [localProfile];
    await receive(ticket);
    snapshot = await repository.readMirrorSnapshot();
    expect(snapshot.topics.single.profileId, otherProfileId);
    expect(profiles, [localProfile]);
  });

  test(
    'signed withdrawal preserves independent descendant root and replay floor',
    () async {
      final folder = await publish(folderId, name: 'Artists', folder: true);
      final topic = await publish(topicId);
      await receive(await advertise([folder, topic]), {folderId, topicId});
      final old = await repository.readMirrorSnapshot();
      final withdrawn = await advertise(
        [folder, topic],
        withdrawn: {folderId},
        direct: {topicId},
      );
      await receive(withdrawn);
      final snapshot = await repository.readMirrorSnapshot();
      expect(snapshot.topics.single.id, old.topics.single.id);
      expect(snapshot.organization.folders, isEmpty);
      expect(
        snapshot.mirrors.checkpoints['${identity.id}/$folderId']!.retired,
        isTrue,
      );
      // A valid key may advertise an old revision in a fresh catalog. The
      // receiver's durable retirement floor must reject it independently of
      // the well-behaved publisher's own reservation protection.
      final replay = SyncCatalog(
        publisher: identity.id,
        sequence: withdrawn.sequence + 1,
        name: 'Publisher',
        publicationRoots: {folder.collection, topic.collection},
        entries: [
          SyncCatalogEntry(
            id: folder.collection,
            name: 'Artists',
            state: SyncPublicationState.active,
            revision: folder,
          ),
          SyncCatalogEntry(
            id: topic.collection,
            name: 'Cats',
            parent: folderId,
            state: SyncPublicationState.active,
            revision: topic,
          ),
        ],
      );
      final replayTicket = await gate.verifyAndCheckpoint(
        publisher: identity.id,
        expectedSequence: replay.sequence,
        bytes: await identity.sign(replay.toJson()),
      );
      await expectLater(
        receive(replayTicket),
        throwsA(isA<SyncReplayRejected>()),
      );
      expect((await repository.readMirrorSnapshot()).mirrors, snapshot.mirrors);
    },
  );
}

class _Store implements MiscDataStore {
  final values = <String, String>{};
  @override
  String? get(String key) => values[key];
  @override
  Future<void> put(String key, String value) async {
    values[key] = value;
  }
}

class _Repository extends FollowingTopicRepositoryNotifier {
  _Repository(this.repository);
  final FollowingTopicRepository repository;
  @override
  Future<FollowingTopicRepository> build() async => repository;
}

class _Blacklist extends GlobalBlacklistedTagsNotifier {
  @override
  IList<BlacklistedTag> build() => <BlacklistedTag>[].lock;
}

class _InterruptedCopyStorage extends IoFileSystem {
  _InterruptedCopyStorage(this.applied);
  final bool Function() applied;
  var interrupted = false;
  @override
  Future<void> syncFile(String path) async {
    if (!interrupted && applied() && path.endsWith('topics.hive')) {
      interrupted = true;
      throw StateError('Interrupted after copy Undo apply');
    }
    await super.syncFile(path);
  }

  @override
  Future<void> writeString(
    String path,
    String content, {
    bool flush = false,
  }) async {
    if (interrupted && content.contains('"state":"rollingBack"'))
      throw StateError('Process stopped before rollback');
    await super.writeString(path, content, flush: flush);
  }
}
