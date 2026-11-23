// Package imports:
import 'package:booru_clients/gelbooru.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/favorites/providers.dart';
import '../../../core/posts/favorites/types.dart';
import '../../../core/posts/favorites/src/types/favorite_interruption.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/settings/providers.dart';
import '../client_provider.dart';
import '../gelbooru_v2_provider.dart';
import '../posts/providers.dart';
import '../posts/repo.dart';
import '../tags/providers.dart';

final gelbooruV2FavoritesPostRepoProvider =
    Provider.family<PostRepository<Post>, (BooruConfigSearch, String uuid)>(
      (ref, params) {
        final (config, uuid) = params;
        final client = ref.watch(gelbooruV2ClientProvider(config.auth));
        final tagComposer = ref.watch(
          gelbooruV2TagQueryComposerProvider(config),
        );
        final imageUrlResolver = ref.watch(
          gelbooruV2PostImageUrlResolverProvider,
        );
        final gelbooruV2 = ref.watch(gelbooruV2Provider);
        final favCapabilities = gelbooruV2
            .getCapabilitiesForSite(config.auth.url)
            ?.favorites;
        final paginationType = PaginationType.parse(
          favCapabilities?.paginationType,
        );

        return GelbooruV2PostRepository(
          fetcher: (tags, page, {limit, options}) => client.getFavorites(
            page: page,
            uid: uuid,
            paginationType: paginationType,
            fixedLimit: favCapabilities?.fixedLimit,
          ),
          fetchSingle: (id, {options}) => client.getPost(id),
          imageUrlResolver: imageUrlResolver,
          tagComposer: tagComposer,
          getSettings: () async =>
              ref.read(listingSettingsForAuthProvider(config.auth)),
        );
      },
    );

final realbooruFavoritesListingRepoProvider =
    Provider.family<PostRepository<Post>, (BooruConfigSearch, String)>((
      ref,
      params,
    ) {
      final (config, userId) = params;
      final client = ref.watch(gelbooruV2ClientProvider(config.auth));
      return GelbooruV2PostRepository(
        listedFavorites: true,
        fetcher: (tags, page, {limit, options}) => client.getFavorites(
          uid: userId,
          page: page,
          paginationType: PaginationType.offset,
          fixedLimit: 50,
          strictRealbooruSync: true,
        ),
        fetchSingle: (id, {options}) => client.getPost(id),
        imageUrlResolver: ref.watch(gelbooruV2PostImageUrlResolverProvider),
        tagComposer: ref.watch(gelbooruV2TagQueryComposerProvider(config)),
        getSettings: () async =>
            ref.read(listingSettingsForAuthProvider(config.auth)),
      );
    });

final gelbooruV2FavoriteRepoProvider =
    Provider.family<FavoriteRepository<Post>, BooruConfigAuth>(
      (ref, config) {
        final client = ref.watch(gelbooruV2ClientProvider(config));
        final isRule34 = GelbooruV2Client.isRule34Website(config.url);

        return FavoriteRepositoryBuilder(
          add: (postId) async {
            try {
              return switch (await client.addFavorite(postId: postId)) {
                GelbooruFavoriteStatus.success => AddFavoriteStatus.success,
                GelbooruFavoriteStatus.alreadyFavorited =>
                  AddFavoriteStatus.alreadyExists,
                GelbooruFavoriteStatus.userNotLoggedIn when isRule34 =>
                  throw _websiteLoginFailure(client),
                _ => AddFavoriteStatus.failure,
              };
            } on DioException catch (error) {
              if (!isRule34 || isFavoriteRequestInterruption(error)) rethrow;
              if (error.response?.statusCode == 401) {
                throw _websiteLoginFailure(client);
              }
              return AddFavoriteStatus.failure;
            }
          },
          remove: (postId) async {
            try {
              await client.removeFavorite(postId: postId);
              return true;
            } on GelbooruFavoriteException catch (error) {
              if (error.status == GelbooruFavoriteStatus.userNotLoggedIn) {
                throw _websiteLoginFailure(client);
              }
              return false;
            } catch (error) {
              if (isFavoriteRequestInterruption(error)) rethrow;
              if (isRule34 &&
                  error is DioException &&
                  error.response?.statusCode == 401) {
                throw _websiteLoginFailure(client);
              }
              return false;
            }
          },
          canFavorite: () => client.canFavorite,
          needsWebsiteLogin: client.needsWebsiteLogin,
        );
      },
    );

FavoriteActionFailure _websiteLoginFailure(GelbooruV2Client client) =>
    client.needsWebsiteLogin
    ? FavoriteActionFailure.websiteLoginRequired
    : FavoriteActionFailure.websiteSessionRejected;
