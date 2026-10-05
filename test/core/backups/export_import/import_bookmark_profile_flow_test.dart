import 'dart:io';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';

import 'package:boorusama/core/backups/export_import/import/bookmark_profile_dependency.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_preflight.dart';
import 'package:boorusama/core/backups/export_import/import/import_journal.dart';
import 'package:boorusama/core/backups/export_import/import/import_transaction.dart';
import 'package:boorusama/core/search/subscriptions/src/data/providers.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import '../../search/subscriptions/subscription_test_utils.dart';
import 'import_transaction_test_utils.dart';
import 'package:boorusama/core/backups/export_import/import/profile_dependency_planner.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/core/backups/export_import/sources/legacy_json_source_adapter.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:flutter/material.dart';

const firstId = '00000000-0000-4000-8000-000000000001';
const secondId = '00000000-0000-4000-8000-000000000002';
const groupId = '00000000-0000-4000-8000-000000000003';
const pinId = '00000000-0000-4000-8000-000000000004';
const feedId = '00000000-0000-4000-8000-000000000005';
const pinProfileId = '00000000-0000-4000-8000-000000000006';
const feedProfileId = '00000000-0000-4000-8000-000000000007';

final _transactionSource =
    Provider.family<PackageTransactionSource, ({String id, String path})>(
      (ref, input) => PackageTransactionSource(
        source: ref.read(backupRegistryProvider).getSource(input.id)!,
        incomingPath: input.path,
        fs: ref.read(appFileSystemProvider),
        ref: ref,
        credentialsIncluded: false,
      ),
    );

void main() {
  for (final scenario in [
    (accounts: 0, rollback: false, source: 'https://site.example'),
    (accounts: 0, rollback: false, source: 'http://site.example:443/install/'),
    (accounts: 0, rollback: false, source: 'http://[::1]:443/install/'),
    (accounts: 0, rollback: false, source: 'https://[::1]/install/'),
    (accounts: 2, rollback: false, source: 'https://site.example'),
    (accounts: 2, rollback: true, source: 'https://site.example'),
  ]) {
    final accounts = scenario.accounts;
    final rollback = scenario.rollback;
    final sourceUrl = scenario.source;
    final nondefaultPort = sourceUrl.contains(':443');
    final ipv6 = sourceUrl.contains('[::1]');
    final canonicalBoundary = nondefaultPort || ipv6;
    final expectedSite = ipv6
        ? (nondefaultPort ? '[::1]:443/install' : '[::1]/install')
        : 'site.example:443/install';
    final crossCategories = accounts == 2 && !rollback;
    testWidgets(
      rollback
          ? 'a late source failure restores profiles, groups, bookmarks, and original hints without incoming mappings'
          : canonicalBoundary
          ? '$sourceUrl snapshot import rejects another website and persists the correct profile hint without preview writes'
          : 'bookmark import with $accounts matching accounts replans without writes and persists final chosen origin',
      (tester) async {
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
          final directory = await Directory.systemTemp.createTemp(
            'bookmark_profile_flow_',
          );
          Hive.init(directory.path);
          if (!Hive.isAdapterRegistered(4)) {
            Hive.registerAdapter(BookmarkHiveObjectAdapter());
          }
          if (!Hive.isAdapterRegistered(5)) {
            Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
          }
          final bookmarkBox = await Hive.openBox<BookmarkHiveObject>(
            'favorites',
          );
          final groupBox = await Hive.openBox<BookmarkGroupHiveObject>(
            'bookmark_groups',
          );
          final profileBox = await Hive.openBox<String>('booru_configs');
          final bookmarks = BookmarkHiveRepository(bookmarkBox);
          final groups = BookmarkGroupRepositoryHive(groupBox);
          final profiles = HiveBooruConfigRepository(box: profileBox);
          final localProfiles = accounts == 0
              ? [
                  _profile(
                    firstId,
                    canonicalBoundary
                        ? (ipv6 && nondefaultPort
                              ? 'https://[::1]/install/'
                              : 'https://site.example/install/')
                        : 'https://other.example',
                  ),
                ]
              : [_profile(firstId), _profile(secondId)];
          await profiles.addAll(localProfiles);
          final beforeProfiles = (await profiles.getAll())
              .map((p) => jsonEncode(p.toJson()))
              .toList();
          // Exercise the existing-record path as well as a newly imported record.
          final existing = (await bookmarks.addBookmarkWithBookmarks([
            rollback
                ? bookmarkWithProfileHint(
                    _bookmark(20, 'https://old.example'),
                    firstId,
                  )
                : _bookmark(1, sourceUrl),
          ])).single;
          await groups.createGroup('Original', id: groupId);
          await groups.replaceMemberships(groupId, {existing.id});
          final searchRepository = memorySubscriptionRepository();
          if (crossCategories) {
            await searchRepository.create(
              profileId: firstId,
              query: 'cat',
              name: 'Local cat',
              id: pinId,
            );
          }
          final beforeSearches = (await searchRepository.getAll()).toList();
          final container = ProviderContainer(
            overrides: [
              booruEngineRegistryProvider.overrideWith(
                (ref) => BooruEngineRegistry(),
              ),
              bookmarkRepoProvider.overrideWith((ref) => bookmarks),
              bookmarkGroupRepoProvider.overrideWith((ref) => groups),
              bookmarkUrlResolverProvider.overrideWith(
                (ref, id) => const DefaultImageUrlResolver(),
              ),
              bookmarkImageCacheManagerProvider.overrideWithValue(null),
              booruConfigRepoProvider.overrideWithValue(profiles),
              booruConfigProvider.overrideWith(
                () => BooruConfigNotifier(initialConfigs: localProfiles),
              ),
              appFileSystemProvider.overrideWithValue(
                _FileSystem(directory.path),
              ),
              appVersionProvider.overrideWithValue(null),
              searchSubscriptionRepositoryProvider.overrideWith(
                () => _SearchRepository(searchRepository),
              ),
              settingsNotifierProvider.overrideWith(
                () => _SettingsNotifier(Settings.defaultSettings),
              ),
              backupRegistryProvider.overrideWith(
                (ref) => BackupRegistry()
                  ..register(ref.read(bookmarksBackupSourceProvider))
                  ..register(ref.read(booruConfigsBackupSourceProvider))
                  ..register(ref.read(pinnedSearchesBackupSourceProvider))
                  ..register(ref.read(followingFeedsBackupSourceProvider)),
              ),
              exportImportSourcesProvider.overrideWith(
                (ref) => [
                  LegacyJsonSourceAdapter(
                    source: ref.read(bookmarksBackupSourceProvider),
                    descriptor: const ExportSelectionDescriptor.collection(
                      id: 'bookmarks',
                      children: [
                        ExportSelectionNode(id: 'group:$groupId'),
                      ],
                    ),
                  ),
                  if (crossCategories) ...[
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
                ],
              ),
            ],
          );
          final listener = container.listen(importFlowProvider, (_, _) {});
          addTearDown(() async {
            listener.close();
            container.dispose();
            await bookmarkBox.close();
            await groupBox.close();
            await profileBox.close();
            await directory.delete(recursive: true);
          });
          final source = container.read(bookmarksBackupSourceProvider);
          final json = source.converter.encode(
            payload: BookmarkBackupCodec().encode(
              BookmarkBackupData(
                bookmarks: [_bookmark(1, sourceUrl), _bookmark(2, sourceUrl)],
                groups: const [],
              ),
            ),
            extraFields: {
              'groups': [
                {
                  'id': groupId,
                  'name': 'Imported',
                  'bookmarkIds': [1, 2],
                },
              ],
            },
          );
          final path = await const ExportPackageWriter(fs: IoFileSystem())
              .write(
                ExportPackageBuild(
                  createdAt: DateTime.utc(2026),
                  appVersion: '1.0.0',
                  sources: [
                    ExportPackageSourceBuild(
                      id: 'bookmarks',
                      schemaVersion: 4,
                      selection: const ExportNodeSelection.explicit(
                        'bookmarks',
                        {
                          'group:$groupId',
                        },
                      ),
                      recommendedAction: ImportAction.configureItems,
                      parts: [
                        ExportPackagePartBuild(
                          path: 'sources/bookmarks/data.json',
                          write: (path) => File(path).writeAsString(json),
                        ),
                      ],
                    ),
                    if (crossCategories) ...[
                      _searchSource('pinned_searches', [
                        {
                          'kind': 'search',
                          'id': pinId,
                          'name': null,
                          'query': 'cat',
                          'position': 0,
                          'profile': _reference(pinProfileId).toJson(),
                        },
                        {'kind': 'organization', 'homeSearchIds': []},
                      ]),
                      _searchSource('following_feeds', [
                        {
                          'kind': 'feed',
                          'id': feedId,
                          'name': 'Feed',
                          'queries': ['dog'],
                          'position': 0,
                          'profile': _reference(feedProfileId).toJson(),
                        },
                      ]),
                    ],
                  ],
                ),
                '${directory.path}/package',
              );
          final notifier = container.read(importFlowProvider.notifier);
          await notifier.load(path);
          final state = container.read(importFlowProvider);
          expect(
            state.status,
            ImportFlowStatus.review,
            reason: state.error is InvalidBackupFormatException
                ? (state.error! as InvalidBackupFormatException).details
                : '${state.error}',
          );
          expect(
            state.preflight!.errors.map((issue) => issue.code),
            contains('unresolved_profile_dependency'),
          );
          if (canonicalBoundary) {
            expect(
              state.profileMappings.single.siteKey.site,
              expectedSite,
            );
            expect(state.profileMappings.single.candidateIds, isEmpty);
            expect(state.profileMappings.single.profileId, isNull);
          }
          final original = state.resolved!.sources.singleWhere(
            (source) => source.id == 'bookmarks',
          );
          notifier.replaceSource(original.copyWith(action: ImportAction.skip));
          expect(
            container.read(importFlowProvider).profileMappings,
            crossCategories ? hasLength(1) : isEmpty,
          );
          if (crossCategories) {
            expect(
              container
                  .read(importFlowProvider)
                  .profileMappings
                  .single
                  .references,
              hasLength(2),
            );
          }
          notifier.replaceSource(original);
          await notifier.apply(context);
          expect(bookmarkBox.length, 1);
          expect((await groups.getGroup(groupId))!.name, 'Original');
          final bookmarkKey = ProfileReferenceKey.fromReference(
            bookmarkProfileReference(_bookmark(1, sourceUrl)),
          );
          final key = ProfileSiteKey.fromReference(
            bookmarkProfileReference(_bookmark(1, sourceUrl)),
          );
          if (accounts == 0) {
            expect(
              (await profiles.getAll()).map((p) => jsonEncode(p.toJson())),
              beforeProfiles,
            );
            final regular = BooruConfig.fromJson({
              ...BooruConfig.defaultConfig(
                booruType: BooruType.gelbooruV2,
                url: sourceUrl,
                customDownloadFileNameFormat: null,
              ).toJson(),
              'id': secondId,
              'name': 'Regular profile',
            });
            await profiles.addAll([regular]);
            await container.read(booruConfigProvider.notifier).fetch();
            await notifier.load(path);
            expect(
              container
                  .read(importFlowProvider)
                  .profileMappings
                  .single
                  .candidateIds,
              {secondId},
            );
          } else {
            notifier.chooseProfileMapping(key, firstId);
            final previous = container.read(importFlowProvider).preflight;
            notifier.chooseProfileMapping(key, secondId);
            expect(
              identical(previous, container.read(importFlowProvider).preflight),
              isFalse,
            );
          }
          if (crossCategories) notifier.acknowledgeWarnings(true);
          final finalId = container
              .read(importFlowProvider)
              .profileMappings
              .single
              .profileId!;
          expect(
            container.read(importFlowProvider).preflight!.isValid,
            isTrue,
            reason: '${container.read(importFlowProvider).preflight!.errors}',
          );
          expect(bookmarkBox.length, 1);
          if (accounts != 0) {
            expect(
              (await profiles.getAll()).map((p) => jsonEncode(p.toJson())),
              beforeProfiles,
            );
          }
          expect(
            (await bookmarks.getAllBookmarksOrThrow(
              imageUrlResolver: (_) => const DefaultImageUrlResolver(),
            )).single.snapshot,
            existing.snapshot,
          );
          expect(await searchRepository.getAll(), beforeSearches);
          expect(await searchRepository.getFeeds(), isEmpty);
          if (crossCategories) {
            final shared = container
                .read(importFlowProvider)
                .profileMappings
                .single;
            expect(shared.references.map((r) => r.id).toSet(), {
              bookmarkKey.exportedId,
              pinProfileId,
              feedProfileId,
            });
          }
          if (rollback) {
            final incomingPath = '${directory.path}/incoming-bookmarks.json';
            await File(incomingPath).writeAsString(json);
            final bookmarkSource = container.read(
              _transactionSource((id: 'bookmarks', path: incomingPath)),
            );
            await bookmarkSource.prepare(null);
            bookmarkSource.profileMappings = {bookmarkKey: finalId};
            final profileSource = container.read(
              booruConfigsBackupSourceProvider,
            );
            final profilePath = '${directory.path}/incoming-profiles.json';
            await File(profilePath).writeAsString(
              profileSource.converter.encode(
                payload: [_profile(secondId).toJson()],
              ),
            );
            final profilesTransaction = container.read(
              _transactionSource((id: 'profiles', path: profilePath)),
            );
            await profilesTransaction.prepare(null);
            final lateFailure = FakeImportSource(
              'late_failure',
              const IoFileSystem(),
              failApply: true,
            );
            final store = ImportJournalStore(
              fs: const IoFileSystem(),
              rootPath: '${directory.path}/transactions',
            );
            final transaction = ImportTransaction(
              store: store,
              fs: const IoFileSystem(),
            );
            final plan = ValidatedImportPlan(
              plan: ResolvedImportPlan(
                sources: [
                  ResolvedImportSource(
                    id: 'profiles',
                    action: ImportAction.replace,
                    items: const [],
                  ),
                  ResolvedImportSource(
                    id: 'bookmarks',
                    action: ImportAction.replace,
                    items: const [],
                  ),
                  ResolvedImportSource(
                    id: 'late_failure',
                    action: ImportAction.replace,
                    items: const [],
                  ),
                ],
              ),
              revisionTokens: {
                'profiles': await profilesTransaction.revisionToken(),
                'bookmarks': await bookmarkSource.revisionToken(),
                'late_failure': await lateFailure.revisionToken(),
              },
              summary: const PlannedChangeSummary(),
            );
            await expectLater(
              transaction.execute(
                transactionId: 'rollback',
                plan: plan,
                sources: {
                  'profiles': profilesTransaction,
                  'bookmarks': bookmarkSource,
                  'late_failure': lateFailure,
                },
              ),
              throwsStateError,
            );
            final restored = await bookmarks.getAllBookmarksOrThrow(
              imageUrlResolver: (_) => const DefaultImageUrlResolver(),
            );
            expect(restored.single.snapshot, existing.snapshot);
            expect(restored.single.identity, existing.identity);
            expect((await groups.getGroup(groupId))!.name, 'Original');
            expect((await groups.getGroup(groupId))!.bookmarkIds, {
              restored.single.id,
            });
            expect(
              (await profiles.getAll()).map((p) => jsonEncode(p.toJson())),
              beforeProfiles,
            );
            expect(
              Directory(store.transactionPath('rollback')).existsSync(),
              isFalse,
            );
            // Recovery has no incoming mapping state after a cold restart.
            final rollbackPath = '${directory.path}/cold-bookmarks.json';
            await bookmarkSource.captureRollback(rollbackPath);
            await bookmarks.removeBookmarks(restored);
            bookmarkSource.profileMappings = const {};
            await bookmarkSource.restore(rollbackPath);
            expect(
              (await bookmarks.getAllBookmarksOrThrow(
                imageUrlResolver: (_) => const DefaultImageUrlResolver(),
              )).single.snapshot,
              existing.snapshot,
            );
            return;
          }
          await notifier.apply(context);
          expect(
            container.read(importFlowProvider).status,
            ImportFlowStatus.complete,
            reason: '${container.read(importFlowProvider).error}',
          );
          final saved = await bookmarks.getAllBookmarksOrThrow(
            imageUrlResolver: (_) => const DefaultImageUrlResolver(),
          );
          expect(saved, hasLength(2));
          expect(
            saved.every((b) => b.snapshot.origin.profileIdHint == finalId),
            isTrue,
          );
          if (canonicalBoundary) {
            expect(saved.map((b) => b.snapshot.origin.sourceHost).toSet(), {
              expectedSite,
            });
            expect(saved.map((b) => b.snapshot.origin.profileIdHint).toSet(), {
              secondId,
            });
          }
          expect(saved.singleWhere((b) => b.postId == 1).id, existing.id);
          expect(
            saved.singleWhere((b) => b.postId == 1).identity,
            existing.identity,
          );
          expect(
            (await groups.getGroup(groupId))!.bookmarkIds,
            saved.map((b) => b.id).toSet(),
          );
          expect((await profiles.getAll()).any((p) => p.id == finalId), isTrue);
          if (crossCategories) {
            final pins = await searchRepository.getAll();
            expect(
              pins.where((p) => p.query == 'cat').map((p) => p.profileId),
              containsAll([firstId, secondId]),
            );
            final feed = (await searchRepository.getFeeds()).single;
            expect(feed.profileId, secondId);
            for (final id in feed.sourceIds) {
              expect((await searchRepository.getById(id))!.profileId, secondId);
            }
          }
        });
      },
    );
  }
}

Bookmark _bookmark(int id, [String url = 'https://site.example']) => Bookmark(
  id: id,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  thumbnailUrl: 'https://media.example/$id.jpg',
  sampleUrl: 'https://media.example/$id.jpg',
  originalUrl: 'https://media.example/$id.jpg',
  sourceUrl: url,
  booruId: BooruType.gelbooruV2.id,
  width: 100,
  height: 100,
  md5: '',
  tags: const {},
  realSourceUrl: null,
  format: 'jpg',
  imageUrlResolver: const DefaultImageUrlResolver(),
  postId: id,
  metadata: const {},
);
BooruConfig _profile(String id, [String url = 'https://site.example']) =>
    BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': id,
      'url': url,
      'name': 'Account',
      'booruId': BooruType.gelbooruV2.id,
      'booruIdHint': BooruType.gelbooruV2.id,
    });

class _FileSystem extends IoFileSystem {
  const _FileSystem(this.root);
  final String root;
  @override
  Future<String> getAppStoragePath() async => root;
  @override
  Future<String?> getTemporaryPath() async => null;
}

class _SettingsNotifier extends SettingsNotifier {
  _SettingsNotifier(super.initialSettings);
}

class _SearchRepository extends SearchSubscriptionRepositoryNotifier {
  _SearchRepository(this.repository);
  final SearchSubscriptionRepository repository;
  @override
  Future<SearchSubscriptionRepository> build() async => repository;
}

BackupProfileReference _reference(String id) => BackupProfileReference(
  id: id,
  booruType: 'gelbooruV2',
  url: 'https://site.example/',
  name: 'Remote',
);
ExportPackageSourceBuild _searchSource(
  String id,
  List<Map<String, Object?>> rows,
) => ExportPackageSourceBuild(
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
