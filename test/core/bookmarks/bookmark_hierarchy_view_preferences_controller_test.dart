import 'dart:async';

import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_view_preferences.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:hive_ce/hive.dart';

class _OperationGate {
  final entered = Completer<void>();
  final release = Completer<void>();

  Future<void> pause() async {
    entered.complete();
    await release.future;
  }
}

class _GatedBookmarkHiveRepository extends BookmarkHiveRepository {
  _GatedBookmarkHiveRepository(
    Box<BookmarkHiveObject> posts, {
    required super.groupPayloadBox,
    required super.metadataBox,
    required super.coordinator,
    required super.legacyGroupBoxName,
    required super.legacyOrganizationBoxName,
  }) : super(posts);

  _OperationGate? revisionGate;
  _OperationGate? committedGate;
  var admittedGroupCommits = 0;
  var completedReadAll = 0;
  final groupCommitCounts = <String, int>{};

  @override
  Future<List<Bookmark>> readAll() async {
    final records = await super.readAll();
    completedReadAll++;
    return records;
  }

  @override
  Future<int> readRevision() async {
    final revision = await super.readRevision();
    final gate = revisionGate;
    revisionGate = null;
    if (gate != null) await gate.pause();
    return revision;
  }

  @override
  Future<void> commitOrganization({
    Iterable<Bookmark> records = const [],
    Set<int> removeIds = const {},
    List<BookmarkGroup> groups = const [],
    Set<String> removeGroupIds = const {},
    List<CollectionFolder>? folders,
  }) async {
    await super.commitOrganization(
      records: records,
      removeIds: removeIds,
      groups: groups,
      removeGroupIds: removeGroupIds,
      folders: folders,
    );
    for (final group in groups) {
      groupCommitCounts.update(
        group.name,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    if (groups.any((group) => group.name == 'Admitted')) {
      admittedGroupCommits++;
      final gate = committedGate;
      committedGate = null;
      if (gate != null) await gate.pause();
    }
  }
}

class _Store implements MiscDataStore {
  final values = <String, String>{};
  bool failNext = false;
  @override
  String? get(String key) => values[key];
  @override
  Future<void> put(String key, String value) async {
    if (failNext) {
      failNext = false;
      throw StateError('Fixture UI preference write failed');
    }
    values[key] = value;
  }
}

void main() {
  late Directory directory;
  late _GatedBookmarkHiveRepository repository;
  late BookmarkGroupRepository groups;
  late DataMutationCoordinator coordinator;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hierarchy-controller-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    final posts = await Hive.openBox<BookmarkHiveObject>('posts');
    final payloads = await Hive.openBox<dynamic>('posts_unified_payloads');
    final metadata = await Hive.openBox<dynamic>('posts_unified_metadata');
    await Hive.openBox<BookmarkGroupHiveObject>('groups');
    final organization = await Hive.openBox<dynamic>('organization');
    await organization.put('version', 1);
    await organization.put('poolBookmarks', []);
    coordinator = DataMutationCoordinator();
    repository = _GatedBookmarkHiveRepository(
      posts,
      groupPayloadBox: payloads,
      metadataBox: metadata,
      coordinator: coordinator,
      legacyGroupBoxName: 'groups',
      legacyOrganizationBoxName: 'organization',
    );
    groups = await repository.openOrganization();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  ProviderContainer createContainer(_Store store) {
    final container = ProviderContainer(
      overrides: [
        miscDataStoreProvider.overrideWithValue(store),
        dataMutationCoordinatorProvider.overrideWithValue(coordinator),
        bookmarkRepoProvider.overrideWith((_) => repository),
        bookmarkGroupRepoProvider.overrideWith((_) => groups),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('snapshot waits for replacement loading before taking the storage coordinator', () async {
    final generation = StateProvider((_) => 0);
    final pending = Completer<BookmarkGroupRepository>();
    final container = ProviderContainer(
      overrides: [
        miscDataStoreProvider.overrideWithValue(_Store()),
        dataMutationCoordinatorProvider.overrideWithValue(coordinator),
        bookmarkRepoProvider.overrideWith((_) => repository),
        bookmarkGroupRepoProvider.overrideWith(
          (ref) => ref.watch(generation) == 0
              ? Future.value(groups)
              : pending.future,
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(bookmarkProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(bookmarkProvider.future);
    container.read(generation.notifier).state = 1;
    await container.pump();
    expect(container.read(bookmarkProvider).isLoading, isTrue);
    expect(container.read(bookmarkProvider).hasValue, isTrue);
    final snapshot = container
        .read(bookmarkProvider.notifier)
        .snapshotForExport();
    await container.pump();
    pending.complete(groups);
    final loaded = await snapshot.timeout(const Duration(seconds: 10));
    expect(loaded.groups.single.isDefault, isTrue);
  });

  test('queued snapshot yields the coordinator if its repository is invalidated before dispatch', () async {
    final generation = StateProvider((_) => 0);
    final pending = Completer<BookmarkGroupRepository>();
    final container = ProviderContainer(
      overrides: [
        miscDataStoreProvider.overrideWithValue(_Store()),
        dataMutationCoordinatorProvider.overrideWithValue(coordinator),
        bookmarkRepoProvider.overrideWith((_) => repository),
        bookmarkGroupRepoProvider.overrideWith(
          (ref) => ref.watch(generation) == 0
              ? Future.value(groups)
              : pending.future,
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(bookmarkProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(bookmarkProvider.future);
    final entered = Completer<void>();
    final release = Completer<void>();
    final holder = coordinator.runExclusive(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final snapshot = container
        .read(bookmarkProvider.notifier)
        .snapshotForExport();
    container.read(generation.notifier).state = 1;
    await container.pump();
    expect(container.read(bookmarkProvider).isLoading, isTrue);
    pending.complete(groups);
    await container.pump();
    release.complete();
    await holder;
    final loaded = await snapshot.timeout(const Duration(seconds: 10));
    expect(loaded.groups.single.isDefault, isTrue);
    expect(container.read(bookmarkProvider).isLoading, isFalse);
  });

  for (final afterCommit in [false, true]) {
    test(
      'admitted mutation survives dependency replacement ${afterCommit ? 'after durable domain commit' : 'after revision read'} without replay',
      () async {
        final generation = StateProvider((_) => 0);
        final pendingGroups = Completer<BookmarkGroupRepository>();
        final container = ProviderContainer(
          overrides: [
            miscDataStoreProvider.overrideWithValue(_Store()),
            dataMutationCoordinatorProvider.overrideWithValue(coordinator),
            bookmarkRepoProvider.overrideWith((_) => repository),
            bookmarkGroupRepoProvider.overrideWith(
              (ref) => ref.watch(generation) == 0
                  ? Future.value(groups)
                  : pendingGroups.future,
            ),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(bookmarkProvider, (_, _) {});
        addTearDown(subscription.close);
        await container.read(bookmarkProvider.future);
        final gate = _OperationGate();
        if (afterCommit) {
          repository.committedGate = gate;
        } else {
          repository.revisionGate = gate;
        }
        final operation = container
            .read(bookmarkProvider.notifier)
            .createGroup('Admitted');
        await gate.entered.future.timeout(const Duration(seconds: 10));
        expect(repository.admittedGroupCommits, afterCommit ? 1 : 0);

        // This continuation belongs to the test's root zone, not the admitted
        // operation. The new provider build must acquire the held coordinator.
        container.read(generation.notifier).state = 1;
        container.invalidate(bookmarkProvider);
        await container.pump();
        expect(container.read(bookmarkProvider).isLoading, true);
        pendingGroups.complete(coordinator.runExclusive(() async => groups));
        final rebuilt = container.read(bookmarkProvider.future);
        gate.release.complete();
        final result = await operation.timeout(const Duration(seconds: 10));
        final current = await rebuilt.timeout(const Duration(seconds: 10));
        expect(
          current.groups
              .where((group) => group.name == 'Admitted')
              .map((group) => group.id),
          [result.id],
        );
        expect(
          (await groups.getGroups())
              .where((group) => group.name == 'Admitted')
              .map((group) => group.id),
          [result.id],
        );
        expect(
          repository.admittedGroupCommits,
          1,
          reason: 'An admitted domain operation must never be replayed after dependency invalidation.',
        );
      },
    );
  }

  test('replacement initialization cannot borrow an admitted callback ownership zone', () async {
    final container = createContainer(_Store());
    final subscription = container.listen(bookmarkProvider, (_, _) {});
    addTearDown(subscription.close);
    final library = container.read(bookmarkProvider.notifier);
    await container.read(bookmarkProvider.future);
    final midway = Completer<void>();
    final finish = Completer<void>();
    late Future<BookmarkLibraryState> replacement;
    late int readsBeforeReplacement;
    final operation = library.runSerializedMutation(() async {
      await groups.createGroup('FirstGroup');
      readsBeforeReplacement = repository.completedReadAll;
      container.invalidate(bookmarkProvider);
      replacement = container.read(bookmarkProvider.future);
      midway.complete();
      await finish.future;
      await groups.createGroup('SecondGroup');
    });
    await midway.future.timeout(const Duration(seconds: 10));
    await container.pump();
    try {
      expect(container.read(bookmarkProvider).isLoading, true);
      expect(
        repository.completedReadAll,
        readsBeforeReplacement,
        reason: 'A replacement build must queue behind the admitted operation instead of borrowing its coordinator zone to read a half-committed domain.',
      );
    } finally {
      finish.complete();
    }
    await operation.timeout(const Duration(seconds: 10));
    final current = await replacement.timeout(const Duration(seconds: 10));
    for (final name in ['FirstGroup', 'SecondGroup']) {
      expect(current.groups.where((group) => group.name == name), hasLength(1));
      expect(
        (await groups.getGroups()).where((group) => group.name == name),
        hasLength(1),
      );
      expect(repository.groupCommitCounts[name], 1);
    }
  });

  test('outer library admission pins nested snapshots, creation and refresh across replacement', () async {
    final generation = StateProvider((_) => 0);
    final pendingGroups = Completer<BookmarkGroupRepository>();
    final container = ProviderContainer(
      overrides: [
        miscDataStoreProvider.overrideWithValue(_Store()),
        dataMutationCoordinatorProvider.overrideWithValue(coordinator),
        bookmarkRepoProvider.overrideWith((_) => repository),
        bookmarkGroupRepoProvider.overrideWith(
          (ref) => ref.watch(generation) == 0
              ? Future.value(groups)
              : pendingGroups.future,
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(bookmarkProvider, (_, _) {});
    addTearDown(subscription.close);
    final library = container.read(bookmarkProvider.notifier);
    await container.read(bookmarkProvider.future);
    final entered = Completer<void>();
    final release = Completer<void>();
    final operation = library.runWithLibrary(() async {
      expect(
        coordinator.isCurrentOwner,
        true,
        reason: 'Admission must pin the actual outer critical section, rather than only warm the library.',
      );
      entered.complete();
      await release.future;
      expect(identical(await library.bookmarkGroupRepository, groups), true);
      expect(identical(await library.bookmarkRepository, repository), true);
      final before = await library.snapshotForExport();
      expect(before.groups.where((group) => group.name == 'Nested'), isEmpty);
      final created = await library.createGroup('Nested');
      await library.refresh();
      final after = await library.snapshotForExport();
      expect(
        after.groups
            .where((group) => group.name == 'Nested')
            .map((group) => group.id),
        [created.id],
      );
      return created;
    });
    await entered.future.timeout(const Duration(seconds: 10));
    container.read(generation.notifier).state = 1;
    container.invalidate(bookmarkProvider);
    await container.pump();
    expect(container.read(bookmarkProvider).isLoading, true);
    pendingGroups.complete(coordinator.runExclusive(() async => groups));
    final rebuilt = container.read(bookmarkProvider.future);
    release.complete();
    final created = await operation.timeout(const Duration(seconds: 10));
    final current = await rebuilt.timeout(const Duration(seconds: 10));
    expect(
      current.groups
          .where((group) => group.name == 'Nested')
          .map((group) => group.id),
      [created.id],
    );
    expect(
      (await groups.getGroups())
          .where((group) => group.name == 'Nested')
          .map((group) => group.id),
      [created.id],
    );
    expect(repository.groupCommitCounts['Nested'], 1);
  });

  for (final cacheFailure in [false, true]) {
    test(
      'confirmed hierarchy deletion prunes modes and Undo restores them, cacheFailure=$cacheFailure',
      () async {
        final store = _Store();
        final container = createContainer(store);
        final library = container.read(bookmarkProvider.notifier);
        await container.read(bookmarkProvider.future);
        expect(
          container.read(bookmarkProvider).requireValue.hasUnifiedRecords,
          isTrue,
        );
        final parent = await library.createGroup('Parent');
        final child = await library.createGroup(
          'Child',
          parentGroupId: parent.id,
        );
        final modes = container.read(
          bookmarkGroupViewPreferencesProvider.notifier,
        );
        await modes.setMode(parent.id, BookmarkGroupViewMode.allBookmarks);
        await library.renameGroup(parent.id, 'Renamed');
        expect(modes.modeFor(parent.id), BookmarkGroupViewMode.allBookmarks);
        store.failNext = cacheFailure;
        await library.deleteGroup(parent.id);
        final deletion = library.lastHierarchyDeletion!;
        expect(
          container
              .read(bookmarkProvider)
              .requireValue
              .groupsById
              .containsKey(parent.id),
          isFalse,
        );
        expect(
          container
              .read(bookmarkProvider)
              .requireValue
              .groupsById
              .containsKey(child.id),
          isFalse,
          reason: 'Deleting a Group removes its complete descendant subtree.',
        );
        if (cacheFailure) {
          expect(
            modes.modeFor(parent.id),
            BookmarkGroupViewMode.allBookmarks,
            reason: 'Failed preference persistence does not fabricate a cache write or fail the committed domain deletion',
          );
          await library.refresh();
        }
        expect(
          container
              .read(bookmarkGroupViewPreferencesProvider)
              .containsKey(parent.id),
          isFalse,
        );
        await library.undoHierarchyDeletion(deletion);
        expect(
          container
              .read(bookmarkProvider)
              .requireValue
              .groupsById[parent.id]!
              .name,
          'Renamed',
        );
        expect(
          container
              .read(bookmarkProvider)
              .requireValue
              .groupsById[child.id]!
              .parentGroupId,
          parent.id,
        );
        expect(modes.modeFor(parent.id), BookmarkGroupViewMode.allBookmarks);
        expect(library.lastHierarchyDeletion, isNull);
      },
    );
  }

  test('startup prunes an absent UUID before an import can reuse it', () async {
    const id = '99999999-9999-4999-8999-999999999999';
    final store = _Store()
      ..values['bookmarkGroupViewModes'] = '{"$id":"allBookmarks"}';
    final container = createContainer(store);
    final library = container.read(bookmarkProvider.notifier);
    await container.read(bookmarkProvider.future);
    expect(
      container.read(bookmarkGroupViewPreferencesProvider).containsKey(id),
      isFalse,
    );
    final repository = await container.read(bookmarkGroupRepoProvider.future);
    await library.runSerializedMutation(
      () => repository.createGroup('Imported', id: id),
    );
    expect(
      container.read(bookmarkGroupViewPreferencesProvider.notifier).modeFor(id),
      BookmarkGroupViewMode.structure,
    );
  });
}
