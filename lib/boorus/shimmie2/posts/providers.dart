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
import '../clients/providers.dart';
import '../favorites/providers.dart';
import 'parser.dart';

final shimmie2PostRepoProvider =
    Provider.family<PostRepository, BooruConfigSearch>(
      (ref, config) {
        final client = ref.watch(shimmie2ClientProvider(config.auth));
        final tagComposer = ref.watch(defaultTagQueryComposerProvider(config));

        return PostRepositoryBuilder(
          tagComposer: tagComposer,
          fetchSingle: (id, {options}) async {
            final numericId = switch (id) {
              NumericPostId(:final value) => value,
              _ => null,
            };
            if (numericId == null) return null;

            final useGraphQL = await ref.read(
              useGraphQLClientProvider(config.auth).future,
            );
            final post = await client.getPost(
              numericId,
              useGraphQL: useGraphQL,
            );
            return post != null ? postDtoToPost(post, null) : null;
          },
          fetch: (tags, page, {limit, options}) async {
            final useGraphQL = await ref.read(
              useGraphQLClientProvider(config.auth).future,
            );

            final posts = await client.getPosts(
              tags: tags,
              page: page,
              limit: limit,
              useGraphQL: useGraphQL,
            );

            final result = posts
                .map(
                  (e) => postDtoToPost(
                    e,
                    PostMetadata(
                      page: page,
                      search: tags.join(' '),
                      limit: limit,
                    ),
                  ),
                )
                .toList();

            // Favorite status is extra; failing to load it must not fail the page.
            try {
              if (await ref.read(
                shimmie2CanFavoriteProvider(config.auth).future,
              )) {
                await ref
                    .read(favoritesProvider(config.auth).notifier)
                    .checkFavorites(result.map((post) => post.id).toList());
              }
            } catch (_) {}
            return result.toResult();
          },
          getSettings: () async => ref.read(imageListingSettingsProvider),
        );
      },
    );

final shimmie2UploaderQueryProvider = Provider.family<UploaderQuery?, Post>((
  ref,
  post,
) {
  return switch (post.uploaderName) {
    final uploader? => UserEqualsUploaderQuery(uploader),
    _ => null,
  };
});
