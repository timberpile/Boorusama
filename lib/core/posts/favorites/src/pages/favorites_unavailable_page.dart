import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../bookmarks/server_favorites.dart';
import '../../../../bookmarks/src/server_favorites/presentation.dart';
import '../../../../configs/config/providers.dart';
import '../../../../navigation/navigation_profile_picker.dart';
import '../widgets/favorites_page_menu.dart';

/// Keep configuration reachable even when this profile cannot fetch favorites.
class FavoritesUnavailablePage extends ConsumerWidget {
  const FavoritesUnavailablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final problem =
        ref.watch(serverFavoriteAvailabilityProvider(ref.watchConfigAuth)) ??
        ServerFavoriteProblem.unsupported;
    return Scaffold(
      appBar: KurumiAppBar(
        title: Text(context.t.profile.favorites),
        actions: const [
          NavigationProfilePicker(favorites: true),
          FavoritesPageMenu(),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(serverFavoriteProblemText(context, problem)),
        ),
      ),
    );
  }
}
