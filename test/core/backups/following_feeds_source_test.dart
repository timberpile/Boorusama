import 'dart:convert';

import 'package:boorusama/core/backups/sources/following_feed_backup_data.dart';
import 'package:boorusama/core/backups/sources/following_feeds_source.dart';
import 'package:boorusama/core/backups/sources/pinned_searches_source.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/data/providers.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shelf/shelf.dart' as shelf;

import '../search/subscriptions/subscription_test_utils.dart';

void main() {
  test(
    'exports feed queries in member order separately from independent pins',
    () async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.profiles.addAll([_profile]);
      await harness.repository.create(profileId: 4, query: 'bird', name: null);
      await harness.repository.saveFeed(
        profileId: 4,
        name: 'Animals',
        queries: ['dog', 'cat'],
        id: _id,
      );

      final feedPayload = await _export(harness.feedSource, 'following_feeds');
      final pinPayload = await _export(harness.pinSource, 'pinned_searches');
      expect(feedPayload['source'], 'following_feeds');
      expect(pinPayload['source'], 'pinned_searches');
      expect(feedPayload['version'], 1);
      expect(pinPayload['version'], 1);
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
      profileId: 4,
      name: 'Animals',
      queries: ['cat'],
    );
    await harness.repository.delete(feed.sourceIds.single);

    await expectLater(harness.feedSource.dataGetter(), throwsStateError);
  });

  test(
    'imports a matching feed definition without changing an independent pin',
    () async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.profiles.addAll([_profile]);
      final pin = await harness.repository.create(
        profileId: 4,
        query: 'cat',
        name: 'Pinned cat',
      );
      await harness.repository.saveFeed(
        profileId: 4,
        name: 'Old',
        queries: ['cat'],
        id: _id,
      );
      final data = FollowingFeedBackupData(
        feeds: [
          FollowingFeedBackupRecord(
            id: _id,
            name: 'New',
            position: 0,
            queries: const ['cat', 'dog'],
            profile: const BackupProfileReference(
              id: 4,
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
      expect(await harness.repository.getById(pin.id), pin);
    },
  );
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
  'id': 4,
  'booruIdHint': BooruType.danbooru.id,
  'url': 'https://example.test',
  'name': 'Example',
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
        searchSubscriptionRepositoryProvider.overrideWith(
          () => _RepositoryNotifier(repository),
        ),
      ],
    );
  }

  final repository = memorySubscriptionRepository();
  final profiles = HiveBooruConfigRepository(box: _ProfileBox());
  late final ProviderContainer container;

  FollowingFeedsBackupSource get feedSource =>
      container.read(followingFeedsBackupSourceProvider)
          as FollowingFeedsBackupSource;
  PinnedSearchesBackupSource get pinSource =>
      container.read(pinnedSearchesBackupSourceProvider)
          as PinnedSearchesBackupSource;
}

class _RepositoryNotifier extends SearchSubscriptionRepositoryNotifier {
  _RepositoryNotifier(this.repository);
  final SearchSubscriptionRepository repository;
  @override
  Future<SearchSubscriptionRepository> build() async => repository;
}

class _ProfileBox implements Box<String> {
  final _items = <int, String>{};
  @override
  Iterable<dynamic> get keys => _items.keys;
  @override
  String? get(dynamic key, {String? defaultValue}) =>
      _items[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, String value) async {
    _items[key as int] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
