import 'package:path/path.dart' as p;

import '../../../../foundation/filesystem.dart';
import '../../../search/following_topics/src/compatibility/topic_storage_contract.dart';

final class ImportSourceDurability {
  const ImportSourceDurability(this.fs);

  final AppFileSystem fs;

  static const _hiveFilesBySource = <String, List<String>>{
    'settings': ['settings.hive'],
    'profiles': ['booru_configs.hive'],
    'favorite_tags': ['favorite_tags.hive'],
    'blacklisted_tags': ['blacklisted_tags.hive'],
    'bookmarks': [
      'favorites.hive',
      'bookmark_groups.hive',
      'bookmark_folders.hive',
    ],
    followingTopicsBackupSourceId: [
      followingTopicsHiveFileName,
      topicOrganizationHiveFileName,
    ],
    topicFeedsBackupSourceId: [
      followingTopicsHiveFileName,
      topicOrganizationHiveFileName,
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
