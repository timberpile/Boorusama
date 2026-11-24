import 'dart:io';

import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/import/import_journal.dart';
import 'package:boorusama/core/backups/export_import/import/import_preflight.dart';
import 'package:boorusama/core/backups/export_import/import/import_transaction.dart';
import 'package:boorusama/core/backups/export_import/import/search_runtime_snapshot.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/core/backups/export_import/sources/legacy_json_source_adapter.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/search/following_topics/src/compatibility/topic_storage_contract.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_hive_object.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart';
import 'package:boorusama/core/search/following_topics/src/data/providers.dart';
import 'package:boorusama/core/search/following_topics/src/types/following_mirror_state.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:hive_ce/hive.dart';

import 'import_transaction_test_utils.dart';

import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_planned_change_projector.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/following_topic_backup_data.dart';
import 'package:boorusama/core/backups/sources/following_topic_import_service.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../search/following_topics/topic_test_utils.dart';

const _id = '22222222-2222-4222-8222-222222222222';
const _data = FollowingTopicBackupData(
  records: [
    FollowingTopicBackupRecord(
      id: _id,
      name: 'Cats',
      query: 'cat',
      position: 0,
      autoUpdateEnabled: false,
      profile: BackupProfileReference(
        id: '11111111-1111-4111-8111-111111111111',
        booruType: 'gelbooruV2',
        url: 'https://safebooru.org',
        name: 'Source profile',
      ),
    ),
  ],
  homeSearchIds: [_id],
);

void main() {
  test(
    'profileless Replace has a concrete preview and repeats without changes',
    () async {
      const projector = ImportPlannedChangeProjector();
      final resolution = ResolvedImportSource(
        id: 'pinned_searches',
        action: ImportAction.replace,
        items: const [],
      );
      final repository = memorySubscriptionRepository();
      final before = projector.followingTopics(
        local: FollowingTopicImportLocalSnapshot(
          searches: [],
          feeds: [],
          organization: TopicOrganization(folders: const []),
        ),
        incoming: _data,
        resolution: resolution,
        profileMappings: {},
      );
      expect(before, isNotNull);
      expect(before!.entitySummaries['following-topic']?.created, 1);

      final service = FollowingTopicImportService(repository: repository);
      final applied = await service.replace(_data, profiles: []);
      expect(applied.importedCount, 1);
      final after = projector.followingTopics(
        local: FollowingTopicImportLocalSnapshot(
          searches: await repository.getAll(),
          feeds: await repository.getFeeds(),
          organization: await repository.getOrganization(),
        ),
        incoming: _data,
        resolution: resolution,
        profileMappings: {},
      );
      expect(after, isNotNull);
      expect(after!.created, 0);
      expect(after.updated, 0);
      expect(after.deleted, 0);
      final repeated = await service.replace(_data, profiles: []);
      expect(repeated.alreadyExistedCount, 1);
      expect(await repository.getAll(), hasLength(1));
    },
  );

  test(
    'staged package imports and reexports a profileless Topic, with rollback after persistence',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'profileless_package_',
      );
      final fs = _FileSystem(root.path);
      Hive.init(root.path);
      Hive.registerAdapter(FollowingTopicHiveObjectAdapter());
      Hive.registerAdapter(SearchPostPreviewHiveObjectAdapter());
      Hive.registerAdapter(RecentSearchPostHiveObjectAdapter());
      addTearDown(() async {
        await Hive.close();
        await root.delete(recursive: true);
      });
      final repository = HiveFollowingTopicRepository(
        box: await Hive.openBox<FollowingTopicHiveObject>(
          followingTopicsBoxName,
        ),
        organizationBox: await Hive.openBox<dynamic>(topicOrganizationBoxName),
        fs: fs,
      );
      final container = ProviderContainer(
        overrides: [
          loggerProvider.overrideWithValue(AppLogger()),
          appFileSystemProvider.overrideWithValue(fs),
          appVersionProvider.overrideWith((ref) => null),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: []),
          ),
          booruConfigRepoProvider.overrideWithValue(_NoProfiles()),
          followingTopicRepositoryProvider.overrideWith(
            () => _SearchRepository(repository),
          ),
          backupRegistryProvider.overrideWith(
            (ref) => BackupRegistry()
              ..register(ref.read(booruConfigsBackupSourceProvider))
              ..register(ref.read(followingTopicsBackupSourceProvider)),
          ),
          exportImportSourcesProvider.overrideWith(
            (ref) => [
              LegacyJsonSourceAdapter(
                source: ref.read(followingTopicsBackupSourceProvider),
                descriptor: const ExportSelectionDescriptor.collection(
                  id: 'pinned_searches',
                ),
              ),
            ],
          ),
        ],
      );
      final listener = container.listen(importFlowProvider, (_, _) {});
      addTearDown(() {
        listener.close();
        container.dispose();
      });
      final context = _MountedContext();
      final source = container.read(followingTopicsBackupSourceProvider);
      final encoded = source.converter.encode(
        payload: source.handler.encode(_data),
        extraFields: const {'source': 'pinned_searches'},
      );
      Future<String> writePackage(String name, String json) =>
          ExportPackageWriter(fs: fs).write(
            ExportPackageBuild(
              appVersion: '1.0.0',
              createdAt: DateTime.utc(2026, 11),
              sources: [
                ExportPackageSourceBuild(
                  id: 'pinned_searches',
                  schemaVersion: 2,
                  recommendedAction: ImportAction.replace,
                  parts: [
                    ExportPackagePartBuild(
                      path: 'sources/pinned_searches/data.json',
                      write: (path) => File(path).writeAsString(json),
                    ),
                  ],
                ),
              ],
            ),
            '${root.path}/$name',
          );
      final path = await writePackage('incoming', encoded);
      final notifier = container.read(importFlowProvider.notifier);
      await notifier.load(path).timeout(const Duration(minutes: 1));
      final review = container.read(importFlowProvider);
      expect(
        review.status,
        ImportFlowStatus.review,
        reason: '${review.error}',
      );
      expect(review.preflight?.errors, isEmpty);
      expect(review.profileMappings.single.profileId, isNull);
      expect(
        review
            .preflight
            ?.sourceSummaries[source.id]
            ?.entitySummaries['following-topic']
            ?.created,
        1,
      );
      await notifier.apply(context);
      expect(
        container.read(importFlowProvider).status,
        ImportFlowStatus.complete,
      );
      final imported = (await repository.getAll()).single;
      expect(
        imported.localSource?.importedProfileId,
        _data.records.single.profile.id,
      );
      expect(imported.autoUpdateEnabled, isFalse);
      expect(container.read(booruConfigProvider), isEmpty);
      expect(
        (await source.dataGetter()).records.single.profile,
        _data.records.single.profile,
      );
      final reexported = await writePackage(
        'reexported',
        await source.encodeForExport(),
      );
      await notifier.load(reexported);
      final repeat = container.read(importFlowProvider);
      expect(repeat.alreadyPresentSearches, 1);
      expect(repeat.preflight?.sourceSummaries[source.id]?.created, 0);
      await notifier.apply(context);
      expect((await repository.getAll()).single, imported);

      final seeded = FollowingTopic(
        id: imported.id,
        profileId: imported.profileId,
        localSource: imported.localSource,
        name: imported.name,
        query: imported.query,
        position: imported.position,
        createdAt: imported.createdAt,
        autoUpdateEnabled: false,
        previews: const [],
        recentPostIdentities: const [],
        unreadCount: 3,
        highestSeenPostId: 42,
        lastSuccessfulCheckAt: DateTime.utc(2026, 10),
      );
      await repository.restoreForProfile(seeded.profileId, [seeded]);
      const mirrorId = '44444444-4444-4444-8444-444444444444';
      const publisher = '55555555-5555-4555-8555-555555555555';
      final mirror = FollowingTopic.create(
        id: mirrorId,
        profileId: publisher,
        query: 'fox',
        name: 'Received foxes',
        position: 1,
        createdAt: DateTime.utc(2026, 10),
      );
      final owner = FollowingMirrorOwner(
        publisher: publisher,
        source: mirrorId,
        kind: FollowingMirrorKind.topic,
        revision: 1,
        position: 1,
        payloadDigest: 'a' * 64,
        descriptorDigest: 'b' * 64,
        definitionDigest: followingDefinitionDigest(
          kind: FollowingMirrorKind.topic,
          parentSource: null,
          position: 1,
          topic: mirror,
        ),
      );
      final originalMirrors = await repository.readMirrorSnapshot();
      await repository.commitMirrorDefinitions(
        expected: originalMirrors.mirrors,
        expectedStructureDigest: originalMirrors.structureDigest,
        next: FollowingMirrorState(epoch: 1, owners: {mirrorId: owner}),
        topics: [mirror],
        organization: TopicOrganization(
          folders: originalMirrors.organization.folders,
          placements: [
            ...originalMirrors.organization.placements,
            const FolderPlacement(itemId: mirrorId, position: 1),
          ],
        ),
      );
      final mirrorState = (await repository.readMirrorSnapshot()).mirrors;
      final received = await repository.getById(mirrorId);
      final runtime = SearchRuntimeSnapshotService(repository);
      final before = await runtime.capture();
      final nextFile = File('${root.path}/next.json');
      await nextFile.writeAsString(
        source.converter.encode(
          extraFields: const {'source': 'pinned_searches'},
          payload: source.handler.encode(
            FollowingTopicBackupData(
              records: [
                FollowingTopicBackupRecord(
                  id: '66666666-6666-4666-8666-666666666666',
                  name: 'New topic',
                  query: 'owl',
                  position: 0,
                  profile: _data.records.single.profile,
                ),
              ],
            ),
          ),
        ),
      );
      final pendingSource = container.read(
        _transactionSource((fs: fs, path: nextFile.path)),
      );
      await pendingSource.prepare(null);
      final lateFailure = _LateFailure(fs, () async {
        expect(
          (await repository.getAll()).map((t) => t.query),
          unorderedEquals(['fox', 'owl']),
        );
        expect((await repository.readMirrorSnapshot()).mirrors, mirrorState);
      });
      final plan = buildValidatedPlan([source.id, lateFailure.id]);
      await expectLater(
        ImportTransaction(
          store: ImportJournalStore(fs: fs, rootPath: '${root.path}/journal'),
          fs: fs,
        ).execute(
          transactionId: 'late-failure',
          plan: ValidatedImportPlan(
            plan: plan.plan,
            revisionTokens: {
              source.id: await pendingSource.revisionToken(),
              lateFailure.id: await lateFailure.revisionToken(),
            },
            summary: plan.summary,
          ),
          sources: {source.id: pendingSource, lateFailure.id: lateFailure},
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'late source',
            'apply failed: later',
          ),
        ),
      );
      expect(await runtime.capture(), before);
      expect((await repository.readMirrorSnapshot()).mirrors, mirrorState);
      expect(await repository.getById(mirrorId), received);
    },
  );
}

final _transactionSource =
    Provider.family<
      PackageTransactionSource,
      ({AppFileSystem fs, String path})
    >(
      (ref, args) => PackageTransactionSource(
        source: ref.read(followingTopicsBackupSourceProvider),
        incomingPath: args.path,
        fs: args.fs,
        ref: ref,
        credentialsIncluded: false,
      ),
    );

class _SearchRepository extends FollowingTopicRepositoryNotifier {
  _SearchRepository(this.repository);
  final FollowingTopicRepository repository;
  @override
  Future<FollowingTopicRepository> build() async => repository;
}

class _NoProfiles implements BooruConfigRepository {
  @override
  Future<List<BooruConfig>> getAll() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MountedContext implements BuildContext {
  @override
  bool get mounted => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FileSystem extends IoFileSystem {
  _FileSystem(this.root);
  final String root;
  @override
  Future<String?> getTemporaryPath() async => null;
  @override
  Future<String> getAppStoragePath() async => root;
}

class _LateFailure implements ImportTransactionSource {
  _LateFailure(AppFileSystem fs, this.verify)
    : delegate = FakeImportSource('later', fs, failApply: true);
  final FakeImportSource delegate;
  final Future<void> Function() verify;
  @override
  String get id => delegate.id;
  @override
  Future<void> apply(ResolvedImportSource plan) async {
    await verify();
    await delegate.apply(plan);
  }

  @override
  Future<void> captureRollback(String path) => delegate.captureRollback(path);
  @override
  Future<void> durableSync() => delegate.durableSync();
  @override
  Future<String> revisionToken() => delegate.revisionToken();
  @override
  Future<void> restore(String path) => delegate.restore(path);
}
