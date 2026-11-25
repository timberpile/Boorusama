import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../configs/config/providers.dart';
import '../../../../local_media/local_media_providers.dart';
import '../../../../navigation/destination_id.dart';
import '../../../../navigation/destination_profile_scope.dart';
import '../../../../navigation/navigation_catalog_provider.dart';
import '../../../../navigation/navigation_chrome_controller.dart';
import '../../../../navigation/navigation_controller.dart';
import '../../../../navigation/profile_context_menu.dart';
import 'search_controller.dart';
import 'search_profile_session.dart';

/// Remote profiles switch within the search. Local Media has its own destination.
class SearchContextProfilePicker extends ConsumerWidget {
  const SearchContextProfilePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(navigationProfilesProvider);
    final blocked = ref.watch(
      navigationChromeProvider.select((s) => s.selectionActive),
    );
    return IgnorePointer(
      ignoring: blocked,
      child: ExcludeFocus(
        excluding: blocked,
        child: ProfileContextMenuButton(
          entries: [
            if (ref.watch(localMediaAvailableProvider))
              ProfileMenuEntry.localMedia(caption: context.t.local_media.title),
            for (final p in profiles)
              ProfileMenuEntry(id: p.id, caption: p.name, url: p.url),
          ],
          selectedProfileId: ref.watchConfig.id,
          tooltip: context.t.navigation.choose_profile,
          onSelected: (id) {
            if (!context.mounted ||
                ref.read(navigationChromeProvider).selectionActive) {
              return;
            }
            if (id == ProfileMenuEntry.localMediaId) {
              final navigation = ref.read(
                navigationControllerProvider.notifier,
              );
              final source = DestinationScope.maybeOf(context)?.id;
              if (source != null &&
                  navigation.binding?.currentDestination == source &&
                  ref.read(localMediaAvailableProvider)) {
                unawaited(
                  navigation.selectDestination(
                    const DestinationId.app(AppDestination.localMedia),
                  ),
                );
              }
              return;
            }
            final profile = ref
                .read(navigationProfilesProvider)
                .where((p) => p.id == id)
                .firstOrNull;
            if (profile == null) return;
            SearchProfileSession.maybeOf(context)?.onSwitch(
              profile,
              InheritedSearchPageController.of(context),
            );
          },
        ),
      ),
    );
  }
}
