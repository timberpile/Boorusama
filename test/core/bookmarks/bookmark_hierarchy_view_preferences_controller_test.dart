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
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:hive_ce/hive.dart';

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
  late BookmarkHiveRepository repository;
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
    repository = BookmarkHiveRepository(
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
              .groupsById[child.id]!
              .parentGroupId,
          isNull,
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
