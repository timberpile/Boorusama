// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../router.dart';
import '../../../../navigation/destination_profile_scope.dart';
import '../../../../navigation/navigation_catalog_provider.dart';
import '../../../../navigation/navigation_controller.dart';
import '../../../../navigation/page_source_context.dart';

void goToFavoritesPage(WidgetRef ref) {
  if (DestinationScope.maybeOf(ref.context) != null) {
    ref
        .read(navigationControllerProvider.notifier)
        .openFavorites(
          ref.read(navigationCatalogProvider).eligibleFavoritesProfileIds,
          explicitProfileId: ref.read(explicitPageSourceProvider)?.profileId,
        );
    return;
  }
  ref.pushRoute(
    Uri(
      path: '/favorites',
    ).toString(),
  );
}
