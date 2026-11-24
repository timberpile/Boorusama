// Package imports:
import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/cupertino.dart';

// Project imports:
import '../../core/router.dart';
import 'explore/widgets.dart';
import 'works/related_page.dart';
import 'works/related_source.dart';

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
  GoRoute(
    path: '/pixiv/related',
    redirect: (context, state) =>
        state.extra is PixivRelatedPageArgs ? null : '/pixiv/explore',
    pageBuilder: (context, state) => CupertinoPage(
      key: state.pageKey,
      child: PixivRelatedTimelinePage(
        args: state.extra! as PixivRelatedPageArgs,
      ),
    ),
  ),
];

void goToPixivExplorePage(WidgetRef ref) {
  ref.pushRoute('/pixiv/explore');
}

void goToPixivRelatedPage(
  WidgetRef ref, {
  required PixivRelatedQuery query,
  required PixivRelatedPage firstPage,
}) => ref.pushRoute(
  '/pixiv/related',
  extra: (query: query, firstPage: firstPage),
);
