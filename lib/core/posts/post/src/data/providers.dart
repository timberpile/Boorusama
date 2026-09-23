// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../types/post_link_generator.dart';
import '../types/post_repository.dart';
import '../types/post_origin.dart';
import '../types/post.dart';
import 'post_link_generator_impl.dart';
import 'post_repository_impl.dart';
import 'origin_aware_post_repository.dart';

final emptyPostRepoProvider = Provider<PostRepository>(
  (ref) => EmptyPostRepository(),
);

final postRepoProvider = Provider.family<PostRepository, BooruConfigSearch>(
  (ref, config) {
    final repo = ref
        .watch(booruEngineRegistryProvider)
        .getRepository(config.booruType);

    final postRepo = repo?.post(config);

    if (postRepo != null) {
      return postRepo;
    }

    return ref.watch(emptyPostRepoProvider);
  },
);

final originAwarePostRepoProvider =
    Provider.family<PostRepository<Post>, BooruConfig>((ref, config) {
      final registry = ref.watch(booruEngineRegistryProvider);
      final engine = registry.getEngine(config.auth.booruType);
      final delegate = switch (engine) {
        final engine? => engine.repository.post(config.search),
        null => ref.watch(emptyPostRepoProvider),
      };
      return OriginAwarePostRepository(
        delegate: delegate,
        origin: PostOrigin.fromSource(
          booruType: config.auth.booruType,
          booruId: config.booruId,
          source: config.url,
          profileIdHint: config.id,
        ),
      );
    }, name: 'originAwarePostRepoProvider');

final postLinkGeneratorProvider =
    Provider.family<PostLinkGenerator, BooruConfigAuth>(
      (ref, config) {
        final repository = ref
            .watch(booruEngineRegistryProvider)
            .getRepository(config.booruType);

        if (repository == null) return const NoLinkPostLinkGenerator();

        return repository.postLinkGenerator(config);
      },
      name: 'postLinkGeneratorProvider',
    );
