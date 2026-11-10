// Package imports:
import 'package:hive_ce/hive.dart';

// Project imports:
import '../../../../../foundation/loggers/logger.dart';
import '../../../../../foundation/filesystem.dart';
import '../../types/bookmark_repository.dart';
import '../../types/bookmark_repository_factory.dart';
import '../../../../boorus/booru/types.dart';
import '../../../../posts/post/types.dart';
import 'bookmark_hive_object.dart';
import 'repository.dart';

final class HiveBookmarkRepositoryFactory implements BookmarkRepositoryFactory {
  const HiveBookmarkRepositoryFactory({
    this.boxName = 'favorites',
    this.logger,
    this.fs = const IoFileSystem(),
  });

  final String boxName;
  final Logger? logger;
  final AppFileSystem fs;

  @override
  Future<BookmarkRepository> create({
    BooruPostDataCodec? Function(BooruType type)? postDataCodec,
    BookmarkStorageContext? storage,
  }) async {
    if (storage == null) {
      throw StateError('The shared Bookmark storage context is required');
    }
    final box = await Hive.openBox<BookmarkHiveObject>(boxName);
    final groups = await Hive.openBox<dynamic>('${boxName}_content_groups');
    final metadata = await Hive.openBox<dynamic>('${boxName}_content_metadata');
    final repository = BookmarkHiveRepository(
      box,
      groupPayloadBox: groups,
      metadataBox: metadata,
      coordinator: storage.coordinator,
      legacyGroupBoxName: boxName == 'favorites'
          ? 'bookmark_groups'
          : '${boxName}_bookmark_groups',
      legacyOrganizationBoxName: boxName == 'favorites'
          ? 'bookmark_folders'
          : '${boxName}_bookmark_folders',
      groupMetadataCodec: storage.groupMetadataCodec,
      postDataCodec: postDataCodec,
      logger: logger,
      fs: fs,
    );
    await repository.openOrganization();
    return repository;
  }

  @override
  Future<void> dispose(BookmarkRepository repository) async {
    // Hive shares boxes across overlapping runtime scopes. The application owns
    // their lifetime; disposing one repository must not close another's box.
  }
}
