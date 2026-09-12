// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/cupertino.dart';

// Project imports:
import '../../core/router.dart';
import 'explore/widgets.dart';

/// Deep-link route for the Explore page, following the
/// `lib/boorus/eshuushuu/router.dart` / `danbooru/router.dart` convention
/// so it is reachable directly, not only via the custom-home selector.
///
/// Registered in `lib/core/router.dart` as `...pixivRoutes,` alongside the
/// other engines' route lists.
final pixivExploreRoute = GoRoute(
  path: '/pixiv/explore',
  pageBuilder: (context, state) => CupertinoPage(
    key: state.pageKey,
    child: const PixivExplorePage(),
  ),
);

final pixivRoutes = [
  pixivExploreRoute,
];

void goToPixivExplorePage(WidgetRef ref) {
  ref.router.push('/pixiv/explore');
}
