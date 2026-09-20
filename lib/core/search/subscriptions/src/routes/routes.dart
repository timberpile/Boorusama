// Project imports:
import '../../../../router.dart';
import '../pages/pinned_searches_page.dart';

final pinnedSearchRoutes = GoRoute(
  path: 'pinned-searches',
  name: '/pinned-searches',
  pageBuilder: genericMobilePageBuilder(
    builder: (context, state) => const PinnedSearchesPage(),
  ),
);
