import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../bookmarks/src/server_favorites/controller.dart';
import '../../../../bookmarks/src/server_favorites/target_settings.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../types/types.dart';
import 'confirmed_favorite_repository.dart';
import 'repository.dart';

final favoriteRepoProvider =
    Provider.family<FavoriteRepository, BooruConfigAuth>(
      (ref, auth) => _repository(ref, auth),
    );

/// Mutation callers with an originating profile retain the shared auth cache,
/// while resolving optional local behavior against that exact profile.
final profileFavoriteRepoProvider =
    Provider.family<FavoriteRepository, (BooruConfigAuth, String)>(
      (ref, key) {
        final repository = ref.watch(favoriteRepoProvider(key.$1));
        // Reuse the engine's injected repository while capturing exactly one
        // profile projection. Never wrap the auth-only projection a second time.
        final delegate = repository is ConfirmedFavoriteRepository
            ? repository.delegate
            : repository;
        return createConfirmedFavoriteRepository(
          ref,
          key.$1,
          delegate,
          profileId: key.$2,
        );
      },
    );

FavoriteRepository _repository(
  Ref ref,
  BooruConfigAuth auth, {
  String? profileId,
}) {
  final delegate = ref
      .watch(booruEngineRegistryProvider)
      .getRepository(auth.booruType)
      ?.favorite(auth);
  if (delegate == null) return EmptyFavoriteRepository();
  return createConfirmedFavoriteRepository(
    ref,
    auth,
    delegate,
    profileId: profileId,
  );
}

FavoriteRepository createConfirmedFavoriteRepository(
  Ref ref,
  BooruConfigAuth auth,
  FavoriteRepository delegate, {
  String? profileId,
}) => ConfirmedFavoriteRepository(
  delegate: delegate,
  prepareProjection: (postId, favorited) => prepareServerFavoriteProjection(
    ref,
    auth,
    postId,
    favorited,
    profileId: profileId,
  ),
  onProjectionError: (error) => ref
      .read(serverFavoriteFeedbackProvider.notifier)
      .report(
        error is ServerFavoriteException
            ? error.problem
            : ServerFavoriteProblem.localFailure,
        profileId: profileId,
      ),
);
