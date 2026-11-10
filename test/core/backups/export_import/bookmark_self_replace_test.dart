import 'package:boorusama/core/backups/export_import/import/bookmark_profile_dependency.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_planned_change_projector.dart';
import 'package:boorusama/core/backups/export_import/import/profile_dependency_planner.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/stored_bookmark_codec.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';

import '../../../support/fakes/test_post.dart';
import '../../../support/fakes/bookmark_test_storage.dart';
import '../../../support/fakes/memory_repositories.dart';

import 'dart:io';

import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/import/bookmark_profile_mapping.dart';

final _source = Provider.family<PackageTransactionSource, String>(
  (ref, path) => PackageTransactionSource(
    source: ref.read(bookmarksBackupSourceProvider),
    incomingPath: path,
    fs: ref.read(appFileSystemProvider),
    ref: ref,
    credentialsIncluded: false,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    (
      name: 'no matching profile',
      opaque: false,
      explicit: false,
      mapped: false,
      hinted: false,
    ),
    (
      name: 'automatic reader',
      opaque: false,
      explicit: false,
      mapped: true,
      hinted: false,
    ),
    (
      name: 'unchanged valid hint',
      opaque: false,
      explicit: false,
      mapped: true,
      hinted: true,
    ),
    (
      name: 'explicit remap',
      opaque: false,
      explicit: true,
      mapped: true,
      hinted: false,
    ),
    (
      name: 'unaddressable record in two groups',
      opaque: true,
      explicit: false,
      mapped: false,
      hinted: false,
    ),
  ]) {
    final explicit = scenario.explicit;
    test(
      'self-copy preview and actual Replace preserve data: ${scenario.name}',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'self-replace-',
        );
        Hive.init(directory.path);
        if (!Hive.isAdapterRegistered(4))
          Hive.registerAdapter(BookmarkHiveObjectAdapter());
        if (!Hive.isAdapterRegistered(5))
          Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
        final posts = await Hive.openBox<BookmarkHiveObject>('favorites');
        await Hive.openBox<BookmarkGroupHiveObject>('bookmark_groups');
        final organization = await Hive.openBox<dynamic>('bookmark_folders');
        await organization.put('version', 1);
        await organization.put('poolBookmarks', []);
        final storage = await BookmarkTestStorage.open(posts);
        final repository = storage.repository(posts);
        final groups = await repository.openOrganization();
        final initialPost = _bookmark(0)
            .copyWith(sourceUrl: 'https://danbooru.donmai.us/posts/1');
        final PostBookmark post;
        if (scenario.opaque) {
          post = PostBookmark.empty.copyWith(
            id: (await repository.reserveIds(1)).single,
            createdAt: DateTime.utc(2016, 5, 6),
            updatedAt: DateTime.utc(2018, 9, 10),
            md5: 'legacy-flat-unaddressable',
            sourceUrl: 'local-only-source',
          );
          await repository.upsert(post);
        } else {
          post = (await repository.addBookmarkWithBookmarks([
            scenario.hinted
                ? bookmarkWithProfileHint(
                    initialPost,
                    '11111111-1111-4111-8111-111111111111',
                  )
                : initialPost,
          ])).single;
        }
        final summary = ContentGroupSummary(
          reference: const ContentReferenceCodec().parse(
            engine: BooruType.danbooru,
            site: Uri.parse('https://danbooru.donmai.us'),
            kind: ContentKind.group,
            sourceKey: 'pool:42',
          ),
          title: 'Loaded Pool',
        );
        final pool = ContentGroupBookmark(
          id: (await repository.reserveIds(1)).single,
          createdAt: DateTime.utc(2023),
          observedAt: DateTime.utc(2024),
          sourceProfileHint: scenario.hinted
              ? '11111111-1111-4111-8111-111111111111'
              : null,
          snapshot: StoredGroupSnapshot(
            summary: summary,
            details: ContentGroupDetails(
              summary: summary,
              description: const GroupDescription(
                text: 'Retained details',
                format: GroupTextFormat.plainText,
              ),
            ),
          ),
        );
        await repository.upsert(pool);
        final group = (await groups.getGroup(defaultBookmarkGroupId))!.copyWith(
          bookmarkIds: {post.id, pool.id},
          addedAt: {
            post.id: DateTime.utc(2024, 2),
            pool.id: DateTime.utc(2025, 3),
          },
        );
        await repository.commitOrganization(groups: [group]);
        if (scenario.opaque) {
          final other = await groups.createGroup('Second membership');
          await groups.replaceMemberships(
            other.id,
            {post.id},
            addedAt: {post.id: DateTime.utc(2025, 4)},
          );
        }
        final beforeGroups = await groups.getGroups();
        final before = {
          for (final r in await repository.readAll())
            r.id: const StoredBookmarkCodec().encode(r),
        };
        final container = ProviderContainer(
          overrides: [
            ...storage.overrides,
            bookmarkRepoProvider.overrideWith((_) => repository),
            bookmarkGroupRepoProvider.overrideWith((_) => groups),
            bookmarkUrlResolverProvider.overrideWith(
              (_, _) => const DefaultImageUrlResolver(),
            ),
            miscDataStoreProvider.overrideWithValue(MemoryMiscDataStore()),
            booruEngineRegistryProvider.overrideWith(
              (_) => BooruEngineRegistry(),
            ),
            booruConfigProvider.overrideWith(
              () => BooruConfigNotifier(initialConfigs: []),
            ),
            appFileSystemProvider.overrideWithValue(
              _FileSystem(directory.path),
            ),
            appVersionProvider.overrideWithValue(null),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await Hive.close();
          await directory.delete(recursive: true);
        });
        final backup = container.read(bookmarksBackupSourceProvider);
        final data = await backup.dataGetter();
        final path = '${directory.path}/fresh.json';
        await File(path).writeAsString(
          backup.converter.encode(
            payload: backup.handler.encode(data),
            extraFields: data.extraFields,
          ),
        );
        final source = container.read(_source(path));
        await source.prepare(null);
        final keys = data.records
            .map(
              (r) => ProfileReferenceKey.fromReference(
                bookmarkRecordProfileReference(r),
              ),
            )
            .toSet();
        const profile = '11111111-1111-4111-8111-111111111111';
        source.profileMappings = scenario.mapped
            ? {for (final key in keys) key: profile}
            : {};
        source.explicitBookmarkProfileMappings = explicit ? keys : {};
        final resolution = ResolvedImportSource(
          id: 'bookmarks',
          action: ImportAction.replace,
          items: const [],
        );
        await container.read(bookmarkProvider.notifier).runWithLibrary(
          () async {
            await source.captureLocalSnapshot();
            final projection = source.plannedChanges(resolution);
            final runs = source.projectionRuns;
            expect(source.plannedChanges(resolution), same(projection));
            final changes = (await projection)!;
            expect(source.plannedChanges(resolution), same(projection));
            expect(source.projectionRuns, runs);
            expect(changes.created, 0);
            expect(changes.deleted, 0);
            expect(changes.updated, explicit ? 2 : 0);
            await source.apply(resolution);
          },
        );
        final after = await repository.readAll();
        expect(after.map((r) => r.id), before.keys);
        expect(
          after.whereType<PostBookmark>().single.sourceUrl,
          post.sourceUrl,
        );
        expect(await groups.getGroups(), beforeGroups);
        if (explicit) {
          expect(after.map(bookmarkRecordProfileHint), everyElement(profile));
          expect(
            (after.whereType<ContentGroupBookmark>().single).snapshot,
            pool.snapshot,
          );
        } else {
          expect({
            for (final r in after) r.id: const StoredBookmarkCodec().encode(r),
          }, before);
        }
      },
    );
  }
  for (final hinted in [false, true]) {
    for (final mapping in [
      null,
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222',
    ]) {
      for (final explicit in [false, true]) {
        test(
          'optional hint mapping preserves local payload: hinted=$hinted mapping=$mapping explicit=$explicit',
          () {
            final base = _bookmark(0)
                .copyWith(sourceUrl: 'https://danbooru.donmai.us/posts/1');
            final original = hinted
                ? bookmarkWithProfileHint(
                    base,
                    '11111111-1111-4111-8111-111111111111',
                  )
                : base;
            final codec = const StoredBookmarkCodec();
            final incoming = (codec.decode(
              codec.encodeForTransfer(original),
            ) as PostBookmark).copyWith(id: 9000);
            final key = ProfileReferenceKey.fromReference(
              bookmarkRecordProfileReference(incoming),
            );
            final result =
                mapBookmarkImportProfiles(
                      incoming: [incoming],
                      local: [original],
                      mappings: {if (mapping != null) key: mapping},
                      explicitMappings: explicit ? {key} : {},
                    )[9000]!
                    as PostBookmark;
            final expected = hinted || explicit
                ? mapping ?? bookmarkRecordProfileHint(original)
                : null;
            expect(result.id, 9000);
            expect(result.sourceUrl, base.sourceUrl);
            expect(result.snapshot.common, original.snapshot.common);
            expect(bookmarkRecordProfileHint(result), expected);
          },
        );
      }
    }
  }
  test('genuine metadata edits remain visible while identical implicit copies remain unchanged', () {
    final original = _bookmark(0);
    final editedPost = TestPost(
      id: original.post.id,
      origin: original.post.origin,
      booruData: original.post.booruData,
      tags: const {'changed'},
    );
    final edited = original.copyWith(
      post: editedPost,
      snapshot: const StoredPostCodec().encode(editedPost),
    );
    final key = ProfileReferenceKey.fromReference(
      bookmarkRecordProfileReference(original),
    );
    final mapped = mapBookmarkImportProfiles(
      incoming: [edited],
      local: [original],
      mappings: {key: '11111111-1111-4111-8111-111111111111'},
    );
    final result = mapped[edited.id]! as PostBookmark;
    expect(result.post.tags, const {'changed'});
    expect(
      bookmarkRecordProfileHint(result),
      '11111111-1111-4111-8111-111111111111',
    );
  });
  test(
    'fresh self-export Replace does not enrich thousands of missing hints',
    () {
      final profile = BooruConfig.fromJson({
        ...BooruConfig.defaultConfig(
          booruType: BooruType.danbooru,
          url: 'https://danbooru.donmai.us',
          customDownloadFileNameFormat: null,
        ).toJson(),
        'id': '11111111-1111-4111-8111-111111111111',
      });
      final records = <Bookmark>[
        for (var i = 0; i < 3201; i++) _bookmark(i),
      ];
      final date = DateTime.utc(2024, 3, 4);
      final group = BookmarkGroup(
        id: defaultBookmarkGroupId,
        name: 'Default',
        bookmarkIds: records.map((r) => r.id).toSet(),
        addedAt: {for (final r in records) r.id: date},
      );
      final data = BookmarkBackupData.unified(
        records: records,
        groups: [
          BookmarkGroupBackup(
            id: group.id,
            name: group.name,
            bookmarkIds: group.bookmarkIds.toList(),
            addedAt: group.addedAt,
          ),
        ],
      );
      final codec = BookmarkBackupCodec();
      final bytes = encodeData(
        version: 10,
        exportDate: DateTime.utc(2026, 11, 10),
        exportVersion: null,
        payload: codec.encode(data),
        extraFields: data.extraFields,
      );
      final incoming = codec.parse(decodeData(data: bytes));
      final dependencies = const ProfileDependencyPlanner().plan(
        references: const [],
        optionalReferences: incoming.records.map(
          bookmarkRecordProfileReference,
        ),
        localProfiles: [profile],
      );
      expect(dependencies.errors, isEmpty);
      expect(dependencies.mappings.single.profileId, profile.id);
      final summary = const ImportPlannedChangeProjector().bookmarks(
        local: BookmarkImportLocalSnapshot(records: records, groups: [group]),
        incoming: incoming,
        resolution: ResolvedImportSource(
          id: 'bookmarks',
          action: ImportAction.replace,
          items: const [],
        ),
        profileMappings: {
          for (final mapping in dependencies.mappings)
            for (final reference in mapping.references)
              ProfileReferenceKey.fromReference(reference): mapping.profileId!,
        },
      )!;
      expect(summary.updated, 0);
      expect(summary.created, 0);
      expect(summary.deleted, 0);
      expect(summary.previewRows, isEmpty);
    },
  );
}

class _FileSystem extends IoFileSystem {
  const _FileSystem(this.root);
  final String root;
  @override
  Future<String> getAppStoragePath() async => root;
}

PostBookmark _bookmark(int id) {
  final post = TestPost(
    id: id + 1,
    origin: PostOrigin.fromSource(
      booruType: BooruType.danbooru,
      booruId: BooruType.danbooru.id,
      source: 'danbooru.donmai.us',
    ),
    booruData: const LegacyPostData(typeKey: 'legacy_danbooru', custom: {}),
  );
  return PostBookmark.fromSnapshot(
    id: id,
    createdAt: DateTime.utc(2023),
    updatedAt: DateTime.utc(2024),
    postId: post.id,
    snapshot: const StoredPostCodec().encode(post),
    post: post,
  );
}
