import 'package:path/path.dart' as p;

import '../../../../foundation/filesystem.dart';

final class ImportSourceDurability {
  const ImportSourceDurability(this.fs);

  final AppFileSystem fs;

  static const _hiveFilesBySource = <String, List<String>>{
    'settings': ['settings.hive'],
    'profiles': ['booru_configs.hive'],
    'favorite_tags': ['favorite_tags.hive'],
    'blacklisted_tags': ['blacklisted_tags.hive'],
    'bookmarks': ['favorites.hive', 'bookmark_groups.hive'],
    'pinned_searches': [
      'pinned_search_subscriptions.hive',
      'pinned_search_folders.hive',
    ],
    'following_feeds': [
      'pinned_search_subscriptions.hive',
      'pinned_search_folders.hive',
    ],
  };

  Future<void> syncHiveSource(String sourceId) async {
    final fileNames = _hiveFilesBySource[sourceId];
    if (fileNames == null) {
      throw StateError('No durability boundary registered for $sourceId');
    }
    final root = await fs.getAppStoragePath();
    for (final fileName in fileNames) {
      final path = p.join(root, fileName);
      if (await fs.fileExists(path)) await fs.syncFile(path);
    }
    await fs.syncDirectory(root);
  }

  Future<void> syncSqliteSource(String databasePath) async {
    for (final suffix in const ['', '-wal', '-shm']) {
      final path = '$databasePath$suffix';
      if (await fs.fileExists(path)) await fs.syncFile(path);
    }
    await fs.syncDirectory(p.dirname(databasePath));
  }
}
