// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/auth/widgets.dart';
import '../../../core/configs/config/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/posts/favorites/providers.dart';
import '../../../core/posts/favorites/widgets.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../client_provider.dart';
import '../configs/extra_data.dart';
import '../posts/parser.dart' as parser;

class EshuushuuFavoritesPage extends ConsumerWidget {
  const EshuushuuFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final extraData = EshuushuuExtraData.fromPassHash(config.passHash);

    return BooruConfigAuthFailsafe(
      builder: (_) => _EshuushuuFavoritesPageInternal(
        userId: extraData.userId ?? 0,
      ),
    );
  }
}

class _EshuushuuFavoritesPageInternal extends ConsumerWidget {
  const _EshuushuuFavoritesPageInternal({
    required this.userId,
  });

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfig;
    final notifier = ref.watch(favoritesProvider(config.auth).notifier);
    final client = ref.watch(eshuushuuClientProvider(config.auth));

    return FavoritesPageScaffold(
      favQueryBuilder: null,
      fetcher: (page) => TaskEither.Do(($) async {
        final dtos = await client.getPosts(
          favoritedByUserId: userId,
          page: page,
        );

        final posts = bindPostsOrigin(
          dtos.map((dto) => parser.postDtoToPost(dto, null)),
          origin: postOriginFromConfig(config),
        );

        notifier.preloadInternal(
          posts,
          selfFavorited: (post) => true,
        );

        return posts.toResult();
      }),
    );
  }
}
