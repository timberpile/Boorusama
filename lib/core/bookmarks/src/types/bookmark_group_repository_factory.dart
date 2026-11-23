import 'bookmark_group_repository.dart';
import 'bookmark_repository.dart';

abstract interface class BookmarkGroupRepositoryFactory {
  Future<BookmarkGroupRepository> create();

  Future<void> dispose(BookmarkGroupRepository repository);
}

/// Production organization factories share the existing payload authority.
/// In-memory and standalone adapters can retain the basic factory interface.
abstract interface class SharedBookmarkRepositoryGroupFactory {
  Future<BookmarkGroupRepository> createWithBookmarkRepository(
    BookmarkRepository repository,
  );
}
