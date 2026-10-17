// Package imports:
import 'package:hive_ce/hive.dart';

// Project imports:
import '../user_metatag_repository.dart';

abstract interface class DanbooruUserMetatagRepositoryFactory {
  Future<UserMetatagRepository> create();

  Future<void> dispose(UserMetatagRepository repository);
}

final class HiveDanbooruUserMetatagRepositoryFactory
    implements DanbooruUserMetatagRepositoryFactory {
  const HiveDanbooruUserMetatagRepositoryFactory();

  @override
  Future<UserMetatagRepository> create() async {
    final exists = await Hive.boxExists('user_metatags');
    final box = await Hive.openBox<String>('user_metatags');
    if (!exists) {
      for (final tag in ['age', 'rating', 'order', 'score', 'id', 'user']) {
        await box.put(tag, tag);
      }
    }
    return UserMetatagRepository(box: box);
  }

  // A replacement application scope may already use the same named Hive box.
  // The process owns its lifetime; disposing one scope must not close it.
  @override
  Future<void> dispose(UserMetatagRepository repository) async {}
}
