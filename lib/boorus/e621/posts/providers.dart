// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/favorites/providers.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/queries/providers.dart';
import '../../../core/settings/providers.dart';
import '../client_provider.dart';
import '../configs/providers.dart';
import 'parser.dart';
import 'types.dart';

final e621PostRepoProvider =
    Provider.family<PostRepository<Post>, BooruConfigSearch>((ref, config) {
      final client = ref.watch(e621ClientProvider(config.auth));
      final tagComposer = ref.watch(legacyTagQueryComposerProvider(config));

      return PostRepositoryBuilder(
        tagComposer: tagComposer,
        fetchSingle: (id, {options}) async {
          final numericId = id as NumericPostId?;

          if (numericId == null) return Future.value();

          final post = await client.getPost(numericId.value);

          return post != null ? postDtoToPost(post, null) : null;
        },
        fetch: (tags, page, {limit, options}) async {
          final favorites =
              (options?.cascadeRequest ?? true) &&
                  ref.read(e621LoginDetailsProvider(config.auth)).hasLogin()
              ? ref.read(favoritesProvider(config.auth).notifier)
              : null;
          final read = favorites?.beginRead();
          final posts = await client.getPosts(
            page: page,
            tags: tags,
            limit: limit,
          );
          if (read != null) {
            favorites!.observeFavorites({
              for (final post in posts) ?post.id: ?post.isFavorited,
            }, read);
          }
          return posts
              .map(
                (post) => postDtoToPost(
                  post,
                  PostMetadata(
                    page: page,
                    search: tags.join(' '),
                    limit: limit,
                  ),
                ),
              )
              .nonNulls
              .toList()
              .toResult();
        },
        getSettings: () async =>
            ref.read(listingSettingsForAuthProvider(config.auth)),
      );
    });

final e621MediaUrlResolverProvider =
    Provider.family<MediaUrlResolver, BooruConfigAuth>((ref, config) {
      return E621MediaUrlResolver(
        postQuality: ref.watch(
          postQualityProvider(config),
        ),
      );
    });

final e621UploaderQueryProvider = Provider.family<UploaderQuery?, Post>((
  ref,
  post,
) {
  return switch (post.uploaderName) {
    final uploader? => UserColonUploaderQuery(uploader),
    _ => null,
  };
});
