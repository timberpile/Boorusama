// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/posts/favorites/providers.dart';
import '../../../../../../core/posts/favorites/types.dart';
import '../../../../../../core/posts/favorites/src/types/favorite_interruption.dart';
import '../../../../client_provider.dart';
import '../../../../configs/providers.dart';
import '../../../../users/user/providers.dart';
import '../../../post/types.dart';
import '../../../votes/providers.dart';
import '../types/favorite.dart';
import 'parser.dart';

final danbooruFavoriteRepoProvider =
    Provider.family<FavoriteRepository<Post>, BooruConfigAuth>(
      (ref, config) {
        final client = ref.watch(danbooruClientProvider(config));
        final loginDetails = ref.watch(danbooruLoginDetailsProvider(config));

        return FavoriteRepositoryBuilder(
          add: (postId) async {
            final votesNotifier = ref.read(
              danbooruPostVotesProvider(config).notifier,
            );

            final success = await client.addToFavorites(postId: postId);

            if (success) {
              await votesNotifier.upvote(postId, localOnly: true);
            }

            return success
                ? AddFavoriteStatus.success
                : AddFavoriteStatus.failure;
          },
          remove: (postId) async {
            final votesNotifier = ref.read(
              danbooruPostVotesProvider(config).notifier,
            );

            final success = await client.removeFromFavorites(postId: postId);

            if (success) {
              try {
                await votesNotifier.removeVote(postId, null);
              } catch (e, stack) {
                if (isFavoriteRequestInterruption(e)) {
                  throw FavoriteCompletedWithInterruption(
                    e as DioException,
                    stack,
                  );
                }
                // Favorite removal is already acknowledged. Failed vote cleanup
                // must not restore a favorite or claim its mutation failed.
              }
            }

            return success;
          },
          isFavorited: (post) => false,
          canFavorite: () => loginDetails.hasLogin(),
          filter: (postIds) async {
            final user = await ref.read(
              danbooruCurrentUserProvider(config).future,
            );
            if (user == null) throw Exception('Current User not found');

            final favorites = await client
                .filterFavoritesFromUserId(
                  postIds: postIds,
                  userId: user.id,
                )
                .then((value) => value.map(favoriteDtoToFavorite).toList())
                .catchError((Object obj) {
                  if (isFavoriteRequestInterruption(obj)) {
                    Error.throwWithStackTrace(obj, StackTrace.current);
                  }
                  return <Favorite>[];
                });

            return favorites.map((f) => f.postId).toList();
          },
        );
      },
    );
