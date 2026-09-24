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
import '../configs/providers.dart';

class Shimmie2FavoritesPage extends ConsumerWidget {
  const Shimmie2FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final loginDetails = ref.watch(shimmie2LoginDetailsProvider(config));
    final usename = loginDetails.username;

    return BooruConfigAuthFailsafe(
      hasLogin: loginDetails.hasLogin() && usename != null,
      builder: (_) => Shimmie2FavoritesPageContent(
        username: usename ?? '',
      ),
    );
  }
}

class Shimmie2FavoritesPageContent extends ConsumerWidget {
  const Shimmie2FavoritesPageContent({
    required this.username,
    super.key,
  });

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfig;
    final query = username.isNotEmpty ? 'favorited_by=$username' : '';
    final notifier = ref.watch(favoritesProvider(config.auth).notifier);
    final repo = ref.watch(originAwarePostRepoProvider(config));

    return FavoritesPageScaffold(
      favQueryBuilder: () => query,
      fetcher: (page) => TaskEither.Do(($) async {
        final r = await $(repo.getPosts(query, page));

        // all posts from this page are already favorited by the user
        notifier.preloadInternal(
          r.posts,
          selfFavorited: (post) => true,
        );

        return r;
      }),
    );
  }
}
