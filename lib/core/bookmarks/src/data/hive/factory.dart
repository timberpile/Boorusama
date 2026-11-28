// Package imports:
import 'package:hive_ce/hive.dart';

// Project imports:
import '../../../../../foundation/loggers/logger.dart';
import '../../../../../foundation/filesystem.dart';
import '../../services/bookmark_storage_migration.dart';
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
    final repository = await _open(
      postDataCodec: postDataCodec,
      storage: storage,
    );
    await repository.openOrganization();
    return repository;
  }

  Future<bool> recoverReleasedOrganization({
    required BooruPostDataCodec? Function(BooruType type) postDataCodec,
    required BookmarkStorageContext storage,
    required Iterable<int> snapshotIds,
    required Map<String, String> legacyFolderGroupIds,
    required Future<ReleasedBookmarkPreimage> Function(BookmarkHiveRepository)
    prepare,
  }) => storage.coordinator.runExclusive(() async {
    final repository = await _open(
      postDataCodec: postDataCodec,
      storage: storage,
    );
    return repository.recoverReleasedOrganization(
      snapshotIds: snapshotIds,
      legacyFolderGroupIds: legacyFolderGroupIds,
      prepare: () => prepare(repository),
    );
  });

  Future<void> recoverTransfer({
    required BooruPostDataCodec? Function(BooruType type) postDataCodec,
    required BookmarkStorageContext storage,
    required Future<void> Function(BookmarkHiveRepository) restore,
  }) => storage.coordinator.runExclusive(() async {
    final repository = await _open(
      postDataCodec: postDataCodec,
      storage: storage,
    );
    await restore(repository);
    await repository.durableSync();
  });

  Future<BookmarkHiveRepository> _open({
    required BooruPostDataCodec? Function(BooruType type)? postDataCodec,
    required BookmarkStorageContext storage,
  }) async {
    final box = await Hive.openBox<BookmarkHiveObject>(boxName);
    final groups = await Hive.openBox<dynamic>('${boxName}_content_groups');
    final metadata = await Hive.openBox<dynamic>('${boxName}_content_metadata');
    return BookmarkHiveRepository(
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
  }

  @override
  Future<void> dispose(BookmarkRepository repository) async {
    // Hive shares boxes across overlapping runtime scopes. The application owns
    // their lifetime; disposing one repository must not close another's box.
  }
}
