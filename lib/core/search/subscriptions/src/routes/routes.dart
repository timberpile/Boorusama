// Project imports:
import '../../../../router.dart';
import '../pages/following_feeds_page.dart';
import '../pages/pinned_searches_page.dart';

final pinnedSearchRoutes = GoRoute(
  path: 'pinned-searches',
  name: '/pinned-searches',
  pageBuilder: genericMobilePageBuilder(
    builder: (context, state) => const PinnedSearchesPage(),
  ),
);

final followingFeedRoutes = GoRoute(
  path: 'following-feeds',
  name: '/following-feeds',
  pageBuilder: genericMobilePageBuilder(
    builder: (context, state) => const FollowingFeedsPage(),
  ),
);
