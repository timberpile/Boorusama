import 'package:boorusama/core/backups/sources/following_feed_backup_data.dart';
import 'package:boorusama/core/backups/sources/following_feed_import_service.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_hive_object.dart';
import 'package:flutter_test/flutter_test.dart';

import '../search/subscriptions/subscription_test_utils.dart';

void main() {
  test(
    'replaces changed queries and preserves an unchanged source state',
    () async {
      final repository = memorySubscriptionRepository();
      final previous = await repository.saveFeed(
        profileId: 4,
        name: 'Old',
        queries: ['cat', 'dog'],
        id: _id(0),
      );
      final cat = (await repository.getAll()).singleWhere(
        (s) => s.query == 'cat',
      );
      await repository.recordRefreshFailure(
        cat.id,
        expectedCreatedAt: cat.createdAt,
        attemptedAt: DateTime.utc(2026),
        kind: SearchRefreshErrorKind.network,
      );

      final result = await FollowingFeedImportService(repository: repository)
          .apply(
            _data([
              _record(0, name: 'New', queries: ['cat', 'bird']),
            ]),
            profiles: [_profile(4)],
          );
      final feed = (await repository.getFeeds()).single;
      final searches = {
        for (final search in await repository.getAll()) search.id: search,
      };
      expect(result.importedCount, 1);
      expect(feed.id, previous.id);
      expect(feed.name, 'New');
      expect(feed.sourceIds.map((id) => searches[id]!.query).toList(), [
        'cat',
        'bird',
      ]);
      expect(feed.sourceIds.first, cat.id);
      expect(searches[cat.id]!.lastErrorKind, SearchRefreshErrorKind.network);
      expect(searches.values.map((s) => s.query), isNot(contains('dog')));
    },
  );

  test(
    'keeps same-named feeds separate and repeated imports idempotent',
    () async {
      final repository = memorySubscriptionRepository();
      final service = FollowingFeedImportService(repository: repository);
      final data = _data([
        _record(0, queries: ['cat']),
        _record(1, queries: ['dog'], position: 1),
      ]);

      final first = await service.apply(data, profiles: [_profile(4)]);
      final second = await service.apply(data, profiles: [_profile(4)]);
      expect(first.importedCount, 2);
      expect(second.importedCount, 0);
      expect(second.alreadyExistedCount, 2);
      expect((await repository.getFeeds()).map((feed) => feed.id), [
        _id(0),
        _id(1),
      ]);
    },
  );

  test('rejects a wrong-owner UUID before changing another feed', () async {
    final repository = memorySubscriptionRepository();
    await repository.saveFeed(
      profileId: 9,
      name: 'Other profile',
      queries: ['bird'],
      id: _id(1),
    );
    final before = await repository.getFeeds();
    final service = FollowingFeedImportService(repository: repository);
    await expectLater(
      service.apply(
        _data([_record(0), _record(1)]),
        profiles: [_profile(4)],
      ),
      throwsA(isA<FeedBackupIdConflictException>()),
    );
    expect(await repository.getFeeds(), before);
  });

  test('previews ambiguous profiles and skips only approved records', () async {
    final repository = memorySubscriptionRepository();
    final service = FollowingFeedImportService(repository: repository);
    final missing = _record(1, profileId: 99);
    final data = _data([_record(0), missing]);
    final profiles = [_profile(4), _profile(9), _profile(10)];
    expect(service.preview(data, profiles: profiles).unmatchedRecordIds, {
      missing.id,
    });
    await expectLater(
      service.apply(data, profiles: profiles),
      throwsA(isA<UnmatchedFollowingFeedProfilesException>()),
    );
    expect(await repository.getFeeds(), isEmpty);
    final result = await service.apply(
      data,
      profiles: profiles,
      allowMissingProfiles: true,
    );
    expect(result.skippedProfileCount, 1);
    expect((await repository.getFeeds()).single.id, _id(0));
  });

  test(
    'inserts imported positions while keeping local relative order',
    () async {
      final repository = memorySubscriptionRepository();
      for (final index in [0, 1, 2]) {
        await repository.saveFeed(
          profileId: 4,
          name: 'Local $index',
          queries: ['local_$index'],
          id: _id(index),
        );
      }
      await FollowingFeedImportService(repository: repository).apply(
        _data([
          _record(2),
          _record(3, position: 1),
          _record(4, position: 1),
        ]),
        profiles: [_profile(4)],
      );
      final feeds = await repository.getFeeds();
      expect(feeds.map((feed) => feed.id), [
        _id(2),
        _id(3),
        _id(4),
        _id(0),
        _id(1),
      ]);
      expect(feeds.map((feed) => feed.position), [0, 1, 2, 3, 4]);
    },
  );

  test('a failed replacement retains the previous feed and sources', () async {
    final sourceBox = _FailingSubscriptionBox();
    final repository = HiveSearchSubscriptionRepository(
      box: sourceBox,
      organizationBox: MemoryBox<dynamic>(),
    );
    final old = await repository.saveFeed(
      profileId: 4,
      name: 'Old',
      queries: ['cat'],
      id: _id(0),
    );
    final oldSearches = await repository.getAll();
    sourceBox.failNextPutAll = true;

    await expectLater(
      FollowingFeedImportService(repository: repository).apply(
        _data([
          _record(0, name: 'New', queries: ['cat', 'bird']),
        ]),
        profiles: [_profile(4)],
      ),
      throwsStateError,
    );
    expect((await repository.getFeeds()).single, old);
    expect(await repository.getAll(), oldSearches);
  });

  test('a failed order write restores every previous position', () async {
    final organizationBox = _FailingOrganizationBox();
    final repository = HiveSearchSubscriptionRepository(
      box: MemorySubscriptionBox(),
      organizationBox: organizationBox,
    );
    final first = await repository.saveFeed(
      profileId: 4,
      name: 'First',
      queries: ['cat'],
    );
    final second = await repository.saveFeed(
      profileId: 4,
      name: 'Second',
      queries: ['dog'],
    );
    final before = await repository.getFeeds();
    organizationBox.failNextPutAll = true;

    await expectLater(
      repository.setFeedOrder(4, [second.id, first.id]),
      throwsStateError,
    );
    expect(await repository.getFeeds(), before);
  });

  test(
    'a failed order write restores the replaced feed and member searches',
    () async {
      final organizationBox = _FailingOrganizationBox();
      final repository = HiveSearchSubscriptionRepository(
        box: MemorySubscriptionBox(),
        organizationBox: organizationBox,
      );
      final saved = await repository.saveFeed(
        profileId: 4,
        name: 'Old',
        queries: ['cat'],
        id: _id(0),
      );
      final old = saved.copyWith(
        posts: [
          feedPostSnapshotFromPost(TestSearchPost(42, DateTime.utc(2026))),
        ],
      );
      await repository.restoreFeeds(4, [old]);
      final beforeSearches = await repository.getAll();
      organizationBox.failNextPutAll = true;

      await expectLater(
        FollowingFeedImportService(repository: repository).apply(
          _data([
            _record(0, name: 'New', queries: ['bird']),
          ]),
          profiles: [_profile(4)],
        ),
        throwsStateError,
      );
      expect((await repository.getFeeds()).single, old);
      expect(await repository.getAll(), beforeSearches);
    },
  );
}

class _FailingSubscriptionBox extends MemorySubscriptionBox {
  var failNextPutAll = false;

  @override
  Future<void> putAll(
    Map<dynamic, SearchSubscriptionHiveObject> entries,
  ) async {
    if (failNextPutAll) {
      failNextPutAll = false;
      throw StateError('Injected write failure');
    }
    await super.putAll(entries);
  }
}

class _FailingOrganizationBox extends MemoryBox<dynamic> {
  var failNextPutAll = false;

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async {
    if (failNextPutAll) {
      failNextPutAll = false;
      await put(entries.keys.first, entries.values.first);
      throw StateError('Injected partial write failure');
    }
    await super.putAll(entries);
  }
}

FollowingFeedBackupData _data(List<FollowingFeedBackupRecord> records) =>
    FollowingFeedBackupData(feeds: records);

FollowingFeedBackupRecord _record(
  int index, {
  String name = 'Animals',
  List<String> queries = const ['cat'],
  int position = 0,
  int profileId = 4,
}) => FollowingFeedBackupRecord(
  id: _id(index),
  name: name,
  queries: queries,
  position: position,
  profile: BackupProfileReference(
    id: profileId,
    booruType: 'danbooru',
    url: profileId == 99
        ? 'https://ambiguous.test/Posts'
        : 'https://example.test/Posts',
    name: 'Remote',
  ),
);

String _id(int index) => '550e8400-e29b-41d4-a716-44665544000$index';

BooruConfig _profile(int id) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'booruIdHint': BooruType.danbooru.id,
  'url': id == 9 || id == 10
      ? 'https://ambiguous.test/Posts'
      : 'https://example.test/Posts',
  'name': 'Local',
});
