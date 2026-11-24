import 'dart:io';

import 'package:boorusama/core/backups/export_import/import/search_runtime_snapshot.dart';
import 'package:boorusama/core/backups/sources/following_topic_backup_data.dart';
import 'package:boorusama/core/backups/sources/following_topic_import_service.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/configs/config/types.dart';

import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_hive_object.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart';
import 'package:boorusama/core/search/following_topics/src/types/following_mirror_state.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const publisher = '11111111-1111-4111-8111-111111111111';
const sourceFolder = '22222222-2222-4222-8222-222222222222';
const sourceTopic = '33333333-3333-4333-8333-333333333333';
const localFolder = '44444444-4444-4444-8444-444444444444';
const localTopic = '55555555-5555-4555-8555-555555555555';
const profile = '66666666-6666-4666-8666-666666666666';

void main() {
  late Directory root;
  late Box<FollowingTopicHiveObject> box;
  late Box<dynamic> metadata;
  late HiveFollowingTopicRepository repository;
  final created = DateTime.utc(2026, 11, 14);

  Future<void> open({AppFileSystem fs = const IoFileSystem()}) async {
    box = await Hive.openBox<FollowingTopicHiveObject>('topics');
    metadata = await Hive.openBox<dynamic>('metadata');
    repository = HiveFollowingTopicRepository(
      box: box,
      organizationBox: metadata,
      fs: fs,
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('following_mirror_');
    Hive.init(root.path);
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(FollowingTopicHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(SearchPostPreviewHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(RecentSearchPostHiveObjectAdapter());
    }
    await open();
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  Future<void> receive({
    int revision = 1,
    String name = 'Cats',
    String query = 'cat',
  }) async {
    final before = await repository.readMirrorSnapshot();
    final topic = FollowingTopic.create(
      id: localTopic,
      profileId: profile,
      query: query,
      name: name,
      position: 0,
      createdAt: created,
    );
    final folder = TopicFolder(
      id: localFolder,
      nameScope: followingFolderNameScope(publisher, null),
      name: 'Artists',
      position: 0,
      feedEnabled: true,
    );
    FollowingMirrorOwner owner(
      String source,
      FollowingMirrorKind kind,
    ) => FollowingMirrorOwner(
      publisher: publisher,
      source: source,
      kind: kind,
      revision: revision,
      parentSource: kind == FollowingMirrorKind.topic ? sourceFolder : null,
      payloadDigest: '${revision % 10}' * 64,
      descriptorDigest: 'a' * 64,
      definitionDigest: followingDefinitionDigest(
        kind: kind,
        parentSource: kind == FollowingMirrorKind.topic ? sourceFolder : null,
        position: 0,
        topic: topic,
        folder: folder,
        children: [
          FollowingDefinitionChild(
            source: sourceTopic,
            kind: FollowingMirrorKind.topic,
            position: 0,
          ),
        ],
      ),
      seenDefinitionDigest: before
          .mirrors
          .owners[kind == FollowingMirrorKind.topic ? localTopic : localFolder]
          ?.seenDefinitionDigest,
    );
    final organization = TopicOrganization(
      folders: [
        ...before.organization.folders.where((f) => f.id != localFolder),
        folder,
      ],
      placements: [
        ...before.organization.placements.where((p) => p.itemId != localTopic),
        const FolderPlacement(
          itemId: localTopic,
          folderId: localFolder,
        ),
      ],
    );
    await repository.commitMirrorDefinitions(
      expected: before.mirrors,
      expectedStructureDigest: before.structureDigest,
      next: FollowingMirrorState(
        epoch: before.mirrors.epoch + 1,
        owners: {
          localTopic: owner(sourceTopic, FollowingMirrorKind.topic),
          localFolder: owner(sourceFolder, FollowingMirrorKind.folder),
        },
        checkpoints: before.mirrors.checkpoints,
        subscriptions: const {
          publisher: {sourceFolder},
        },
        publisherNames: const {publisher: 'Source device'},
      ),
      topics: [topic],
      organization: organization,
    );
  }

  test('received definitions reject ordinary edits while local runtime remains writable', () async {
    final local = await repository.create(
      profileId: profile,
      query: 'dog',
      name: 'Local',
    );
    await receive();
    final before = await repository.readMirrorSnapshot();
    for (final operation in <Future<void> Function()>[
      () => Future.sync(() => repository.rename(localTopic, 'Renamed')),
      () => Future.sync(
        () => repository.edit(
          localTopic,
          profileId: profile,
          query: 'wolf',
          name: 'Changed',
        ),
      ),
      () => repository.delete(localTopic),
      () => repository.deleteSharedFolderAndTopics(localFolder),
      () => repository.replaceOrganization(
        TopicOrganization(
          folders: const [],
          homeSearchIds: [local.id, localTopic],
        ),
      ),
      () => repository.replaceOrganization(
        TopicOrganization(
          folders: before.organization.folders,
          placements: [
            for (final p in before.organization.placements)
              p.itemId == localTopic
                  ? const FolderPlacement(itemId: localTopic)
                  : p,
          ],
        ),
      ),
      () => Future.sync(
        () => repository.saveTopicInNewFolder(
          profileId: profile,
          query: 'dog',
          name: 'Local',
          folderName: 'Mixed',
          parentFolderId: localFolder,
        ),
      ),
      () => repository.restoreForProfile(
        profile,
        before.topics.where((topic) => topic.id == localTopic).toList(),
      ),
    ]) {
      await expectLater(operation(), throwsA(anything));
      expect((await repository.readMirrorSnapshot()).mirrors, before.mirrors);
    }
    await repository.setAutoUpdate([localTopic], false);
    await repository.commitRefresh(
      SearchRefreshCommit(
        topicId: localTopic,
        expectedCreatedAt: created,
        expectedCheckpoint: null,
        startedAt: created.add(const Duration(hours: 1)),
        baseline: true,
        discoveredPosts: const [],
        identityRetentionBoundary: created,
      ),
    );
    final refreshed = (await repository.getById(localTopic))!;
    expect(refreshed.hasBaseline, isTrue);
    expect(refreshed.autoUpdateEnabled, isFalse);
    await repository.acknowledgeMirrorDefinition(localTopic);
    await repository.markRead(localTopic);
    expect(
      (await repository.readMirrorSnapshot())
          .mirrors
          .owners[localTopic]!
          .hasDefinitionChange,
      isFalse,
    );
    expect((await repository.getById(local.id))!.name, 'Local');
    await receive(revision: 2, name: 'Renamed at source');
    final renamed = (await repository.getById(localTopic))!;
    expect(renamed.name, 'Renamed at source');
    expect(renamed.lastSuccessfulCheckAt, refreshed.lastSuccessfulCheckAt);
    expect(renamed.autoUpdateEnabled, isFalse);
    expect(
      (await repository.readMirrorSnapshot())
          .mirrors
          .owners[localTopic]!
          .hasDefinitionChange,
      isTrue,
    );
    await receive(revision: 3, query: 'wolf');
    final changed = (await repository.getById(localTopic))!;
    expect(changed.hasBaseline, isFalse);
    expect(changed.runtimeRevision, refreshed.runtimeRevision + 1);
    expect(changed.autoUpdateEnabled, isFalse);
    await repository.deleteForProfile(profile);
    expect(await repository.getById(local.id), isNull);
    expect((await repository.getById(localTopic))!.query, 'wolf');
    expect(
      (await repository.readMirrorSnapshot()).mirrors.owners,
      hasLength(2),
    );
  });

  test('local runtime rollback preserves newer received definitions, receipts and refresh state', () async {
    final local = await repository.create(
      profileId: profile,
      query: 'dog',
      name: 'Local',
    );
    await receive();
    await repository.setAutoUpdate([localTopic], false);
    await repository.acknowledgeMirrorDefinition(localFolder);
    final snapshots = SearchRuntimeSnapshotService(repository);
    final captured = await snapshots.capture();
    expect(captured.searches.map((topic) => topic.id), [local.id]);
    expect(captured.organization.folders, isEmpty);
    await repository.rename(local.id, 'Temporary import');
    await receive(revision: 2, name: 'Newer remote definition');
    await repository.acknowledgeMirrorDefinition(localTopic);
    final committed = await repository.readMirrorSnapshot();
    final runtime = await repository.getById(localTopic);
    await snapshots.restore(
      const SearchRuntimeSnapshotCodec().decode(
        const SearchRuntimeSnapshotCodec().encode(captured),
      ),
    );
    final restored = await repository.readMirrorSnapshot();
    expect(restored.mirrors, committed.mirrors);
    expect(await repository.getById(localTopic), runtime);
    expect((await repository.getById(local.id))!.name, 'Local');
    expect(restored.organization.folders, committed.organization.folders);
    expect(await snapshots.capture(), captured);
    await repository.restoreForProfile(profile, [local]);
    expect(await repository.getById(localTopic), runtime);
    await expectLater(
      repository.restoreForProfile(profile, [runtime!]),
      throwsA(isA<FollowingMirrorReadOnly>()),
    );
    expect((await repository.readMirrorSnapshot()).mirrors, committed.mirrors);
    await Hive.close();
    await open();
    expect((await repository.readMirrorSnapshot()).mirrors, committed.mirrors);
    expect(await repository.getById(localTopic), runtime);
  });

  test('ordinary import and Replace remain local beside same-profile mirrors and reject received ID collisions', () async {
    await receive();
    await repository.setAutoUpdate([localTopic], false);
    await repository.acknowledgeMirrorDefinition(localTopic);
    final before = await repository.readMirrorSnapshot();
    final remote = await repository.getById(localTopic);
    final config = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': profile,
      'url': 'https://example.test',
      'booruIdHint': 0,
    });
    FollowingTopicBackupData data(String id, String query) =>
        FollowingTopicBackupData(
          records: [
            FollowingTopicBackupRecord(
              id: id,
              query: query,
              name: 'Imported',
              position: 0,
              profile: BackupProfileReference(
                id: profile,
                booruType: config.auth.booruType.name,
                url: config.url,
                name: config.name,
              ),
            ),
          ],
        );
    final importer = FollowingTopicImportService(repository: repository);
    const importedId = '77777777-7777-4777-8777-777777777777';
    final added = await importer.apply(
      data(importedId, 'cat'),
      profiles: [config],
    );
    expect(added.importedCount, 1);
    expect(added.resolvedIds[importedId], importedId);
    expect(await repository.getById(localTopic), remote);
    await expectLater(
      importer.replace(data(localTopic, 'Overwrite'), profiles: [config]),
      throwsA(isA<FollowingMirrorReadOnly>()),
    );
    expect((await repository.getById(importedId))!.query, 'cat');
    expect(await repository.getById(localTopic), remote);
    await importer.replace(
      const FollowingTopicBackupData(records: []),
      profiles: [config],
    );
    expect(await repository.getById(importedId), isNull);
    expect(await repository.getById(localTopic), remote);
    expect((await repository.readMirrorSnapshot()).mirrors, before.mirrors);
    expect(
      (await repository.getOrganization()).folders,
      before.organization.folders,
    );
  });

  test('recovery reconstructs source-parent namespaces for identically named virtual roots', () async {
    const otherSource = '77777777-7777-4777-8777-777777777777';
    const otherLocal = '88888888-8888-4888-8888-888888888888';
    Future<void> commit({String firstName = 'Favorites'}) async {
      final before = await repository.readMirrorSnapshot();
      final folders = [
        TopicFolder(
          id: localFolder,
          name: firstName,
          nameScope: followingFolderNameScope(publisher, sourceTopic),
          position: 4,
        ),
        TopicFolder(
          id: otherLocal,
          name: 'Favorites',
          nameScope: followingFolderNameScope(publisher, profile),
          position: 9,
        ),
      ];
      final owners = <String, FollowingMirrorOwner>{};
      for (final folder in folders) {
        final parent = folder.id == localFolder ? sourceTopic : profile;
        owners[folder.id] = FollowingMirrorOwner(
          publisher: publisher,
          source: folder.id == localFolder ? sourceFolder : otherSource,
          kind: FollowingMirrorKind.folder,
          revision: before.mirrors.epoch + 1,
          parentSource: parent,
          position: folder.position,
          payloadDigest: 'a' * 64,
          descriptorDigest: 'b' * 64,
          definitionDigest: followingDefinitionDigest(
            kind: FollowingMirrorKind.folder,
            parentSource: parent,
            position: folder.position,
            folder: folder,
          ),
        );
      }
      await repository.commitMirrorDefinitions(
        expected: before.mirrors,
        expectedStructureDigest: before.structureDigest,
        next: FollowingMirrorState(
          epoch: before.mirrors.epoch + 1,
          owners: owners,
          checkpoints: before.mirrors.checkpoints,
          subscriptions: const {
            publisher: {sourceFolder, otherSource},
          },
        ),
        topics: const [],
        organization: TopicOrganization(folders: folders),
      );
    }

    await commit();
    final original = await repository.readMirrorSnapshot();
    repository = HiveFollowingTopicRepository(
      box: box,
      organizationBox: metadata,
      fs: _InterruptedStorage(
        () => (metadata.get('search:sync_mirrors') as Map?)?['epoch'] == 2,
      ),
    );
    await expectLater(commit(firstName: 'Changed'), throwsA(anything));
    await Hive.close();
    await open();
    final recovered = await repository.readMirrorSnapshot();
    expect(recovered.organization, original.organization);
    expect(recovered.mirrors, original.mirrors);
    expect(recovered.organization.tree.children(null).map((f) => f.id), [
      localFolder,
      otherLocal,
    ]);
    await expectLater(
      repository.replaceOrganization(
        TopicOrganization(
          folders: [
            for (final f in recovered.organization.folders)
              f.id == localFolder ? f.copyWith(name: 'Local edit') : f,
          ],
        ),
      ),
      throwsA(isA<FollowingMirrorReadOnly>()),
    );
    await commit(firstName: 'Changed');
    await Hive.close();
    await open();
    expect(
      (await repository.getOrganization()).tree
          .children(null)
          .map((f) => f.name),
      ['Changed', 'Favorites'],
    );
  });

  test('an interrupted mirror transaction recovers definitions and ownership together before reads', () async {
    final local = await repository.create(
      profileId: profile,
      query: 'dog',
      name: 'Keep me',
    );
    final fs = _InterruptedStorage(
      () => metadata.get('search:sync_mirrors') != null,
    );
    repository = HiveFollowingTopicRepository(
      box: box,
      organizationBox: metadata,
      fs: fs,
    );
    await expectLater(receive(), throwsA(anything));
    expect(
      metadata.get('search:sync_mirrors'),
      isNotNull,
      reason: 'Fault occurs after apply, before its durable commit',
    );
    await Hive.close();
    await open();
    final recovered = await repository.readMirrorSnapshot();
    expect(recovered.mirrors.owners, isEmpty);
    expect(await repository.getById(localTopic), isNull);
    expect((await repository.getById(local.id))!.name, 'Keep me');
    expect(recovered.organization.folders, isEmpty);
    await receive();
    await Hive.close();
    await open();
    expect(
      (await repository.readMirrorSnapshot()).mirrors.owners,
      hasLength(2),
    );
    expect((await repository.getById(local.id))!.name, 'Keep me');
  });
}

class _InterruptedStorage extends IoFileSystem {
  _InterruptedStorage(this.applied);
  final bool Function() applied;
  var interrupted = false;
  @override
  Future<void> syncFile(String path) async {
    if (!interrupted && applied() && path.endsWith('topics.hive')) {
      interrupted = true;
      throw StateError('Injected interruption after mirror apply');
    }
    await super.syncFile(path);
  }

  @override
  Future<void> writeString(
    String path,
    String content, {
    bool flush = false,
  }) async {
    if (interrupted && content.contains('"state":"rollingBack"')) {
      throw StateError('Process unavailable before rollback can begin');
    }
    await super.writeString(path, content, flush: flush);
  }
}
