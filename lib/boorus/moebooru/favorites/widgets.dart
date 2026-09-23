// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/auth/widgets.dart';
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/favorites/widgets.dart';
import '../../../core/posts/post/providers.dart';

class MoebooruFavoritesPage extends ConsumerWidget {
  const MoebooruFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;

    return BooruConfigAuthFailsafe(
      builder: (_) => MoebooruFavoritesPageInternalPage(
        username: config.login!,
      ),
    );
  }
}

class MoebooruFavoritesPageInternalPage extends ConsumerWidget {
  const MoebooruFavoritesPageInternalPage({
    required this.username,
    super.key,
  });

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfig;
    final query = 'vote:3:$username order:vote';

    return FavoritesPageScaffold(
      favQueryBuilder: () => query,
      fetcher: (page) =>
          ref.read(originAwarePostRepoProvider(config)).getPosts(query, page),
    );
  }
}
