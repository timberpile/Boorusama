import 'dart:io';

import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/sources/following_topic_backup_codec.dart';
import 'package:boorusama/core/backups/sources/following_topic_import_service.dart';
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
  HiveFollowingTopicRepository repository, {
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
  late Directory work;
  setUp(() async {
    work = await Directory.systemTemp.createTemp('released-auxiliary-fixture-');
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

  test('released package stages all domains and imports Following with profile bindings', () async {
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
    Hive.init(work.path);
    final repository = await _following();
    final importer = FollowingTopicImportService(repository: repository);
    expect(importer.preview(topics, profiles: []).unmatchedRecordIds, {_topic});
    await expectLater(
      importer.replace(topics, profiles: []),
      throwsA(isA<UnmatchedFollowingTopicProfilesException>()),
    );
    expect(await repository.getAll(), isEmpty);
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
}
