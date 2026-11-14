import 'dart:typed_data';

import 'package:boorusama/boorus/pixiv/posts/post_codec.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/boorus/pixiv/works/bookmark_targets.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/backups/folder_sync/bookmark_package.dart';
import 'package:boorusama/core/backups/folder_sync/catalog.dart';
import 'package:boorusama/core/backups/folder_sync/catalog_gate.dart';
import 'package:boorusama/core/backups/folder_sync/protocol.dart';
import 'package:boorusama/core/backups/folder_sync/publication.dart';
import 'package:boorusama/core/backups/folder_sync/reading_state.dart';
import 'package:boorusama/core/backups/folder_sync/receive_preparation.dart';
import 'package:boorusama/core/backups/folder_sync/storage.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_record_fields.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../boorus/pixiv/works/work_test_fixtures.dart';

const source = '11111111-2222-4333-8444-555555555555';
const otherSource = '22222222-2222-4333-8444-555555555555';

void main() {
  late SyncSigningIdentity identity;
  late _Storage storage;
  late _Store store;
  late DataMutationCoordinator mutations;
  late SyncPublicationWriter writer;
  late SyncCollectionId collection;
  final codec = BookmarkBackupCodec(
    postDataCodec: (_) => const PixivPostCodec(),
  );
  const fs = IoFileSystem();

  BookmarkBackupData data({
    String id = source,
    String name = 'Source',
    int offset = 0,
    bool reverse = false,
  }) {
    final access = workAccess();
    final dto = work();
    final at = DateTime.utc(2026, 11, 14);
    final records = [
      bookmarkWithId(
        PixivWorkBookmarkTarget(
          access: access,
          summary: pixivWorkSummary(dto, access),
        ).draft(currentAccess: access, at: at),
        offset,
      ),
      bookmarkWithId(
        PixivPageBookmarkTarget(
          access: access,
          post: pixivWorkPagePosts(dto, access)[2],
        ).draft(currentAccess: access, at: at),
        offset + 1,
      ),
    ];
    return BookmarkBackupData.unified(
      records: reverse ? records.reversed : records,
      groups: [
        BookmarkGroupBackup(
          id: id,
          name: name,
          bookmarkIds: [offset, offset + 1],
          addedAt: {offset: at, offset + 1: at},
        ),
      ],
    );
  }

  Future<ValidatedSyncBookmarkPackage> build({BookmarkBackupData? snapshot}) =>
      SyncBookmarkPackageBuilder(fs: fs, codec: codec).build(
        collection: collection,
        data: snapshot ?? data(),
        appVersion: '4.6.1',
        createdAt: DateTime.utc(2026, 11, 14),
      );

  SyncCatalogEntry active(SyncRevision revision) => SyncCatalogEntry(
    id: collection,
    name: 'Source',
    state: SyncPublicationState.active,
    revision: revision,
  );

  Future<VerifiedSyncCatalog> accept(SyncCatalog catalog) async {
    final gate = SyncCatalogGate(store: store, mutations: mutations);
    await gate.approvePublisher(
      publisher: identity.id,
      publicKey: identity.publicKey,
    );
    return gate.verifyAndCheckpoint(
      publisher: identity.id,
      expectedSequence: catalog.sequence,
      bytes: storage.files[catalog.path]!,
    );
  }

  setUp(() async {
    identity = await SyncSigningIdentity.create();
    storage = _Storage();
    store = _Store();
    mutations = DataMutationCoordinator();
    collection = SyncCollectionId(
      publisher: identity.id,
      kind: 'bookmarks',
      source: source,
    );
    writer = SyncPublicationWriter(
      storage: storage,
      identity: identity,
      sequences: SyncPublicationSequences(store: store, mutations: mutations),
    );
  });

  test('signed descriptor-last publication and validated v10 receive preserve Work/Page identities', () async {
    final package = await build();
    final revision = await writer.publishRevision(package);
    expect(storage.writes, [
      'devices/${identity.id}/identity.json',
      revision.payloadPath,
      revision.descriptorPath,
    ]);
    final catalog = await writer.publishCatalog(
      name: 'Publisher',
      entries: [active(revision)],
    );
    final ticket = await accept(catalog);
    final prepared =
        await SyncReceivePreparation(
          storage: storage,
          fs: fs,
          codec: codec,
        ).prepare(
          catalog: ticket,
          collection: collection,
          publisherKey: identity.publicKey,
        );
    expect(
      prepared!.package.data.records
          .whereType<ContentGroupBookmark>()
          .single
          .reference
          .sourceKey,
      'work:120',
    );
    expect(
      prepared.package.data.records
          .whereType<PostBookmark>()
          .single
          .post
          .pixivData!
          .pageIndex,
      2,
    );
    expect(
      prepared.package.data.records.map(syncBookmarkMemberKey).toSet(),
      package.data.records.map(syncBookmarkMemberKey).toSet(),
    );
    expect(prepared.package.bytes, package.bytes);
    expect(() => prepared.package.bytes[0] = 0, throwsUnsupportedError);
    // Receiving never grants outgoing publication authority.
    await expectLater(
      writer.publishRevision(prepared.package),
      throwsFormatException,
    );
    expect(storage.deletes, 0);
  });

  test('semantic hash excludes file IDs, record order, archive clocks and Group names', () async {
    final first = await build();
    final second = await build(
      snapshot: data(offset: 70, name: 'Renamed', reverse: true),
    );
    expect(first.semanticHash, second.semanticHash);
    expect(first.bytes, isNot(second.bytes));
  });

  test(
    'validator rejects a valid archive bound to a different source',
    () async {
      final package = await build();
      await expectLater(
        SyncBookmarkPackageValidator(fs: fs, codec: codec).validate(
          collection: SyncCollectionId(
            publisher: identity.id,
            kind: 'bookmarks',
            source: otherSource,
          ),
          bytes: package.bytes,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'validation rejects corrupt archives before any shared publication',
    () async {
      await expectLater(
        SyncBookmarkPackageValidator(fs: fs, codec: codec).validate(
          collection: collection,
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsException,
      );
      expect(storage.writes, isEmpty);
    },
  );

  test('package expansion is bounded before decoding its payload', () async {
    final package = await build();
    await expectLater(
      SyncBookmarkPackageValidator(fs: fs, codec: codec).validate(
        collection: collection,
        bytes: package.bytes,
        // Allows the archive itself, but no space for its expanded JSON.
        maxPreparedBytes: package.bytes.length * 2 + 8,
      ),
      throwsException,
    );
    expect(storage.writes, isEmpty);
  });

  test(
    'sync publication strips local browsing context and normalizes tag sets',
    () async {
      final a = data();
      final b = data();
      final first = a.records.whereType<PostBookmark>().single;
      final second = b.records.whereType<PostBookmark>().single;
      first.snapshot.common['tags'] = ['alpha', 'beta'];
      second.snapshot.common['tags'] = ['beta', 'alpha'];
      first.snapshot.common['metadata'] = {
        'search': 'PRIVATE_QUERY_SENTINEL',
        'page': 27,
        'limit': 99,
      };
      second.snapshot.common['metadata'] = {'search': 'other-query', 'page': 1};
      expect(
        syncBookmarkSemanticHash(a, codec),
        syncBookmarkSemanticHash(b, codec),
      );
      final package = await build(snapshot: a);
      expect(
        package.data.records.whereType<PostBookmark>().single.post.metadata,
        isNull,
      );
      // Inspect expanded archive content as well as the parsed domain object.
      final directory = await fs.createTempDirectory('sync_privacy_test_');
      try {
        final path = '$directory/revision.bsexport';
        await fs.writeBytes(path, package.bytes);
        final staged = await const ExportPackageReader(fs: fs).stage(path);
        try {
          final payload = await fs.readString(staged.pathFor('bookmarks.json'));
          expect(payload, isNot(contains('PRIVATE_QUERY_SENTINEL')));
          expect(payload, isNot(contains('"metadata"')));
        } finally {
          await staged.dispose();
        }
      } finally {
        await fs.deleteDirectory(directory, recursive: true);
      }
    },
  );

  test(
    'prepared data is detached from immutable validation evidence',
    () async {
      final package = await build();
      final detached = package.data;
      detached.groups.single.bookmarkIds.clear();
      detached.records.whereType<PostBookmark>().single.snapshot.common.clear();
      expect(package.data.groups.single.bookmarkIds, hasLength(2));
      expect(
        package.data.records
            .whereType<PostBookmark>()
            .single
            .post
            .pixivData!
            .pageIndex,
        2,
      );
    },
  );

  test('null-revision withdrawal blocks a delayed reserved revision across restart', () async {
    final prior = await writer.publishRevision(await build());
    await writer.publishCatalog(
      name: 'Publisher',
      entries: [
        SyncCatalogEntry(
          id: collection,
          name: 'Source',
          state: SyncPublicationState.withdrawn,
        ),
      ],
    );
    final recreated = SyncPublicationWriter(
      storage: storage,
      identity: identity,
      sequences: SyncPublicationSequences(store: store, mutations: mutations),
    );
    await expectLater(
      recreated.publishCatalog(name: 'Publisher', entries: [active(prior)]),
      throwsA(isA<SyncReplayRejected>()),
    );
    final fresh = await recreated.publishRevision(await build());
    await recreated.publishCatalog(name: 'Publisher', entries: [active(fresh)]);
    expect(fresh.revision, greaterThan(prior.revision));
  });

  test(
    'unchanged content skips archive rebuilding across publisher recreation',
    () async {
      final counting = _CountingFileSystem();
      final queue = DataMutationCoordinator();
      SyncBookmarkPublisher publisher() => SyncBookmarkPublisher(
        writer: writer,
        builder: SyncBookmarkPackageBuilder(fs: counting, codec: codec),
        workQueue: queue,
      );
      final first = await publisher().publishIfChanged(
        collection: collection,
        data: data(),
        appVersion: '4.6.1',
        createdAt: DateTime.utc(2026),
      );
      final builds = counting.directories;
      final writes = storage.writes.length;
      final second = await publisher().publishIfChanged(
        collection: collection,
        data: data(name: 'Renamed', offset: 900, reverse: true),
        appVersion: '4.6.2',
        createdAt: DateTime.utc(2027),
      );
      expect(second.revision, first.revision);
      expect(counting.directories, builds);
      expect(storage.writes, hasLength(writes));
      await writer.publishCatalog(
        name: 'Publisher',
        entries: [
          SyncCatalogEntry(
            id: collection,
            name: 'Source',
            state: SyncPublicationState.withdrawn,
            revision: first,
          ),
        ],
      );
      final fresh = await publisher().publishIfChanged(
        collection: collection,
        data: data(),
        appVersion: '4.6.1',
        createdAt: DateTime.utc(2027),
      );
      expect(fresh.revision, greaterThan(first.revision));
    },
  );

  test(
    'publication preparation cannot take the application mutation coordinator',
    () {
      expect(
        () => SyncBookmarkPublisher(
          writer: writer,
          builder: SyncBookmarkPackageBuilder(fs: fs, codec: codec),
          workQueue: mutations,
        ),
        throwsArgumentError,
      );
    },
  );

  test('counter failures prevent all shared writes', () async {
    final package = await build();
    store.fail = true;
    await expectLater(writer.publishRevision(package), throwsStateError);
    expect(storage.writes, isEmpty);
  });

  test(
    'partial payload publication consumes its reservation across recreation',
    () async {
      final package = await build();
      storage.failSuffix = '/1.json';
      await expectLater(writer.publishRevision(package), throwsStateError);
      expect(
        storage.files.keys.any((path) => path.endsWith('/1.bsexport')),
        isTrue,
      );
      expect(
        storage.files.keys.any((path) => path.endsWith('/1.json')),
        isFalse,
      );
      storage.failSuffix = null;
      final recreated = SyncPublicationWriter(
        storage: storage,
        identity: identity,
        sequences: SyncPublicationSequences(store: store, mutations: mutations),
      );
      final second = await recreated.publishRevision(package);
      expect(second.revision, 2);
      expect(storage.files.containsKey(second.descriptorPath), isTrue);
      expect(storage.deletes, 0);
    },
  );

  test(
    'missing payload cannot be advertised as a committed revision',
    () async {
      final revision = await writer.publishRevision(await build());
      storage.files.remove(revision.payloadPath);
      await expectLater(
        writer.publishCatalog(name: 'Publisher', entries: [active(revision)]),
        throwsFormatException,
      );
      expect(
        storage.files.keys.any((path) => path.contains('/catalog/')),
        isFalse,
      );
    },
  );

  test('catalog intent rejects stale revision and implicit omission', () async {
    final one = await writer.publishRevision(await build());
    final two = await writer.publishRevision(await build());
    await writer.publishCatalog(name: 'Publisher', entries: [active(two)]);
    await expectLater(
      writer.publishCatalog(name: 'Publisher', entries: [active(one)]),
      throwsA(isA<SyncReplayRejected>()),
    );
    await expectLater(
      writer.publishCatalog(name: 'Publisher', entries: []),
      throwsFormatException,
    );
    final withdrawn = SyncCatalogEntry(
      id: collection,
      name: 'Source',
      state: SyncPublicationState.withdrawn,
      revision: two,
    );
    await writer.publishCatalog(name: 'Publisher', entries: [withdrawn]);
    await expectLater(
      writer.publishCatalog(name: 'Publisher', entries: [active(two)]),
      throwsA(isA<SyncReplayRejected>()),
    );
  });

  test('missing package is unavailable; prepared old catalog cannot commit after newer observation', () async {
    final revision = await writer.publishRevision(await build());
    final one = await writer.publishCatalog(
      name: 'Publisher',
      entries: [active(revision)],
    );
    final ticket = await accept(one);
    final prepare = SyncReceivePreparation(
      storage: storage,
      fs: fs,
      codec: codec,
    );
    final prepared = await prepare.prepare(
      catalog: ticket,
      collection: collection,
      publisherKey: identity.publicKey,
    );
    final newer = await writer.publishCatalog(
      name: 'New label',
      entries: [active(revision)],
    );
    await accept(newer);
    var applied = false;
    await expectLater(
      SyncCatalogGate(store: store, mutations: mutations).withCurrentCatalog(
        prepared!.catalog,
        () async {
          applied = true;
        },
      ),
      throwsA(isA<SyncReplayRejected>()),
    );
    expect(applied, isFalse);
    storage.files.remove(revision.payloadPath);
    expect(
      await prepare.prepare(
        catalog: await accept(newer),
        collection: collection,
        publisherKey: identity.publicKey,
      ),
      isNull,
    );
    expect(storage.deletes, 0);
  });

  test('concurrent durable reservations are unique and survive new sequence service', () async {
    final sequences = SyncPublicationSequences(
      store: store,
      mutations: mutations,
    );
    final numbers = await Future.wait([
      for (var i = 0; i < 20; i++)
        sequences.reserve(identity.id, collection: collection),
    ]);
    expect(numbers.toSet().length, 20);
    expect(
      await SyncPublicationSequences(
        store: store,
        mutations: mutations,
      ).reserve(identity.id, collection: collection),
      21,
    );
  });
}

final class _Store implements MiscDataStore {
  final values = <String, String>{};
  var fail = false;
  @override
  String? get(String key) => values[key];
  @override
  Future<void> put(String key, String value) async {
    if (fail) throw StateError('Checkpoint unavailable');
    values[key] = value;
  }
}

final class _Storage implements FolderSyncStorage {
  final files = <String, Uint8List>{};
  final writes = <String>[];
  String? failSuffix;
  var deletes = 0;
  @override
  Future<void> writeImmutable(String path, Uint8List bytes) async {
    if (failSuffix != null && path.endsWith(failSuffix!)) {
      throw StateError('Partial publication');
    }
    final prior = files[path];
    if (prior != null && syncDigest(prior) != syncDigest(bytes)) {
      throw const SyncConflict();
    }
    files[path] = Uint8List.fromList(bytes);
    writes.add(path);
  }

  @override
  Future<Uint8List?> read(
    String path, {
    int maxBytes = folderSyncMaxBytes,
  }) => Future.value(files[path]);
  @override
  Future<List<String>> list(String path) =>
      throw StateError('No discovery needed');
  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) {
    deletes++;
    return Future.error(StateError('No deletion authority'));
  }
}

final class _CountingFileSystem extends IoFileSystem {
  var directories = 0;
  @override
  Future<String> createTempDirectory(String prefix) {
    directories++;
    return super.createTempDirectory(prefix);
  }
}
