// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/posts/favorites/providers.dart';
import '../../../../../../core/posts/favorites/types.dart';
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

            await votesNotifier.upvote(postId, localOnly: true);

            final success = await client.addToFavorites(postId: postId);

            if (!success) {
              votesNotifier.removeLocalVote(postId);
            }

            return success
                ? AddFavoriteStatus.success
                : AddFavoriteStatus.failure;
          },
          remove: (postId) async {
            final votesNotifier = ref.read(
              danbooruPostVotesProvider(config).notifier,
            );

            votesNotifier.removeLocalVote(postId);

            final success = await client.removeFromFavorites(postId: postId);

            if (success) {
              try {
                await votesNotifier.removeVote(postId, null);
              } catch (e) {
                return false;
              }
            } else {
              await votesNotifier.upvote(postId, localOnly: true);
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
                .catchError((Object obj) => <Favorite>[]);

            return favorites.map((f) => f.postId).toList();
          },
        );
      },
    );
