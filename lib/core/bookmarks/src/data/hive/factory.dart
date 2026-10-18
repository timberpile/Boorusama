// Package imports:
import 'package:hive_ce/hive.dart';

// Project imports:
import '../../types/bookmark_repository.dart';
import '../../types/bookmark_repository_factory.dart';
import '../../../../boorus/booru/types.dart';
import '../../../../posts/post/types.dart';
import 'bookmark_hive_object.dart';
import 'repository.dart';

final class HiveBookmarkRepositoryFactory implements BookmarkRepositoryFactory {
  const HiveBookmarkRepositoryFactory({this.boxName = 'favorites'});

  final String boxName;

  @override
  Future<BookmarkRepository> create({
    BooruPostDataCodec? Function(BooruType type)? postDataCodec,
  }) async {
    final box = await Hive.openBox<BookmarkHiveObject>(boxName);
    return BookmarkHiveRepository(box, postDataCodec: postDataCodec);
  }

  @override
  Future<void> dispose(BookmarkRepository repository) async {
    // Hive shares boxes across overlapping runtime scopes. The application owns
    // their lifetime; disposing one repository must not close another's box.
  }
}
