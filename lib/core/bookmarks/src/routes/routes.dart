// Package imports:
import 'package:foundation/foundation.dart';
import 'package:kurumi/cupertino.dart';

// Project imports:
import '../../../posts/listing/providers.dart';
import '../../../router.dart';
import '../../../posts/post/types.dart';
import '../pages/bookmark_details_page.dart';
import '../pages/bookmark_page.dart';
import '../pages/bookmark_group_browser_page.dart';
import '../types/bookmark_view.dart';

final bookmarkRoutes = GoRoute(
  path: 'bookmarks',
  name: '/bookmarks',
  pageBuilder: genericMobilePageBuilder(
    builder: (context, state) => const BookmarkGroupBrowserPage(),
  ),
  routes: [
    GoRoute(
      path: 'group',
      name: '/bookmarks/group',
      pageBuilder: genericMobilePageBuilder(
        builder: (context, state) {
          final kind = state.uri.queryParameters['kind'];
          final id = state.uri.queryParameters['id'];
          final view = switch ((kind, id)) {
            ('all', _) => const BookmarkView.all(),
            ('group', final String id) => BookmarkView.group(id),
            _ => const BookmarkView.ungrouped(),
          };
          return BookmarkPage(
            view: view,
            title: state.uri.queryParameters['title'],
          );
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
            controller: extra['controller'] as PostGridController<Post>,
          ),
        );
      },
    ),
  ],
);
