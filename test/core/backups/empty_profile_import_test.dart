import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/import/import_journal.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_preflight.dart';
import 'package:boorusama/core/backups/export_import/import/import_transaction.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/core/backups/export_import/sources/legacy_json_source_adapter.dart';
import 'package:boorusama/core/backups/sources/booru_configs_source.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/core/search/following_topics/src/data/providers.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../search/following_topics/topic_test_utils.dart';
import 'export_import/import_transaction_test_utils.dart';

const _incomingId = '00000000-0000-4000-8000-000000000001';
const _existingId = '00000000-0000-4000-8000-000000000002';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a profile package reaches review without any local profile', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('disk_space_2'),
      (_) async => 100000.0,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel('disk_space_2'),
        null,
      ),
    );
    final path = await ExportPackageWriter(fs: harness.fs).write(
      ExportPackageBuild(
        createdAt: DateTime.utc(2026, 10, 29),
        appVersion: '1.0.0',
        sources: [
          ExportPackageSourceBuild(
            id: 'profiles',
            schemaVersion: 1,
            selection: const ExportNodeSelection.all('profiles'),
            parts: [
              ExportPackagePartBuild(
                path: 'sources/profiles/data.json',
                write: (path) => File(path).writeAsString(
                  _encodedProfiles([_profile(_incomingId)]),
                ),
              ),
            ],
          ),
        ],
      ),
      '${harness.directory.path}/profiles',
    );
    final subscription = harness.container.listen(
      importFlowProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    await harness.container.read(importFlowProvider.notifier).load(path);

    final state = harness.container.read(importFlowProvider);
    expect(state.status, ImportFlowStatus.review, reason: '${state.error}');
    expect(state.error, isNull);
    expect(state.resolved!.sources.single.id, 'profiles');
    expect(await harness.profiles.getAll(), isEmpty);
    expect(harness.container.read(booruConfigProvider), isEmpty);
  });

  test(
    'an implicit profile dependency can snapshot an empty installation',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final transaction = harness.transaction(null);

      await transaction.captureLocalSnapshot();
      await transaction.measureRollback();
      await transaction.captureRollback(
        '${harness.directory.path}/rollback.json',
      );

      expect(transaction.preflightRollbackBytes, greaterThan(0));
      expect(await harness.profiles.getAll(), isEmpty);
    },
  );

  for (final initiallyEmpty in [true, false]) {
    test(
      'rollback restores ${initiallyEmpty ? 'empty' : 'existing'} profiles and provider state',
      () async {
        final initial = initiallyEmpty
            ? <BooruConfig>[]
            : [_profile(_existingId)];
        final harness = _Harness(initial);
        addTearDown(harness.dispose);
        final incoming = File('${harness.directory.path}/incoming.json');
        await incoming.writeAsString(_encodedProfiles([_profile(_incomingId)]));
        final transaction = harness.transaction(incoming.path);
        final rollback = '${harness.directory.path}/rollback.json';

        await transaction.prepare(null);
        await transaction.captureLocalSnapshot();
        await transaction.measureRollback();
        await transaction.captureRollback(rollback);
        await transaction.apply(
          ResolvedImportSource(
            id: 'profiles',
            action: ImportAction.replace,
            items: const [],
          ),
        );
        expect((await harness.profiles.getAll()).single.id, _incomingId);
        expect(
          harness.container.read(booruConfigProvider).single.id,
          _incomingId,
        );

        await transaction.restore(rollback);

        expect(await harness.profiles.getAll(), initial);
        expect(harness.container.read(booruConfigProvider), initial);
      },
    );
  }

  for (final initiallyEmpty in [true, false]) {
    for (final failAfterProfiles in [true, false]) {
      test(
        '${initiallyEmpty ? 'empty' : 'existing'} profiles survive a mixed-source ${failAfterProfiles ? 'rollback' : 'commit'}',
        () async {
          final initial = initiallyEmpty
              ? <BooruConfig>[]
              : [_profile(_existingId)];
          final harness = _Harness(initial);
          addTearDown(harness.dispose);
          final incoming = File('${harness.directory.path}/incoming.json');
          final imported = _profile(_incomingId);
          await incoming.writeAsString(_encodedProfiles([imported]));
          final profiles = harness.transaction(incoming.path);
          await profiles.prepare(null);
          final other = FakeImportSource(
            'second',
            harness.fs,
            failApply: failAfterProfiles,
          );
          final plan = ValidatedImportPlan(
            plan: buildValidatedPlan(['profiles', 'second']).plan,
            revisionTokens: {
              'profiles': await profiles.revisionToken(),
              'second': await other.revisionToken(),
            },
            summary: const PlannedChangeSummary(),
          );
          final store = ImportJournalStore(
            fs: harness.fs,
            rootPath: '${harness.directory.path}/transactions',
          );

          final execution = ImportTransaction(store: store, fs: harness.fs)
              .execute(
                transactionId: 'mixed',
                plan: plan,
                sources: {'profiles': profiles, 'second': other},
              );
          await expectLater(
            execution,
            failAfterProfiles ? throwsStateError : completes,
          );

          final expected = failAfterProfiles ? initial : [imported];
          expect(await harness.profiles.getAll(), expected);
          expect(harness.container.read(booruConfigProvider), expected);
          expect(
            other.value,
            failAfterProfiles ? 'old:second' : 'imported:second',
          );
          expect(
            await harness.fs.directoryExists(store.transactionPath('mixed')),
            isFalse,
          );
        },
      );
    }
  }

  for (final clipboard in [false, true]) {
    for (final valid in [false, true]) {
      test(
        '${clipboard ? 'clipboard' : 'file'} import ${valid ? 'accepts valid' : 'rejects empty'} profiles on a fresh installation',
        () async {
          final harness = _Harness();
          addTearDown(harness.dispose);
          final encoded = _encodedProfiles(
            valid ? [_profile(_incomingId)] : [],
          );
          final source = harness.source;
          final Future<Object?> preparation;
          if (clipboard) {
            final messenger = TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger;
            messenger.setMockMethodCallHandler(SystemChannels.platform, (
              call,
            ) async {
              if (call.method == 'Clipboard.getData') return {'text': encoded};
              return null;
            });
            addTearDown(
              () => messenger.setMockMethodCallHandler(
                SystemChannels.platform,
                null,
              ),
            );
            preparation = source.capabilities.clipboard!.prepareImport(null);
          } else {
            final file = File('${harness.directory.path}/incoming.json');
            await file.writeAsString(encoded);
            preparation = source.capabilities.file!.prepareImport(
              file.path,
              null,
            );
          }

          await expectLater(preparation, valid ? completes : throwsException);
          expect(await harness.profiles.getAll(), isEmpty);
        },
      );
    }
  }

  test(
    'rollback preparation still rejects malformed nonempty profiles',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final malformed = jsonEncode({
        'version': 1,
        'data': [
          {..._profile(_incomingId).toJson(), 'name': ''},
        ],
      });

      await expectLater(
        harness.source.prepareRollback(malformed),
        throwsException,
      );
      expect(await harness.profiles.getAll(), isEmpty);
    },
  );
}

String _encodedProfiles(List<BooruConfig> profiles) => jsonEncode({
  'version': 1,
  'exportVersion': '1.0.0',
  'data': [for (final profile in profiles) profile.toJson()],
});

BooruConfig _profile(String id) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'booruId': BooruType.danbooru.id,
  'booruIdHint': BooruType.danbooru.id,
  'url': 'https://danbooru.example',
  'name': 'Profile $id',
});

class _Harness {
  _Harness([List<BooruConfig> initial = const []]) {
    directory = Directory.systemTemp.createTempSync('empty_profile_import_');
    fs = _TestFileSystem(directory.path);
    profiles = _Profiles(initial);
    final searches = memorySubscriptionRepository();
    container = ProviderContainer(
      overrides: [
        loggerProvider.overrideWithValue(AppLogger()),
        appFileSystemProvider.overrideWithValue(fs),
        appVersionProvider.overrideWith((ref) => null),
        booruConfigRepoProvider.overrideWithValue(profiles),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: List.of(initial)),
        ),
        followingTopicRepositoryProvider.overrideWith(
          () => _SearchRepository(searches),
        ),
        backupRegistryProvider.overrideWith(
          (ref) =>
              BackupRegistry()
                ..register(ref.read(booruConfigsBackupSourceProvider)),
        ),
        exportImportSourcesProvider.overrideWith(
          (ref) => [
            LegacyJsonSourceAdapter(
              source: ref.read(booruConfigsBackupSourceProvider),
              descriptor: const ExportSelectionDescriptor.collection(
                id: 'profiles',
              ),
            ),
          ],
        ),
      ],
    );
  }

  late final Directory directory;
  late final _TestFileSystem fs;
  late final _Profiles profiles;
  late final ProviderContainer container;

  BooruConfigsBackupSource get source =>
      container.read(booruConfigsBackupSourceProvider);

  PackageTransactionSource transaction(String? incomingPath) => container.read(
    Provider(
      (ref) => PackageTransactionSource(
        source: ref.read(booruConfigsBackupSourceProvider),
        incomingPath: incomingPath,
        fs: fs,
        ref: ref,
        credentialsIncluded: false,
      ),
    ),
  );

  void dispose() {
    container.dispose();
    directory.deleteSync(recursive: true);
  }
}

class _Profiles implements BooruConfigRepository {
  _Profiles(List<BooruConfig> initial) : _profiles = List.of(initial);
  final List<BooruConfig> _profiles;

  @override
  Future<List<BooruConfig>> getAll() async => List.of(_profiles);

  @override
  Future<void> clear() async => _profiles.clear();

  @override
  Future<List<BooruConfig>> addAll(List<BooruConfig> profiles) async {
    _profiles.addAll(profiles);
    return List.of(profiles);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestFileSystem extends IoFileSystem {
  _TestFileSystem(this.root);
  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String> getAppStoragePath() async => root;
}

class _SearchRepository extends FollowingTopicRepositoryNotifier {
  _SearchRepository(this.repository);
  final FollowingTopicRepository repository;

  @override
  Future<FollowingTopicRepository> build() async => repository;
}
