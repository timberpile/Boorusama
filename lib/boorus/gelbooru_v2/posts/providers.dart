// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/blacklists/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/settings/providers.dart';
import '../../../foundation/riverpod/riverpod.dart';
import '../client_provider.dart';
import '../gelbooru_v2_provider.dart';
import '../tags/providers.dart';
import 'repo.dart';
import 'types.dart';

final gelbooruV2PostRepoProvider =
    Provider.family<PostRepository<Post>, BooruConfigSearch>(
      (ref, config) {
        final client = ref.watch(gelbooruV2ClientProvider(config.auth));
        final tagComposer = ref.watch(
          gelbooruV2TagQueryComposerProvider(config),
        );
        final imageUrlResolver = ref.watch(
          gelbooruV2PostImageUrlResolverProvider,
        );

        return GelbooruV2PostRepository(
          fetcher: (tags, page, {limit, options}) => client.getPosts(
            page: page,
            tags: tags,
            limit: limit,
          ),
          fetchSingle: (id, {options}) => client.getPost(id),
          imageUrlResolver: imageUrlResolver,
          tagComposer: tagComposer,
          getSettings: () async => ref.read(imageListingSettingsProvider),
        );
      },
    );

final gelbooruV2PostProvider =
    FutureProvider.family<Post?, (PostId, BooruConfig)>((
      ref,
      params,
    ) async {
      final (id, config) = params;
      final gelbooruV2 = ref.watch(gelbooruV2Provider);
      final cacheDuration = gelbooruV2
          .getCapabilitiesForSite(config.auth.url)
          ?.post
          ?.cacheSeconds;

      if (cacheDuration != null && cacheDuration > 0) {
        ref.cacheFor(Duration(seconds: cacheDuration));
      }

      final postRepo = OriginAwarePostRepository.fromConfig(
        delegate: ref.watch(gelbooruV2PostRepoProvider(config.search)),
        config: config,
      );

      final result = await postRepo.getPost(id).run();

      return result.getOrElse((_) => null);
    });

final gelbooruV2ChildPostsProvider = FutureProvider.autoDispose
    .family<List<Post>, (BooruConfigFilter, BooruConfig, Post)>(
      (ref, params) {
        final (filter, config, post) = params;

        return ref
            .watch(originAwarePostRepoProvider(config))
            .getPostsFromTagWithBlacklist(
              tag: post.relationshipQuery,
              blacklist: ref.watch(blacklistTagsProvider(filter).future),
            );
      },
    );

final gelbooruV2PostImageUrlResolverProvider =
    Provider<GelbooruV2ImageUrlResolver>(
      (ref) => const GelbooruV2ImageUrlResolver(),
    );

final gelbooruV2UploaderQueryProvider = Provider.family<UploaderQuery?, Post>((
  ref,
  post,
) {
  return switch (post.uploaderName) {
    final uploader? => UserColonUploaderQuery(uploader),
    _ => null,
  };
});
