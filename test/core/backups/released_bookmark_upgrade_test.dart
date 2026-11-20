import 'dart:io';

import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_schema.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_planner.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_service.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_factory_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/factory.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;

import '../../support/fakes/memory_repositories.dart';

const _fixtures = 'test/fixtures/released_upgrade';
const _baseline = 'v4.6.1-timberpile.3';
const _archive = '550e8400-e29b-41d4-a716-446655440000';
const _shared = '550e8400-e29b-41d4-a716-446655440001';
const _empty = '550e8400-e29b-41d4-a716-446655440002';
const _profile = '550e8400-e29b-41d4-a716-446655440017';
const _convertedFolder = '99892305-8b85-5176-b066-50be5efd6f35';
final _created = DateTime.utc(2026, 1, 2, 3, 4, 5, 678, 901);
final _updated = DateTime.utc(2026, 2, 3, 4, 5, 6, 789, 123);
final _storedCreated = DateTime.utc(2026, 1, 2, 3, 4, 5, 678);
final _storedUpdated = DateTime.utc(2026, 2, 3, 4, 5, 6, 789);

BooruPostDataCodec? _engine(BooruType type) =>
    type == BooruType.gelbooruV2 ? const GelbooruV2PostCodec() : null;
final _codec = BookmarkBackupCodec(postDataCodec: _engine);

typedef _Library = ({
  BookmarkRepository repository,
  UnifiedBookmarkStore records,
  BookmarkGroupRepository groups,
  DataMutationCoordinator coordinator,
});

Future<_Library> _open(String root) async {
  Hive.init(root);
  final coordinator = DataMutationCoordinator();
  final repository = await const HiveBookmarkRepositoryFactory().create(
    storage: BookmarkStorageContext(coordinator: coordinator),
    postDataCodec: _engine,
  );
  return (
    repository: repository,
    coordinator: coordinator,
    records: unifiedBookmarkStorage(repository)!,
    groups: await const HiveBookmarkGroupRepositoryFactory()
        .createWithBookmarkRepository(repository),
  );
}

Future<void> _expectLibrary(
  _Library library, {
  required bool inPlace,
  required bool withFolders,
}) async {
  final records = (await library.records.readAll()).cast<PostBookmark>();
  expect(records.map((record) => record.postId).toSet(), {42, 67});
  expect(records, hasLength(2));
  final byPost = {for (final record in records) record.postId: record.id};
  if (inPlace) expect(byPost, {42: 12, 67: 27});
  final created = inPlace ? _storedCreated : _created;
  for (final record in records) {
    expect(record.snapshot.origin.profileIdHint, _profile);
    expect(record.snapshot.origin.sourceHost, 'gelbooru.example/board');
    expect(record.post.tags, {'cat', 'blue_eyes'});
    expect(record.post.booruData, isA<GelbooruV2PostData>());
    expect((record.post.booruData as GelbooruV2PostData).hasNotes, isTrue);
    expect(record.createdAt, created);
    expect(record.updatedAt, inPlace ? _storedUpdated : _updated);
  }
  final groups = {for (final g in await library.groups.getGroups()) g.id: g};
  expect(groups[_archive]?.bookmarkIds, {byPost[42], byPost[67]});
  expect(groups[_shared]?.bookmarkIds, {byPost[42]});
  expect(groups[_archive]?.addedAt, {byPost[42]: created, byPost[67]: created});
  expect(groups[_shared]?.addedAt, {byPost[42]: created});
  expect(groups[defaultBookmarkGroupId]?.parentGroupId, isNull);
  if (withFolders) {
    expect(groups[_archive]?.parentGroupId, _convertedFolder);
    expect(groups[_empty]?.parentGroupId, _convertedFolder);
    expect(groups[_empty]?.bookmarkIds, isEmpty);
    expect(groups[_convertedFolder]?.name, 'Folder');
    expect(groups[_convertedFolder]?.bookmarkIds, isEmpty);
    expect(groups[defaultBookmarkGroupId]?.bookmarkIds, {byPost[67]});
    if (inPlace) {
      expect(groups[_archive]?.position, 1);
      expect(groups[_empty]?.position, 0);
      expect(groups[_shared]?.position, 2);
      expect(await library.groups.getRecentGroupIds(), [_archive]);
      expect(await library.groups.getLegacyFolderGroupIds(), {
        _archive: _convertedFolder,
        _empty: _empty,
      });
    }
  }
}

BookmarkImportService _importer(_Library library) => BookmarkImportService(
  bookmarkRepository: library.repository,
  groupRepository: library.groups,
  imageUrlResolver: (_) => const DefaultImageUrlResolver(),
);

Future<String> _packageBookmarkBytes() async {
  final staged = await const ExportPackageReader(fs: IoFileSystem())
      .stage('$_fixtures/$_baseline/released.bsexport');
  addTearDown(staged.dispose);
  return File(staged.pathFor('sources/bookmarks/data.json')).readAsString();
}

void main() {
  late Directory work;
  setUp(() async {
    work = await Directory.systemTemp.createTemp('released-bookmark-fixture-');
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
  });
  tearDown(() async {
    await Hive.close();
    await work.delete(recursive: true);
  });

  test(
    'released Hive data migrates directly and survives two cold opens',
    () async {
      final source = Directory('$_fixtures/$_baseline/storage');
      final originals = <String, List<int>>{};
      for (final name in [
        'favorites.hive',
        'bookmark_groups.hive',
        'bookmark_folders.hive',
      ]) {
        final file = File(p.join(source.path, name));
        originals[name] = await file.readAsBytes();
        await file.copy(p.join(work.path, name));
      }
      for (var start = 0; start < 3; start++) {
        final library = await _open(work.path);
        await _expectLibrary(library, inPlace: true, withFolders: true);
        final metadata = Hive.box<dynamic>('favorites_content_metadata');
        expect(
          (metadata.get(BookmarkStorageMigration.activeKey) as Map)['version'],
          2,
        );
        expect(metadata.get(BookmarkStorageMigration.pendingKey), isNull);
        expect(metadata.get('repositorySchema'), 1);
        expect(await Hive.boxExists('bookmark_groups_unified_v2'), isFalse);
        expect(await Hive.boxExists('bookmark_groups_hierarchy_v3'), isFalse);
        await Hive.close();
        for (final entry in originals.entries) {
          expect(
            await File(p.join(work.path, entry.key)).readAsBytes(),
            entry.value,
          );
        }
      }
      final library = await _open(work.path);
      expect(await library.records.reserveIds(1), [28]);
    },
  );

  test('fresh installation activates only the final hierarchy', () async {
    final library = await _open(work.path);
    expect(await library.records.readAll(), isEmpty);
    expect(
      (await library.groups.getGroups()).single.id,
      defaultBookmarkGroupId,
    );
    expect(await library.records.reserveIds(1), [0]);
    expect(await Hive.boxExists('bookmark_groups_hierarchy_v2'), isTrue);
  });

  test(
    'released rollback restores records missing after a partial import',
    () async {
      final library = await _open(work.path);
      // The released importer could remove the old rows before a crash.
      expect(await library.records.read(12), isNull);
      expect(await library.records.read(27), isNull);
      final container = ProviderContainer(
        overrides: [
          dataMutationCoordinatorProvider.overrideWithValue(
            library.coordinator,
          ),
          bookmarkRepoProvider.overrideWith((_) => library.repository),
          bookmarkGroupRepoProvider.overrideWith((_) => library.groups),
          bookmarkUrlResolverProvider.overrideWith(
            (_, _) => const DefaultImageUrlResolver(),
          ),
          booruEngineRegistryProvider.overrideWith(
            (_) => BooruEngineRegistry(),
          ),
          appVersionProvider.overrideWithValue(null),
          miscDataStoreProvider.overrideWithValue(MemoryMiscDataStore()),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: []),
          ),
        ],
      );
      addTearDown(container.dispose);
      final recovery = Provider(
        (ref) => PackageTransactionSource(
          source: ref.read(bookmarksBackupSourceProvider),
          incomingPath: null,
          fs: const IoFileSystem(),
          ref: ref,
          credentialsIncluded: false,
        ),
      );
      await container
          .read(bookmarkProvider.notifier)
          .runWithLibrary(
            () => container
                .read(recovery)
                .restore('$_fixtures/$_baseline/bookmarks.json'),
          );
      await _expectLibrary(library, inPlace: false, withFolders: true);
      expect((await library.records.readAll()).map((record) => record.id), [
        0,
        1,
      ]);
    },
  );

  for (final (tag, version) in [
    ('v4.5.0-timberpile.3', 4),
    ('v4.5.0-timberpile.4', 4),
    ('v4.5.0-timberpile.5', 5),
    ('v4.6.1-timberpile.1', 5),
    ('v4.6.1-timberpile.2', 5),
    (_baseline, 5),
  ]) {
    test('$tag Bookmark export imports, re-exports and reopens', () async {
      final encoded = await File('$_fixtures/$tag/bookmarks.json')
          .readAsString();
      final incomingBytes = tag == _baseline
          ? await _packageBookmarkBytes()
          : encoded;
      expect(incomingBytes, encoded);
      final payload = decodeData(data: incomingBytes);
      final withFolders = version == 5;
      expect(payload.version, version);
      final incoming = _codec.parse(payload);
      final library = await _open(work.path);
      await _importer(library).replace(incoming);
      await _expectLibrary(library, inPlace: false, withFolders: withFolders);

      final data = buildBookmarkBackupData(
        records: await library.records.readAll(),
        groups: await library.groups.getGroups(),
        scope: const BookmarkExportScope.all(),
      );
      final reexport = _codec.parse(
        decodeData(
          data: encodeData(
            version: kBookmarksBackupVersion,
            exportDate: DateTime.utc(2026),
            exportVersion: null,
            payload: _codec.encode(data),
            extraFields: data.extraFields,
          ),
        ),
      );
      final importer = _importer(library);
      final plan = const BookmarkImportPlanner().plan(
        data: reexport,
        currentBookmarks: await library.records.readAll(),
        currentGroups: await library.groups.getGroups(),
      );
      // One copy shares its existing records rather than allocating duplicates.
      final shared = plan.groups.singleWhere((group) => group.id == _shared);
      const copyId = '550e8400-e29b-41d4-a716-446655440088';
      await importer.apply(
        plan.resolveActions({
          for (final group in plan.groups)
            group.id: group.id == _shared
                ? shared.resolveAction(ImportAction.copy, destinationId: copyId)
                : group.resolveAction(ImportAction.merge),
        }),
      );
      expect(
        (await library.groups.getGroup(copyId))?.bookmarkIds,
        (await library.groups.getGroup(_shared))?.bookmarkIds,
      );
      for (var start = 0; start < 2; start++) {
        await Hive.close();
        final reopened = await _open(work.path);
        await _expectLibrary(
          reopened,
          inPlace: false,
          withFolders: withFolders,
        );
        expect(
          (await reopened.groups.getGroup(copyId))?.bookmarkIds,
          (await reopened.groups.getGroup(_shared))?.bookmarkIds,
        );
      }
    });
  }
}
