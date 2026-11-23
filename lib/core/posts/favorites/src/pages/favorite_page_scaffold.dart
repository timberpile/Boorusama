// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:foundation/widgets.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../search/search/routes.dart';
import '../../../../widgets/widgets.dart';
import '../../../../navigation/navigation_profile_picker.dart';
import '../../../listing/widgets.dart';
import '../../../post/providers.dart';
import '../../../post/types.dart';
import '../providers/favorites_notifier.dart';
import '../widgets/favorites_page_menu.dart';

class FavoritesPageScaffold extends ConsumerWidget {
  const FavoritesPageScaffold({
    required this.fetcher,
    required this.favQueryBuilder,
    this.favoriteOwner,
    this.favoriteAccountFromAuth,
    super.key,
  });

  final PostsOrError<Post> Function(int page) fetcher;
  final String Function()? favQueryBuilder;
  final String? favoriteOwner;
  final String? Function(BooruConfigAuth)? favoriteAccountFromAuth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfig;
    return Consumer(
      // A profile/account change retires the request owner and its grid.
      key: _FavoritePageKey((config.id, config.auth, favoriteOwner)),
      builder: (context, ref, _) => _buildPage(context, ref, config),
    );
  }

  Widget _buildPage(BuildContext context, WidgetRef ref, BooruConfig config) {
    final origin = PostOrigin.fromSource(
      booruType: config.auth.booruType,
      booruId: config.booruId,
      source: config.url,
      profileIdHint: config.id,
    );
    return CustomContextMenuOverlay(
      child: PostScope<Post>(
        fetcher: (page) => TaskEither.Do(($) async {
          bool isCurrent() =>
              context.mounted &&
              ref.readConfig.id == config.id &&
              ref.readConfigAuth == config.auth;

          if (!isCurrent()) return PostResult<Post>.empty();
          final owner = favoriteOwner;
          final resolveAccount = favoriteAccountFromAuth;
          final account = resolveAccount == null
              ? config.auth.login
              : resolveAccount(config.auth);
          final observer = owner != null && owner == account
              ? ref.read(favoritesProvider(config.auth).notifier)
              : null;
          final read = observer?.beginRead();
          final result = await $(fetcher(page));
          if (owner != null && read != null && isCurrent()) {
            observer!.observeOwnFavorites(
              result.posts.map((post) => post.id),
              read,
              owner: owner,
              accountFromAuth: resolveAccount == null ? null : (_) => account,
            );
          }
          return bindPostResultOrigin(result, origin: origin);
        }),
        builder: (context, controller) => PostGrid(
          controller: controller,
          sliverHeaders: [
            KurumiSliverAppBar(
              title: Text(context.t.profile.favorites),
              elevation: 0,
              shadowColor: Colors.transparent,
              backgroundColor: Kurumi.themeOf(context).colorScheme.surface,
              actions: [
                if (favQueryBuilder != null)
                  IconButton(
                    icon: const Icon(Symbols.search),
                    onPressed: () {
                      goToSearchPage(
                        ref,
                        tag: favQueryBuilder!(),
                      );
                    },
                  ),
                const NavigationProfilePicker(favorites: true),
                const FavoritesPageMenu(),
              ],
            ),
            const SliverSizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}

// The auth context participates in equality without appearing in widget dumps.
class _FavoritePageKey extends ValueKey<Object> {
  const _FavoritePageKey(super.value);

  @override
  String toString() => 'FavoritesPage';
}
