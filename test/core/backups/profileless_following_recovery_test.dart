import 'package:boorusama/core/backups/export_import/import/search_runtime_snapshot.dart';
import 'package:boorusama/core/backups/sources/following_topic_backup_data.dart';
import 'package:boorusama/core/backups/sources/following_topic_import_service.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../search/following_topics/topic_test_utils.dart';

const _first = '11111111-1111-4111-8111-111111111111';
const _second = '22222222-2222-4222-8222-222222222222';
const _foreign = '33333333-3333-4333-8333-333333333333';
const _existing = '44444444-4444-4444-8444-444444444444';
const _localProfile = '55555555-5555-4555-8555-555555555555';
const _reference = BackupProfileReference(
  id: _foreign,
  booruType: 'futureEngine',
  url: 'https://private.example/installation',
  name: 'Unavailable source',
);

FollowingTopicBackupRecord _record(String id, String query, int position) =>
    FollowingTopicBackupRecord(
      id: id,
      query: query,
      name: 'Retained definition',
      position: position,
      profile: _reference,
      autoUpdateEnabled: false,
    );

void main() {
  test(
    'later invalid input rolls back newly restored detached namespaces',
    () async {
      final repository = memorySubscriptionRepository();
      final original = await repository.create(
        profileId: _localProfile,
        query: 'dog',
        name: 'Existing local Topic',
        id: _existing,
      );
      final organization = TopicOrganization(
        folders: [],
        homeSearchIds: [_existing],
      );
      await repository.replaceOrganization(organization);
      final service = FollowingTopicImportService(repository: repository);
      final data = FollowingTopicBackupData(
        records: [
          _record(_first, 'cat', 0),
          _record(_second, '   ', 1),
        ],
      );

      await expectLater(
        service.apply(data, profiles: []),
        throwsA(isA<FormatException>()),
      );
      expect(await repository.getAll(), [original]);
      expect(await repository.getOrganization(), organization);
    },
  );

  test(
    'runtime snapshot round trip preserves portable provenance and preferences',
    () async {
      final repository = memorySubscriptionRepository();
      final service = FollowingTopicImportService(repository: repository);
      await service.apply(
        FollowingTopicBackupData(records: [_record(_first, 'cat', 0)]),
        profiles: [],
      );
      final snapshots = SearchRuntimeSnapshotService(repository);
      final before = await snapshots.capture();
      const codec = SearchRuntimeSnapshotCodec();
      final restored = codec.decode(codec.encode(before));
      expect(restored, before);
      expect(restored.searches.single.localSource?.importedProfileId, _foreign);
      expect(restored.searches.single.autoUpdateEnabled, isFalse);

      await repository.delete(_first);
      await snapshots.restore(restored);
      expect(await snapshots.capture(), before);
      expect(
        followingTopicBackupProfile((await repository.getAll()).single, []),
        _reference,
      );
    },
  );

  test('failed Replace preserves existing detached definitions', () async {
    final repository = memorySubscriptionRepository();
    final service = FollowingTopicImportService(repository: repository);
    await service.apply(
      FollowingTopicBackupData(records: [_record(_first, 'cat', 0)]),
      profiles: [],
    );
    final snapshots = SearchRuntimeSnapshotService(repository);
    final before = await snapshots.capture();
    await expectLater(
      service.replace(
        FollowingTopicBackupData(records: [_record(_second, ' ', 0)]),
        profiles: [],
      ),
      throwsA(isA<FormatException>()),
    );
    expect(await snapshots.capture(), before);
  });
}
