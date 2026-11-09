import 'dart:async';
import 'dart:convert';

import 'package:boorusama/core/backups/folder_sync/providers.dart';
import 'package:boorusama/core/backups/folder_sync/service.dart';
import 'package:boorusama/core/backups/folder_sync/storage.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'server_favorites/test_support.dart';

void main() {
  for (final selection in [false, true]) {
    test(
      '${selection ? 'selection' : 'group'} deletion releases coordinator before waiting for sync bindings',
      () async {
        final h = FavoriteHarness();
        final persisted = Completer<void>();
        final release = Completer<void>();
        final port = _SnapshotPort();
        final sync = FolderSyncService(
          metadata: _Metadata(),
          port: port,
          storageFor: DirectoryFolderSyncStorage.new,
        );
        var armed = false;
        await h.open(
          unifiedOrganization: true,
          extraOverrides: (_) => [
            folderSyncServiceProvider.overrideWithValue(sync),
          ],
          syncBoxes: (boxes) async {
            if (armed && !persisted.isCompleted) {
              persisted.complete();
              await release.future;
            }
            for (final box in boxes) {
              await box.flush();
            }
          },
        );
        addTearDown(() async {
          if (!release.isCompleted) release.complete();
          await sync.dispose();
          await h.close();
        });
        final library = h.container.read(bookmarkLibraryProvider.notifier);
        port.snapshot = () async {
          await library.snapshotForExport();
        };
        expect(h.container.read(folderSyncServiceProvider), same(sync));
        await sync.initialize();
        await sync.chooseFolder('${h.directory.path}/shared');
        final parent = await library.createGroup('A');
        final child = await library.createGroup('B', parentGroupId: parent.id);
        final preview = await library.previewDeleteSelection(
          folderIds: {},
          groupIds: {parent.id},
        );
        armed = true;
        final deletion = selection
            ? library.deleteSelection(preview)
            : library.deleteGroup(parent.id).then<void>((_) {});
        await persisted.future.timeout(const Duration(seconds: 10));
        // The sync service now owns its tail and queues a real notifier snapshot
        // behind the coordinator held by the paused Hive deletion.
        final synchronization = sync.synchronize();
        await port.entered.future.timeout(const Duration(seconds: 10));
        expect(port.completed, isFalse);
        release.complete();
        await Future.wait([deletion, synchronization])
            .timeout(const Duration(seconds: 10));
        expect(port.completed, isTrue);
        final after = await library.snapshotForExport();
        expect(after.groupsById, isNot(contains(parent.id)));
        expect(after.groupsById, isNot(contains(child.id)));
        final later = await library
            .createGroup('Later')
            .timeout(const Duration(seconds: 10));
        expect(
          (await library.snapshotForExport()).groupsById,
          contains(later.id),
        );
      },
    );
  }
}

class _SnapshotPort implements SyncCollectionPort {
  late Future<void> Function() snapshot;
  final entered = Completer<void>();
  var completed = false;
  @override
  Future<List<SyncSourceCollection>> sources() async {
    if (!entered.isCompleted) entered.complete();
    await snapshot();
    completed = true;
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Metadata implements FolderSyncMetadataStore {
  Map<String, dynamic> value = {};
  @override
  Future<Map<String, dynamic>> load() async => value;
  @override
  Future<void> save(Map<String, dynamic> data) async {
    value = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }
}
