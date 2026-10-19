import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../boorus/navigation_pages.dart';
import '../../foundation/boot/providers.dart';
import '../blacklists/widgets.dart';
import '../bookmarks/widgets.dart';
import '../boorus/engine/providers.dart';
import '../bulk_downloads/widgets.dart';
import '../configs/config/providers.dart';
import '../configs/create/routes.dart';
import '../donate/src/donation_page.dart';
import '../download_manager/widgets.dart';
import '../posts/favorites/src/pages/favorites_page.dart';
import '../premiums/widgets.dart';
import '../search/following_topics/widgets.dart';
import '../settings/src/pages/settings_page.dart';
import '../settings/routes.dart';
import '../tags/favorites/widgets.dart';
import 'destination_id.dart';
import 'navigation_catalog_provider.dart';
import 'navigation_controller.dart';
import 'profile_management_page.dart';

class NavigationDestinationPage extends ConsumerWidget {
  const NavigationDestinationPage({
    required this.id,
    this.initial,
    this.initialRequest,
    this.scrollTo,
    this.filter,
    this.group,
    super.key,
  });
  final String? initial;
  final Object? initialRequest;
  final String? scrollTo;
  final String? filter;
  final String? group;
  final DestinationId id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (id.kind) {
      case DestinationKind.browse:
        final builder = ref.watch(booruBuilderProvider(ref.watchConfigAuth));
        return Scaffold(
          body:
              builder?.homeViewBuilder(context) ??
              const NavigationRecoveryPage(favorites: false),
        );
      case DestinationKind.favorites:
        return const Scaffold(body: FavoritesPage());
      case DestinationKind.tool:
        return buildEngineNavigationPage(context, ref.watchConfig, id.toolId!);
      case DestinationKind.app:
        Future<bool> closeSettings() => ref
            .read(navigationControllerProvider.notifier)
            .selectDestination(
              ref.read(navigationControllerProvider.notifier).browseDestination,
            );
        return switch (id.appDestination!) {
          AppDestination.following => const FollowingTopicsPage(),
          AppDestination.bookmarks => const BookmarkGroupBrowserPage(),
          AppDestination.blacklist => const BlacklistedTagPage(),
          AppDestination.favoriteTags => const FavoriteTagsPage(),
          AppDestination.bulkDownload => const BulkDownloadPage(),
          AppDestination.downloadManager => DownloadManagerGatewayPage(
            filter: filter,
            group: group,
          ),
          AppDestination.profiles => const ProfileManagementPage(),
          AppDestination.settings => SettingsPage(
            initial: initial,
            initialRequest: initialRequest,
            scrollTo: scrollTo,
            onCloseHost: closeSettings,
          ),
          AppDestination.support => SettingsPage(
            scrollTo: 'support',
            onCloseHost: closeSettings,
          ),
          AppDestination.backups => SettingsPage(
            initial: 'backup_and_restore',
            onCloseHost: closeSettings,
          ),
          AppDestination.donate =>
            ref.watch(isFossBuildProvider)
                ? const DonationPage()
                : const PremiumPage(),
          AppDestination.browseRecovery => const NavigationRecoveryPage(
            favorites: false,
          ),
          AppDestination.favoritesRecovery => const NavigationRecoveryPage(
            favorites: true,
          ),
        };
    }
  }
}

/// Recovery is an explicit choice. A removed account never silently retargets
/// an account-specific command to the first remaining profile.
class NavigationRecoveryPage extends ConsumerWidget {
  const NavigationRecoveryPage({required this.favorites, super.key});
  final bool favorites;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(navigationProfilesProvider);
    final eligible = ref
        .watch(navigationCatalogProvider)
        .eligibleFavoritesProfileIds;
    return Scaffold(
      appBar: KurumiAppBar(
        title: Text(
          favorites ? context.t.profile.favorites : context.t.navigation.browse,
        ),
      ),
      body: ListView(
        children: [
          ListTile(title: Text(context.t.navigation.choose_profile)),
          for (final profile in profiles)
            if (!favorites || eligible.contains(profile.id))
              ListTile(
                title: Text(profile.name),
                subtitle: Text(profile.url),
                onTap: () {
                  final controller = ref.read(
                    navigationControllerProvider.notifier,
                  );
                  unawaited(
                    favorites
                        ? controller.selectFavoritesProfile(
                            profile.id,
                            eligible,
                          )
                        : controller.selectBrowseProfile(profile.id),
                  );
                },
              ),
          if (favorites && profiles.isNotEmpty && eligible.isEmpty)
            ListTile(
              title: Text(context.t.navigation.profiles),
              onTap: () => unawaited(openProfilesSettingsPage(ref)),
            ),
          if (profiles.isEmpty)
            ListTile(
              title: Text(context.t.generic.action.add),
              onTap: () => goToAddBooruConfigPage(ref),
            ),
        ],
      ),
    );
  }
}
