import '../../types/bookmark_group_repository.dart';
import '../../types/bookmark_group_repository_factory.dart';
import '../../types/bookmark_repository.dart';
import 'unified_bookmark_repository.dart';

final class HiveBookmarkGroupRepositoryFactory
    implements
        BookmarkGroupRepositoryFactory,
        SharedBookmarkRepositoryGroupFactory {
  const HiveBookmarkGroupRepositoryFactory();

  @override
  Future<BookmarkGroupRepository> create() =>
      Future.error(StateError('The shared Bookmark repository is required'));

  @override
  Future<BookmarkGroupRepository> createWithBookmarkRepository(
    BookmarkRepository repository,
  ) {
    return switch (repository) {
      final BookmarkHiveRepository hive => hive.openOrganization(),
      _ => throw StateError('Unified Hive Bookmark storage is required'),
    };
  }

  @override
  Future<void> dispose(BookmarkGroupRepository repository) async {
    // The application owns shared Hive boxes and the injected payload authority.
  }
}
