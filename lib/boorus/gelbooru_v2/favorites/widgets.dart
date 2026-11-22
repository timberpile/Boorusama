// Package imports:
import 'package:booru_clients/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/auth/widgets.dart';
import '../../../core/configs/config/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/posts/favorites/widgets.dart';
import '../../../core/posts/post/providers.dart';
import '../gelbooru_v2_provider.dart';
import 'providers.dart';

class GelbooruV2FavoritesPage extends ConsumerWidget {
  const GelbooruV2FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final gelbooruV2 = ref.watch(gelbooruV2Provider);

    return BooruConfigAuthFailsafe(
      unauthorizedBuilder: (_) => const FavoritesUnavailablePage(),
      builder: (_) => switch (gelbooruV2
          .getCapabilitiesForSite(config.url)
          ?.favorites
          ?.endpointType) {
        EndpointType.html => GelbooruV2FavoritesPageHtml(uid: config.login!),
        _ => GelbooruV2FavoritesPageApi(uid: config.login!),
      },
    );
  }
}

class GelbooruV2FavoritesPageApi extends ConsumerWidget {
  const GelbooruV2FavoritesPageApi({
    required this.uid,
    super.key,
  });

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfig;
    final query = 'fav:$uid';

    return FavoritesPageScaffold(
      favQueryBuilder: () => query,
      favoriteOwner: uid,
      fetcher: (page) =>
          ref.read(originAwarePostRepoProvider(config)).getPosts(query, page),
    );
  }
}

class GelbooruV2FavoritesPageHtml extends ConsumerWidget {
  const GelbooruV2FavoritesPageHtml({
    required this.uid,
    super.key,
  });

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfig;
    final repo = OriginAwarePostRepository.fromConfig(
      delegate: ref.watch(
        gelbooruV2FavoritesPostRepoProvider((config.search, uid)),
      ),
      config: config,
    );

    return FavoritesPageScaffold(
      favQueryBuilder: null,
      favoriteOwner: uid,
      fetcher: (page) => repo.getPosts('', page),
    );
  }
}
