// Project imports:
import '../../types/blacklisted_tag_repository.dart';
import '../../types/global_blacklisted_tag_repository_factory.dart';
import 'tag_repository.dart';

final class HiveGlobalBlacklistedTagRepositoryFactory
    implements GlobalBlacklistedTagRepositoryFactory {
  const HiveGlobalBlacklistedTagRepositoryFactory({required this.path});

  final String path;

  @override
  Future<GlobalBlacklistedTagRepository> create() async {
    final repository = HiveBlacklistedTagRepository();
    await repository.init(path);
    return repository;
  }

  @override
  Future<void> dispose(GlobalBlacklistedTagRepository repository) async {
    // Hive shares boxes across overlapping runtime scopes. The application owns
    // their lifetime; disposing one repository must not close another's box.
  }
}
