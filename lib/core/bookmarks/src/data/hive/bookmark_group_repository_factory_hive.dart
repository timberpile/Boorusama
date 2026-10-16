import 'package:hive_ce/hive.dart';

import '../../types/bookmark_group_repository.dart';
import '../../types/bookmark_group_repository_factory.dart';
import 'bookmark_group_hive_object.dart';
import 'bookmark_group_repository_hive.dart';

final class HiveBookmarkGroupRepositoryFactory
    implements BookmarkGroupRepositoryFactory {
  const HiveBookmarkGroupRepositoryFactory();

  @override
  Future<BookmarkGroupRepository> create() async {
    final groupBox = await Hive.openBox<BookmarkGroupHiveObject>(
      'bookmark_groups',
    );
    final folderBox = await Hive.openBox<dynamic>('bookmark_folders');
    final repository = BookmarkGroupRepositoryHive(
      groupBox,
      organizationBox: folderBox,
    );
    await repository.initializeFolders();
    return repository;
  }

  @override
  Future<void> dispose(BookmarkGroupRepository repository) async {
    if (repository case final BookmarkGroupRepositoryHive hiveRepository) {
      await hiveRepository.close();
    }
  }
}
