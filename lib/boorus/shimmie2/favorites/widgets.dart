// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/auth/widgets.dart';
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/favorites/widgets.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../configs/providers.dart';

class Shimmie2FavoritesPage extends ConsumerWidget {
  const Shimmie2FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final loginDetails = ref.watch(shimmie2LoginDetailsProvider(config));
    final username = loginDetails.username;

    return BooruConfigAuthFailsafe(
      unauthorizedBuilder: (_) => const FavoritesUnavailablePage(),
      hasLogin: loginDetails.hasLogin() && username != null,
      builder: (_) => Shimmie2FavoritesPageContent(
        username: username ?? '',
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
    final repo = ref.watch(originAwarePostRepoProvider(config));

    return FavoritesPageScaffold(
      favQueryBuilder: () => query,
      favoriteOwner: username,
      favoriteAccountFromAuth: (auth) {
        final login = ref.read(shimmie2LoginDetailsProvider(auth));
        return login.hasLogin() ? login.username : null;
      },
      fetcher: (page) =>
          repo.getPosts(query, page, options: PostFetchOptions.raw),
    );
  }
}
