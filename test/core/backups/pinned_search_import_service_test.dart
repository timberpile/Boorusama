import '../../profile_uuid_utils.dart';
import 'package:boorusama/core/backups/sources/pinned_search_backup_data.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/backups/sources/pinned_search_import_service.dart';
import 'package:boorusama/core/backups/export_import/import/collection_import_action.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../search/subscriptions/subscription_test_utils.dart';

void main() {
  for (final testCase in [
    (
      action: ImportAction.update,
      expectedName: 'Remote',
      expectedIds: [_id(0), _id(1)],
    ),
    (
      action: ImportAction.merge,
      expectedName: 'Local',
      expectedIds: [_id(0), _id(1)],
    ),
  ]) {
    test(
      '${testCase.action.name} applies the expected folder definition',
      () async {
        const folderId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
        final repository = memorySubscriptionRepository();
        for (final index in [0, 1, 2]) {
          await repository.create(
            profileId: '00000000-0000-4000-8000-000000000004',
            query: _record(index).query,
            name: null,
            id: _id(index),
          );
        }
        await repository.replaceOrganization(
          SearchOrganization(
            folders: [
              SharedSearchFolder(
                id: folderId,
                name: 'Local',
                searchIds: [_id(0), _id(1)],
              ),
            ],
            homeSearchIds: [_id(2)],
          ),
        );
        final data = PinnedSearchBackupData(
          records: [_record(1), _record(2)],
          folders: [
            PinnedSearchFolderBackupRecord(
              id: folderId,
              name: 'Remote',
              position: 0,
              searchIds: [_id(1), _id(2)],
            ),
          ],
        );

        await PinnedSearchImportService(repository: repository).apply(
          data,
          profiles: [_profile(4)],
          folderActions: {
            folderId: CollectionImportAction(
              itemId: folderId,
              action: testCase.action,
            ),
          },
        );

        final folder = (await repository.getOrganization()).folders.single;
        expect(folder.name, testCase.expectedName);
        expect(folder.searchIds, testCase.expectedIds);
      },
    );
  }

  for (final matchingId in [false, true]) {
    test(
      'Copy allocates a unique folder name for a ${matchingId ? 'matching ID' : 'different ID with the same name'}',
      () async {
        const incomingId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
        const oldId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
        const copyId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
        final repository = memorySubscriptionRepository();
        final local = await repository.create(
          profileId: profileUuid(4),
          query: 'local_only',
          name: null,
        );
        await repository.replaceOrganization(
          SearchOrganization(
            folders: [
              SharedSearchFolder(
                id: matchingId ? incomingId : oldId,
                name: 'Animals',
                searchIds: [local.id],
              ),
              SharedSearchFolder(
                id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
                name: 'ANIMALS (2)',
                searchIds: const [],
              ),
            ],
            homeSearchIds: const [],
          ),
        );
        final data = PinnedSearchBackupData(
          records: [_record(1)],
          folders: [
            PinnedSearchFolderBackupRecord(
              id: incomingId,
              name: 'Animals',
              position: 0,
              searchIds: [_id(1)],
            ),
          ],
        );
        await PinnedSearchImportService(repository: repository).apply(
          data,
          profiles: [_profile(4)],
          folderActions: {
            incomingId: CollectionImportAction(
              itemId: incomingId,
              action: ImportAction.copy,
              destinationId: matchingId ? copyId : null,
            ),
          },
        );
        final folders = (await repository.getOrganization()).folders;
        final copy = folders.singleWhere((f) => f.searchIds.contains(_id(1)));
        expect(copy.name, 'Animals');
        expect(copy.parentId, isNotNull);
        expect(copy.id, isNot(incomingId));
        expect(
          folders.singleWhere((f) => f.id == copy.parentId).name,
          'Imported Searches',
        );
        expect(
          folders
              .singleWhere(
                (folder) => folder.id == (matchingId ? incomingId : oldId),
              )
              .searchIds,
          [local.id],
        );
        expect(
          folders.map((folder) => folder.name.toLowerCase()).toSet(),
          hasLength(3),
        );
      },
    );
  }

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
    await service.apply(
      data,
      profiles: [_profile(9)],
      profileIdResolver: (_) => profileUuid(9),
    );
    await service.apply(
      data,
      profiles: [_profile(9)],
      profileIdResolver: (_) => profileUuid(9),
    );
    final folders = (await repository.getOrganization()).folders;
    expect(folders.length, 2);
    expect(folders.singleWhere((f) => f.name == 'Animals').searchIds, [
      (await repository.getAll()).single.id,
    ]);
    expect(
      folders.singleWhere((f) => f.name == 'Imported Searches').searchIds,
      isEmpty,
    );
  });

  test(
    'an explicit profile mapping imports without a currently loaded profile',
    () async {
      final repository = memorySubscriptionRepository();

      await PinnedSearchImportService(repository: repository).apply(
        PinnedSearchBackupData(records: [_record(0)]),
        profiles: const [],
        profileIdResolver: (_) => '00000000-0000-4000-8000-00000000004d',
      );

      expect((await repository.getAll()).single.profileId, profileUuid(77));
    },
  );

  test(
    'previews unmatched pins and rejects before any writes',
    () async {
      final repository = memorySubscriptionRepository();
      final service = PinnedSearchImportService(repository: repository);
      final missing = _record(
        1,
        profileId: '00000000-0000-4000-8000-000000000063',
      );
      final data = PinnedSearchBackupData(
        records: [_record(0), missing],
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
      expect(result.skippedProfileCount, 1);
      expect(
        (await repository.getOrganization()).folders.single.searchIds,
        [_id(0)],
      );
    },
  );

  test('restores mixed profiles and mapped query IDs in saved order', () async {
    final repository = memorySubscriptionRepository();
    final existing = await repository.create(
      profileId: '00000000-0000-4000-8000-000000000009',
      query: _record(0).query,
      name: null,
      id: _id(9),
    );
    final dog = PinnedSearchBackupRecord(
      id: _id(1),
      name: null,
      query: 'dog',
      position: 0,
      profile: const BackupProfileReference(
        id: '00000000-0000-4000-8000-000000000063',
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
    await service.apply(
      data,
      profiles: profiles,
      profileIdResolver: (reference) =>
          reference.id == profileUuid(99) ? profileUuid(88) : profileUuid(9),
    );
    final organization = await repository.getOrganization();
    expect(
      organization.folders.singleWhere((f) => f.name == 'Animals').searchIds,
      [dog.id],
    );
    expect(
      organization.folders
          .singleWhere((f) => f.name == 'Imported Searches')
          .searchIds,
      [_id(3), _id(2)],
    );
    expect(organization.homeSearchIds, [existing.id]);
    expect((await repository.getById(dog.id))!.profileId, profileUuid(88));
    await service.apply(
      data,
      profiles: profiles,
      profileIdResolver: (reference) =>
          reference.id == profileUuid(99) ? profileUuid(88) : profileUuid(9),
    );
    expect(await repository.getOrganization(), organization);
  });

  test(
    'pin-only restore preserves existing folders and appends new Home pins',
    () async {
      final repository = memorySubscriptionRepository();
      await repository.create(
        profileId: '00000000-0000-4000-8000-000000000004',
        query: _record(0).query,
        name: null,
        id: _id(0),
      );
      await repository.create(
        profileId: '00000000-0000-4000-8000-000000000004',
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
    'skips only the individually skipped searches during folder import',
    () async {
      final repository = memorySubscriptionRepository();
      final existing = await repository.create(
        profileId: '00000000-0000-4000-8000-000000000004',
        query: '  cat   rating:safe ',
        name: 'Local cat',
        id: _id(8),
      );
      const folderId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final cat = _record(0);
      final dog = PinnedSearchBackupRecord(
        id: _id(1),
        name: 'Dog',
        query: 'dog',
        position: 1,
        profile: cat.profile,
      );

      final result = await PinnedSearchImportService(repository: repository)
          .apply(
            PinnedSearchBackupData(
              records: [
                PinnedSearchBackupRecord(
                  id: cat.id,
                  name: cat.name,
                  query: 'cat rating:safe',
                  position: cat.position,
                  profile: cat.profile,
                ),
                dog,
              ],
              folders: [
                PinnedSearchFolderBackupRecord(
                  id: folderId,
                  name: 'Animals',
                  position: 0,
                  searchIds: [cat.id, dog.id],
                ),
              ],
            ),
            profiles: [_profile(4)],
            recordActions: {dog.id: ImportAction.skip},
            folderActions: {
              folderId: const CollectionImportAction(
                itemId: folderId,
                action: ImportAction.copy,
              ),
            },
          );

      expect(result.alreadyExistedCount, 1);
      expect(result.importedCount, 0);
      expect(await repository.getAll(), [existing]);
      expect(
        (await repository.getOrganization()).homeSearchIds,
        [existing.id],
      );
    },
  );

  test(
    'appends pin-only imports after unlisted local pins with future timestamps',
    () async {
      final repository = memorySubscriptionRepository();
      await repository.create(
        profileId: '00000000-0000-4000-8000-000000000004',
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
          profileId: '00000000-0000-4000-8000-000000000004',
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
      expect(organization.homeSearchIds, [_id(3), _id(2)]);
      expect(organization.folders.map((folder) => folder.name), [
        'Renamed',
        'Empty',
      ]);
      expect(organization.folders.first.searchIds, [_id(0), _id(1)]);
    },
  );

  final mappingCases = [
    (
      description: 'the matching ID before ambiguous URLs',
      profiles: [_profile(4), _profile(5)],
      expectedId: 4,
    ),
    (
      description: 'no automatic mapping to a unique URL with another UUID',
      profiles: [_profile(9)],
      expectedId: null,
    ),
    (
      description: 'no mapping when same UUID has another URL',
      profiles: [
        _profile(4, url: 'https://other.test'),
        _profile(9),
      ],
      expectedId: null,
    ),
    (
      description: 'no mapping when same UUID has another engine',
      profiles: [
        _profile(4, type: BooruType.gelbooru),
        _profile(9),
      ],
      expectedId: null,
    ),
    (
      description: 'no profile for an ambiguous URL',
      profiles: [_profile(5), _profile(9)],
      expectedId: null,
    ),
    (
      description:
          'no automatic mapping to the only compatible profile for a missing URL',
      profiles: [_profile(4, url: 'https://other.test')],
      expectedId: null,
    ),
    (
      description:
          'no automatic mapping to the only compatible profile for a different scheme',
      profiles: [_profile(4, url: 'http://example.test/Posts')],
      expectedId: null,
    ),
    (
      description:
          'no automatic mapping to the only compatible profile for a different path',
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
        c.expectedId == null ? isEmpty : [profileUuid(c.expectedId!)],
      );
    });
  }

  test('appends after existing positions in stable imported order', () async {
    final repository = memorySubscriptionRepository();
    await repository.restoreForProfile('00000000-0000-4000-8000-000000000004', [
      SearchSubscription.create(
        id: _id(9),
        profileId: '00000000-0000-4000-8000-000000000004',
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
    'preserves query matches without reusing an ID collision',
    () async {
      final repository = memorySubscriptionRepository();
      final existingId = await repository.create(
        profileId: '00000000-0000-4000-8000-000000000004',
        query: 'original',
        name: 'Local name',
        id: _id(0),
      );
      final existingQuery = await repository.create(
        profileId: '00000000-0000-4000-8000-000000000004',
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
          importedCount: 2,
          alreadyExistedCount: 1,
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
      expect(afterFirst, hasLength(4));
      expect(
        afterFirst.singleWhere((search) => search.query == 'cat  tag_0').id,
        isNot(existingId.id),
      );
      expect(afterFirst.last.id, _id(2));
    },
  );

  test('an ID collision with a different query creates a new search', () async {
    final repository = memorySubscriptionRepository();
    final local = await repository.create(
      profileId: '00000000-0000-4000-8000-000000000004',
      query: 'local query',
      name: 'Local',
      id: _id(0),
    );

    final result = await PinnedSearchImportService(repository: repository)
        .apply(
          PinnedSearchBackupData(records: [_record(0, query: 'remote query')]),
          profiles: [_profile(4)],
        );

    final searches = await repository.getAll();
    expect(result.importedCount, 1);
    expect(searches, hasLength(2));
    expect(
      searches.singleWhere((search) => search.id == local.id).query,
      'local query',
    );
    expect(
      searches.singleWhere((search) => search.id != local.id).query,
      'remote query',
    );
  });

  test(
    'replacement reuses matching searches and removes only absent searches',
    () async {
      final repository = memorySubscriptionRepository();
      final existing = await repository.create(
        profileId: '00000000-0000-4000-8000-000000000004',
        query: 'cat tag_0',
        name: 'Local name',
        id: _id(9),
      );
      await repository.create(
        profileId: '00000000-0000-4000-8000-000000000004',
        query: 'remove me',
        name: null,
        id: _id(8),
      );
      await repository.recordRefreshFailure(
        existing.id,
        expectedCreatedAt: existing.createdAt,
        attemptedAt: DateTime.utc(2026),
        kind: SearchRefreshErrorKind.network,
      );
      const folderId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

      await PinnedSearchImportService(repository: repository).replace(
        PinnedSearchBackupData(
          records: [_record(0)],
          folders: [
            PinnedSearchFolderBackupRecord(
              id: folderId,
              name: 'Animals',
              position: 0,
              searchIds: [_id(0)],
            ),
          ],
        ),
        profiles: [_profile(4)],
      );

      final searches = await repository.getAll();
      expect(searches, hasLength(1));
      expect(searches.single.id, existing.id);
      expect(searches.single.lastErrorKind, SearchRefreshErrorKind.network);
      final folder = (await repository.getOrganization()).folders.single;
      expect(folder.id, folderId);
      expect(folder.searchIds, [existing.id]);
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
                _record(
                  2,
                  query: 'cat rating:safe',
                  profileId: '00000000-0000-4000-8000-000000000005',
                ),
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
      expect((await repository.getAll()).map((pin) => pin.profileId), [
        profileUuid(4),
        profileUuid(5),
      ]);
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
            profileId: '00000000-0000-4000-8000-000000000004',
            name: 'Feed',
            queries: ['original'],
          );
          collisionId = (await repository.getAll())
              .firstWhere((pin) => feed.sourceIds.contains(pin.id))
              .id;
        } else {
          collisionId = (await repository.create(
            profileId: '00000000-0000-4000-8000-000000000009',
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
        final pin = (await repository.findByQuery(
          '00000000-0000-4000-8000-000000000004',
          'cat',
        ))!;
        expect(pin.id, isNot(collisionId));
        expect(
          (await repository.getOrganization()).folders
              .singleWhere((f) => f.name == 'Animals')
              .searchIds,
          [
            pin.id,
          ],
        );
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

  test(
    'imports typed tags without upgrading a matching legacy pin',
    () async {
      final repository = memorySubscriptionRepository();
      final legacy = await repository.create(
        profileId: '00000000-0000-4000-8000-000000000004',
        query: 'cat rating:safe',
        name: null,
      );
      final structured = PinnedSearchBackupRecord(
        id: _id(0),
        name: 'Cats',
        query: 'cat rating:safe',
        queryStructure: SearchQueryStructure.typedTags(const [
          'cat',
          'rating:safe',
        ]),
        position: 0,
        profile: _record(0).profile,
      );
      final service = PinnedSearchImportService(repository: repository);

      final duplicateResult = await service.apply(
        PinnedSearchBackupData(records: [structured]),
        profiles: [_profile(4)],
      );

      expect(duplicateResult.alreadyExistedCount, 1);
      expect((await repository.getById(legacy.id))?.queryStructure, isNull);

      await repository.delete(legacy.id);
      final importResult = await service.apply(
        PinnedSearchBackupData(records: [structured]),
        profiles: [_profile(4)],
      );
      expect(importResult.importedCount, 1);
      expect(
        (await repository.getAll()).single.queryStructure,
        structured.queryStructure,
      );
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
  'id': profileUuid(id),
  'booruIdHint': type.id,
  'url': url,
  'name': 'Local profile',
});

PinnedSearchBackupRecord _record(
  int index, {
  int position = 0,
  String? query,
  String profileId = '00000000-0000-4000-8000-000000000004',
}) => PinnedSearchBackupRecord(
  id: _id(index),
  name: 'Cats $index',
  query: query ?? 'cat  tag_$index',
  position: position,
  profile: BackupProfileReference(
    id: profileId,
    booruType: 'danbooru',
    url: 'https://EXAMPLE.test/Posts/',
    name: 'Remote profile',
  ),
);
