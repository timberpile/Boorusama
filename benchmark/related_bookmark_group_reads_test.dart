import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  test('group read CPU with legacy and dated 20000-member rows', () async {
    final directory = await Directory.systemTemp.createTemp(
      'related_group_cpu_',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    final box = await Hive.openBox<BookmarkGroupHiveObject>('groups');
    final repository = BookmarkGroupRepositoryHive(box);
    const id = '00000000-0000-4000-8000-000000000001';
    final ids = List.generate(20000, (i) => i);
    for (final dated in [false, true]) {
      await box.put(
        id,
        BookmarkGroupHiveObject(
          id: id,
          name: 'Large',
          bookmarkIds: ids,
          addedAt: dated
              ? {for (final i in ids) i: '2026-11-03T12:00:00.123456Z'}
              : null,
        ),
      );
      for (var sample = -3; sample < 10; sample++) {
        final watch = Stopwatch()..start();
        for (var read = 0; read < 3; read++) {
          await repository.getGroups();
        }
        for (var read = 0; read < 2; read++) {
          await repository.getGroup(id);
        }
        watch.stop();
        if (sample >= 0) {
          stdout.writeln(
            'GROUP_CPU dated=$dated sample=$sample us=${watch.elapsedMicroseconds}',
          );
        }
      }
      expect((await repository.getGroup(id))!.bookmarkIds, hasLength(20000));
    }
    await box.close();
    await directory.delete(recursive: true);
  });
}
