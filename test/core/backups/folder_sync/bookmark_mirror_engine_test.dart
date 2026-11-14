import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:boorusama/boorus/pixiv/posts/post_codec.dart';
import 'package:boorusama/boorus/pixiv/works/bookmark_targets.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/backups/folder_sync/bookmark_mirror_engine.dart';
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
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/backups/folder_sync/service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:i18n/i18n.dart';
import 'package:boorusama/core/backups/folder_sync/page.dart';
import 'package:boorusama/core/backups/folder_sync/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:hive_ce/hive.dart';

import '../../../boorus/pixiv/works/work_test_fixtures.dart';

void main() {
  late Directory directory;
  late BookmarkHiveRepository repository;
  late UnifiedBookmarkGroupRepository groups;
  late BookmarkLibraryService library;
  late SyncBookmarkMirrorEngine engine;
  late SyncSigningIdentity identity;
  late SyncPublicationWriter writer;
  late DirectoryFolderSyncStorage shared;
  late SyncCatalogGate gate;
  final codec = BookmarkBackupCodec(
    postDataCodec: (_) => const PixivPostCodec(),
  );
  const parent = '11111111-2222-4333-8444-555555555555';
  const child = '22222222-2222-4333-8444-555555555555';
  final at = DateTime.utc(2026, 11, 14);
  late Bookmark workRecord;
  late Bookmark pageRecord;

  Future<SyncRevision> publish(String id, List<Bookmark> records) async {
    final data = BookmarkBackupData.unified(
      records: records,
      groups: [
        BookmarkGroupBackup(
          id: id,
          name: id,
          bookmarkIds: records.map((record) => record.id).toList(),
          addedAt: {for (final record in records) record.id: at},
        ),
      ],
    );
    final package =
        await SyncBookmarkPackageBuilder(
          fs: const IoFileSystem(),
          codec: codec,
        ).build(
          collection: SyncCollectionId(
            publisher: identity.id,
            kind: 'bookmarks',
            source: id,
          ),
          data: data,
          appVersion: '4.6.1',
          createdAt: at,
        );
    return writer.publishRevision(package);
  }

  Future<VerifiedSyncCatalog> advertise(
    SyncRevision a,
    SyncRevision b, {
    SyncPublicationState parentState = SyncPublicationState.active,
    String childName = 'B',
  }) async {
    final catalog = await writer.publishCatalog(
      name: 'Publisher',
      entries: [
        SyncCatalogEntry(
          id: a.collection,
          name: 'A',
          state: parentState,
          revision: a,
        ),
        SyncCatalogEntry(
          id: b.collection,
          name: childName,
          parent: parent,
          state: SyncPublicationState.active,
          revision: b,
        ),
      ],
    );
    final bytes = await shared.read(catalog.path);
    return gate.verifyAndCheckpoint(
      publisher: identity.id,
      expectedSequence: catalog.sequence,
      bytes: bytes!,
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sync_engine_');
    Hive.init('${directory.path}/local');
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    final coordinator = DataMutationCoordinator();
    final posts = await Hive.openBox<BookmarkHiveObject>('posts');
    final metadata = await Hive.openBox<dynamic>('metadata');
    repository = BookmarkHiveRepository(
      posts,
      groupPayloadBox: await Hive.openBox<dynamic>('payloads'),
      metadataBox: metadata,
      coordinator: coordinator,
      postDataCodec: (_) => const PixivPostCodec(),
    );
    final reader = await BookmarkStorageMigration(
      bookmarks: repository,
      legacyGroups: await Hive.openBox<BookmarkGroupHiveObject>('legacy'),
      legacyOrganization: await Hive.openBox<dynamic>('organization'),
      metadata: metadata,
    ).open();
    groups = UnifiedBookmarkGroupRepository(
      bookmarks: repository,
      reader: reader,
    );
    library = BookmarkLibraryService(
      bookmarkRepository: repository,
      groupRepository: groups,
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    );
    await library.load();
    identity = await SyncSigningIdentity.create();
    final appStore = _Store();
    shared = DirectoryFolderSyncStorage('${directory.path}/shared');
    gate = SyncCatalogGate(store: appStore, mutations: coordinator);
    await gate.approvePublisher(
      publisher: identity.id,
      publicKey: identity.publicKey,
    );
    writer = SyncPublicationWriter(
      identity: identity,
      storage: shared,
      sequences: SyncPublicationSequences(
        store: appStore,
        mutations: coordinator,
      ),
    );
    engine = SyncBookmarkMirrorEngine(
      store: repository,
      groups: groups,
      gate: gate,
      preparation: SyncReceivePreparation(
        storage: shared,
        fs: const IoFileSystem(),
        codec: codec,
      ),
      now: () => at,
    );
    final access = workAccess();
    workRecord = PixivWorkBookmarkTarget(
      access: access,
      summary: pixivWorkSummary(work(), access),
    ).draft(currentAccess: access, at: at);
    pageRecord = PixivPageBookmarkTarget(
      access: access,
      post: pixivWorkPagePosts(work(), access)[2],
    ).draft(currentAccess: access, at: at).copyWith(id: 1);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'two independent Hive libraries exchange Groups without publication echoes',
    () async {
      final metadata = await Hive.openBox<dynamic>('device_b_metadata');
      final other = BookmarkHiveRepository(
        await Hive.openBox<BookmarkHiveObject>('device_b_posts'),
        groupPayloadBox: await Hive.openBox<dynamic>('device_b_payloads'),
        metadataBox: metadata,
        coordinator: DataMutationCoordinator(),
        postDataCodec: (_) => const PixivPostCodec(),
      );
      final reader = await BookmarkStorageMigration(
        bookmarks: other,
        legacyGroups: await Hive.openBox<BookmarkGroupHiveObject>(
          'device_b_legacy',
        ),
        legacyOrganization: await Hive.openBox<dynamic>('device_b_folders'),
        metadata: metadata,
      ).open();
      final otherGroups = UnifiedBookmarkGroupRepository(
        bookmarks: other,
        reader: reader,
      );
      final otherLibrary = BookmarkLibraryService(
        bookmarkRepository: other,
        groupRepository: otherGroups,
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      );
      await otherLibrary.load();
      final ga = (await library.createGroupWithSavedRecords(
        'A local',
        const [],
        drafts: [workRecord],
      )).group;
      final gb = (await otherLibrary.createGroupWithSavedRecords(
        'B local',
        const [],
        drafts: [pageRecord],
      )).group;
      Future<FolderSyncService> device(
        BookmarkHiveRepository store,
        UnifiedBookmarkGroupRepository organization,
      ) async => FolderSyncService(
        preferences: _Store(),
        store: store,
        groups: organization,
        fs: const IoFileSystem(),
        codec: codec,
        storageFor: (location) async => DirectoryFolderSyncStorage(location),
        identity: await SyncSigningIdentity.create(),
        mutations: store.coordinator,
      );
      final a = await device(repository, groups);
      final b = await device(other, otherGroups);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final path = '${directory.path}/two_devices';
      await a.configure(path, deviceName: 'Device A');
      await a.publishRoots({ga.id});
      await b.configure(path, deviceName: 'Device B');
      await b.publishRoots({gb.id});
      await a.synchronize();
      await a.approve(a.devices.single);
      await b.synchronize();
      await b.approve(b.devices.single);
      await a.subscribe(b.identity.id, {gb.id});
      await b.subscribe(a.identity.id, {ga.id});
      final sa = await library.load();
      var sb = await otherLibrary.load();
      expect(sa.mirrors.owners, hasLength(1));
      expect(sb.mirrors.owners, hasLength(1));
      expect(sa.records, hasLength(2));
      expect(sb.records, hasLength(2));
      expect(sa.bookmarkIdsForView(const BookmarkView.all()), ga.bookmarkIds);
      expect(sb.bookmarkIdsForView(const BookmarkView.all()), gb.bookmarkIds);
      final storage = DirectoryFolderSyncStorage(path);
      final ca = await storage.list('devices/${a.identity.id}/catalog');
      final cb = await storage.list('devices/${b.identity.id}/catalog');
      await a.synchronize();
      await b.synchronize();
      await a.synchronize();
      expect(await storage.list('devices/${a.identity.id}/catalog'), ca);
      expect(await storage.list('devices/${b.identity.id}/catalog'), cb);
      final received = sb.mirrors.localIdFor(a.identity.id, ga.id)!;
      final reading = SyncGroupReadingState.fromJson(
        sb.mirrors.owners[received]!.reading,
      );
      await b.markRead(received, reading.members);
      await groups.renameGroup(ga.id, 'A renamed');
      await a.synchronize();
      await b.synchronize();
      sb = await otherLibrary.load();
      expect(sb.groupsById[received]!.name, 'A renamed');
      expect(
        SyncGroupReadingState.fromJson(sb.mirrors.owners[received]!.reading)
            .readMembers,
        reading.members,
      );
    },
  );

  for (final rollbackTombstone in [false, true]) {
    test(
      'tombstones bind skipped source revisions (stale tombstone=$rollbackTombstone)',
      () async {
        final old = await publish(parent, [workRecord]);
        final b = await publish(child, [pageRecord]);
        await engine.receive(
          ticket: await advertise(old, b),
          publisherKey: identity.publicKey,
          directRoots: {parent},
        );
        final middle = await publish(parent, [workRecord, pageRecord]);
        if (rollbackTombstone) {
          await engine.receive(
            ticket: await advertise(middle, b),
            publisherKey: identity.publicKey,
          );
        }
        var latest = middle;
        for (var i = 0; i < 3; i++) {
          latest = await publish(parent, [workRecord, pageRecord]);
        }
        final sequence = await writer.sequences.reserve(identity.id);
        final tombstone = SyncCatalog(
          publisher: identity.id,
          sequence: sequence,
          name: 'Publisher',
          entries: [
            SyncCatalogEntry(
              id: old.collection,
              name: 'A',
              state: SyncPublicationState.deleted,
              revision: rollbackTombstone ? old : latest,
            ),
            SyncCatalogEntry(
              id: b.collection,
              name: 'B',
              state: SyncPublicationState.active,
              revision: b,
              parent: parent,
            ),
          ],
        );
        final ticket = await gate.verifyAndCheckpoint(
          publisher: identity.id,
          expectedSequence: sequence,
          bytes: await identity.sign(tombstone.toJson()),
        );
        final before = await repository.readMirrorState();
        if (rollbackTombstone) {
          await expectLater(
            engine.receive(ticket: ticket, publisherKey: identity.publicKey),
            throwsA(isA<SyncReplayRejected>()),
          );
          expect(await repository.readMirrorState(), before);
        } else {
          await engine.receive(
            ticket: ticket,
            publisherKey: identity.publicKey,
          );
          final after = await repository.readMirrorState();
          expect(after.owners, isEmpty);
          expect(
            after.checkpoints['${identity.id}/$parent']!.revision,
            latest.revision,
          );
          // Middle was never applied; it is still older than the signed deletion.
          final next = await writer.sequences.reserve(identity.id);
          final revived = SyncCatalog(
            publisher: identity.id,
            sequence: next,
            name: 'Publisher',
            entries: [
              SyncCatalogEntry(
                id: middle.collection,
                name: 'A',
                state: SyncPublicationState.active,
                revision: middle,
              ),
              SyncCatalogEntry(
                id: b.collection,
                name: 'B',
                state: SyncPublicationState.active,
                revision: b,
                parent: parent,
              ),
            ],
          );
          final retry = await gate.verifyAndCheckpoint(
            publisher: identity.id,
            expectedSequence: next,
            bytes: await identity.sign(revived.toJson()),
          );
          await expectLater(
            engine.receive(ticket: retry, publisherKey: identity.publicKey),
            throwsA(isA<SyncReplayRejected>()),
          );
          expect(await repository.readMirrorState(), after);
        }
      },
    );
  }

  testWidgets(
    'setup entry and device naming fit narrow enlarged text with keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 760);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = (await tester.runAsync(library.load))!;
      final service = FolderSyncService(
        preferences: gate.store,
        store: repository,
        groups: groups,
        fs: const IoFileSystem(),
        codec: codec,
        storageFor: (_) async =>
            throw StateError('Opening UI must not access transport'),
        identity: identity,
        mutations: repository.coordinator,
      );
      addTearDown(service.dispose);
      Widget app(String? section) => ProviderScope(
        overrides: [
          folderSyncServiceProvider.overrideWith((_) async => service),
          bookmarkProvider.overrideWith(() => _SnapshotLibrary(state)),
        ],
        child: BooruLocalization(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.7)),
              child: KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: child!,
              ),
            ),
            home: FolderSyncPage(section: section),
          ),
        ),
      );
      await tester.pumpWidget(app('publish'));
      await tester.pumpAndSettle();
      expect(
        find.text(Translations().folder_sync.choose_folder),
        findsOneWidget,
      );
      expect(service.configured, isFalse);
      expect(service.failure, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(null));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Translations().folder_sync.device_name));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.enterText(find.byType(TextField), 'My local device');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(Translations().generic.action.save));
      final renamed = Completer<void>();
      void changed() {
        if (service.name == 'My local device' &&
            !service.busy &&
            !renamed.isCompleted)
          renamed.complete();
      }

      service.addListener(changed);
      await tester.tap(find.text(Translations().generic.action.save));
      await tester.pumpAndSettle();
      // Hive's coordinator was opened outside FakeAsync. Alternate event-loop
      // completion and frame pumping until both scheduler domains are drained.
      for (var turn = 0; turn < 100 && !renamed.isCompleted; turn++) {
        await tester.runAsync(() => Future<void>(() {}));
        await tester.pump();
      }
      expect(
        renamed.isCompleted,
        isTrue,
        reason: 'Save must complete its coordinated preference write',
      );
      service.removeListener(changed);
      tester.view.resetViewInsets();
      expect(service.name, 'My local device');
      expect(service.configured, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'Subscribe only adds roots even when a caller supplies a stale subset',
    () async {
      final a = await publish(parent, [workRecord]);
      final b = await publish(child, [pageRecord]);
      final ticket = await advertise(a, b);
      await engine.receive(
        ticket: ticket,
        publisherKey: identity.publicKey,
        directRoots: {parent},
      );
      final before = await repository.readMirrorState();
      await engine.receive(
        ticket: ticket,
        publisherKey: identity.publicKey,
        directRoots: {child},
      );
      final after = await repository.readMirrorState();
      expect(after.subscriptions[identity.id], {parent, child});
      expect(
        after.localIdFor(identity.id, parent),
        before.localIdFor(identity.id, parent),
      );
      expect(after.owners, hasLength(2));
    },
  );

  test('source revision high-water survives unsubscribe and rejects resurrection rollback', () async {
    final a = await publish(parent, [workRecord]);
    final b = await publish(child, [pageRecord]);
    await engine.receive(
      ticket: await advertise(a, b),
      publisherKey: identity.publicKey,
      directRoots: {parent},
    );
    final newer = await publish(parent, [workRecord, pageRecord]);
    await engine.receive(
      ticket: await advertise(newer, b),
      publisherKey: identity.publicKey,
    );
    await engine.unsubscribe(identity.id, parent);
    final before = await repository.readMirrorState();
    expect(before.owners, isEmpty);
    expect(
      before.checkpoints['${identity.id}/$parent']!.revision,
      newer.revision,
    );
    final sequence = await writer.sequences.reserve(identity.id);
    final stale = SyncCatalog(
      publisher: identity.id,
      sequence: sequence,
      name: 'Publisher',
      entries: [
        SyncCatalogEntry(
          id: a.collection,
          name: 'A',
          state: SyncPublicationState.active,
          revision: a,
        ),
        SyncCatalogEntry(
          id: b.collection,
          name: 'B',
          state: SyncPublicationState.active,
          revision: b,
          parent: parent,
        ),
      ],
    );
    final ticket = await gate.verifyAndCheckpoint(
      publisher: identity.id,
      expectedSequence: sequence,
      bytes: await identity.sign(stale.toJson()),
    );
    await expectLater(
      engine.receive(
        ticket: ticket,
        publisherKey: identity.publicKey,
        directRoots: {parent},
      ),
      throwsA(isA<SyncReplayRejected>()),
    );
    expect(await repository.readMirrorState(), before);
  });

  test(
    'disposed service cannot apply a transport scan after replacement',
    () async {
      final a = await publish(parent, [workRecord]);
      final b = await publish(child, [pageRecord]);
      await advertise(a, b);
      final receiver = await SyncSigningIdentity.create();
      final paused = _PausedStorage(shared);
      var reloads = 0;
      FolderSyncService service(FolderSyncStorage storage) => FolderSyncService(
        preferences: gate.store,
        store: repository,
        groups: groups,
        fs: const IoFileSystem(),
        codec: codec,
        storageFor: (_) async => storage,
        identity: receiver,
        mutations: repository.coordinator,
        onApplied: () async {
          reloads++;
        },
      );
      final old = service(paused);
      final pending = old.configure('${directory.path}/shared');
      final rejected = expectLater(pending, throwsStateError);
      await paused.entered.future;
      old.dispose();
      final replacement = service(shared);
      addTearDown(replacement.dispose);
      paused.resume.complete();
      await rejected;
      expect(reloads, 0);
      expect((await repository.readMirrorState()).owners, isEmpty);
      await replacement.synchronize();
      expect(replacement.devices.single.id, identity.id);
    },
  );

  test('overlap, offline unsubscribe, independent reading, local copy and Forget preserve ownership', () async {
    final a = await publish(parent, [workRecord]);
    final b = await publish(child, [workRecord, pageRecord]);
    final ticket = await advertise(a, b);
    await engine.receive(
      ticket: ticket,
      publisherKey: identity.publicKey,
      directRoots: {child},
    );
    var state = await library.load();
    final bId = state.mirrors.localIdFor(identity.id, child)!;
    expect(bId, isNot(child));
    expect(state.localBookmarkIds, isEmpty);
    await engine.receive(
      ticket: ticket,
      publisherKey: identity.publicKey,
      directRoots: {parent, child},
    );
    state = await library.load();
    final aId = state.mirrors.localIdFor(identity.id, parent)!;
    expect(state.mirrors.owners, hasLength(2));
    expect(state.records, hasLength(2));
    expect(state.groupsById[bId]!.parentGroupId, aId);
    expect(state.mirrors.subscriptions[identity.id], {parent, child});
    final before = SyncGroupReadingState.fromJson(
      state.mirrors.owners[bId]!.reading,
    );
    await engine.acknowledgeArrival(bId, before.revision);
    var reading = SyncGroupReadingState.fromJson(
      (await repository.readMirrorState()).owners[bId]!.reading,
    );
    expect(reading.arrivals, isEmpty);
    expect(reading.unreadMembers, hasLength(2));
    await engine.markRead(bId, {reading.members.first});
    reading = SyncGroupReadingState.fromJson(
      (await repository.readMirrorState()).owners[bId]!.reading,
    );
    expect(reading.unreadMembers, hasLength(1));
    expect(
      SyncGroupReadingState.fromJson(
        (await repository.readMirrorState()).owners[aId]!.reading,
      ).unreadMembers,
      hasLength(1),
    );
    await engine.unsubscribe(identity.id, child);
    expect((await library.load()).groupsById[bId]!.parentGroupId, aId);
    await engine.receive(
      ticket: ticket,
      publisherKey: identity.publicKey,
      directRoots: {parent, child},
    );
    await engine.unsubscribe(identity.id, parent);
    state = await library.load();
    expect(state.mirrors.owners.keys, {bId});
    expect(state.groupsById[bId]!.parentGroupId, isNull);
    final copy = await engine.createLocalCopy(bId);
    await groups.renameGroup(copy.id, 'Editable copy');
    await engine.forgetDevice(identity.id);
    state = await library.load();
    expect(state.mirrors.owners, isEmpty);
    expect(state.groupsById[copy.id]!.name, 'Editable copy');
    expect(
      state.bookmarkIdsForView(const BookmarkView.all()),
      copy.bookmarkIds,
    );
    expect(state.records, hasLength(2));
  });

  test('missing new payload and stale prepared catalog never delete usable mirrors', () async {
    final a = await publish(parent, [workRecord]);
    final b = await publish(child, [workRecord, pageRecord]);
    final first = await advertise(a, b);
    await engine.receive(
      ticket: first,
      publisherKey: identity.publicKey,
      directRoots: {parent},
    );
    final before = await repository.readMirrorState();
    final updated = await publish(child, [pageRecord]);
    final newer = await advertise(a, updated);
    final path = File('${shared.root.path}/${updated.payloadPath}');
    final bytes = await path.readAsBytes();
    await path.delete();
    await expectLater(
      engine.receive(ticket: newer, publisherKey: identity.publicKey),
      throwsA(isA<SyncRevisionUnavailable>()),
    );
    expect(await repository.readMirrorState(), before);
    await expectLater(
      engine.receive(ticket: first, publisherKey: identity.publicKey),
      throwsA(isA<SyncReplayRejected>()),
    );
    expect(await repository.readMirrorState(), before);
    await path.writeAsBytes(bytes);
    await engine.receive(ticket: newer, publisherKey: identity.publicKey);
    final state = await library.load();
    expect(state.records, hasLength(2));
    expect(
      state
          .groupsById[state.mirrors.localIdFor(identity.id, child)]!
          .bookmarkIds,
      hasLength(1),
    );
  });

  for (final schema in [10, 11]) {
    test(
      'same applied bytes cannot bypass schema or descriptor checks: $schema',
      () async {
        final a = await publish(parent, [workRecord]);
        final b = await publish(child, [pageRecord]);
        final first = await advertise(a, b);
        await engine.receive(
          ticket: first,
          publisherKey: identity.publicKey,
          directRoots: {parent},
        );
        final before = await repository.readMirrorState();
        final changed = SyncRevision.fromJson({
          ...b.toJson(),
          'schema': schema,
          'semanticHash': 'f' * 64,
        });
        final catalog = SyncCatalog(
          publisher: identity.id,
          sequence: await writer.sequences.reserve(identity.id),
          name: 'Publisher',
          entries: [
            SyncCatalogEntry(
              id: a.collection,
              name: 'A',
              state: SyncPublicationState.active,
              revision: a,
            ),
            SyncCatalogEntry(
              id: b.collection,
              name: 'Changed',
              parent: parent,
              state: SyncPublicationState.active,
              revision: changed,
            ),
          ],
        );
        final bytes = await identity.sign(catalog.toJson());
        final ticket = await gate.verifyAndCheckpoint(
          publisher: identity.id,
          expectedSequence: catalog.sequence,
          bytes: bytes,
        );
        await expectLater(
          engine.receive(ticket: ticket, publisherKey: identity.publicKey),
          throwsA(
            schema == 11
                ? isA<SyncUpdateRequired>()
                : isA<SyncReplayRejected>(),
          ),
        );
        expect(await repository.readMirrorState(), before);
      },
    );
  }

  test('signed newer snapshot refreshes received-only content with stable local identity', () async {
    final a = await publish(parent, [workRecord]);
    final b = await publish(child, [pageRecord]);
    await engine.receive(
      ticket: await advertise(a, b),
      publisherKey: identity.publicKey,
      directRoots: {child},
    );
    final before = (await library.load()).items.single;
    final access = workAccess();
    final changed = PixivPageBookmarkTarget(
      access: access,
      post: (pageRecord as PostBookmark).post.withDetailFacts(
        const PostDetailFacts(description: 'Updated source snapshot'),
      ),
    ).draft(currentAccess: access, at: at).copyWith(id: 1);
    final next = await publish(child, [changed]);
    await engine.receive(
      ticket: await advertise(a, next),
      publisherKey: identity.publicKey,
    );
    final after = (await library.load()).items.single;
    expect(after.id, before.id);
    expect(after.post.detailFacts.description, 'Updated source snapshot');
  });

  test(
    'verified deleted tombstone removes only uncovered mirror data',
    () async {
      final a = await publish(parent, [workRecord]);
      final b = await publish(child, [pageRecord]);
      await engine.receive(
        ticket: await advertise(a, b),
        publisherKey: identity.publicKey,
        directRoots: {parent, child},
      );
      final childId = (await repository.readMirrorState()).localIdFor(
        identity.id,
        child,
      );
      await engine.receive(
        ticket: await advertise(
          a,
          b,
          parentState: SyncPublicationState.deleted,
        ),
        publisherKey: identity.publicKey,
      );
      final state = await library.load();
      expect(state.mirrors.owners.keys, {childId});
      expect(state.records, hasLength(1));
      final sequence = await writer.sequences.reserve(identity.id);
      final stale = SyncCatalog(
        publisher: identity.id,
        sequence: sequence,
        name: 'Publisher',
        entries: [
          SyncCatalogEntry(
            id: a.collection,
            name: 'A',
            state: SyncPublicationState.active,
            revision: a,
          ),
          SyncCatalogEntry(
            id: b.collection,
            name: 'B',
            state: SyncPublicationState.active,
            revision: b,
            parent: parent,
          ),
        ],
      );
      final ticket = await gate.verifyAndCheckpoint(
        publisher: identity.id,
        expectedSequence: sequence,
        bytes: await identity.sign(stale.toJson()),
      );
      await expectLater(
        engine.receive(ticket: ticket, publisherKey: identity.publicKey),
        throwsA(isA<SyncReplayRejected>()),
      );
      expect(await repository.readMirrorState(), state.mirrors);
    },
  );

  test(
    'discovery, trusted subscription and relocation use real repositories',
    () async {
      final a = await publish(parent, [workRecord]);
      final b = await publish(child, [pageRecord]);
      await advertise(a, b);
      final receiverIdentity = await SyncSigningIdentity.create();
      final preferences = gate.store;
      final service = FolderSyncService(
        preferences: preferences,
        store: repository,
        groups: groups,
        fs: const IoFileSystem(),
        codec: codec,
        storageFor: (path) async => DirectoryFolderSyncStorage(path),
        identity: receiverIdentity,
        mutations: repository.coordinator,
        now: () => at,
      );
      addTearDown(service.dispose);
      await service.configure('${directory.path}/shared');
      expect(service.devices.single.id, identity.id);
      await service.subscribe(identity.id, {parent});
      final before = await repository.readMirrorState();
      final relocated = '${directory.path}/relocated';
      await service.configure(relocated);
      expect(await repository.readMirrorState(), before);
      expect(service.gate.approvedKey(identity.id), identity.publicKey);
      expect(service.identity.id, receiverIdentity.id);
      final copy = await service.localCopy(
        before.localIdFor(identity.id, child)!,
      );
      await service.publishRoots({copy.id});
      final catalogFiles = await DirectoryFolderSyncStorage(relocated)
          .list('devices/${receiverIdentity.id}/catalog');
      expect(catalogFiles, isNotEmpty);
      final count = catalogFiles.length;
      await service.synchronize();
      expect(
        (await DirectoryFolderSyncStorage(relocated)
                .list('devices/${receiverIdentity.id}/catalog'))
            .length,
        count,
      );
      final catalogFile = File(
        '$relocated/v1/devices/${receiverIdentity.id}/catalog/${catalogFiles.last}',
      );
      await catalogFile.writeAsString('{');
      await service.synchronize();
      expect(
        (await DirectoryFolderSyncStorage(relocated)
                .list('devices/${receiverIdentity.id}/catalog'))
            .length,
        count + 1,
      );
      expect(await catalogFile.readAsString(), '{');
      await service.forget(identity.id);
      expect((await library.load()).groupsById.containsKey(copy.id), isTrue);
    },
  );

  test(
    'verified parent withdrawal retains an independently subscribed child',
    () async {
      final a = await publish(parent, [workRecord]);
      final b = await publish(child, [pageRecord]);
      final first = await advertise(a, b);
      await engine.receive(
        ticket: first,
        publisherKey: identity.publicKey,
        directRoots: {parent, child},
      );
      final bId = (await repository.readMirrorState()).localIdFor(
        identity.id,
        child,
      )!;
      final stopped = await advertise(
        a,
        b,
        parentState: SyncPublicationState.withdrawn,
        childName: 'Renamed B',
      );
      await engine.receive(ticket: stopped, publisherKey: identity.publicKey);
      final state = await library.load();
      expect(state.mirrors.owners.keys, {bId});
      expect(state.groupsById[bId]!.name, 'Renamed B');
      expect(state.groupsById[bId]!.parentGroupId, isNull);
      expect(state.records, hasLength(1));
    },
  );
}

final class _Store implements MiscDataStore {
  final values = <String, String>{};
  @override
  String? get(String key) => values[key];
  @override
  Future<void> put(String key, String value) async {
    values[key] = value;
  }
}

class _PausedStorage implements FolderSyncStorage {
  _PausedStorage(this.delegate);
  final FolderSyncStorage delegate;
  final entered = Completer<void>();
  final resume = Completer<void>();
  @override
  Future<List<String>> list(String path) async {
    if (path == 'devices') {
      entered.complete();
      await resume.future;
    }
    return delegate.list(path);
  }

  @override
  Future<Uint8List?> read(String path, {int maxBytes = folderSyncMaxBytes}) =>
      delegate.read(path, maxBytes: maxBytes);
  @override
  Future<void> writeImmutable(String path, Uint8List bytes) =>
      delegate.writeImmutable(path, bytes);
  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) =>
      delegate.deleteOwnedRevision(path, owner: owner);
}

class _SnapshotLibrary extends BookmarkLibraryNotifier {
  _SnapshotLibrary(this.snapshot);
  final BookmarkLibraryState snapshot;
  @override
  Future<BookmarkLibraryState> build() async => snapshot;
}
