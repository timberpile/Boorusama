// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../core/home/widgets.dart';
import '../explore/widgets.dart';
import '../router.dart';

/// Puts the Explore page in the app's navigation (mobile drawer and
/// desktop rail) alongside the existing custom-home entry in
/// `home/custom_home.dart`, so it is reachable without switching the
/// home-screen layout, matching how Danbooru/e621 surface their own
/// secondary pages.
class PixivHomePage extends ConsumerWidget {
  const PixivHomePage({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomePageScaffold(
      mobileMenu: [
        SideMenuTile(
          icon: const Icon(Symbols.leaderboard),
          title: Text(context.t.pixiv.explore.title),
          onTap: () => goToPixivExplorePage(ref),
        ),
      ],
      desktopMenuBuilder: (context, constraints) => [
        HomeNavigationTile(
          value: 1,
          constraints: constraints,
          selectedIcon: Symbols.leaderboard,
          icon: Symbols.leaderboard,
          title: context.t.pixiv.explore.title,
        ),
      ],
      desktopViews: const [
        PixivExplorePage(),
      ],
    );
  }
}
