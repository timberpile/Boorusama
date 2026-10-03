import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/backups/export_import/import/import_source_durability.dart';
import 'package:boorusama/foundation/filesystem.dart';

void main() {
  late Directory directory;
  late _RecordingFileSystem fs;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('import_durability_');
    fs = _RecordingFileSystem(directory.path);
  });

  tearDown(() => directory.delete(recursive: true));

  test('bookmark durability syncs only its two Hive stores', () async {
    for (final name in const [
      'favorites.hive',
      'bookmark_groups.hive',
      'unrelated_cache.bin',
    ]) {
      await File('${directory.path}/$name').writeAsString(name);
    }

    await ImportSourceDurability(fs).syncHiveSource('bookmarks');

    expect(fs.syncedFiles, {
      '${directory.path}/favorites.hive',
      '${directory.path}/bookmark_groups.hive',
    });
    expect(fs.syncedDirectories, [directory.path]);
  });

  test(
    'SQLite durability syncs the database journal files and parent',
    () async {
      final databasePath = '${directory.path}/history.db';
      for (final suffix in const ['', '-wal', '-shm']) {
        await File('$databasePath$suffix').writeAsString(suffix);
      }
      await File('${directory.path}/unrelated.db').writeAsString('unrelated');

      await ImportSourceDurability(fs).syncSqliteSource(databasePath);

      expect(fs.syncedFiles, {
        databasePath,
        '$databasePath-wal',
        '$databasePath-shm',
      });
      expect(fs.syncedDirectories, [directory.path]);
    },
  );
}

final class _RecordingFileSystem extends IoFileSystem {
  _RecordingFileSystem(this.root);

  final String root;
  final Set<String> syncedFiles = {};
  final List<String> syncedDirectories = [];

  @override
  Future<String> getAppStoragePath() async => root;

  @override
  Future<void> syncFile(String path) async => syncedFiles.add(path);

  @override
  Future<void> syncDirectory(String path) async => syncedDirectories.add(path);
}
