// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/favorites/providers.dart';
import '../../../core/posts/favorites/types.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/queries/types.dart';
import '../../../core/settings/providers.dart';
import '../client_provider.dart';
import '../configs/providers.dart';
import '../posts/types.dart';
import '../posts/parser.dart';

final e621FavoritesPostRepoProvider =
    Provider.family<PostRepository<Post>, BooruConfigSearch>((ref, config) {
      final client = ref.watch(e621ClientProvider(config.auth));
      return PostRepositoryBuilder(
        tagComposer: EmptyTagQueryComposer(),
        fetch: (tags, page, {limit, options}) async {
          final data = await client.getFavorites(page: page, limit: limit);
          return PostResult(
            total: null,
            posts: data.map(postDtoToPostNoMetadata).nonNulls.toList(),
            // Unavailable files must not make a nonempty server page look like
            // the end of the collection. Let the importer report partial data.
            hasMore: data.isNotEmpty,
          );
        },
        fetchSingle: (id, {options}) async {
          final post = await client.getPost((id as NumericPostId).value);
          return post == null ? null : postDtoToPostNoMetadata(post);
        },
        getSettings: () async =>
            ref.read(listingSettingsForAuthProvider(config.auth)),
      );
    });

final e621FavoriteRepoProvider =
    Provider.family<FavoriteRepository<Post>, BooruConfigAuth>(
      (ref, config) {
        final client = ref.watch(e621ClientProvider(config));
        final loginDetails = ref.watch(e621LoginDetailsProvider(config));

        return FavoriteRepositoryBuilder(
          add: (postId) => client
              .addToFavorites(postId: postId)
              .then(
                (value) => value
                    ? AddFavoriteStatus.success
                    : AddFavoriteStatus.failure,
              ),
          remove: (postId) => client.removeFromFavorites(postId: postId),
          isFavorited: (post) => post.isFavorited,
          canFavorite: () => loginDetails.hasLogin(),
        );
      },
    );
