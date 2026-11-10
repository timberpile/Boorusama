// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../boorus/engine/providers.dart';
import '../../../content/providers.dart';
import '../../../../foundation/data_mutation_coordinator.dart';
import '../types/bookmark_repository.dart';
import '../types/bookmark_repository_factory.dart';
import '../types/bookmark_group_repository.dart';
import '../types/bookmark_group_repository_factory.dart';

final bookmarkGroupRepositoryFactoryProvider =
    Provider<BookmarkGroupRepositoryFactory>(
      (_) => throw UnimplementedError(
        'bookmarkGroupRepositoryFactoryProvider must be overridden',
      ),
    );

final bookmarkGroupRepoProvider = FutureProvider<BookmarkGroupRepository>(
  (ref) async {
    final factory = ref.watch(bookmarkGroupRepositoryFactoryProvider);
    final repository = switch (factory) {
      final SharedBookmarkRepositoryGroupFactory shared =>
        await shared.createWithBookmarkRepository(
          await ref.watch(bookmarkRepoProvider.future),
        ),
      _ => await factory.create(),
    };
    ref.onDispose(() async {
      await factory.dispose(repository);
    });
    return repository;
  },
  name: 'bookmarkGroupRepoProvider',
  dependencies: [bookmarkGroupRepositoryFactoryProvider, bookmarkRepoProvider],
);

final bookmarkRepositoryFactoryProvider = Provider<BookmarkRepositoryFactory>(
  (_) => throw UnimplementedError(
    'bookmarkRepositoryFactoryProvider must be overridden',
  ),
);

final bookmarkRepoProvider = FutureProvider<BookmarkRepository>(
  (ref) async {
    final factory = ref.watch(bookmarkRepositoryFactoryProvider);
    final registry = ref.watch(booruEngineRegistryProvider);
    final bookmarkRepo = await factory.create(
      postDataCodec: (type) => registry.getPostCapability(type)?.codec,
      storage: BookmarkStorageContext(
        coordinator: ref.watch(dataMutationCoordinatorProvider),
        groupMetadataCodec: ref.watch(groupMetadataCodecProvider),
      ),
    );

    ref.onDispose(() async {
      await factory.dispose(bookmarkRepo);
    });

    return bookmarkRepo;
  },
  name: 'bookmarkRepoProvider',
  dependencies: [
    bookmarkRepositoryFactoryProvider,
    booruEngineRegistryProvider,
    dataMutationCoordinatorProvider,
    groupMetadataCodecProvider,
  ],
);
