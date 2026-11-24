import 'dart:io';

import 'package:boorusama/core/backups/mitemite/following_package.dart';
import 'package:boorusama/core/backups/mitemite/catalog.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/backups/mitemite/publication.dart';
import 'package:boorusama/core/backups/mitemite/revision_transport.dart';
import 'package:boorusama/core/backups/mitemite/storage.dart';
import 'package:boorusama/core/backups/sources/following_topic_backup_data.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';

const source = '11111111-1111-4111-8111-111111111111';
const profile = '22222222-2222-4222-8222-222222222222';

FollowingTopicBackupData topic({
  String query = 'cat',
  bool automatic = false,
  String profileId = profile,
  String profileName = 'Private account label',
}) => FollowingTopicBackupData(
  records: [
    FollowingTopicBackupRecord(
      id: source,
      name: 'Cats',
      query: query,
      position: 7,
      autoUpdateEnabled: automatic,
      folderPosition: 2,
      profile: BackupProfileReference(
        id: profileId,
        booruType: 'danbooru',
        url: 'https://username:password@example.test/booru?token=private',
        name: profileName,
      ),
    ),
  ],
  homeSearchIds: const [source],
);

void main() {
  late Directory directory;
  late SyncSigningIdentity identity;
  late SyncCollectionId collection;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('following_package_');
    identity = await SyncSigningIdentity.create();
    collection = SyncCollectionId(
      publisher: identity.id,
      kind: 'following_topics',
      source: source,
    );
  });
  tearDown(() => Future.sync(() => directory.delete(recursive: true)));

  test('portable definitions omit credentials, private profile labels and automatic refresh preferences', () async {
    final package = await const SyncFollowingPackageBuilder(fs: IoFileSystem())
        .build(
          collection: collection,
          data: topic(),
          appVersion: 'test',
          createdAt: DateTime.utc(2026),
        );
    final record = package.data.records.single;
    expect(record.profile.url, 'https://example.test/booru');
    expect(record.profile.name, 'danbooru');
    expect(record.autoUpdateEnabled, isTrue);
    expect(record.position, 0);
    expect(record.folderId, isNull);
    expect(package.data.records.single.profile.id, profile);
    expect(
      syncFollowingSemanticHash(topic()),
      syncFollowingSemanticHash(
        topic(
          automatic: true,
          profileId: '33333333-3333-4333-8333-333333333333',
          profileName: 'Another private account',
        ),
      ),
    );
    expect(
      syncFollowingSemanticHash(topic(query: 'dog')),
      isNot(package.semanticHash),
    );
    final incoming =
        await const SyncFollowingPackageValidator(fs: IoFileSystem()).validate(
          collection: collection,
          bytes: package.bytes,
        );
    expect(incoming.forPublication, isFalse);
    expect(incoming.semanticHash, package.semanticHash);
    await expectLater(
      const SyncFollowingPackageValidator(fs: IoFileSystem()).validate(
        collection: SyncCollectionId(
          publisher: identity.id,
          kind: 'following_topics',
          source: profile,
        ),
        bytes: package.bytes,
      ),
      throwsA(anything),
    );
    await expectLater(
      const SyncFollowingPackageValidator(fs: IoFileSystem()).validate(
        collection: collection,
        bytes: package.bytes,
        maxPreparedBytes: package.bytes.length,
      ),
      throwsA(anything),
    );
  });

  test('one folder Feed is one definition source with no embedded Topic cache or membership snapshot', () async {
    final package = await const SyncFollowingPackageBuilder(fs: IoFileSystem())
        .build(
          collection: collection,
          data: const FollowingTopicBackupData(
            records: [],
            folders: [
              FollowingTopicFolderBackupRecord(
                id: source,
                name: 'Artists',
                position: 4,
                searchIds: [],
                feedEnabled: true,
                feedMaxPosts: 123,
              ),
            ],
          ),
          appVersion: 'test',
          createdAt: DateTime.utc(2026),
        );
    expect(package.data.records, isEmpty);
    expect(package.data.folders.single.id, source);
    expect(package.data.folders.single.feedEnabled, isTrue);
    expect(package.data.folders.single.feedMaxPosts, 123);
    expect(package.data.folders.single.position, 0);
  });

  test('signed Following publication retains no-op revisions and refuses incoming package echoes', () async {
    final storage = DirectoryMiteMiteStorage(directory.path);
    final writer = SyncPublicationWriter(
      storage: storage,
      identity: identity,
      sequences: SyncPublicationSequences(
        store: _Store(),
        mutations: DataMutationCoordinator(),
      ),
    );
    final publisher = SyncFollowingPublisher(
      writer: writer,
      builder: const SyncFollowingPackageBuilder(fs: IoFileSystem()),
      workQueue: DataMutationCoordinator(),
    );
    Future<SyncRevision> publish(FollowingTopicBackupData data, int day) =>
        publisher.publishIfChanged(
          collection: collection,
          data: data,
          appVersion: 'test',
          createdAt: DateTime.utc(2026, 1, day),
        );
    final first = await publish(topic(), 1);
    expect(first.schema, ValidatedSyncFollowingPackage.schema);
    final unchanged = await publish(topic(automatic: true), 2);
    expect(unchanged.revision, first.revision);
    expect(unchanged.sha256, first.sha256);
    final changed = await publish(topic(query: 'dog'), 3);
    expect(changed.revision, greaterThan(first.revision));
    final transport = await SyncRevisionTransport(storage)
        .read(expected: changed, publisherKey: identity.publicKey);
    final incoming =
        await const SyncFollowingPackageValidator(fs: IoFileSystem()).validate(
          collection: collection,
          bytes: transport!.bytes,
        );
    await expectLater(
      writer.publishFollowingRevision(incoming),
      throwsA(isA<FormatException>()),
    );
    final catalog = await writer.publishCatalog(
      name: 'Device',
      publicationRoots: {collection},
      entries: [
        SyncCatalogEntry(
          id: collection,
          name: 'Cats',
          state: SyncPublicationState.active,
          revision: changed,
        ),
      ],
    );
    expect(catalog.offeredEntries.single.id, collection);
  });
}

class _Store implements MiscDataStore {
  final values = <String, String>{};
  @override
  String? get(String key) => values[key];
  @override
  Future<void> put(String key, String value) async {
    values[key] = value;
  }
}
