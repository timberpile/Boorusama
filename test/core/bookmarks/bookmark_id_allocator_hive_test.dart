import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/bookmark_id_allocator.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_id_store.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'bookmark-id-reservations-',
    );
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('allocator');
  });
  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  BookmarkIdAllocator allocator(int existing) => BookmarkIdAllocator(
    store: HiveBookmarkIdStore(box),
    coordinator: DataMutationCoordinator(),
    highestExistingId: () async => existing,
  );

  test('a fresh Hive reopen retains reservations above deleted payload IDs', () async {
    expect(await allocator(120).reserve(2), [121, 122]);
    await box.close();
    box = await Hive.openBox<dynamic>('allocator');
    // A lower payload maximum after deletion must not lower the durable bound.
    expect(await allocator(0).reserve(1), [123]);
    await box.close();
    box = await Hive.openBox<dynamic>('allocator');
    expect(await allocator(-1).reserve(1), [124]);
    expect(await HiveBookmarkIdStore(box).readNextId(), 125);
  });

  test(
    'unknown durable allocator structure blocks reservations without writes',
    () async {
      final unknown = {'version': 99, 'nextId': 7};
      await box.put(HiveBookmarkIdStore.reservationKey, unknown);
      await box.flush();
      await box.close();
      box = await Hive.openBox<dynamic>('allocator');
      await expectLater(allocator(-1).reserve(1), throwsFormatException);
      expect(box.get(HiveBookmarkIdStore.reservationKey), unknown);
    },
  );
  test('reservation sync includes its file and containing directory', () async {
    final fs = _SyncFileSystem();
    final ids = BookmarkIdAllocator(
      store: HiveBookmarkIdStore(box, fs: fs),
      coordinator: DataMutationCoordinator(),
      highestExistingId: () async => -1,
    );
    expect(await ids.reserve(1), [0]);
    expect(fs.synced, [box.path, directory.path]);
  });
}

class _SyncFileSystem extends IoFileSystem {
  final synced = <String>[];

  @override
  Future<void> syncFile(String path) async {
    await super.syncFile(path);
    synced.add(path);
  }

  @override
  Future<void> syncDirectory(String path) async {
    await super.syncDirectory(path);
    synced.add(path);
  }
}
