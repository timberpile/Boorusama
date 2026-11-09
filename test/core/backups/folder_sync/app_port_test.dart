import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:boorusama/core/backups/folder_sync/app_port.dart';
import 'package:boorusama/core/backups/export_import/import/bookmark_profile_dependency.dart';
import 'package:boorusama/core/backups/folder_sync/mirror_guard.dart';
import 'package:boorusama/core/backups/folder_sync/protocol.dart';
import 'package:boorusama/core/backups/folder_sync/service.dart';
import 'package:boorusama/core/backups/folder_sync/storage.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_hive_object.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/cache/hive_misc_data_store.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/import/import_recovery_gate.dart';
import 'package:boorusama/core/backups/export_import/import/import_journal.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_preflight.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/search/following_topics/src/compatibility/topic_storage_contract.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/data/providers.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../bookmarks/pool_bookmark_test_utils.dart';

final _portProvider = Provider<AppSyncCollectionPort>(
  AppSyncCollectionPort.new,
);
final _rollbackSourceProvider =
    Provider.family<PackageTransactionSource, String>(
      (ref, id) => PackageTransactionSource(
        source: ref.read(backupRegistryProvider).getSource(id)!,
        incomingPath: null,
        fs: ref.read(appFileSystemProvider),
        ref: ref,
        credentialsIncluded: true,
      ),
    );
const _sourceId = '10000000-0000-4000-8000-000000000001';
const _localId = '10000000-0000-4000-8000-000000000002';

void main() {
  test('production v10 and Following sync preserve Hive membership, actor hints and initial disabled updates', () async {
    final directory = await Directory.systemTemp.createTemp(
      'folder-sync-port-',
    );
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
    final containers = <ProviderContainer>[];
    addTearDown(() async {
      for (final container in containers) {
        container.dispose();
      }
      await Hive.close();
      await directory.delete(recursive: true);
    });

    Future<(ProviderContainer, BookmarkHiveRepository, BookmarkGroupRepository)>
    dataset(String prefix) async {
      final root = '${directory.path}/$prefix';
      await Directory(root).create(recursive: true);
      final coordinator = DataMutationCoordinator();
      final posts = await Hive.openBox<BookmarkHiveObject>('${prefix}_posts');
      final payload = await Hive.openBox<dynamic>('${prefix}_payload');
      final metadata = await Hive.openBox<dynamic>('${prefix}_metadata');
      await Hive.openBox<BookmarkGroupHiveObject>('${prefix}_groups');
      await Hive.openBox<dynamic>('${prefix}_organization');
      final profiles = HiveBooruConfigRepository(
        box: await Hive.openBox<String>('${prefix}_profiles'),
      );
      final misc = HiveMiscDataStore(
        await Hive.openBox<String>('${prefix}_misc'),
      );
      final bootstrap = ProviderContainer(
        overrides: [miscDataStoreProvider.overrideWithValue(misc)],
      );
      final guard = bootstrap.read(collectionMirrorGuardProvider);
      bootstrap.dispose();
      final repository = BookmarkHiveRepository(
        posts,
        groupPayloadBox: payload,
        metadataBox: metadata,
        coordinator: coordinator,
        legacyGroupBoxName: '${prefix}_groups',
        legacyOrganizationBoxName: '${prefix}_organization',
        mirrorGuard: guard,
      );
      final groups = await repository.openOrganization();
      final topicRepository = HiveFollowingTopicRepository(
        box: await Hive.openBox<FollowingTopicHiveObject>('${prefix}_topics'),
        organizationBox: await Hive.openBox<dynamic>(
          '${prefix}_topic_organization',
        ),
        mirrorGuard: guard,
      );
      final container = ProviderContainer(
        overrides: [
          loggerProvider.overrideWithValue(AppLogger()),
          dataMutationCoordinatorProvider.overrideWithValue(coordinator),
          booruEngineRegistryProvider.overrideWith(
            (ref) => BooruEngineRegistry(),
          ),
          bookmarkRepoProvider.overrideWith((ref) => repository),
          bookmarkGroupRepoProvider.overrideWith((ref) => groups),
          bookmarkUrlResolverProvider.overrideWith(
            (ref, id) => const DefaultImageUrlResolver(),
          ),
          booruConfigRepoProvider.overrideWithValue(profiles),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: []),
          ),
          appFileSystemProvider.overrideWithValue(_FileSystem(root)),
          appVersionProvider.overrideWithValue(null),
          settingsNotifierProvider.overrideWith(() => _Settings()),
          collectionMirrorGuardProvider.overrideWithValue(guard),
          miscDataStoreProvider.overrideWithValue(misc),
          backupRegistryProvider.overrideWith(
            (ref) => BackupRegistry()
              ..register(ref.read(bookmarksBackupSourceProvider))
              ..register(ref.read(followingTopicsBackupSourceProvider)),
          ),
          followingTopicRepositoryProvider.overrideWith(
            () => _Topics(topicRepository),
          ),
        ],
      );
      containers.add(container);
      await container.read(bookmarkProvider.future);
      await container.read(followingTopicsProvider.future);
      return (container, repository, groups);
    }

    final (a, aStore, aGroups) = await dataset('a');
    final (b, bStore, bGroups) = await dataset('b');
    final sourceGroup = await aGroups.createGroup('Published', id: _sourceId);
    final saved = (await aStore.addBookmarkWithBookmarks([testPoolPost(1)]))
        .single;
    await aGroups.replaceMemberships(sourceGroup.id, {saved.id});
    await a.read(bookmarkProvider.notifier).refresh();
    final captured = await a
        .read(_portProvider)
        .capture(
          const SyncSourceCollection(
            kind: 'bookmarks',
            id: _sourceId,
            name: 'Published',
          ),
        );
    final revision = SyncRevision(
      collection: SyncCollectionId(
        publisher: '10000000-0000-4000-8000-000000000003',
        kind: 'bookmarks',
        source: _sourceId,
      ),
      revision: 1,
      length: captured.bytes.length,
      sha256: syncDigest(captured.bytes),
      semanticHash: captured.semanticHash,
      schema: captured.schema,
    );
    final result = await b
        .read(_portProvider)
        .apply(
          revision: revision,
          bytes: captured.bytes,
          localId: _localId,
          name: 'Receiver name',
        );
    expect(result.localId, _localId);
    final received = await bGroups.getGroup(_localId);
    expect(received!.name, 'Receiver name');
    expect(received.bookmarkIds.length, 1);
    expect((await bStore.readAll()).length, 1);
    expect(
      (await bGroups.getGroup(defaultBookmarkGroupId))!.bookmarkIds,
      isEmpty,
    );
    final outside = await bGroups.createGroup('Outside');
    await bGroups.replaceMemberships(outside.id, received.bookmarkIds);
    await bGroups.renameGroup(_localId, 'Local override');
    const receiverHint = '10000000-0000-4000-8000-000000000099';
    final receiverRecord = (await bStore.readAll()).single;
    await bStore.upsert(
      bookmarkRecordWithProfileHint(receiverRecord, receiverHint),
    );
    await b
        .read(_portProvider)
        .apply(
          revision: revision,
          bytes: captured.bytes,
          localId: _localId,
          name: 'Source renamed',
        );
    expect((await bGroups.getGroup(_localId))!.name, 'Local override');
    expect(
      bookmarkRecordProfileHint((await bStore.readAll()).single),
      receiverHint,
    );
    expect(
      (await bGroups.getGroup(outside.id))!.bookmarkIds,
      received.bookmarkIds,
    );
    expect((await bStore.readAll()).length, 1);
    expect(
      await Directory('${directory.path}/b/import_transactions')
          .list()
          .toList(),
      isEmpty,
    );
    final profileA = BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: BooruType.gelbooru,
        url: 'https://gelbooru.com',
        customDownloadFileNameFormat: null,
      ).toJson(),
      'id': '10000000-0000-4000-8000-000000000011',
    });
    final profileB = BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: BooruType.gelbooru,
        url: 'https://gelbooru.com',
        customDownloadFileNameFormat: null,
      ).toJson(),
      'id': '10000000-0000-4000-8000-000000000012',
    });
    await a.read(booruConfigRepoProvider).addAll([profileA]);
    await b.read(booruConfigRepoProvider).addAll([profileB]);
    await a.read(booruConfigProvider.notifier).fetch();
    await b.read(booruConfigProvider.notifier).fetch();
    final sourceTopics = await a.read(followingTopicRepositoryProvider.future);
    const topicId = '10000000-0000-4000-8000-000000000077';
    await sourceTopics.create(
      profileId: profileA.id,
      query: 'fixture',
      name: 'Disabled source topic',
      id: topicId,
    );
    await sourceTopics.setAutoUpdate([topicId], false);
    a.invalidate(followingTopicsProvider);
    await a.read(followingTopicsProvider.future);
    final wire = _WireStorage();
    final publisher = FolderSyncService(
      metadata: _SyncMetadata(),
      port: a.read(_portProvider),
      storageFor: (_) => wire,
    );
    final receiverMetadata = _SyncMetadata();
    final receiver = FolderSyncService(
      metadata: receiverMetadata,
      port: b.read(_portProvider),
      storageFor: (_) => wire,
      bindingsChanged: b.read(collectionMirrorGuardProvider).replaceBindings,
      followingBindingsChanged: b
          .read(collectionMirrorGuardProvider)
          .replaceFollowingBindings,
    );
    addTearDown(publisher.dispose);
    addTearDown(receiver.dispose);
    await publisher.initialize();
    await receiver.initialize();
    await publisher.chooseFolder('shared');
    await receiver.chooseFolder('shared');
    await publisher.setPublication(
      const SyncSourceCollection(
        kind: 'following_topics',
        id: topicId,
        name: 'Disabled source topic',
      ),
      enabled: true,
    );
    await publisher.synchronize();
    final offer = (await receiver.discover()).single;
    await receiver.approvePublisher(
      offer['publisher'] as String,
      offer['publicKey'] as String,
    );
    await receiver.subscribe(
      offer: (offer['collections'] as List).single as Map<String, dynamic>,
      publisher: offer['publisher'] as String,
      name: 'Local topic',
    );
    await receiver.synchronize();
    final localTopicId =
        ((receiver.snapshot['subscriptions'] as Map).values.single
                as Map)['localId']
            as String;
    final receivedTopics = await b.read(
      followingTopicRepositoryProvider.future,
    );
    expect(
      (await receivedTopics.getById(localTopicId))!.autoUpdateEnabled,
      false,
    );
    expect(
      b
          .read(followingTopicsProvider)
          .requireValue
          .topics
          .single
          .autoUpdateEnabled,
      false,
    );
    await receiver.synchronize(); // An identical revision must not hide a wrong initial setting.
    expect(
      (await receivedTopics.getById(localTopicId))!.autoUpdateEnabled,
      false,
    );
    expect((await receivedTopics.getAll()).length, 1);
    final persisted =
        jsonDecode(jsonEncode(receiverMetadata.value)) as Map<String, dynamic>;
    (persisted['subscriptions'] as Map)['book-mirror'] = {
      'kind': 'bookmarks',
      'localId': _localId,
      'publisher': (publisher.snapshot['identity'] as Map)['id'],
      'source': _sourceId,
      'applied': 1,
      'state': 'ready',
      'members': result.members.toList(),
      'unseen': <String>[],
      'direct': true,
      'inherited': <String>[],
    };
    await b
        .read(miscDataStoreProvider)
        .put(folderSyncMetadataKey, jsonEncode(persisted));
    final guard = b.read(collectionMirrorGuardProvider)
      ..replaceBindings([_localId]);
    final fs = b.read(appFileSystemProvider);
    final journals = ImportJournalStore(
      fs: fs,
      rootPath: '${await fs.getAppStoragePath()}/import_transactions',
    );
    final plan = ValidatedImportPlan(
      plan: ResolvedImportPlan(
        sources: [
          ResolvedImportSource(
            id: 'bookmarks',
            action: ImportAction.update,
            items: const [],
          ),
          ResolvedImportSource(
            id: followingTopicsBackupSourceId,
            action: ImportAction.update,
            items: const [],
          ),
        ],
      ),
      revisionTokens: const {},
      summary: const PlannedChangeSummary(updated: 2),
    );
    var journal = await journals.create('received-interrupted', plan);
    final hashes = <String, String>{};
    for (final id in ['bookmarks', followingTopicsBackupSourceId]) {
      final path = '${journals.rollbackPath(journal.transactionId, id)}.data';
      await b.read(_rollbackSourceProvider(id)).captureRollback(path);
      await fs.syncFile(path);
      hashes[id] = syncDigest(await fs.readBytes(path));
    }
    journal = journal.copyWith(
      state: ImportJournalState.applying,
      completedSourceIds: ['bookmarks'],
      currentSourceId: followingTopicsBackupSourceId,
      rollbackHashes: hashes,
    );
    await journals.write(journal);
    await guard.applyReceived(() async {
      await bGroups.replaceMemberships(_localId, {});
      await receivedTopics.edit(
        localTopicId,
        profileId: profileB.id,
        query: 'interrupted-query',
        name: 'Local topic',
        autoUpdateEnabled: true,
      );
    });
    await publisher.dispose();
    await receiver.dispose();
    for (final container in containers) {
      container.dispose();
    }
    containers.clear();
    await Hive.close();
    Hive.init(directory.path);
    final (restarted, restartedStore, restartedGroups) = await dataset('b');
    final restartedGuard = restarted.read(collectionMirrorGuardProvider);
    expect(restartedGuard.isReadOnly(_localId), true);
    expect(restartedGuard.isFollowingReadOnly(localTopicId), true);
    final recovery = await restarted.read(importRecoveryProvider.future);
    expect(recovery.failures, isEmpty);
    expect(recovery.recoveredTransactionIds, ['received-interrupted']);
    expect(
      (await restartedGroups.getGroup(_localId))!.bookmarkIds,
      received.bookmarkIds,
    );
    expect((await restartedStore.readAll()).length, 1);
    final restoredTopics = await restarted.read(
      followingTopicRepositoryProvider.future,
    );
    final restoredTopic = (await restoredTopics.getById(localTopicId))!;
    expect(restoredTopic.query, 'fixture');
    expect(restoredTopic.autoUpdateEnabled, false);
    await expectLater(
      restartedGroups.replaceMemberships(_localId, {}),
      throwsA(isA<CollectionMirrorReadOnly>()),
    );
    await expectLater(
      restoredTopics.edit(
        localTopicId,
        profileId: restoredTopic.profileId,
        query: 'unapproved',
        name: restoredTopic.name,
      ),
      throwsA(isA<CollectionMirrorReadOnly>()),
    );
  });
}

class _FileSystem extends IoFileSystem {
  const _FileSystem(this.root);
  final String root;
  @override
  Future<String> getAppStoragePath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

class _Settings extends SettingsNotifier {
  _Settings() : super(Settings.defaultSettings);
  @override
  Settings build() => Settings.defaultSettings;
}

class _Topics extends FollowingTopicRepositoryNotifier {
  _Topics(this.repository);
  final FollowingTopicRepository repository;
  @override
  Future<FollowingTopicRepository> build() async => repository;
}

class _SyncMetadata implements FolderSyncMetadataStore {
  Map<String, dynamic> value = {};
  @override
  Future<Map<String, dynamic>> load() async =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  @override
  Future<void> save(Map<String, dynamic> next) async {
    value = jsonDecode(jsonEncode(next)) as Map<String, dynamic>;
  }
}

class _WireStorage implements FolderSyncStorage {
  final files = <String, Uint8List>{};
  @override
  Future<List<String>> list(String path) async {
    final prefix = path.isEmpty ? '' : '$path/';
    return files.keys
        .where((key) => key.startsWith(prefix))
        .map((key) => key.substring(prefix.length).split('/').first)
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Future<Uint8List?> read(
    String path, {
    int maxBytes = folderSyncMaxBytes,
  }) async {
    final bytes = files[path];
    if (bytes != null && bytes.length > maxBytes) throw const FormatException();
    return bytes;
  }

  @override
  Future<void> writeImmutable(String path, Uint8List bytes) async {
    if (files.containsKey(path) &&
        base64Encode(files[path]!) != base64Encode(bytes))
      throw StateError('Immutable overwrite');
    files[path] = bytes;
  }

  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) async {
    if (!isOwnedSyncRevisionPath(path, owner)) throw const FormatException();
    files.remove(path);
  }
}
