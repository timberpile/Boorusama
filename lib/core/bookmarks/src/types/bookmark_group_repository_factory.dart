import 'bookmark_group_repository.dart';

abstract interface class BookmarkGroupRepositoryFactory {
  Future<BookmarkGroupRepository> create();

  Future<void> dispose(BookmarkGroupRepository repository);
}
