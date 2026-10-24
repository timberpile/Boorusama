import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../boorus/booru/types.dart';
import '../../../../boorus/e621/favorites/providers.dart';
import '../../../../boorus/moebooru/moebooru.dart';
import '../../../../boorus/gelbooru_v2/favorites/providers.dart';
import '../../../../boorus/gelbooru_v2/gelbooru_v2_provider.dart';
import '../../../configs/config/types.dart';
import '../../../posts/post/providers.dart';
import '../../../posts/post/types.dart';
import 'fetch_runner.dart';
import 'target_settings.dart';

/// Sources use the app's ordinary clients and request coordination. Engines
/// without a verified account-favorites query are explicitly unsupported.
abstract interface class ServerFavoriteSource {
  Future<ServerFavoritePage<Post>> fetchPage(
    int page, {
    ServerFavoriteCancellation? cancellation,
  });
  Future<Post?> getPost(int postId);
}

bool supportsServerFavoriteFetch(BooruType type) => switch (type) {
  BooruType.danbooru ||
  BooruType.e621 ||
  BooruType.moebooru ||
  BooruType.gelbooru ||
  BooruType.gelbooruV2 ||
  BooruType.szurubooru => true,
  _ => false,
};

bool supportsServerFavoriteProjection(BooruType type) => switch (type) {
  BooruType.danbooru ||
  BooruType.e621 ||
  BooruType.moebooru ||
  BooruType.gelbooru ||
  BooruType.gelbooruV2 ||
  BooruType.szurubooru => true,
  _ => false,
};

/// This is deliberately pure: checking availability must not construct an
/// engine client, probe an account, or start a favorites request.
String serverFavoriteQuery(BooruConfigAuth auth) {
  if (!supportsServerFavoriteFetch(auth.booruType)) {
    throw const ServerFavoriteException(ServerFavoriteProblem.unsupported);
  }
  final login = auth.login;
  final hasApiKey = auth.apiKey?.trim().isNotEmpty ?? false;
  final hasCookie =
      auth.booruType == BooruType.gelbooruV2 &&
      (auth.passHash?.trim().isNotEmpty ?? false);
  if (login == null || login.trim().isEmpty || (!hasApiKey && !hasCookie)) {
    throw const ServerFavoriteException(ServerFavoriteProblem.signedOut);
  }
  final username = login.replaceAll(' ', '_');
  return switch (auth.booruType) {
    BooruType.danbooru => 'ordfav:$username',
    // The dedicated endpoint preserves favorite order for the signed-in account.
    BooruType.e621 => '',
    BooruType.moebooru => 'vote:3:$username order:vote',
    BooruType.gelbooru when int.tryParse(login) != null => 'fav:$login',
    BooruType.gelbooru => throw const ServerFavoriteException(
      ServerFavoriteProblem.signedOut,
    ),
    // Gelbooru V2 uses its dedicated account-favorites endpoint, not tag search.
    BooruType.gelbooruV2 when int.tryParse(login) != null => '',
    BooruType.gelbooruV2 => throw const ServerFavoriteException(
      ServerFavoriteProblem.signedOut,
    ),
    // The authenticated-account token avoids wildcard or query injection in usernames.
    BooruType.szurubooru => 'special:fav',
    _ => throw const ServerFavoriteException(ServerFavoriteProblem.unsupported),
  };
}

/// Local capability metadata only; availability never starts a network request.
final serverFavoriteAvailabilityProvider =
    Provider.family<ServerFavoriteProblem?, BooruConfigAuth>((ref, auth) {
      try {
        if (!supportsServerFavoriteFetch(auth.booruType)) {
          return ServerFavoriteProblem.unsupported;
        }
        if (auth.booruType == BooruType.moebooru &&
            !ref.watch(moebooruProvider).supportsFavorite(auth.url)) {
          return ServerFavoriteProblem.unsupported;
        }
        serverFavoriteQuery(auth);
        return null;
      } on ServerFavoriteException catch (error) {
        return error.problem;
      }
    });

BooruConfigSearch _rawSearch(BooruConfigAuth auth) => BooruConfigSearch(
  auth: auth,
  filter: const BooruConfigSearchFilter(
    ratingFilter: BooruConfigRatingFilter.none,
    granularRatingFilters: null,
    alwaysIncludeTags: null,
    deletedItemBehavior: BooruConfigDeletedItemBehavior.show,
    bannedPostVisibility: BooruConfigBannedPostVisibility.show,
    blacklistConfigs: null,
  ),
);

/// Direct projections need post lookup, independently of favorites-list support.
final serverFavoritePostLoaderProvider =
    Provider.family<Future<Post?> Function(int), BooruConfig>((ref, config) {
      final repository = OriginAwarePostRepository.fromConfig(
        delegate: ref.watch(postRepoProvider(_rawSearch(config.auth))),
        config: config,
      );
      return RepositoryServerFavoriteSource(repository, '').getPost;
    });

final serverFavoriteSourceProvider =
    Provider.family<ServerFavoriteSource, BooruConfig>((ref, config) {
      final auth = config.auth;
      final problem = ref.watch(serverFavoriteAvailabilityProvider(auth));
      if (problem != null) throw ServerFavoriteException(problem);
      final query = serverFavoriteQuery(auth);
      // Never apply the profile's browsing filters, automatic tags, blacklist,
      // or rating filter to an account-favorites download.
      final search = _rawSearch(auth);
      final gelbooruV2 = auth.booruType == BooruType.gelbooruV2;
      final repository = OriginAwarePostRepository(
        delegate: switch (auth.booruType) {
          BooruType.gelbooruV2 => ref.watch(
            gelbooruV2FavoritesPostRepoProvider((
              search,
              auth.login!.trim(),
            )),
          ),
          BooruType.e621 => ref.watch(e621FavoritesPostRepoProvider(search)),
          _ => ref.watch(postRepoProvider(search)),
        },
        origin: postOriginFromConfig(config),
      );
      return RepositoryServerFavoriteSource(
        repository,
        query,
        resolvePosts:
            gelbooruV2 &&
            (ref
                    .watch(gelbooruV2Provider)
                    .getCapabilitiesForSite(auth.url)
                    ?.posts
                    ?.thumbnailOnly ??
                false),
      );
    });

class RepositoryServerFavoriteSource implements ServerFavoriteSource {
  const RepositoryServerFavoriteSource(
    this.repository,
    this.query, {
    this.resolvePosts = false,
  });

  final PostRepository<Post> repository;
  final String query;
  final bool resolvePosts;

  @override
  Future<ServerFavoritePage<Post>> fetchPage(
    int page, {
    ServerFavoriteCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final result = await repository
        .getPosts(
          query,
          page,
          limit: 100,
          options: PostFetchOptions.raw,
        )
        .run();
    final data = result.fold(
      (_) => throw const ServerFavoriteException(
        ServerFavoriteProblem.remoteFailure,
      ),
      (data) => data,
    );
    // A search-depth cap is a partial result, never an end marker.
    if (data.maxPage case final cap?
        when page > cap && (data.hasMore ?? true)) {
      throw const ServerFavoriteException(
        ServerFavoriteProblem.paginationStalled,
      );
    }
    if (!resolvePosts) {
      return ServerFavoritePage(data.posts, hasMore: data.hasMore);
    }
    final posts = <Post>[];
    for (final listed in data.posts) {
      cancellation?.throwIfCancelled();
      final lookup = getPost(listed.id);
      final post = cancellation == null
          ? await lookup
          : await cancellation.wait(lookup);
      cancellation?.throwIfCancelled();
      if (post == null || post.id != listed.id) {
        throw const ServerFavoriteException(
          ServerFavoriteProblem.missingPostIdentity,
        );
      }
      posts.add(post);
    }
    return ServerFavoritePage(posts, hasMore: data.hasMore);
  }

  @override
  Future<Post?> getPost(int postId) async {
    final result = await repository
        .getPost(
          NumericPostId(postId),
          options: PostFetchOptions.raw,
        )
        .run();
    return result.fold(
      (_) => throw const ServerFavoriteException(
        ServerFavoriteProblem.remoteFailure,
      ),
      (post) => post,
    );
  }
}
