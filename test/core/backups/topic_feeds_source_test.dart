import 'dart:convert';

import 'package:boorusama/core/backups/preparation/preparation_pipeline.dart';
import 'package:boorusama/core/backups/sources/topic_feed_backup_data.dart';
import 'package:boorusama/core/backups/sources/topic_feeds_source.dart';
import 'package:boorusama/core/backups/sources/following_topics_source.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/backups/widgets/search_backup_missing_profiles_dialog.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/search/following_topics/src/data/providers.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:i18n/i18n.dart';
import 'package:shelf/shelf.dart' as shelf;

import '../search/following_topics/topic_test_utils.dart';

void main() {
  test(
    'exports feed queries in member order separately from independent topics',
    () async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.profiles.addAll([_profile]);
      await harness.repository.create(
        profileId: '00000000-0000-4000-8000-000000000004',
        query: 'bird',
        name: null,
      );
      await harness.repository.saveFeed(
        profileId: '00000000-0000-4000-8000-000000000004',
        name: 'Animals',
        queries: ['dog', 'cat'],
        id: _id,
      );

      final feedPayload = await _export(harness.feedSource, 'following_feeds');
      final pinPayload = await _export(harness.pinSource, 'pinned_searches');
      expect(feedPayload['source'], 'following_feeds');
      expect(pinPayload['source'], 'pinned_searches');
      expect(feedPayload['version'], 1);
      expect(pinPayload['version'], 2);
      final feedRows = feedPayload['data'] as List;
      expect(feedRows, hasLength(1));
      expect(feedRows.single['kind'], 'feed');
      expect(feedRows.single['queries'], ['dog', 'cat']);
      expect(feedRows.single.keys, isNot(contains('sourceIds')));
      expect(feedRows.single.keys, isNot(contains('posts')));
      final pinRows = pinPayload['data'] as List;
      expect(pinRows.map((row) => row['kind']), ['search', 'organization']);
      expect(pinRows.first['query'], 'bird');
      expect(
        harness
            .feedSource
            .exportResultBuilder!(await harness.feedSource.dataGetter())
            .feedCount,
        1,
      );
    },
  );

  test(
    'modern folder feeds export only as Topics, not duplicate feed definitions',
    () async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.profiles.addAll([_profile]);
      final topic = await harness.repository.create(
        profileId: _profile.id,
        query: 'bird',
        name: null,
      );
      const folderId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      await harness.repository.replaceOrganization(
        TopicOrganization(
          folders: [
            TopicFolder(
              id: folderId,
              name: 'Birdwatching',
              searchIds: [topic.id],
              feedEnabled: true,
            ),
          ],
        ),
      );
      await harness.repository.ensureFolderFeed(folderId);

      final legacy = await harness.feedSource.dataGetter();
      expect(legacy.feeds, isEmpty);
      final topics = await harness.pinSource.dataGetter();
      expect(topics.records, hasLength(1));
      expect(topics.folders.single.feedEnabled, isTrue);
    },
  );

  test('exports and imports an empty feed list', () async {
    final harness = _Harness();
    addTearDown(harness.container.dispose);
    final payload = await _export(harness.feedSource, 'following_feeds');
    expect(payload['data'], isEmpty);
    final data = harness.feedSource.handler.parse(
      harness.feedSource.converter.decode(data: jsonEncode(payload)),
    );
    expect(data.feeds, isEmpty);
  });

  test('fails export when a feed member search is missing', () async {
    final harness = _Harness();
    addTearDown(harness.container.dispose);
    await harness.profiles.addAll([_profile]);
    final feed = await harness.repository.saveFeed(
      profileId: '00000000-0000-4000-8000-000000000004',
      name: 'Animals',
      queries: ['cat'],
    );
    await harness.repository.delete(feed.sourceIds.single);

    await expectLater(harness.feedSource.dataGetter(), throwsStateError);
  });

  test(
    'imports a matching feed definition without changing an independent topic',
    () async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.profiles.addAll([_profile]);
      final topic = await harness.repository.create(
        profileId: '00000000-0000-4000-8000-000000000004',
        query: 'cat',
        name: 'Pinned cat',
      );
      await harness.repository.saveFeed(
        profileId: '00000000-0000-4000-8000-000000000004',
        name: 'Old',
        queries: ['cat'],
        id: _id,
      );
      final data = TopicFeedBackupData(
        feeds: [
          TopicFeedBackupRecord(
            id: _id,
            name: 'New',
            position: 0,
            queries: const ['cat', 'dog'],
            profile: const BackupProfileReference(
              id: '00000000-0000-4000-8000-000000000004',
              booruType: 'danbooru',
              url: 'https://example.test',
              name: 'Example',
            ),
          ),
        ],
      );

      final result = await harness.feedSource.resultExecutor!(data, null);
      expect(result?.feedCount, 1);
      expect((await harness.repository.getFeeds()).single.name, 'New');
      expect(await harness.repository.getById(topic.id), topic);
    },
  );

  testWidgets(
    'shows the standalone feed warning and skips only unmatched feeds',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.profiles.addAll([_profile]);
      final context = await _pumpContext(tester, harness);
      final data = TopicFeedBackupData(
        feeds: [
          _record(
            _id,
            profileId: '00000000-0000-4000-8000-000000000004',
            url: 'https://example.test',
          ),
          _record(
            '550e8400-e29b-41d4-a716-446655440001',
            profileId: '00000000-0000-4000-8000-000000000009',
            url: 'https://missing.test',
            booruType: 'e621',
          ),
        ],
      );
      Object? error;
      final pending = harness.feedSource.resultExecutor!(data, context)
          .then<void>((_) {}, onError: (Object e) => error = e);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No matching profile for 1 topic feed. Those records will be skipped. Continue importing?',
        ),
        findsOneWidget,
      );
      expect(await harness.repository.getFeeds(), isEmpty);
      await tester.tap(find.text('Skip and import'));
      await tester.pumpAndSettle();
      await pending;
      expect(error, isNull);
      expect((await harness.repository.getFeeds()).single.id, _id);
    },
  );

  testWidgets('one dialog lists unmatched followed topics and feeds', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.container.dispose);
    final context = await _pumpContext(tester, harness);
    Object? error;
    final pending = confirmSearchBackupProfiles(
      unmatchedRecordIds: {'topic', 'feed1', 'feed2'},
      topicCount: 1,
      feedCount: 2,
      context: context,
    ).then<void>((_) {}, onError: (Object e) => error = e);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No matching profile for 1 topic and 2 topic feeds. Those records will be skipped. Continue importing?',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await pending;
    expect(error, isA<ImportCancelledException>());
  });

  testWidgets(
    'a newly matching UUID while the warning is open cancels before writes',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.profiles.addAll([_profile]);
      final context = await _pumpContext(tester, harness);
      final data = TopicFeedBackupData(
        feeds: [
          _record(
            _id,
            profileId: '00000000-0000-4000-8000-000000000063',
            url: 'https://example.test',
          ),
          _record(
            '550e8400-e29b-41d4-a716-446655440001',
            profileId: '00000000-0000-4000-8000-000000000009',
            url: 'https://missing.test',
            booruType: 'e621',
          ),
        ],
      );
      Object? error;
      final pending = harness.feedSource.resultExecutor!(data, context)
          .then<void>((_) {}, onError: (Object e) => error = e);
      await tester.pumpAndSettle();
      expect(find.text('Skip unmatched records?'), findsOneWidget);
      await harness.profiles.addAll([
        _profileWithId('00000000-0000-4000-8000-000000000063'),
      ]);
      await tester.tap(find.text('Skip and import'));
      await tester.pumpAndSettle();
      await pending;
      expect(error, isA<ImportCancelledException>());
      expect(await harness.repository.getFeeds(), isEmpty);
    },
  );
}

TopicFeedBackupRecord _record(
  String id, {
  required String profileId,
  required String url,
  String booruType = 'danbooru',
}) => TopicFeedBackupRecord(
  id: id,
  name: 'Animals',
  position: 0,
  queries: const ['cat'],
  profile: BackupProfileReference(
    id: profileId,
    booruType: booruType,
    url: url,
    name: 'Remote',
  ),
);

Future<BuildContext> _pumpContext(WidgetTester tester, _Harness harness) async {
  late BuildContext context;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: BooruLocalization(
        child: MaterialApp(
          builder: (context, child) =>
              MaterialUiCompatibilityBridge(child: child!),
          home: Builder(
            builder: (value) {
              context = value;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      ),
    ),
  );
  return context;
}

Future<Map<String, dynamic>> _export(
  dynamic source,
  String id,
) async {
  final response = await source.capabilities.server.export(
    shelf.Request('GET', Uri.parse('https://device.test/$id')),
  );
  return jsonDecode(await response.readAsString()) as Map<String, dynamic>;
}

const _id = '550e8400-e29b-41d4-a716-446655440000';

final _profile = BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': '00000000-0000-4000-8000-000000000004',
  'booruIdHint': BooruType.danbooru.id,
  'url': 'https://example.test',
  'name': 'Example',
});

BooruConfig _profileWithId(String id) => BooruConfig.fromJson({
  ..._profile.toJson(),
  'id': id,
});

class _Harness {
  _Harness() {
    container = ProviderContainer(
      overrides: [
        appVersionProvider.overrideWithValue(null),
        booruConfigRepoProvider.overrideWithValue(profiles),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: const []),
        ),
        followingTopicRepositoryProvider.overrideWith(
          () => _RepositoryNotifier(repository),
        ),
      ],
    );
  }

  final repository = memorySubscriptionRepository();
  final profiles = HiveBooruConfigRepository(box: _ProfileBox());
  late final ProviderContainer container;

  TopicFeedsBackupSource get feedSource =>
      container.read(topicFeedsBackupSourceProvider);
  FollowingTopicsBackupSource get pinSource =>
      container.read(followingTopicsBackupSourceProvider);
}

class _RepositoryNotifier extends FollowingTopicRepositoryNotifier {
  _RepositoryNotifier(this.repository);
  final FollowingTopicRepository repository;
  @override
  Future<FollowingTopicRepository> build() async => repository;
}

class _ProfileBox implements Box<String> {
  final _items = <String, String>{};
  @override
  Iterable<dynamic> get keys => _items.keys;
  @override
  String? get(dynamic key, {String? defaultValue}) =>
      _items[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, String value) async {
    _items[key as String] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
