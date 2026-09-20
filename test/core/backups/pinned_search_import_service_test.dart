import 'package:boorusama/core/backups/sources/pinned_search_backup_data.dart';
import 'package:boorusama/core/backups/sources/pinned_search_import_service.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../search/subscriptions/subscription_test_utils.dart';

void main() {
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
          profile: record.profile,
        ),
        PinnedSearchFolderBackupRecord(
          id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          name: 'Empty',
          position: 1,
          searchIds: const [],
          profile: record.profile,
        ),
      ],
    );
    final service = PinnedSearchImportService(repository: repository);
    await service.apply(data, profiles: [_profile(9)]);
    await service.apply(data, profiles: [_profile(9)]);
    final folders = await repository.getFolders();
    expect(folders.length, 2);
    expect(folders.first.profileId, 9);
    expect(folders.first.searchIds, {(await repository.getAll()).single.id});
    expect(folders.last.searchIds, isEmpty);
  });

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

  test('preserves a colliding ID owned by another profile', () async {
    final repository = memorySubscriptionRepository();
    final existing = await repository.create(
      profileId: 9,
      query: 'original',
      name: null,
      id: _id(0),
    );
    final result = await PinnedSearchImportService(repository: repository)
        .apply(
          PinnedSearchBackupData(records: [_record(0)]),
          profiles: [_profile(4)],
        );
    expect(
      result,
      const PinnedSearchImportResult(
        importedCount: 0,
        alreadyExistedCount: 1,
        skippedProfileCount: 0,
      ),
    );
    expect(await repository.getAll(), [existing]);
  });

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
