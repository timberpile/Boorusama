// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/auth/widgets.dart';
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/favorites/widgets.dart';
import '../../../core/posts/post/providers.dart';

class GelbooruFavoritesPage extends ConsumerWidget {
  const GelbooruFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;

    return BooruConfigAuthFailsafe(
      unauthorizedBuilder: (_) => const FavoritesUnavailablePage(),
      builder: (_) => GelbooruFavoritesPageInternal(
        uid: config.login!,
      ),
    );
  }
}

class GelbooruFavoritesPageInternal extends ConsumerWidget {
  const GelbooruFavoritesPageInternal({
    required this.uid,
    super.key,
  });

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfig;
    final query = 'fav:$uid';
    final repo = ref.watch(originAwarePostRepoProvider(config));

    return FavoritesPageScaffold(
      favQueryBuilder: () => query,
      favoriteOwner: uid,
      fetcher: (page) => repo.getPosts(query, page),
    );
  }
}
