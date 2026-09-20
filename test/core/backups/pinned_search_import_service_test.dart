import 'package:boorusama/core/backups/sources/pinned_search_backup_data.dart';
import 'package:boorusama/core/backups/sources/pinned_search_import_service.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../search/subscriptions/subscription_test_utils.dart';

void main() {
  test(
    'feed backups restore owned hidden queries separately and repeated imports preserve them',
    () async {
      final repository = memorySubscriptionRepository();
      final record = _record(0);
      final data = PinnedSearchBackupData(
        records: [record],
        feeds: [
          PinnedSearchFeedBackupRecord(
            id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            name: 'Animals',
            position: 0,
            queries: [record.query, 'dog'],
            profile: record.profile,
          ),
        ],
      );
      final service = PinnedSearchImportService(repository: repository);
      await service.apply(data, profiles: [_profile(9)]);
      await service.apply(data, profiles: [_profile(9)]);
      final feed = (await repository.getFeeds()).single;
      expect(feed.profileId, 9);
      expect(feed.posts, isEmpty);
      final subscriptions = await repository.getAll();
      expect(
        subscriptions.where((s) => feed.sourceIds.contains(s.id)).length,
        2,
      );
      expect(
        subscriptions.where((s) => !feed.sourceIds.contains(s.id)).length,
        1,
      );
      expect(subscriptions.every((s) => s.lastSuccessfulCheckAt == null), true);
      await repository.deleteFeed(feed.id);
      expect(
        feed.sourceIds,
        isNot(contains((await repository.getAll()).single.id)),
      );
    },
  );

  test(
    'same-named feeds keep distinct definitions after repeated import',
    () async {
      final repository = memorySubscriptionRepository();
      final profile = _record(0).profile;
      final data = PinnedSearchBackupData(
        records: const [],
        feeds: [
          PinnedSearchFeedBackupRecord(
            id: _id(10),
            name: 'Animals',
            position: 0,
            queries: const ['cat'],
            profile: profile,
          ),
          PinnedSearchFeedBackupRecord(
            id: _id(11),
            name: 'animals',
            position: 1,
            queries: const ['dog'],
            profile: profile,
          ),
        ],
      );
      final service = PinnedSearchImportService(repository: repository);

      await service.apply(data, profiles: [_profile(9)]);
      await service.apply(data, profiles: [_profile(9)]);

      final feeds = await repository.getFeeds();
      final searches = {
        for (final search in await repository.getAll()) search.id: search,
      };
      expect(feeds.map((feed) => feed.id), [_id(10), _id(11)]);
      expect(feeds.map((feed) => feed.name), ['Animals', 'animals']);
      expect(
        feeds.map((feed) => searches[feed.sourceIds.single]!.query),
        ['cat', 'dog'],
      );
    },
  );

  test('a feed ID collision with another profile keeps both feeds', () async {
    final repository = memorySubscriptionRepository();
    await repository.saveFeed(
      profileId: 4,
      name: 'Local',
      queries: ['bird'],
      id: _id(12),
    );
    final data = PinnedSearchBackupData(
      records: const [],
      feeds: [
        PinnedSearchFeedBackupRecord(
          id: _id(12),
          name: 'Animals',
          position: 0,
          queries: const ['cat'],
          profile: _record(0).profile,
        ),
      ],
    );
    final service = PinnedSearchImportService(repository: repository);

    await service.apply(data, profiles: [_profile(9)]);
    await service.apply(data, profiles: [_profile(9)]);

    final feeds = await repository.getFeeds();
    final searches = {
      for (final search in await repository.getAll()) search.id: search,
    };
    expect(feeds.length, 2);
    expect(feeds.first.id, _id(12));
    expect(feeds.first.profileId, 4);
    expect(feeds.last.profileId, 9);
    expect(searches[feeds.first.sourceIds.single]!.query, 'bird');
    expect(searches[feeds.last.sourceIds.single]!.query, 'cat');
  });

  test('folder imports remap profiles and remain idempotent', () async {
    final repository = memorySubscriptionRepository();
    final record = _record(0);
    final data = PinnedSearchBackupData(
      records: [record],
      folders: [
        PinnedSearchFolderBackupRecord(
          id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          name: 'Animals',
          position: 0,
          searchIds: [record.id],
        ),
        const PinnedSearchFolderBackupRecord(
          id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          name: 'Empty',
          position: 1,
          searchIds: [],
        ),
      ],
    );
    final service = PinnedSearchImportService(repository: repository);
    await service.apply(data, profiles: [_profile(9)]);
    await service.apply(data, profiles: [_profile(9)]);
    final folders = (await repository.getOrganization()).folders;
    expect(folders.length, 2);
    expect(folders.first.searchIds, [(await repository.getAll()).single.id]);
    expect(folders.last.searchIds, isEmpty);
  });

  test(
    'previews unmatched pins and feeds and rejects before any writes',
    () async {
      final repository = memorySubscriptionRepository();
      final service = PinnedSearchImportService(repository: repository);
      final missing = _record(1, profileId: 99);
      final data = PinnedSearchBackupData(
        records: [_record(0), missing],
        feeds: [
          PinnedSearchFeedBackupRecord(
            id: _id(8),
            name: 'Feed',
            position: 0,
            queries: const ['cat'],
            profile: missing.profile,
          ),
        ],
        folders: const [
          PinnedSearchFolderBackupRecord(
            id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            name: 'Empty',
            position: 0,
            searchIds: [],
          ),
        ],
      );
      final profiles = [_profile(4), _profile(5)];
      expect(service.preview(data, profiles: profiles).unmatchedRecordIds, {
        _id(1),
        _id(8),
      });
      expect(await repository.getAll(), isEmpty);
      await expectLater(
        service.apply(data, profiles: profiles),
        throwsA(isA<UnmatchedPinnedSearchProfilesException>()),
      );
      expect(await repository.getAll(), isEmpty);
      expect((await repository.getOrganization()).folders, isEmpty);
      expect(await repository.getFeeds(), isEmpty);
      final result = await service.apply(
        data,
        profiles: profiles,
        allowMissingProfiles: true,
      );
      expect(result.skippedProfileCount, 2);
      expect(
        (await repository.getOrganization()).folders.single.searchIds,
        isEmpty,
      );
    },
  );

  test('restores mixed profiles and mapped query IDs in saved order', () async {
    final repository = memorySubscriptionRepository();
    final existing = await repository.create(
      profileId: 9,
      query: _record(0).query,
      name: null,
      id: _id(9),
    );
    final dog = PinnedSearchBackupRecord(
      id: _id(1),
      name: null,
      query: 'dog',
      position: 0,
      profile: const PinnedSearchProfileReference(
        id: 99,
        booruType: 'danbooru',
        url: 'https://other.test',
        name: 'Other',
      ),
    );
    final data = PinnedSearchBackupData(
      records: [_record(0), dog, _record(2), _record(3)],
      homeSearchIds: [_id(3), _id(2)],
      folders: [
        PinnedSearchFolderBackupRecord(
          id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          name: 'Animals',
          position: 0,
          searchIds: [dog.id, _id(0)],
        ),
      ],
    );
    final service = PinnedSearchImportService(repository: repository);
    final profiles = [_profile(9), _profile(88, url: 'https://other.test')];
    await service.apply(data, profiles: profiles);
    final organization = await repository.getOrganization();
    expect(organization.folders.single.searchIds, [dog.id, existing.id]);
    expect(organization.homeSearchIds, [_id(3), _id(2)]);
    expect((await repository.getById(dog.id))!.profileId, 88);
    await service.apply(data, profiles: profiles);
    expect(await repository.getOrganization(), organization);
  });

  test(
    'pin-only restore preserves existing folders and appends new Home pins',
    () async {
      final repository = memorySubscriptionRepository();
      await repository.create(
        profileId: 4,
        query: _record(0).query,
        name: null,
        id: _id(0),
      );
      await repository.create(
        profileId: 4,
        query: 'local',
        name: null,
        id: _id(9),
      );
      await repository.replaceOrganization(
        SearchOrganization(
          folders: [
            SharedSearchFolder(
              id: 'folder',
              name: 'Local',
              searchIds: [_id(0)],
            ),
          ],
          homeSearchIds: [_id(9)],
        ),
      );
      await PinnedSearchImportService(repository: repository).apply(
        PinnedSearchBackupData(records: [_record(0), _record(1)]),
        profiles: [_profile(4)],
      );
      final organization = await repository.getOrganization();
      expect(organization.folders.single.searchIds, [_id(0)]);
      expect(organization.homeSearchIds, [_id(9), _id(1)]);
    },
  );

  test(
    'appends pin-only imports after unlisted local pins with future timestamps',
    () async {
      final repository = memorySubscriptionRepository();
      await repository.create(
        profileId: 4,
        query: 'local',
        name: null,
        id: _id(9),
        createdAt: DateTime.utc(2100),
      );
      await PinnedSearchImportService(repository: repository).apply(
        PinnedSearchBackupData(records: [_record(0)]),
        profiles: [_profile(4)],
      );
      expect((await repository.getOrganization()).homeSearchIds, [
        _id(9),
        _id(0),
      ]);
    },
  );

  test(
    'merges imported destinations while retaining untouched local pins and folders',
    () async {
      final repository = memorySubscriptionRepository();
      for (final index in [0, 1, 2, 3]) {
        await repository.create(
          profileId: 4,
          query: _record(index).query,
          name: null,
          id: _id(index),
        );
      }
      await repository.replaceOrganization(
        SearchOrganization(
          folders: [
            SharedSearchFolder(
              id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
              name: 'Renamed',
              searchIds: [_id(0), _id(1)],
            ),
            SharedSearchFolder(id: 'empty', name: 'Empty', searchIds: const []),
          ],
          homeSearchIds: [_id(3), _id(2)],
        ),
      );
      final data = PinnedSearchBackupData(
        records: [_record(0), _record(2)],
        homeSearchIds: [_id(0)],
        folders: [
          const PinnedSearchFolderBackupRecord(
            id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            name: 'Original',
            position: 0,
            searchIds: [],
          ),
          PinnedSearchFolderBackupRecord(
            id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            name: 'Renamed',
            position: 1,
            searchIds: [_id(2)],
          ),
        ],
      );
      await PinnedSearchImportService(
        repository: repository,
      ).apply(data, profiles: [_profile(4)]);
      final organization = await repository.getOrganization();
      expect(organization.homeSearchIds, [_id(0), _id(3)]);
      expect(organization.folders.map((folder) => folder.name), [
        'Renamed',
        'Empty',
      ]);
      expect(organization.folders.first.searchIds, [_id(2), _id(1)]);
    },
  );

  final mappingCases = [
    (
      description: 'the matching ID before ambiguous URLs',
      profiles: [_profile(4), _profile(5)],
      expectedId: 4,
    ),
    (
      description: 'a unique URL when the original ID changed',
      profiles: [_profile(9)],
      expectedId: 9,
    ),
    (
      description: 'a unique URL when the original ID has another URL',
      profiles: [
        _profile(4, url: 'https://other.test'),
        _profile(9),
      ],
      expectedId: 9,
    ),
    (
      description: 'a unique URL when the original ID has another type',
      profiles: [
        _profile(4, type: BooruType.gelbooru),
        _profile(9),
      ],
      expectedId: 9,
    ),
    (
      description: 'no profile for an ambiguous URL',
      profiles: [_profile(5), _profile(9)],
      expectedId: null,
    ),
    (
      description: 'no profile for a missing URL',
      profiles: [_profile(4, url: 'https://other.test')],
      expectedId: null,
    ),
    (
      description: 'no profile for a different scheme',
      profiles: [_profile(4, url: 'http://example.test/Posts')],
      expectedId: null,
    ),
    (
      description: 'no profile for a different path',
      profiles: [_profile(4, url: 'https://example.test/posts')],
      expectedId: null,
    ),
    (
      description: 'no profile for a different type',
      profiles: [_profile(4, type: BooruType.gelbooru)],
      expectedId: null,
    ),
    (
      description: 'no profile when none are configured',
      profiles: <BooruConfig>[],
      expectedId: null,
    ),
  ];
  for (final c in mappingCases) {
    test('resolves ${c.description}', () async {
      final repository = memorySubscriptionRepository();
      final result = await PinnedSearchImportService(repository: repository)
          .apply(
            PinnedSearchBackupData(records: [_record(0)]),
            profiles: c.profiles,
            allowMissingProfiles: true,
          );
      expect(
        result,
        PinnedSearchImportResult(
          importedCount: c.expectedId == null ? 0 : 1,
          alreadyExistedCount: 0,
          skippedProfileCount: c.expectedId == null ? 1 : 0,
        ),
      );
      expect(
        (await repository.getAll()).map((pin) => pin.profileId),
        c.expectedId == null ? isEmpty : [c.expectedId],
      );
    });
  }

  test('appends after existing positions in stable imported order', () async {
    final repository = memorySubscriptionRepository();
    await repository.restoreForProfile(4, [
      SearchSubscription.create(
        id: _id(9),
        profileId: 4,
        query: 'existing',
        name: null,
        position: 8,
        createdAt: DateTime.utc(2026),
      ),
    ]);
    await PinnedSearchImportService(repository: repository).apply(
      PinnedSearchBackupData(
        records: [
          _record(2, position: 6),
          _record(0, position: 1),
          _record(1, position: 1),
        ],
      ),
      profiles: [_profile(4)],
    );
    final pins = await repository.getAll();
    expect(pins.map((pin) => pin.id), [_id(9), _id(0), _id(1), _id(2)]);
    expect(pins.map((pin) => pin.position), [8, 9, 10, 11]);
    expect(pins.map((pin) => pin.query), [
      'existing',
      'cat  tag_0',
      'cat  tag_1',
      'cat  tag_2',
    ]);
  });

  test(
    'preserves existing ID and normalized-query matches across repeated imports',
    () async {
      final repository = memorySubscriptionRepository();
      final existingId = await repository.create(
        profileId: 4,
        query: 'original',
        name: 'Local name',
        id: _id(0),
      );
      final existingQuery = await repository.create(
        profileId: 4,
        query: 'cat tag_1',
        name: null,
        id: _id(9),
      );
      final data = PinnedSearchBackupData(
        records: [_record(0), _record(1), _record(2)],
      );
      final service = PinnedSearchImportService(repository: repository);

      final first = await service.apply(data, profiles: [_profile(4)]);
      final afterFirst = await repository.getAll();
      final second = await service.apply(data, profiles: [_profile(4)]);

      expect(
        first,
        const PinnedSearchImportResult(
          importedCount: 1,
          alreadyExistedCount: 2,
          skippedProfileCount: 0,
        ),
      );
      expect(
        second,
        const PinnedSearchImportResult(
          importedCount: 0,
          alreadyExistedCount: 3,
          skippedProfileCount: 0,
        ),
      );
      expect(await repository.getAll(), afterFirst);
      expect(afterFirst.take(2), [existingId, existingQuery]);
      expect(afterFirst.last.id, _id(2));
    },
  );

  test(
    'reuses a query repeated inside an import only within its profile',
    () async {
      final repository = memorySubscriptionRepository();
      final result = await PinnedSearchImportService(repository: repository)
          .apply(
            PinnedSearchBackupData(
              records: [
                _record(0, query: 'cat  rating:safe'),
                _record(1, query: ' cat\trating:safe '),
                _record(2, query: 'cat rating:safe', profileId: 5),
              ],
            ),
            profiles: [_profile(4), _profile(5)],
          );
      expect(
        result,
        const PinnedSearchImportResult(
          importedCount: 2,
          alreadyExistedCount: 1,
          skippedProfileCount: 0,
        ),
      );
      expect((await repository.getAll()).map((pin) => pin.profileId), [4, 5]);
    },
  );

  for (final feedOwned in [false, true]) {
    test(
      'imports a fresh pin when its ID collides with ${feedOwned ? "a feed source" : "another profile"}',
      () async {
        final repository = memorySubscriptionRepository();
        final String collisionId;
        if (feedOwned) {
          final feed = await repository.saveFeed(
            profileId: 4,
            name: 'Feed',
            queries: ['original'],
          );
          collisionId = (await repository.getAll())
              .firstWhere((pin) => feed.sourceIds.contains(pin.id))
              .id;
        } else {
          collisionId = (await repository.create(
            profileId: 9,
            query: 'original',
            name: null,
            id: _id(0),
          )).id;
        }
        final original = await repository.getById(collisionId);
        final record = PinnedSearchBackupRecord(
          id: collisionId,
          name: null,
          query: 'cat',
          position: 0,
          profile: _record(0).profile,
        );
        final data = PinnedSearchBackupData(
          records: [record],
          folders: [
            PinnedSearchFolderBackupRecord(
              id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
              name: 'Animals',
              position: 0,
              searchIds: [collisionId],
            ),
          ],
        );
        final service = PinnedSearchImportService(repository: repository);
        final result = await service.apply(data, profiles: [_profile(4)]);
        expect(result.importedCount, 1);
        expect(await repository.getById(collisionId), original);
        final pin = (await repository.findByQuery(4, 'cat'))!;
        expect(pin.id, isNot(collisionId));
        expect((await repository.getOrganization()).folders.single.searchIds, [
          pin.id,
        ]);
        expect(
          (await service.apply(
            data,
            profiles: [_profile(4)],
          )).alreadyExistedCount,
          1,
        );
      },
    );
  }

  test(
    'restores definitions with an empty baseline and no runtime history',
    () async {
      final repository = memorySubscriptionRepository();
      await PinnedSearchImportService(repository: repository).apply(
        PinnedSearchBackupData(records: [_record(0)]),
        profiles: [_profile(4)],
      );
      final pin = (await repository.getAll()).single;
      expect(pin.id, _id(0));
      expect(pin.name, 'Cats 0');
      expect(pin.query, 'cat  tag_0');
      expect(pin.previews, isEmpty);
      expect(pin.recentPostIdentities, isEmpty);
      expect(pin.unreadCount, 0);
      expect(pin.lastAttemptAt, isNull);
      expect(pin.lastSuccessfulCheckAt, isNull);
      expect(pin.lastErrorKind, isNull);
    },
  );
}

String _id(int value) => '550e8400-e29b-41d4-a716-44665544000$value';

BooruConfig _profile(
  int id, {
  String url = 'https://example.test/Posts',
  BooruType type = BooruType.danbooru,
}) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'booruIdHint': type.id,
  'url': url,
  'name': 'Local profile',
});

PinnedSearchBackupRecord _record(
  int index, {
  int position = 0,
  String? query,
  int profileId = 4,
}) => PinnedSearchBackupRecord(
  id: _id(index),
  name: 'Cats $index',
  query: query ?? 'cat  tag_$index',
  position: position,
  profile: PinnedSearchProfileReference(
    id: profileId,
    booruType: 'danbooru',
    url: 'https://EXAMPLE.test/Posts/',
    name: 'Remote profile',
  ),
);
