import 'package:boorusama/core/backups/export_import/import/collection_import_action.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/following_topic_backup_data.dart';
import 'package:boorusama/core/backups/sources/following_topic_import_service.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../search/following_topics/topic_test_utils.dart';

const _profileId = '11111111-1111-4111-8111-111111111111';
const _topicId = '22222222-2222-4222-8222-222222222222';
const _secondId = '33333333-3333-4333-8333-333333333333';
const _folderId = '44444444-4444-4444-8444-444444444444';
const _reference = BackupProfileReference(
  id: _profileId,
  booruType: 'gelbooruV2',
  url: 'https://safebooru.org',
  name: 'Source profile',
);

FollowingTopicBackupRecord _record({
  String id = _topicId,
  BackupProfileReference profile = _reference,
}) => FollowingTopicBackupRecord(
  id: id,
  name: 'Cats',
  query: 'cat',
  position: 0,
  profile: profile,
  autoUpdateEnabled: false,
);

void main() {
  test('retains valid unresolved Topics instead of skipping them', () async {
    final repository = memorySubscriptionRepository();
    final service = FollowingTopicImportService(repository: repository);
    final data = FollowingTopicBackupData(records: [_record()]);

    expect(service.preview(data, profiles: []).unmatchedRecordIds, isEmpty);
    final result = await service.apply(data, profiles: []);
    final topic = (await repository.getAll()).single;

    expect(result.importedCount, 1);
    expect(result.skippedProfileCount, 0);
    expect(topic.id, _topicId);
    expect(topic.profileId, isNot(_profileId));
    expect(topic.query, 'cat');
    expect(topic.name, 'Cats');
    expect(topic.autoUpdateEnabled, isFalse);
    expect(topic.lastSuccessfulCheckAt, isNull);
    expect(topic.localSource?.importedProfileId, _profileId);
    expect(topic.localSource?.url, _reference.url);
    expect((await repository.getOrganization()).homeSearchIds, [_topicId]);
    expect(followingTopicBackupProfile(topic, []), _reference);
  });

  test(
    'retains unknown and private sites without requiring public access',
    () async {
      final repository = memorySubscriptionRepository();
      const private = BackupProfileReference(
        id: _profileId,
        booruType: 'futureEngine',
        url: 'https://private.example/installation',
        name: 'Private source',
      );
      final service = FollowingTopicImportService(repository: repository);
      final result = await service.apply(
        FollowingTopicBackupData(records: [_record(profile: private)]),
        profiles: [],
      );
      final topic = (await repository.getAll()).single;
      expect(result.importedCount, 1);
      expect(topic.localSource?.booruType, 'futureEngine');
      expect(followingTopicBackupProfile(topic, []), private);
    },
  );

  test(
    'reimport after a compatible profile appears does not duplicate Topics',
    () async {
      final repository = memorySubscriptionRepository();
      final service = FollowingTopicImportService(repository: repository);
      final data = FollowingTopicBackupData(records: [_record()]);
      await service.apply(data, profiles: []);
      final before = (await repository.getAll()).single;
      final profile = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': _profileId,
        'booruId': BooruType.gelbooruV2.id,
        'booruIdHint': BooruType.gelbooruV2.id,
        'url': _reference.url,
      });

      final result = await service.apply(data, profiles: [profile]);
      expect(result.importedCount, 0);
      expect(result.alreadyExistedCount, 1);
      expect(await repository.getAll(), [before]);
      await repository.deleteForProfile(profile.id);
      expect(await repository.getAll(), [before]);
    },
  );

  test(
    'independent identical records and explicit folder copies stay independent',
    () async {
      final repository = memorySubscriptionRepository();
      final service = FollowingTopicImportService(repository: repository);
      final data = FollowingTopicBackupData(
        records: [
          _record(),
          _record(id: _secondId),
        ],
        folders: const [
          FollowingTopicFolderBackupRecord(
            id: _folderId,
            name: 'Animals',
            position: 0,
            searchIds: [_topicId, _secondId],
            feedEnabled: true,
            feedMaxPosts: 2000,
          ),
        ],
      );
      await service.apply(data, profiles: []);
      final repeated = await service.apply(data, profiles: []);
      expect(repeated.alreadyExistedCount, 2);
      expect(await repository.getAll(), hasLength(2));
      final copied = await service.apply(
        data,
        profiles: [],
        folderActions: const {
          _folderId: CollectionImportAction(
            itemId: _folderId,
            action: ImportAction.copy,
          ),
        },
      );
      expect(copied.importedCount, 2);
      expect(await repository.getAll(), hasLength(4));
      expect(copied.resolvedIds.values.toSet(), hasLength(2));
      expect(copied.resolvedIds.values, isNot(contains(_topicId)));
    },
  );

  test('a conflicting Topic UUID never overwrites the other source', () async {
    final repository = memorySubscriptionRepository();
    final service = FollowingTopicImportService(repository: repository);
    await service.apply(
      FollowingTopicBackupData(records: [_record()]),
      profiles: [],
    );
    const other = BackupProfileReference(
      id: _profileId,
      booruType: 'gelbooruV2',
      url: 'https://other.example/booru',
      name: 'Different installation',
    );
    final result = await service.apply(
      FollowingTopicBackupData(records: [_record(profile: other)]),
      profiles: [],
    );
    expect(result.importedCount, 1);
    expect(result.resolvedIds[_topicId], isNot(_topicId));
    final topics = await repository.getAll();
    expect(topics, hasLength(2));
    expect(topics.map((t) => t.localSource!.url).toSet(), {
      _reference.url,
      other.url,
    });
  });

  test('portable source provenance round-trips as source JSON', () {
    final source = FollowingTopicSource(
      booruType: _reference.booruType,
      url: _reference.url,
      importedProfileId: _profileId,
      importedProfileName: _reference.name,
    );
    expect(FollowingTopicSource.fromJson(source.toJson()), source);
    final legacy = FollowingTopicSource.fromJson({
      'booruType': _reference.booruType,
      'url': _reference.url,
    });
    expect(legacy.importedProfileId, isNull);
  });
}
