// Project imports:
import 'bookmark_repository.dart';
import '../../../boorus/booru/types.dart';
import '../../../posts/post/types.dart';

abstract interface class BookmarkRepositoryFactory {
  Future<BookmarkRepository> create({
    BooruPostDataCodec? Function(BooruType type)? postDataCodec,
  });

  Future<void> dispose(BookmarkRepository repository);
}
