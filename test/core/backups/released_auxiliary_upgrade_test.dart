import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/analytics/providers.dart';
import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/import/import_journal.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/blacklists/src/data/hive/factory.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_factory_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/factory.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/bulk_downloads/src/data/repo_io.dart';
import 'package:boorusama/core/bulk_downloads/src/types/download_options.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/search/histories/src/data/repo_io.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/tags/favorites/providers.dart';
import 'package:boorusama/core/tags/favorites/src/data/favorite_tag_repository_factory_hive.dart';
import 'package:boorusama/foundation/info/device_info.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/sources/following_topic_backup_codec.dart';
import 'package:boorusama/core/backups/sources/following_topic_import_service.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/backups/sources/topic_feed_backup_codec.dart';
import 'package:boorusama/core/backups/sources/topic_feed_import_service.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/blacklists/src/data/hive/tag_repository.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bulk_downloads/src/data/repo_sqlite.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/downloads/sidecar/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/search/following_topics/src/compatibility/topic_storage_contract.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_hive_object.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart';
import 'package:boorusama/core/search/histories/src/data/repo_sqlite.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/settings/src/data/setting_repository_hive.dart';
import 'package:boorusama/core/tags/favorites/src/data/favorite_tag_hive_object.dart';
import 'package:boorusama/core/tags/favorites/src/data/favorite_tag_repository_hive.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const _fixture = 'test/fixtures/released_upgrade/v4.6.1-timberpile.3';
const _primary = '550e8400-e29b-41d4-a716-446655440017';
const _secondary = '550e8400-e29b-41d4-a716-446655440018';
const _missing = '550e8400-e29b-41d4-a716-446655440019';
const _topic = '550e8400-e29b-41d4-a716-446655440027';
const _feed = '550e8400-e29b-41d4-a716-446655440028';
const _folder = '550e8400-e29b-41d4-a716-446655440029';
final _date = DateTime.utc(2026, 2, 4, 1, 2, 3, 456);

Future<HiveFollowingTopicRepository> _following() async =>
    HiveFollowingTopicRepository(
      box: await Hive.openBox<FollowingTopicHiveObject>(followingTopicsBoxName),
      organizationBox: await Hive.openBox<dynamic>(topicOrganizationBoxName),
    );

Future<void> _expectFollowing(
  FollowingTopicRepository repository, {
  bool inPlace = false,
}) async {
  final topic = (await repository.getById(_topic))!;
  expect(topic.name, 'Cats');
  expect(topic.query, 'cat_fixture');
  expect(topic.profileId, _primary);
  expect(topic.autoUpdateEnabled, isFalse);
  if (inPlace) expect(topic.createdAt, _date);
  final folder = (await repository.getOrganization()).folders.singleWhere(
    (folder) => folder.id == _folder,
  );
  expect(folder.name, 'Fixture topics');
  expect(folder.searchIds, [_topic]);
  final feed = (await repository.getFeeds()).singleWhere(
    (feed) => feed.id == _feed,
  );
  expect(feed.profileId, _secondary);
  expect(feed.name, 'Fixture legacy feed');
  final queries = [
    for (final id in feed.sourceIds) (await repository.getById(id))!.query,
  ];
  expect(queries, ['artist_fixture', 'landscape_fixture']);
}

Future<void> _expectSqlite(String downloadPath, String historyPath) async {
  final db = sqlite3.open(downloadPath);
  try {
    final downloads = DownloadRepositorySqlite(db)..initialize();
    final saved = (await downloads.getSavedTasks()).single;
    expect(saved.name, 'Fixture saved download');
    expect(saved.task.sidecarFormat, SidecarFormat.json);
    final session = (await downloads.getSessionsByTaskId(saved.task.id)).single;
    final record = (await downloads.getRecordsBySessionId(session.id)).single;
    expect(record.fileName, 'fixture.jpg');
    expect(record.sidecar?.format, SidecarFormat.json);
    expect(record.sidecar?.postId, '42');
    expect(record.sidecar?.tags, ['artist_fixture']);
    expect(record.sidecar?.urls, ['https://img.example/fixture.jpg']);
  } finally {
    db.close();
  }

  final historyDb = sqlite3.open(historyPath);
  try {
    final history = SearchHistoryRepositorySqlite(db: historyDb)..initialize();
    final row = (await history.getHistories()).single;
    expect(row.query, 'cat_fixture');
    expect(row.queryType, QueryType.simple);
    expect(row.searchCount, 2);
    expect(row.booruTypeName, BooruType.gelbooruV2.name);
    expect(Uri.parse(row.siteUrl).host, 'gelbooru.example');
  } finally {
    historyDb.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory work;
  setUp(() async {
    work = await Directory.systemTemp.createTemp('released-auxiliary-fixture-');
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(FollowingTopicHiveObjectAdapter());
      Hive.registerAdapter(SearchPostPreviewHiveObjectAdapter());
      Hive.registerAdapter(RecentSearchPostHiveObjectAdapter());
      Hive.registerAdapter(FavoriteTagHiveObjectAdapter());
      Hive.registerAdapter(BlacklistedTagHiveObjectAdapter());
    }
  });
  tearDown(() async {
    await Hive.close();
    await work.delete(recursive: true);
  });

  test('published profile, settings, tags, Following and SQLite state survive cold opens', () async {
    final source = Directory('$_fixture/storage');
    for (final file in source.listSync(recursive: true).whereType<File>()) {
      final target = p.join(
        work.path,
        p.relative(file.path, from: source.path),
      );
      await Directory(p.dirname(target)).create(recursive: true);
      await file.copy(target);
    }
    for (var i = 0; i < 3; i++) {
      Hive.init(work.path);
      final profiles = HiveBooruConfigRepository(
        box: await Hive.openBox<String>('booru_configs'),
      );
      final configs = {
        for (final profile in await profiles.getAll()) profile.id: profile,
      };
      expect(configs.keys.toSet(), {_primary, _secondary});
      expect(configs[_primary]?.auth.booruType, BooruType.gelbooruV2);
      expect(configs[_secondary]?.auth.booruType, BooruType.danbooru);
      final settings =
          (await SettingsRepositoryHive(
            Hive.openBox<dynamic>('settings'),
          ).load().run()).fold(
            (error) => throw StateError('$error'),
            (value) => value,
          );
      expect(settings.currentBooruConfigId, _primary);
      expect(settings.booruConfigIdOrderList, [_secondary, _primary]);
      expect(settings.autoFocusSearchBar, isFalse);
      expect(settings.safeMode, isTrue);

      final tags = FavoriteTagRepositoryHive(
        await Hive.openBox<FavoriteTagHiveObject>('favorite_tags'),
      );
      final favorite = (await tags.getAll()).single;
      expect(favorite.name, 'artist_fixture');
      expect(favorite.labels, ['synthetic']);
      expect(favorite.createdAt.toUtc(), _date);
      final blacklist = HiveBlacklistedTagRepository();
      await blacklist.init(work.path);
      final rule = (await blacklist.getBlacklist()).single;
      expect(rule.id, 9);
      expect(rule.name, 'excluded_fixture');
      expect(rule.isActive, isFalse);
      expect(rule.createdDate.toUtc(), _date);

      await _expectFollowing(await _following(), inPlace: true);
      await _expectSqlite(
        p.join(work.path, 'data/download.db'),
        p.join(work.path, 'data/search_history.db'),
      );
      await Hive.close();
    }
  });

  test('released package stages all domains and restores Topics with or without profiles', () async {
    final staged = await const ExportPackageReader(fs: IoFileSystem())
        .stage('$_fixture/released.bsexport');
    addTearDown(staged.dispose);
    expect(
      {
        for (final source in staged.manifest.sources)
          source.id: source.schemaVersion,
      },
      {
        'profiles': 1,
        'settings': 1,
        'bookmarks': 5,
        'favorite_tags': 1,
        'blacklisted_tags': 1,
        followingTopicsBackupSourceId: 2,
        topicFeedsBackupSourceId: 1,
        'downloads': 1,
        'search_histories': 1,
      },
    );
    Future<String> json(String source) =>
        File(staged.pathFor('sources/$source/data.json')).readAsString();
    final profiles = [
      for (final row in decodeData(data: await json('profiles')).data)
        BooruConfig.fromJson(row as Map<String, dynamic>),
    ];
    final topics = FollowingTopicBackupCodec().parse(
      decodeData(data: await json(followingTopicsBackupSourceId)),
    );
    final feeds = TopicFeedBackupCodec().parse(
      decodeData(data: await json(topicFeedsBackupSourceId)),
    );

    final profilelessPath = p.join(work.path, 'profileless');
    Hive.init(profilelessPath);
    final profileless = await _following();
    final detachedImporter = FollowingTopicImportService(
      repository: profileless,
    );
    expect(
      detachedImporter.preview(topics, profiles: []).unmatchedRecordIds,
      isEmpty,
    );
    final result = await detachedImporter.replace(topics, profiles: []);
    expect(result.importedCount, 1);
    expect(result.skippedProfileCount, 0);
    final namespace = (await profileless.getAll()).single.profileId;
    expect(profiles.map((profile) => profile.id), isNot(contains(namespace)));

    await Hive.close();
    Hive.init(profilelessPath);
    final reopened = await _following();
    final topic = (await reopened.getById(_topic))!;
    expect(topic.profileId, namespace);
    expect(topic.name, 'Cats');
    expect(topic.query, 'cat_fixture');
    expect(topic.autoUpdateEnabled, isFalse);
    expect(
      followingTopicBackupProfile(topic, []),
      topics.records.single.profile,
    );
    final folder = (await reopened.getOrganization()).folders.single;
    expect(folder.id, _folder);
    expect(folder.name, 'Fixture topics');
    expect(folder.searchIds, [_topic]);

    await Hive.close();
    Hive.init(work.path);
    final repository = await _following();
    final importer = FollowingTopicImportService(repository: repository);
    await importer.replace(topics, profiles: profiles);
    await TopicFeedImportService(repository: repository)
        .replace(feeds, profiles: profiles);
    await _expectFollowing(repository);
    for (var i = 0; i < 2; i++) {
      await Hive.close();
      Hive.init(work.path);
      await _expectFollowing(await _following());
    }
    await _expectSqlite(
      staged.pathFor('sources/downloads/data.db'),
      staged.pathFor('sources/search_histories/data.db'),
    );
  });

  test(
    'released orphan retains its missing profile ID on cold reopen',
    () async {
      await File('$_fixture/missing-profile/orphan_fixture.hive')
          .copy(p.join(work.path, followingTopicsHiveFileName));
      for (var i = 0; i < 3; i++) {
        Hive.init(work.path);
        final topic = (await (await _following()).getById(_topic))!;
        expect(topic.profileId, _missing);
        expect(topic.query, 'missing_profile_fixture');
        expect(topic.createdAt, _date);
        await Hive.close();
      }
    },
  );

  for (final failCommit in [false, true]) {
    test(
      failCommit
          ? 'released package rolls back every source after all nine durable writes'
          : 'released package applies all nine sources and survives two cold reopens',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        const diskSpace = MethodChannel('disk_space_2');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(diskSpace, (_) async => 100000.0);
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          messenger.setMockMethodCallHandler(diskSpace, null);
        });
        final fs = _PackageFileSystem(work.path);
        final journal = ImportJournalStore(
          fs: fs,
          rootPath: p.join(work.path, 'import_transactions'),
        );
        await Directory(p.join(work.path, 'data')).create();
        ProviderContainer? app;
        Future<void> close() async {
          final closing = app;
          app = null;
          final topics = closing?.read(
            followingTopicRepositoryProvider.notifier,
          );
          closing?.dispose();
          await topics?.closeFuture;
          await Hive.close();
        }

        addTearDown(close);
        app = await _openDestination(fs);
        if (failCommit) {
          await _seedDestination(app!, fs);
          await _expectLocalDestination(app!, fs);
        }
        // The listener keeps the real auto-dispose flow alive across preflight,
        // plan edits and the transaction.
        final listener = app!.listen(importFlowProvider, (_, _) {});
        final flow = app!.read(importFlowProvider.notifier);
        await flow.load('$_fixture/released.bsexport');
        var state = app!.read(importFlowProvider);
        expect(state.status, ImportFlowStatus.review, reason: '${state.error}');
        for (final source in state.resolved!.sources) {
          flow.replaceSource(source.copyWith(action: ImportAction.replace));
        }
        await flow.previewComplete;
        flow.acknowledgeWarnings(true);
        state = app!.read(importFlowProvider);
        final validated = state.preflight!.validatedPlan;
        expect(validated, isNotNull, reason: '${state.preflight!.errors}');
        expect(
          validated!.plan.sources.map((source) => source.id).toSet(),
          _packageSourceIds,
        );
        expect(
          validated.plan.sources.map((source) => source.action).toSet(),
          {ImportAction.replace},
        );
        expect(
          state.profileMappings
              .map((mapping) => (mapping.profileId, mapping.providedByImport))
              .toSet(),
          {(_primary, true), (_secondary, true)},
        );

        fs.failCommit = failCommit;
        await flow.apply(null);
        state = app!.read(importFlowProvider);
        if (failCommit) {
          expect(state.status, ImportFlowStatus.error);
          expect(state.error, isA<_CommitInterrupted>());
          expect(fs.durableSourcesBeforeFault.toSet(), _packageSourceIds);
          await _expectLocalDestination(app!, fs);
        } else {
          expect(
            state.status,
            ImportFlowStatus.complete,
            reason: '${state.error}',
          );
          expect(state.bookmarkRefreshFailed, isFalse);
          await _expectImportedDestination(app!, fs);
        }
        expect(await journal.pending(), isEmpty);
        listener.close();
        for (var i = 0; i < 2; i++) {
          await close();
          app = await _openDestination(fs);
          if (failCommit) {
            await _expectLocalDestination(app!, fs);
          } else {
            await _expectImportedDestination(app!, fs);
          }
          expect(await journal.pending(), isEmpty);
        }
        await close();
      },
    );
  }
}

const _packageSourceIds = {
  'profiles',
  'settings',
  'bookmarks',
  'favorite_tags',
  'blacklisted_tags',
  followingTopicsBackupSourceId,
  topicFeedsBackupSourceId,
  'downloads',
  'search_histories',
};

const _archive = '550e8400-e29b-41d4-a716-446655440000';
const _shared = '550e8400-e29b-41d4-a716-446655440001';
const _emptyFolder = '550e8400-e29b-41d4-a716-446655440002';
const _localProfile = '550e8400-e29b-41d4-a716-446655440041';
const _localTopic = '550e8400-e29b-41d4-a716-446655440042';
const _localFeed = '550e8400-e29b-41d4-a716-446655440043';
const _localGroup = '550e8400-e29b-41d4-a716-446655440044';

Future<ProviderContainer> _openDestination(_PackageFileSystem fs) async {
  Hive.init(fs.root);
  final settings = SettingsRepositoryHive(Hive.openBox<dynamic>('settings'));
  final initial = (await settings.load().run()).fold(
    (_) => Settings.defaultSettings,
    (value) => value,
  );
  final profiles = HiveBooruConfigRepository(
    box: await Hive.openBox<String>('booru_configs'),
  );
  final initialProfiles = await profiles.getAll();
  return ProviderContainer(
    overrides: [
      loggerProvider.overrideWithValue(AppLogger()),
      appFileSystemProvider.overrideWithValue(fs),
      appVersionProvider.overrideWithValue(null),
      deviceInfoProvider.overrideWithValue(const DeviceInfo()),
      analyticsProvider.overrideWith((ref) => null),
      booruEngineRegistryProvider.overrideWith((ref) => BooruEngineRegistry()),
      booruConfigRepoProvider.overrideWithValue(profiles),
      booruConfigProvider.overrideWith(
        () => BooruConfigNotifier(initialConfigs: initialProfiles),
      ),
      settingsRepoProvider.overrideWithValue(settings),
      settingsNotifierProvider.overrideWith(() => SettingsNotifier(initial)),
      bookmarkRepositoryFactoryProvider.overrideWithValue(
        HiveBookmarkRepositoryFactory(fs: fs),
      ),
      bookmarkGroupRepositoryFactoryProvider.overrideWithValue(
        const HiveBookmarkGroupRepositoryFactory(),
      ),
      favoriteTagRepositoryFactoryProvider.overrideWithValue(
        const HiveFavoriteTagRepositoryFactory(),
      ),
      globalBlacklistedTagRepositoryFactoryProvider.overrideWithValue(
        HiveGlobalBlacklistedTagRepositoryFactory(path: fs.root),
      ),
    ],
  );
}

Future<void> _expectImportedDestination(
  ProviderContainer app,
  _PackageFileSystem fs,
) async {
  final profiles = {
    for (final entry in await app.read(booruConfigRepoProvider).getAll())
      entry.id: entry,
  };
  expect(profiles.keys.toSet(), {_primary, _secondary});
  expect(profiles[_primary]!.url, 'https://gelbooru.example/board/');
  expect(profiles[_secondary]!.url, 'https://danbooru.example/');
  final settings = await _readSettings(app);
  expect(settings.currentBooruConfigId, profiles[_primary]!.id);
  expect(settings.booruConfigIdOrderList, [_secondary, _primary]);
  expect(settings.autoFocusSearchBar, isFalse);
  expect(settings.safeMode, isTrue);

  final bookmarks = await _bookmarks(app);
  final ids = {for (final post in bookmarks) post.postId: post.id};
  expect(ids.keys.toSet(), {42, 67});
  expect(ids.values.toSet(), {0, 1});
  expect(bookmarks.map((post) => post.post.origin.profileIdHint).toSet(), {
    _primary,
  });
  expect(bookmarks.map((post) => post.post.origin.sourceHost).toSet(), {
    'gelbooru.example/board',
  });
  final groups = {
    for (final group in await (await app.read(
      bookmarkGroupRepoProvider.future,
    )).getGroups())
      group.id: group,
  };
  final archive = groups[_archive]!;
  final parent = groups[archive.parentGroupId]!;
  expect(parent.id, isNot(_archive));
  expect(parent.name, 'Folder');
  expect(parent.parentGroupId, isNull);
  expect(groups[_emptyFolder]!.parentGroupId, parent.id);
  expect(groups[_emptyFolder]!.bookmarkIds, isEmpty);
  expect(archive.bookmarkIds, {ids[42], ids[67]});
  expect(groups[_shared]!.bookmarkIds, {ids[42]});
  expect(groups[defaultBookmarkGroupId]!.bookmarkIds, {ids[67]});
  expect(archive.addedAt, {
    for (final post in bookmarks) post.id: post.createdAt,
  });

  final favorite = (await (await app.read(
    favoriteTagRepoProvider.future,
  )).getAll()).single;
  expect(favorite.name, 'artist_fixture');
  expect(favorite.labels, ['synthetic']);
  final rule = (await (await app.read(
    globalBlacklistedTagRepoProvider.future,
  )).getBlacklist()).single;
  expect(rule.id, 9);
  expect(rule.name, 'excluded_fixture');
  expect(rule.isActive, isFalse);

  await _expectFollowing(
    await app.read(followingTopicRepositoryProvider.future),
  );
  await _expectSqlite(
    await getDownloadsDbPath(fs),
    await getSearchHistoryDbPath(fs),
  );
}

Future<void> _seedDestination(
  ProviderContainer app,
  _PackageFileSystem fs,
) async {
  final profile = BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: BooruType.danbooru,
      url: 'https://local.example/',
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': _localProfile,
  });
  await app.read(booruConfigRepoProvider).addAll([profile]);
  await app.read(booruConfigProvider.notifier).fetch();
  await app
      .read(settingsNotifierProvider.notifier)
      .replaceSettings(
        Settings.defaultSettings.copyWith(
          currentBooruConfigId: _localProfile,
          booruConfigIdOrders: _localProfile,
          autoFocusSearchBar: true,
          safeMode: false,
        ),
      );
  final store = unifiedBookmarkStorage(
    await app.read(bookmarkRepoProvider.future),
  )!;
  final localId = (await store.reserveIds(1)).single;
  final post = PostBookmark(
    id: localId,
    createdAt: _date,
    updatedAt: _date,
    thumbnailUrl: 'https://local.example/thumb.jpg',
    sampleUrl: 'https://local.example/sample.jpg',
    originalUrl: 'https://local.example/original.jpg',
    sourceUrl: 'https://local.example/posts/93',
    booruId: BooruType.danbooru.id,
    width: 100,
    height: 100,
    md5: '',
    tags: const {'local_tag'},
    realSourceUrl: null,
    format: 'jpg',
    imageUrlResolver: const DefaultImageUrlResolver(),
    postId: 93,
    metadata: const {},
  );
  await store.commitOrganization(
    records: [post],
    groups: [
      BookmarkGroup(
        id: _localGroup,
        name: 'Local archive',
        bookmarkIds: {localId},
        addedAt: {localId: _date},
      ),
    ],
  );
  await (await app.read(favoriteTagRepoProvider.future)).create(
    name: 'local_favorite',
    labels: ['local'],
  );
  await (await app.read(globalBlacklistedTagRepoProvider.future))
      .addTag('local_block');
  final following = await app.read(followingTopicRepositoryProvider.future);
  await following.create(
    id: _localTopic,
    profileId: _localProfile,
    query: 'local_topic',
    name: 'Local topic',
    createdAt: _date,
  );
  await following.replaceOrganization(
    TopicOrganization(folders: const [], homeSearchIds: const [_localTopic]),
  );
  await following.saveFeed(
    id: _localFeed,
    profileId: _localProfile,
    name: 'Local feed',
    queries: ['local_feed_member'],
  );

  final downloadsDb = sqlite3.open(await getDownloadsDbPath(fs));
  try {
    final downloads = DownloadRepositorySqlite(downloadsDb)..initialize();
    final task = await downloads.createTask(
      DownloadOptions(
        path: '/synthetic/local',
        skipIfExists: true,
        quality: 'original',
        perPage: 16,
        concurrency: 1,
        tags: SearchTagSet.fromList(const ['local_download']),
      ),
    );
    await downloads.createSavedTask(task, 'Local saved download');
  } finally {
    downloadsDb.close();
  }
  final history = SearchHistoryRepositorySqlite(
    db: sqlite3.open(await getSearchHistoryDbPath(fs)),
  )..initialize();
  try {
    await history.addHistory(
      'local_history',
      queryType: QueryType.simple,
      booruTypeName: BooruType.danbooru.name,
      siteUrl: profile.url,
    );
  } finally {
    history.close();
  }
}

Future<void> _expectLocalDestination(
  ProviderContainer app,
  _PackageFileSystem fs,
) async {
  final profile = (await app.read(booruConfigRepoProvider).getAll()).single;
  expect(profile.id, _localProfile);
  expect(profile.url, 'https://local.example/');
  final settings = await _readSettings(app);
  expect(settings.currentBooruConfigId, profile.id);
  expect(settings.booruConfigIdOrderList, [profile.id]);
  expect(settings.autoFocusSearchBar, isTrue);
  expect(settings.safeMode, isFalse);

  final post = (await _bookmarks(app)).single;
  expect(post.id, 0);
  expect(post.postId, 93);
  expect(post.tags, {'local_tag'});
  final groups = await (await app.read(bookmarkGroupRepoProvider.future))
      .getGroups();
  expect(groups.map((group) => group.id).toSet(), {
    _localGroup,
    defaultBookmarkGroupId,
  });
  final archive = groups.singleWhere((group) => group.id == _localGroup);
  expect(archive.name, 'Local archive');
  expect(archive.bookmarkIds, {post.id});
  expect(archive.addedAt, {post.id: _date});
  expect(
    (await (await app.read(
      favoriteTagRepoProvider.future,
    )).getAll()).single.name,
    'local_favorite',
  );
  expect(
    (await (await app.read(
      globalBlacklistedTagRepoProvider.future,
    )).getBlacklist()).single.name,
    'local_block',
  );

  final following = await app.read(followingTopicRepositoryProvider.future);
  expect((await following.getOrganization()).homeSearchIds, [_localTopic]);
  final topic = (await following.getById(_localTopic))!;
  expect(topic.query, 'local_topic');
  expect(topic.profileId, profile.id);
  final feed = (await following.getFeeds()).single;
  expect(feed.id, _localFeed);
  expect(feed.profileId, profile.id);
  final member = (await following.getById(feed.sourceIds.single))!;
  expect(member.query, 'local_feed_member');
  expect(member.profileId, profile.id);
  expect((await following.getAll()).map((topic) => topic.id).toSet(), {
    _localTopic,
    member.id,
  });

  final downloadsDb = sqlite3.open(await getDownloadsDbPath(fs));
  try {
    final task = (await (DownloadRepositorySqlite(
      downloadsDb,
    )..initialize()).getSavedTasks()).single;
    expect(task.name, 'Local saved download');
    expect(task.task.path, '/synthetic/local');
  } finally {
    downloadsDb.close();
  }
  final history = SearchHistoryRepositorySqlite(
    db: sqlite3.open(await getSearchHistoryDbPath(fs)),
  )..initialize();
  try {
    final row = (await history.getHistories()).single;
    expect(row.query, 'local_history');
    expect(row.siteUrl, profile.url);
  } finally {
    history.close();
  }
}

Future<Settings> _readSettings(ProviderContainer app) async =>
    (await app.read(settingsRepoProvider).load().run()).fold(
      (error) => throw StateError('$error'),
      (settings) => settings,
    );

Future<List<PostBookmark>> _bookmarks(ProviderContainer app) async =>
    (await unifiedBookmarkStorage(
      await app.read(bookmarkRepoProvider.future),
    )!.readAll()).cast<PostBookmark>();

class _CommitInterrupted implements Exception {}

class _PackageFileSystem extends IoFileSystem {
  _PackageFileSystem(this.root);

  final String root;
  var failCommit = false;
  List<String> durableSourcesBeforeFault = const [];

  @override
  Future<String> getAppStoragePath() async => root;

  @override
  Future<String> getTemporaryPath() async => root;

  @override
  Future<void> writeString(
    String path,
    String content, {
    bool flush = false,
  }) async {
    if (failCommit && p.basename(path) == 'journal.json.tmp') {
      final candidate = ImportJournal.fromJson(
        jsonDecode(content) as Map<String, dynamic>,
      );
      if (candidate.state == ImportJournalState.committed) {
        // Inspect the previous durable frame before interrupting publication.
        final previous = ImportJournal.fromJson(
          jsonDecode(await readString(p.join(p.dirname(path), 'journal.json')))
              as Map<String, dynamic>,
        );
        expect(previous.state, ImportJournalState.applied);
        durableSourcesBeforeFault = previous.completedSourceIds;
        failCommit = false;
        throw _CommitInterrupted();
      }
    }
    await super.writeString(path, content, flush: flush);
  }
}
