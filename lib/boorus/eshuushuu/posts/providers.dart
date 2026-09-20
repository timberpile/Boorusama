// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/favorites/providers.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/queries/providers.dart';
import '../../../core/settings/providers.dart';
import '../client_provider.dart';
import 'parser.dart';
import 'search_provider.dart';

final eshuushuuPostRepoProvider =
    Provider.family<PostRepository, BooruConfigSearch>(
      (ref, config) {
        final tagComposer = ref.watch(defaultTagQueryComposerProvider(config));
        final client = ref.watch(eshuushuuClientProvider(config.auth));
        final searchNotifier = ref.watch(
          eshuushuuPostSearchProvider(config.auth).notifier,
        );

        return PostRepositoryBuilder(
          tagComposer: tagComposer,
          getSettings: () async => ref.read(imageListingSettingsProvider),
          fetchSingle: (id, {options}) async {
            final numericId = switch (id) {
              NumericPostId(:final value) => value,
              _ => null,
            };
            if (numericId == null) return null;

            final post = await client.getPost(numericId);
            return post != null ? postDtoToPost(post, null) : null;
          },
          fetch: (tags, page, {limit, options}) async {
            final posts = await searchNotifier.searchByTags(
              tags,
              page: page,
              limit: limit,
            );

            if (options?.cascadeRequest ?? true) {
              ref.read(favoritesProvider(config.auth).notifier).preload(posts);
            }

            return posts.toResult();
          },
          fetchFromController: (controller, page, {limit, options}) async {
            final tags = controller.tags.map((e) => e.originalTag).toList();
            final posts = await searchNotifier.searchByTags(
              tags,
              page: page,
              limit: limit,
            );

            if (options?.cascadeRequest ?? true) {
              ref.read(favoritesProvider(config.auth).notifier).preload(posts);
            }

            return posts.toResult();
          },
        );
      },
    );
