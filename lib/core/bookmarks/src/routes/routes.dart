// Package imports:
import 'package:foundation/foundation.dart';
import 'package:kurumi/cupertino.dart';

// Project imports:
import '../../../posts/listing/providers.dart';
import '../../../router.dart';
import '../data/bookmark_convert.dart';
import '../pages/bookmark_details_page.dart';
import '../pages/bookmark_group_browser_page.dart';
import '../pages/bookmark_page.dart';

final bookmarkRoutes = GoRoute(
  path: 'bookmarks',
  name: '/bookmarks',
  pageBuilder: genericMobilePageBuilder(
    builder: (context, state) => const BookmarkGroupBrowserPage(),
  ),
  routes: [
    GoRoute(
      path: 'view',
      name: '/bookmarks/view',
      pageBuilder: genericMobilePageBuilder(
        builder: (context, state) {
          final groupId = switch (state.uri.queryParameters['groupId']) {
            null || 'all' => null,
            final value => int.parse(value),
          };

          return BookmarkContentPage(selectedGroupId: groupId);
        },
      ),
    ),
    GoRoute(
      path: 'details',
      name: '/bookmarks/details',
      pageBuilder: (context, state) {
        final extra = state.extra! as Map<String, dynamic>;

        return CupertinoPage(
          key: state.pageKey,
          name: state.name,
          child: BookmarkDetailsPage(
            initialIndex: state.uri.queryParameters['index']?.toInt() ?? 0,
            initialThumbnailUrl: extra['initialThumbnailUrl'] as String,
            controller: extra['controller'] as PostGridController<BookmarkPost>,
          ),
        );
      },
    ),
  ],
);
