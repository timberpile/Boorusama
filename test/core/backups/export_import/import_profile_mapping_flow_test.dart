import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/search/subscriptions/src/data/providers.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/import/profile_dependency_planner.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/core/backups/export_import/sources/legacy_json_source_adapter.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../search/subscriptions/subscription_test_utils.dart';

const firstId = '00000000-0000-4000-8000-000000000001';
const secondId = '00000000-0000-4000-8000-000000000002';
const remoteId = '00000000-0000-4000-8000-000000000003';
const pinId = '00000000-0000-4000-8000-000000000004';
const feedId = '00000000-0000-4000-8000-000000000005';
const reference = BackupProfileReference(
  id: remoteId,
  booruType: 'danbooru',
  url: 'https://same.example',
  name: 'Remote',
);

void main() {
  for (final stale in [false, true]) {
    testWidgets(
      stale
          ? 'stale local searches refresh the staged plan and require explicit confirmation'
          : 'changing a reviewed mapping replans pins and applies final pin and feed ownership without preview writes',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync('data007_flow_');
        final fs = _TestFileSystem(directory.path);
        final repository = memorySubscriptionRepository();
        final profiles = [_profile(firstId), _profile(secondId)];
        final container = ProviderContainer(
          overrides: [
            appFileSystemProvider.overrideWithValue(fs),
            appVersionProvider.overrideWith((ref) => null),
            booruConfigProvider.overrideWith(
              () => BooruConfigNotifier(initialConfigs: profiles),
            ),
            booruConfigRepoProvider.overrideWithValue(_Profiles(profiles)),
            searchSubscriptionRepositoryProvider.overrideWith(
              () => _SearchRepository(repository),
            ),
            backupRegistryProvider.overrideWith(
              (ref) => BackupRegistry()
                ..register(ref.read(booruConfigsBackupSourceProvider))
                ..register(ref.read(pinnedSearchesBackupSourceProvider))
                ..register(ref.read(followingFeedsBackupSourceProvider)),
            ),
            exportImportSourcesProvider.overrideWith(
              (ref) => [
                LegacyJsonSourceAdapter(
                  source: ref.read(pinnedSearchesBackupSourceProvider),
                  descriptor: const ExportSelectionDescriptor.collection(
                    id: 'pinned_searches',
                  ),
                ),
                LegacyJsonSourceAdapter(
                  source: ref.read(followingFeedsBackupSourceProvider),
                  descriptor: const ExportSelectionDescriptor.collection(
                    id: 'following_feeds',
                  ),
                ),
              ],
            ),
          ],
        );
        final subscription = container.listen(importFlowProvider, (_, _) {});
        addTearDown(() {
          subscription.close();
          container.dispose();
          directory.deleteSync(recursive: true);
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('disk_space_2'),
              (_) async => 100000.0,
            );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('disk_space_2'),
                null,
              ),
        );
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.runAsync(() async {
          await repository.create(
            profileId: firstId,
            query: 'cat',
            name: null,
            id: pinId,
          );
          final before = (await repository.getAll()).toList();
          final path = await const ExportPackageWriter(fs: IoFileSystem())
              .write(
                ExportPackageBuild(
                  createdAt: DateTime.utc(2026, 10),
                  appVersion: '1.0.0',
                  sources: [
                    _source('pinned_searches', [
                      {
                        'kind': 'search',
                        'id': pinId,
                        'name': null,
                        'query': 'cat',
                        'position': 0,
                        'profile': reference.toJson(),
                      },
                      {'kind': 'organization', 'homeSearchIds': []},
                    ]),
                    _source('following_feeds', [
                      {
                        'kind': 'feed',
                        'id': feedId,
                        'name': 'Feed',
                        'queries': ['dog'],
                        'position': 0,
                        'profile': reference.toJson(),
                      },
                    ]),
                  ],
                ),
                '${directory.path}/mapping',
              );
          final notifier = container.read(importFlowProvider.notifier);
          await notifier.load(path);
          expect(
            container.read(importFlowProvider).status,
            ImportFlowStatus.review,
            reason: '${container.read(importFlowProvider).error}',
          );
          final key = ProfileSiteKey.fromReference(reference);
          notifier.chooseProfileMapping(key, firstId);
          notifier.acknowledgeWarnings(true);
          final first = container.read(importFlowProvider).preflight!;
          expect(first.isValid, isTrue, reason: '${first.errors}');
          notifier.chooseProfileMapping(key, secondId);
          final changed = container.read(importFlowProvider);
          expect(changed.profileMappings.single.profileId, secondId);
          expect(identical(changed.preflight, first), isFalse);
          expect(
            identical(changed.preflight!.validatedPlan, first.validatedPlan),
            isFalse,
          );
          expect(
            changed.preflight!.sourceSummaries['pinned_searches']!.created,
            greaterThan(first.sourceSummaries['pinned_searches']!.created),
          );
          expect(await repository.getAll(), before);
          expect(await repository.getFeeds(), isEmpty);
          if (stale) {
            File(path).deleteSync();
            await repository.create(
              profileId: secondId,
              query: 'cat',
              name: null,
              id: '00000000-0000-4000-8000-000000000099',
            );
            final externalState = (await repository.getAll()).toList();
            await notifier.apply(context);
            final refreshed = container.read(importFlowProvider);
            expect(
              refreshed.status,
              ImportFlowStatus.review,
              reason: '${refreshed.error}',
            );
            expect(refreshed.planRefreshed, isTrue);
            expect(refreshed.profileMappings.single.profileId, secondId);
            expect(await repository.getFeeds(), isEmpty);
            expect(await repository.getAll(), externalState);
            expect(
              refreshed.preflight!.sourceSummaries['pinned_searches']!.created,
              lessThan(
                changed.preflight!.sourceSummaries['pinned_searches']!.created,
              ),
            );
            expect(
              refreshed
                  .preflight!
                  .sourceSummaries['pinned_searches']!
                  .previewRows,
              isEmpty,
            );
            expect(refreshed.preflight!.requiresWarningAcknowledgement, isTrue);
            notifier.acknowledgeWarnings(true);
            expect(
              container
                  .read(importFlowProvider)
                  .preflight!
                  .validatedPlan!
                  .revisionTokens,
              isNot(changed.preflight!.validatedPlan!.revisionTokens),
            );
          }
          await notifier.apply(context);
          expect(
            container.read(importFlowProvider).status,
            ImportFlowStatus.complete,
            reason: '${container.read(importFlowProvider).error}',
          );
          final pins = await repository.getAll();
          expect(
            pins
                .where((search) => search.query == 'cat')
                .map((search) => search.profileId),
            containsAll([firstId, secondId]),
          );
          final feed = (await repository.getFeeds()).single;
          expect(feed.profileId, secondId);
          for (final id in feed.sourceIds) {
            expect((await repository.getById(id))!.profileId, secondId);
          }
          expect(profiles.map((profile) => profile.id), [firstId, secondId]);
        });
      },
    );
  }
}

ExportPackageSourceBuild _source(String id, List<Map<String, Object?>> rows) =>
    ExportPackageSourceBuild(
      id: id,
      schemaVersion: 1,
      selection: ExportNodeSelection.explicit(id, {
        id == 'pinned_searches' ? 'search:$pinId' : 'feed:$feedId',
      }),
      recommendedAction: ImportAction.configureItems,
      parts: [
        ExportPackagePartBuild(
          path: 'sources/$id/data.json',
          write: (path) => File(path).writeAsString(
            jsonEncode({
              'version': 1,
              'source': id,
              'date': '2026-10-05T00:00:00.000Z',
              'exportVersion': '1.0.0',
              'data': rows,
            }),
          ),
        ),
      ],
    );
BooruConfig _profile(String id) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'booruId': BooruType.danbooru.id,
  'booruIdHint': BooruType.danbooru.id,
  'url': reference.url,
  'name': id == firstId ? 'First' : 'Second',
});

class _Profiles implements BooruConfigRepository {
  _Profiles(this.profiles);
  final List<BooruConfig> profiles;
  @override
  Future<List<BooruConfig>> getAll() async => profiles;
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

class _SearchRepository extends SearchSubscriptionRepositoryNotifier {
  _SearchRepository(this.repository);
  final SearchSubscriptionRepository repository;
  @override
  Future<SearchSubscriptionRepository> build() async => repository;
}
