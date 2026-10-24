import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../../boorus/danbooru/users/user/providers.dart';
import '../../boorus/shimmie2/favorites/providers.dart';
import '../boorus/booru/types.dart';
import '../configs/config/providers.dart';
import 'destination_activity.dart';
import 'navigation_catalog_provider.dart';

/// Account discovery belongs to a visited page, never to catalog enumeration.
class NavigationAccountDiscovery extends ConsumerStatefulWidget {
  const NavigationAccountDiscovery({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<NavigationAccountDiscovery> createState() =>
      _NavigationAccountDiscoveryState();
}

class _NavigationAccountDiscoveryState
    extends ConsumerState<NavigationAccountDiscovery> {
  Object? _last;
  @override
  Widget build(BuildContext context) {
    if (NavigationActivity.of(context)) {
      final auth = ref.watchConfigAuth;
      if (ref.watch(booruLoginDetailsProvider(auth)).hasLogin()) {
        final data = switch (auth.booruType) {
          BooruType.danbooru => ref.watch(danbooruCurrentUserProvider(auth)),
          BooruType.shimmie2 => ref.watch(shimmie2CanFavoriteProvider(auth)),
          _ => null,
        };
        if (data != _last) {
          _last = data;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) ref.invalidate(navigationCapabilitiesProvider);
          });
        }
      }
    }
    return widget.child;
  }
}
