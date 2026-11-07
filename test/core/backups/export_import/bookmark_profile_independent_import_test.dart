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
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/stored_bookmark_codec.dart';
import 'package:boorusama/core/content/content_map.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../support/fakes/bookmark_test_storage.dart';
import '../../../support/fakes/test_post.dart';
import '../../bookmarks/pool_bookmark_test_utils.dart';
import 'import_transaction_test_utils.dart';

const root = '11111111-1111-4111-8111-111111111111';
const leaf = '22222222-2222-4222-8222-222222222222';

final _transactionSource = Provider.family<PackageTransactionSource, String>(
  (ref, path) => PackageTransactionSource(
    source: ref.read(bookmarksBackupSourceProvider),
    incomingPath: path,
    fs: ref.read(appFileSystemProvider),
    ref: ref,
    credentialsIncluded: false,
  ),
);

void main() {
  for (final mode in [
    ImportAction.merge,
    ImportAction.update,
    ImportAction.mergeIntoTarget,
    ImportAction.replace,
  ]) {
    testWidgets(
      'nested v10 mixed bookmarks import twice without profiles ($mode)',
      (
        tester,
      ) async {
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
        var httpAttempts = 0;
        await HttpOverrides.runZoned(
          () => tester.runAsync(() async {
            final directory = await Directory.systemTemp.createTemp(
              'profileless-import-',
            );
            Hive.init(directory.path);
            if (!Hive.isAdapterRegistered(4)) {
              Hive.registerAdapter(BookmarkHiveObjectAdapter());
            }
            if (!Hive.isAdapterRegistered(5)) {
              Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
            }
            final posts = await Hive.openBox<BookmarkHiveObject>('favorites');
            final legacyGroups = await Hive.openBox<BookmarkGroupHiveObject>(
              'bookmark_groups',
            );
            final legacyOrganization = await Hive.openBox<dynamic>(
              'organization',
            );
            final profileBox = await Hive.openBox<String>('booru_configs');
            final storage = await BookmarkTestStorage.open(posts);
            final bookmarks = storage.repository(posts);
            final reader = await BookmarkStorageMigration(
              bookmarks: bookmarks,
              legacyGroups: legacyGroups,
              legacyOrganization: legacyOrganization,
              metadata: storage.metadataBox,
            ).open();
            final groups = UnifiedBookmarkGroupRepository(
              bookmarks: bookmarks,
              reader: reader,
            );
            final profiles = HiveBooruConfigRepository(box: profileBox);
            final container = ProviderContainer(
              overrides: [
                ...storage.overrides,
                loggerProvider.overrideWithValue(AppLogger()),
                booruEngineRegistryProvider.overrideWith(
                  (ref) => BooruEngineRegistry(),
                ),
                bookmarkRepoProvider.overrideWith((ref) => bookmarks),
                bookmarkGroupRepoProvider.overrideWith((ref) => groups),
                bookmarkUrlResolverProvider.overrideWith(
                  (ref, id) => const DefaultImageUrlResolver(),
                ),
                booruConfigRepoProvider.overrideWithValue(profiles),
                booruConfigProvider.overrideWith(
                  () => BooruConfigNotifier(initialConfigs: []),
                ),
                appFileSystemProvider.overrideWithValue(
                  _FileSystem(directory.path),
                ),
                appVersionProvider.overrideWithValue(null),
                settingsNotifierProvider.overrideWith(
                  () => _SettingsNotifier(Settings.defaultSettings),
                ),
                backupRegistryProvider.overrideWith(
                  (ref) => BackupRegistry()
                    ..register(ref.read(bookmarksBackupSourceProvider))
                    ..register(ref.read(booruConfigsBackupSourceProvider)),
                ),
                exportImportSourcesProvider.overrideWith(
                  (ref) => [
                    LegacyJsonSourceAdapter(
                      source: ref.read(bookmarksBackupSourceProvider),
                      descriptor: const ExportSelectionDescriptor.collection(
                        id: 'bookmarks',
                        children: [
                          ExportSelectionNode(id: 'group:$root'),
                          ExportSelectionNode(id: 'group:$leaf'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
            final listener = container.listen(importFlowProvider, (_, _) {});
            addTearDown(() async {
              listener.close();
              container.dispose();
              await storage.close();
              await posts.close();
              await legacyGroups.close();
              await legacyOrganization.close();
              await profileBox.close();
              await Hive.close();
              await directory.delete(recursive: true);
            });
            ContentReference reference(String key) =>
                const ContentReferenceCodec().parse(
                  engine: BooruType.danbooru,
                  site: Uri.parse('https://source.example.test/install'),
                  kind: ContentKind.group,
                  sourceKey: key,
                );
            final summary = ContentGroupSummary(
              reference: reference('pool:42'),
              title: 'Saved pool',
            );
            final pool = ContentGroupBookmark(
              id: 2,
              snapshot: StoredGroupSnapshot(
                summary: summary,
                details: ContentGroupDetails(
                  summary: summary,
                  description: const GroupDescription(
                    text: 'Saved details',
                    format: GroupTextFormat.plainText,
                  ),
                ),
              ),
              createdAt: DateTime.utc(2019),
              observedAt: DateTime.utc(2024),
            );
            final related = RelatedBookmark(
              id: 3,
              snapshot: StoredGroupSnapshot(
                summary: ContentGroupSummary(
                  reference: reference('related:900'),
                  title: 'Related',
                ),
              ),
              createdAt: DateTime.utc(2018),
              observedAt: DateTime.utc(2025),
              // The fixture exercises the explicitly absent Related preference.
              // ignore: avoid_redundant_argument_values
              preferredOrder: null,
            );
            final postData = TestPost(
              id: 7,
              origin: poolOrigin(host: 'source.example.test'),
              booruData: const LegacyPostData(
                typeKey: 'legacy_danbooru',
                custom: {},
              ),
            );
            final post = PostBookmark.fromSnapshot(
              id: 1,
              createdAt: DateTime.utc(2020),
              updatedAt: DateTime.utc(2022),
              postId: 7,
              snapshot: const StoredPostCodec().encode(postData),
              post: postData,
            );
            final nullIdPost = testPoolPost(8)
                .copyWith(id: 4, postId: () => null);
            final dates = {
              1: DateTime.utc(2020, 1, 2),
              2: DateTime.utc(2021, 2, 3),
              3: DateTime.utc(2022, 3, 4),
              4: DateTime.utc(2023, 4, 5),
            };
            final data = BookmarkBackupData.unified(
              records: [post, pool, related, nullIdPost],
              groups: [
                const BookmarkGroupBackup(
                  id: root,
                  name: 'Structural parent',
                  bookmarkIds: [],
                ),
                BookmarkGroupBackup(
                  id: leaf,
                  name: 'Nested',
                  parentGroupId: root,
                  bookmarkIds: const [1, 2, 3, 4],
                  addedAt: dates,
                ),
              ],
            );
            final source = container.read(bookmarksBackupSourceProvider);
            final json = source.converter.encode(
              payload: BookmarkBackupCodec().encode(data),
              extraFields: data.extraFields,
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
                        selection: const ExportNodeSelection.all('bookmarks'),
                        recommendedAction: ImportAction.configureItems,
                        parts: [
                          ExportPackagePartBuild(
                            path: 'sources/bookmarks/data.json',
                            write: (path) => File(path).writeAsString(json),
                          ),
                        ],
                      ),
                    ],
                  ),
                  '${directory.path}/package',
                );
            final notifier = container.read(importFlowProvider.notifier);
            if (mode == ImportAction.merge) {
              final invalid = jsonDecode(json) as Map<String, dynamic>;
              (invalid['data'] as List)[1]['snapshot']['schemaVersion'] = 99;
              final invalidPath =
                  await const ExportPackageWriter(fs: IoFileSystem()).write(
                    ExportPackageBuild(
                      createdAt: DateTime.utc(2026),
                      appVersion: '1.0.0',
                      sources: [
                        ExportPackageSourceBuild(
                          id: 'bookmarks',
                          schemaVersion: 4,
                          selection: const ExportNodeSelection.all('bookmarks'),
                          recommendedAction: ImportAction.configureItems,
                          parts: [
                            ExportPackagePartBuild(
                              path: 'sources/bookmarks/data.json',
                              write: (path) =>
                                  File(path).writeAsString(jsonEncode(invalid)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    '${directory.path}/invalid-package',
                  );
              final beforeGroups = await groups.getGroups();
              await notifier.load(invalidPath);
              expect(
                container.read(importFlowProvider).status,
                ImportFlowStatus.error,
              );
              expect(
                container.read(importFlowProvider).error,
                isA<InvalidBackupFormatException>(),
              );
              await notifier.apply(context);
              expect(await bookmarks.readAll(), isEmpty);
              expect(await groups.getGroups(), beforeGroups);
              expect(await profiles.getAll(), isEmpty);
            }
            await notifier.load(path);
            final state = container.read(importFlowProvider);
            expect(
              state.status,
              ImportFlowStatus.review,
              reason: '${state.error}',
            );
            expect(
              state.preflight!.isValid,
              isTrue,
              reason: '${state.preflight!.errors}',
            );
            await notifier.apply(context);
            expect(
              container.read(importFlowProvider).status,
              ImportFlowStatus.complete,
              reason: '${container.read(importFlowProvider).error}',
            );
            expect(await profiles.getAll(), isEmpty);
            final records = await bookmarks.readAll();
            expect(records, hasLength(4));
            final savedPool = records
                .whereType<ContentGroupBookmark>()
                .where((b) => b is! RelatedBookmark)
                .single;
            final savedRelated = records.whereType<RelatedBookmark>().single;
            expect(savedPool.snapshot, pool.snapshot);
            expect(savedPool.createdAt, pool.createdAt);
            expect(savedPool.observedAt, pool.observedAt);
            expect(savedRelated.snapshot, related.snapshot);
            expect(savedRelated.preferredOrder, isNull);
            expect(savedRelated.createdAt, related.createdAt);
            expect(savedRelated.observedAt, related.observedAt);
            final savedPosts = records.whereType<PostBookmark>().toList();
            expect(savedPosts, hasLength(2));
            final savedPost = savedPosts.singleWhere((b) => b.postId == 7);
            final savedNullPost = savedPosts.singleWhere(
              (b) => b.postId == null,
            );
            expect(savedPost.snapshot, post.snapshot);
            expect(savedNullPost.snapshot, nullIdPost.snapshot);
            expect(savedPost.createdAt, post.createdAt);
            expect(savedPost.updatedAt, post.updatedAt);
            expect(savedNullPost.createdAt, nullIdPost.createdAt);
            expect(savedNullPost.updatedAt, nullIdPost.updatedAt);
            expect((await groups.getGroup(root))!.bookmarkIds, isEmpty);
            final nested = (await groups.getGroup(leaf))!;
            expect(nested.parentGroupId, root);
            expect(nested.addedAt, {
              savedPost.id: dates[1],
              savedPool.id: dates[2],
              savedRelated.id: dates[3],
              savedNullPost.id: dates[4],
            });
            if (mode == ImportAction.replace) {
              final replacementPostData = TestPost(
                id: 99,
                origin: poolOrigin(host: 'replacement.example.test'),
                booruData: const LegacyPostData(
                  typeKey: 'legacy_danbooru',
                  custom: {},
                ),
              );
              final replacementPost = PostBookmark.fromSnapshot(
                id: 99,
                createdAt: DateTime.utc(2024),
                updatedAt: DateTime.utc(2025),
                postId: 99,
                snapshot: const StoredPostCodec().encode(replacementPostData),
                post: replacementPostData,
              );
              final replacement = BookmarkBackupData.unified(
                records: [replacementPost],
                groups: [
                  BookmarkGroupBackup(
                    id: leaf,
                    name: 'Replacement',
                    bookmarkIds: const [99],
                    addedAt: {99: DateTime.utc(2026)},
                  ),
                ],
              );
              final replacementPath = '${directory.path}/replacement.json';
              await File(replacementPath).writeAsString(
                source.converter.encode(
                  payload: BookmarkBackupCodec().encode(replacement),
                  extraFields: replacement.extraFields,
                ),
              );
              final bookmarkSource = container.read(
                _transactionSource(replacementPath),
              );
              await bookmarkSource.prepare(null);
              bookmarkSource.profileMappings = const {};
              final before = {
                for (final record in await bookmarks.readAll())
                  record.id: const StoredBookmarkCodec().encode(record),
              };
              final beforeGroups = await groups.getGroups();
              int nextId() =>
                  contentMap(
                        storage.metadataBox.get('idReservation'),
                      )['nextId']!
                      as int;
              final beforeNextId = nextId();
              final late = FakeImportSource(
                'late_failure',
                const IoFileSystem(),
                failApply: true,
              );
              final store = ImportJournalStore(
                fs: const IoFileSystem(),
                rootPath: '${directory.path}/recovery-transactions',
              );
              final transaction = ImportTransaction(
                store: store,
                fs: const IoFileSystem(),
              );
              final plan = ValidatedImportPlan(
                plan: ResolvedImportPlan(
                  sources: [
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
                  'bookmarks': await bookmarkSource.revisionToken(),
                  'late_failure': await late.revisionToken(),
                },
                summary: const PlannedChangeSummary(),
              );
              final stalePlan = ValidatedImportPlan(
                plan: plan.plan,
                revisionTokens: {
                  'bookmarks': 'stale',
                  'late_failure': await late.revisionToken(),
                },
                summary: const PlannedChangeSummary(),
              );
              await expectLater(
                transaction.execute(
                  transactionId: 'stale',
                  plan: stalePlan,
                  sources: {'bookmarks': bookmarkSource, 'late_failure': late},
                ),
                throwsA(isA<StaleImportPlanException>()),
              );
              expect({
                for (final record in await bookmarks.readAll())
                  record.id: const StoredBookmarkCodec().encode(record),
              }, before);
              expect(await groups.getGroups(), beforeGroups);
              expect(nextId(), beforeNextId);
              expect(late.applyCount, 0);
              expect(
                Directory(store.transactionPath('stale')).existsSync(),
                isFalse,
              );
              await expectLater(
                transaction.execute(
                  transactionId: 'rollback',
                  plan: plan,
                  sources: {'bookmarks': bookmarkSource, 'late_failure': late},
                ),
                throwsStateError,
              );
              expect(late.applyCount, 1);
              expect({
                for (final record in await bookmarks.readAll())
                  record.id: const StoredBookmarkCodec().encode(record),
              }, before);
              expect(await groups.getGroups(), beforeGroups);
              expect(nextId(), greaterThan(beforeNextId));
              expect(await profiles.getAll(), isEmpty);
              expect(
                Directory(store.transactionPath('rollback')).existsSync(),
                isFalse,
              );

              final coldPath = '${directory.path}/cold-rollback.json';
              await bookmarkSource.captureRollback(coldPath);
              await bookmarkSource.apply(
                ResolvedImportSource(
                  id: 'bookmarks',
                  action: ImportAction.replace,
                  items: const [],
                ),
              );
              expect({
                for (final record in await bookmarks.readAll())
                  record.id: const StoredBookmarkCodec().encode(record),
              }, isNot(before));
              final afterMutationNextId = nextId();
              bookmarkSource.profileMappings = const {};
              await bookmarkSource.restore(coldPath);
              expect({
                for (final record in await bookmarks.readAll())
                  record.id: const StoredBookmarkCodec().encode(record),
              }, before);
              expect(await groups.getGroups(), beforeGroups);
              expect(nextId(), greaterThanOrEqualTo(afterMutationNextId));
              expect(await profiles.getAll(), isEmpty);
            }
            await notifier.load(path);
            final resolved = container
                .read(importFlowProvider)
                .resolved!
                .sources
                .single;
            notifier.replaceSource(
              mode == ImportAction.replace
                  ? resolved.copyWith(action: mode)
                  : resolved.copyWith(
                      items: [
                        for (final item in resolved.items)
                          if (item.id == 'group:$leaf')
                            item.copyWith(
                              action: mode,
                              targetId: mode == ImportAction.mergeIntoTarget
                                  ? 'group:$root'
                                  : null,
                            )
                          else
                            item,
                      ],
                    ),
            );
            expect(
              container.read(importFlowProvider).preflight!.isValid,
              isTrue,
              reason: '${container.read(importFlowProvider).preflight!.errors}',
            );
            await notifier.apply(context);
            expect(
              container.read(importFlowProvider).status,
              ImportFlowStatus.complete,
              reason: '${container.read(importFlowProvider).error}',
            );
            final again = await bookmarks.readAll();
            expect(
              again.whereType<ContentGroupBookmark>().map((b) => b.id).toSet(),
              {savedPool.id, savedRelated.id},
            );
            expect(
              again
                  .whereType<PostBookmark>()
                  .where((b) => b.postId == 7)
                  .single
                  .id,
              savedPost.id,
            );
            final poolAgain =
                (await bookmarks.read(savedPool.id))! as ContentGroupBookmark;
            final relatedAgain =
                (await bookmarks.read(savedRelated.id))! as RelatedBookmark;
            final postAgain =
                (await bookmarks.read(savedPost.id))! as PostBookmark;
            expect(poolAgain.snapshot, pool.snapshot);
            expect(poolAgain.createdAt, pool.createdAt);
            expect(poolAgain.observedAt, pool.observedAt);
            expect(relatedAgain.snapshot, related.snapshot);
            expect(relatedAgain.createdAt, related.createdAt);
            expect(relatedAgain.observedAt, related.observedAt);
            expect(relatedAgain.preferredOrder, isNull);
            expect(postAgain.snapshot, post.snapshot);
            expect(postAgain.createdAt, post.createdAt);
            expect(postAgain.updatedAt, post.updatedAt);
            final repeatedGroup = (await groups.getGroup(
              mode == ImportAction.mergeIntoTarget ? root : leaf,
            ))!;
            expect(repeatedGroup.addedAt[savedPost.id], dates[1]);
            expect(repeatedGroup.addedAt[savedPool.id], dates[2]);
            expect(repeatedGroup.addedAt[savedRelated.id], dates[3]);
            expect(await profiles.getAll(), isEmpty);
            expect(container.read(booruConfigProvider), isEmpty);
            expect(httpAttempts, 0);
          }),
          createHttpClient: (_) {
            httpAttempts++;
            throw StateError('Unexpected HTTP request');
          },
        );
      },
    );
  }
}

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
