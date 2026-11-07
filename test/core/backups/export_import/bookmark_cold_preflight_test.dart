import 'dart:async';
import 'dart:io';

import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/core/backups/export_import/sources/legacy_json_source_adapter.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_factory_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/factory.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository_factory.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

const groupId = '11111111-1111-4111-8111-111111111111';

void main() {
  testWidgets('cold bookmark preflight and import finish without profiles', (
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
        final parentZone = Zone.current;
        final directory = await Directory.systemTemp.createTemp(
          'cold-bookmark-import-',
        );
        Hive.init(directory.path);
        if (!Hive.isAdapterRegistered(4)) {
          Hive.registerAdapter(BookmarkHiveObjectAdapter());
        }
        if (!Hive.isAdapterRegistered(5)) {
          Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
        }
        final profileBox = await Hive.openBox<String>('booru_configs');
        final profiles = HiveBooruConfigRepository(box: profileBox);
        final coordinator = DataMutationCoordinator();
        final container = ProviderContainer(
          overrides: [
            loggerProvider.overrideWithValue(AppLogger()),
            dataMutationCoordinatorProvider.overrideWithValue(coordinator),
            booruEngineRegistryProvider.overrideWith(
              (ref) => BooruEngineRegistry(),
            ),
            bookmarkRepositoryFactoryProvider.overrideWithValue(
              _ParentZoneFactory(parentZone),
            ),
            bookmarkGroupRepositoryFactoryProvider.overrideWithValue(
              const HiveBookmarkGroupRepositoryFactory(),
            ),
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
                    children: [ExportSelectionNode(id: 'group:$groupId')],
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
          await Hive.close();
          await directory.delete(recursive: true);
        });
        final post = PostBookmark(
          id: 1,
          createdAt: DateTime.utc(2020),
          updatedAt: DateTime.utc(2021),
          thumbnailUrl: '',
          sampleUrl: '',
          originalUrl: '',
          sourceUrl: 'https://source.example.test',
          booruId: BooruType.danbooru.id,
          width: 100,
          height: 100,
          md5: '',
          tags: const {},
          realSourceUrl: null,
          format: 'jpg',
          imageUrlResolver: const DefaultImageUrlResolver(),
          postId: 7,
          metadata: const {},
        );
        final data = BookmarkBackupData.unified(
          records: [post],
          groups: [
            BookmarkGroupBackup(
              id: groupId,
              name: 'Cold',
              bookmarkIds: const [1],
              addedAt: {1: DateTime.utc(2022)},
            ),
          ],
        );
        final source = container.read(bookmarksBackupSourceProvider);
        final json = source.converter.encode(
          payload: BookmarkBackupCodec().encode(data),
          extraFields: data.extraFields,
        );
        final path = await const ExportPackageWriter(fs: IoFileSystem()).write(
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
        expect(Hive.isBoxOpen('favorites'), isFalse);
        final notifier = container.read(importFlowProvider.notifier);
        await notifier.load(path).timeout(const Duration(seconds: 30));
        final state = container.read(importFlowProvider);
        expect(state.status, ImportFlowStatus.review, reason: '${state.error}');
        expect(
          state.preflight!.isValid,
          isTrue,
          reason: '${state.preflight!.errors}',
        );
        await notifier.apply(context).timeout(const Duration(seconds: 30));
        expect(
          container.read(importFlowProvider).status,
          ImportFlowStatus.complete,
          reason: '${container.read(importFlowProvider).error}',
        );
        final bookmarks = await container.read(bookmarkRepoProvider.future);
        final groups = await container.read(bookmarkGroupRepoProvider.future);
        final saved = (await bookmarks.getAllBookmarksOrThrow(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        )).single;
        expect(saved.postId, 7);
        expect(saved.snapshot, post.snapshot);
        expect(
          (await groups.getGroup(groupId))!.addedAt[saved.id],
          DateTime.utc(2022),
        );
        expect(await profiles.getAll(), isEmpty);
        expect(container.read(booruConfigProvider), isEmpty);
        expect(httpAttempts, 0);
      }),
      createHttpClient: (_) {
        httpAttempts++;
        throw StateError('Unexpected HTTP request');
      },
    );
  });
}

// Provider initialization can run outside the zone holding the preflight lock.
final class _ParentZoneFactory implements BookmarkRepositoryFactory {
  _ParentZoneFactory(this.zone);
  final Zone zone;
  final _delegate = const HiveBookmarkRepositoryFactory();
  @override
  Future<BookmarkRepository> create({
    BooruPostDataCodec? Function(BooruType type)? postDataCodec,
    BookmarkStorageContext? storage,
  }) => zone.run(
    () => _delegate.create(postDataCodec: postDataCodec, storage: storage),
  );
  @override
  Future<void> dispose(BookmarkRepository repository) =>
      _delegate.dispose(repository);
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
