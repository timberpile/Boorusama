import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../boorus/danbooru/users/user/providers.dart';
import '../../boorus/navigation_capabilities.dart';
import '../../boorus/nhentai/availability.dart';
import '../../boorus/shimmie2/favorites/providers.dart';
import '../../foundation/boot/providers.dart';
import '../boorus/engine/providers.dart';
import '../configs/config/providers.dart';
import '../configs/config/types.dart';
import '../premiums/providers.dart';
import '../local_media/local_media_providers.dart';
import '../premiums/types.dart';
import 'destination_definition.dart';
import 'destination_id.dart';
import 'navigation_catalog.dart';

final navigationProfilesProvider = Provider<List<BooruConfig>>(
  (ref) => ref.watch(orderedProfileConfigsProvider),
);

final navigationCapabilitiesProvider =
    Provider<List<ProfileNavigationCapabilities>>(
      (ref) => [
        for (final config in ref.watch(navigationProfilesProvider))
          describeEngineNavigation(
            config: config,
            nhentaiAvailable: ref.watch(nhentaiAvailableProvider),
            loginDetails: ref.watch(booruLoginDetailsProvider(config.auth)),
            hasFavoritesBuilder:
                ref
                    .watch(booruBuilderProvider(config.auth))
                    ?.favoritesPageBuilder !=
                null,
            knownUserId: ref.exists(danbooruCurrentUserProvider(config.auth))
                ? ref
                      .watch(danbooruCurrentUserProvider(config.auth))
                      .valueOrNull
                      ?.id
                : null,
            knownShimmieFavorites:
                ref.exists(shimmie2CanFavoriteProvider(config.auth))
                ? ref
                      .watch(shimmie2CanFavoriteProvider(config.auth))
                      .valueOrNull
                : null,
          ),
      ],
    );

final navigationCatalogProvider = Provider<NavigationCatalog>((ref) {
  final foss = ref.watch(isFossBuildProvider);
  return buildNavigationCatalog(
    profilesInStoredOrder: ref.watch(navigationCapabilitiesProvider),
    globalDefinitions: [
      GlobalNavigationDefinition(
        destination: AppDestination.localMedia,
        label: (c) => c.t.local_media.title,
        icon: Icons.perm_media_outlined,
        available: ref.watch(localMediaAvailableProvider),
      ),
      GlobalNavigationDefinition.sharedFavorites(
        label: (c) => c.t.profile.favorites,
        icon: Icons.favorite,
      ),
      GlobalNavigationDefinition(
        destination: AppDestination.blacklist,
        label: (c) => c.t.sideMenu.your_blacklist,
        icon: Icons.block,
      ),
      GlobalNavigationDefinition(
        destination: AppDestination.favoriteTags,
        label: (c) => c.t.favorite_tags.title,
        icon: Icons.tag,
      ),
      GlobalNavigationDefinition(
        destination: AppDestination.bulkDownload,
        label: (c) => c.t.sideMenu.bulk_download,
        icon: Icons.download,
      ),
      GlobalNavigationDefinition(
        destination: AppDestination.downloadManager,
        label: (c) => c.t.sideMenu.download_manager,
        icon: Icons.download_done,
      ),
      GlobalNavigationDefinition(
        destination: AppDestination.settings,
        label: (c) => c.t.sideMenu.settings,
        icon: Icons.settings,
      ),
      GlobalNavigationDefinition(
        destination: AppDestination.support,
        label: (c) => c.t.navigation.support,
        icon: Icons.help_outline,
      ),
      GlobalNavigationDefinition(
        destination: AppDestination.donate,
        label: (c) => foss
            ? c.t.donation.donate
            : c.t.premium.get_premium(brand: kPremiumBrandName),
        icon: Icons.favorite_outline,
        available:
            ref.watch(isFossBuildProvider) ||
            (ref.watch(showPremiumFeatsProvider) &&
                !kForcePremium &&
                !ref.watch(hasPremiumProvider)),
      ),
    ],
  );
});
