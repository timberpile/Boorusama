// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../foundation/data_mutation_coordinator.dart';
import '../../../../foundation/boot/providers.dart';
import '../types/blacklisted_tag.dart';
import '../types/blacklisted_tag_repository.dart';
import 'hive/tag_repository.dart';

final globalBlacklistedTagRepoProvider =
    FutureProvider<GlobalBlacklistedTagRepository>(
      (ref) async {
        final dbPath = await ref.watch(dbPathProvider.future);

        final globalBlacklistedTags = HiveBlacklistedTagRepository();
        await globalBlacklistedTags.init(dbPath);

        return _CoordinatedBlacklistedTagRepository(
          globalBlacklistedTags,
          ref.watch(dataMutationCoordinatorProvider),
        );
      },
      name: 'globalBlacklistedTagRepoProvider',
    );

final class _CoordinatedBlacklistedTagRepository
    implements GlobalBlacklistedTagRepository {
  const _CoordinatedBlacklistedTagRepository(
    this.delegate,
    this.coordinator,
  );

  final GlobalBlacklistedTagRepository delegate;
  final DataMutationCoordinator coordinator;

  @override
  Future<BlacklistedTag?> addTag(String tag) =>
      coordinator.runExclusive(() => delegate.addTag(tag));

  @override
  Future<List<BlacklistedTag>> addTags(List<BlacklistedTag> tags) =>
      coordinator.runExclusive(() => delegate.addTags(tags));

  @override
  Future<List<BlacklistedTag>> getBlacklist() => delegate.getBlacklist();

  @override
  Future<void> removeTag(int tagId) =>
      coordinator.runExclusive(() => delegate.removeTag(tagId));

  @override
  Future<void> replaceAll(List<BlacklistedTag> tags) =>
      coordinator.runExclusive(() => delegate.replaceAll(tags));

  @override
  Future<BlacklistedTag> updateTag(int tagId, String newTag) =>
      coordinator.runExclusive(() => delegate.updateTag(tagId, newTag));
}
