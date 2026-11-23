import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  const id = '00000000-0000-4000-8000-000000000001';
  const otherId = '00000000-0000-4000-8000-000000000002';
  final date = DateTime.utc(2026, 11, 3, 0, 0, 0, 123, 456);
  late Directory directory;
  late Box<BookmarkGroupHiveObject> box;
  late BookmarkGroupRepositoryHive repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('group_snapshot_reuse_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    box = await Hive.openBox<BookmarkGroupHiveObject>('groups');
    repository = BookmarkGroupRepositoryHive(box);
    await box.put(
      id,
      BookmarkGroupHiveObject(
        id: id,
        name: 'First',
        bookmarkIds: [1],
        addedAt: {1: date.toIso8601String()},
      ),
    );
    await repository.createGroup('Other', id: otherId);
  });
  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  test(
    'unchanged Hive rows reuse decoded membership snapshots across reads',
    () async {
      final first = (await repository.getGroup(id))!;
      expect(first.addedAt[1], date);
      expect(await repository.getGroup(id), same(first));
      expect(
        (await repository.getGroups()).singleWhere((g) => g.id == id),
        same(first),
      );
      await repository.renameGroup(otherId, 'Renamed other');
      expect(await repository.getGroup(id), same(first));
    },
  );

  test('membership writes replace only changed snapshots and keep old values immutable', () async {
    final first = (await repository.getGroup(id))!;
    final other = await repository.getGroup(otherId);
    await repository.addBookmarks(id, {2});
    final changed = (await repository.getGroup(id))!;
    expect(changed, isNot(same(first)));
    expect(changed.bookmarkIds, {1, 2});
    expect(changed.addedAt[1], date);
    expect(first.bookmarkIds, {1});
    expect(first.addedAt, {1: date});
    expect(await repository.getGroup(otherId), same(other));
    await repository.removeBookmarks(id, {2});
    expect((await repository.getGroup(id))!.bookmarkIds, {1});
    expect(changed.bookmarkIds, {1, 2});
  });

  test('external replacement, deletion and recreation cannot return stale snapshots', () async {
    final first = await repository.getGroup(id);
    await box.put(
      id,
      BookmarkGroupHiveObject(
        id: id,
        name: 'Replaced',
        bookmarkIds: [3],
        addedAt: {3: date.toIso8601String()},
      ),
    );
    final replaced = (await repository.getGroup(id))!;
    expect(replaced, isNot(same(first)));
    expect(replaced.name, 'Replaced');
    expect(replaced.bookmarkIds, {3});
    await box.delete(id);
    expect(await repository.getGroup(id), isNull);
    await repository.createGroup('Recreated', id: id);
    expect((await repository.getGroup(id))!.bookmarkIds, isEmpty);
    expect((await repository.getGroup(id))!.name, 'Recreated');
  });

  test(
    'Hive reopen decodes persisted values rather than an old snapshot',
    () async {
      await repository.getGroup(id);
      await box.close();
      box = await Hive.openBox<BookmarkGroupHiveObject>('groups');
      repository = BookmarkGroupRepositoryHive(box);
      final restored = (await repository.getGroup(id))!;
      expect(restored.addedAt[1], date);
      expect(await repository.getGroup(id), same(restored));
    },
  );

  test(
    'Hive row input collections cannot mutate a published snapshot',
    () {
      final ids = [4];
      final dates = <dynamic, dynamic>{4: date.toIso8601String()};
      final row = BookmarkGroupHiveObject(
        id: id,
        name: 'Immutable',
        bookmarkIds: ids,
        addedAt: dates,
      );
      ids.add(5);
      dates[5] = date.toIso8601String();
      expect(row.bookmarkIds, [4]);
      expect(row.addedAt!.keys, [4]);
      expect(() => row.bookmarkIds.add(6), throwsUnsupportedError);
      expect(
        () => row.addedAt![6] = date.toIso8601String(),
        throwsUnsupportedError,
      );
    },
  );
}
