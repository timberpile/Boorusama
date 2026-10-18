// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../boorus/engine/providers.dart';
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
    final repository = await factory.create();
    ref.onDispose(() async {
      await factory.dispose(repository);
    });
    return repository;
  },
  name: 'bookmarkGroupRepoProvider',
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
    );

    ref.onDispose(() async {
      await factory.dispose(bookmarkRepo);
    });

    return bookmarkRepo;
  },
  name: 'bookmarkRepoProvider',
);
