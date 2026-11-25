import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../local_media/local_media_providers.dart';
import 'destination_id.dart';
import 'destination_profile_scope.dart';
import 'navigation_catalog_provider.dart';
import 'navigation_chrome_controller.dart';
import 'navigation_controller.dart';
import 'profile_context_menu.dart';

class NavigationProfilePicker extends ConsumerWidget {
  const NavigationProfilePicker({required this.favorites, super.key});
  final bool favorites;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = DestinationScope.maybeOf(context)?.id;
    const localMedia = DestinationId.app(AppDestination.localMedia);
    const localEntry = ProfileMenuEntry.localMediaId;
    if (id == null ||
        (favorites
            ? id.kind != DestinationKind.favorites
            : id.kind != DestinationKind.browse && id != localMedia)) {
      return const SizedBox.shrink();
    }
    final profiles = ref.watch(navigationProfilesProvider);
    final eligible = ref
        .watch(navigationCatalogProvider)
        .eligibleFavoritesProfileIds;
    final blocked = ref.watch(
      navigationChromeProvider.select((s) => s.selectionActive),
    );
    return IgnorePointer(
      ignoring: blocked,
      child: ExcludeFocus(
        excluding: blocked,
        child: ProfileContextMenuButton(
          selectedProfileId: id == localMedia ? localEntry : id.profileId,
          tooltip: context.t.navigation.choose_profile,
          entries: [
            if (!favorites && ref.watch(localMediaAvailableProvider))
              ProfileMenuEntry.localMedia(caption: context.t.local_media.title),
            for (final p in profiles)
              if (!favorites || eligible.contains(p.id))
                ProfileMenuEntry(id: p.id, caption: p.name, url: p.url),
          ],
          onSelected: (profileId) {
            if (!context.mounted ||
                ref.read(navigationChromeProvider).selectionActive) {
              return;
            }
            final controller = ref.read(navigationControllerProvider.notifier);
            if (controller.binding?.currentDestination != id) return;
            if (!favorites && profileId == localEntry) {
              unawaited(controller.selectDestination(localMedia));
              return;
            }
            if (!ref
                .read(navigationProfilesProvider)
                .any((p) => p.id == profileId)) {
              return;
            }
            final liveEligible = ref
                .read(navigationCatalogProvider)
                .eligibleFavoritesProfileIds;
            unawaited(
              favorites
                  ? controller.selectFavoritesProfile(profileId, liveEligible)
                  : controller.selectBrowseProfile(profileId),
            );
          },
        ),
      ),
    );
  }
}
