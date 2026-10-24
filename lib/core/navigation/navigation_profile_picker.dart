import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

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
    if (id == null ||
        (favorites
            ? id.kind != DestinationKind.favorites
            : id.kind != DestinationKind.browse)) {
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
          selectedProfileId: id.profileId,
          tooltip: context.t.navigation.choose_profile,
          entries: [
            for (final p in profiles)
              if (!favorites || eligible.contains(p.id))
                ProfileMenuEntry(id: p.id, caption: p.name, url: p.url),
          ],
          onSelected: (profileId) {
            if (!context.mounted ||
                ref.read(navigationChromeProvider).selectionActive)
              return;
            final controller = ref.read(navigationControllerProvider.notifier);
            if (controller.binding?.currentDestination != id ||
                !ref
                    .read(navigationProfilesProvider)
                    .any((p) => p.id == profileId))
              return;
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
