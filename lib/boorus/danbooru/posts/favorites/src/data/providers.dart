// Package imports:
import 'package:collection/collection.dart';
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
              // Danbooru removes positive votes as part of deleting a favorite.
              // Mirror that acknowledgement instead of sending another deletion.
              votesNotifier.removeLocalUpvote(postId);
            }

            return success;
          },
          canFavorite: () => loginDetails.hasLogin(),
          filter: (postIds) async {
            final user = await ref.read(
              danbooruCurrentUserProvider(config).future,
            );
            if (user == null) return null;

            final result = <int>[];
            try {
              for (final batch in postIds.slices(100)) {
                final favorites = await client.filterFavoritesFromUserId(
                  postIds: batch,
                  userId: user.id,
                );
                final ids = <int>{};
                for (final favorite in favorites) {
                  if (favorite.userId != user.id ||
                      !batch.contains(favorite.postId) ||
                      !ids.add(favorite.postId)) {
                    return null;
                  }
                }
                result.addAll(ids);
              }
              return result;
            } catch (error) {
              if (isFavoriteRequestInterruption(error)) rethrow;
              return null;
            }
          },
        );
      },
    );
