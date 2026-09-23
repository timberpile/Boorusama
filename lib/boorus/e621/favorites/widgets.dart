// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/auth/widgets.dart';
import '../../../core/configs/config/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/posts/favorites/widgets.dart';
import '../../../core/posts/post/providers.dart';

class E621FavoritesPage extends ConsumerWidget {
  const E621FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;

    return BooruConfigAuthFailsafe(
      builder: (_) => E621FavoritesPageInternal(
        username: config.login!,
      ),
    );
  }
}

class E621FavoritesPageInternal extends ConsumerWidget {
  const E621FavoritesPageInternal({
    required this.username,
    super.key,
  });

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfig;
    final query = 'fav:${config.auth.login?.replaceAll(' ', '_')}';

    return FavoritesPageScaffold(
      favQueryBuilder: () => query,
      fetcher: (page) =>
          ref.read(originAwarePostRepoProvider(config)).getPosts(query, page),
    );
  }
}
