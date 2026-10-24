// Project imports:
import '../../../../router.dart';

import 'package:kurumi/material.dart';

import '../pages/topic_feeds_page.dart';
import '../pages/topic_feed_management_page.dart';
import '../pages/following_topics_page.dart';
import '../compatibility/topic_storage_contract.dart';

final followingTopicRoutes = GoRoute(
  path: 'following-topics',
  name: '/following-topics',
  pageBuilder: genericMobilePageBuilder(
    builder: (context, state) => const FollowingTopicsPage(),
  ),
  routes: [
    GoRoute(
      path: 'folders/:folderId',
      name: '/following-topics/folder',
      pageBuilder: (_, state) => MaterialPage<void>(
        key: state.pageKey,
        name: 'following-folder:${state.pathParameters['folderId']}',
        child: FollowingTopicsPage(folderId: state.pathParameters['folderId']),
      ),
    ),
    GoRoute(
      path: 'feeds/:feedId',
      name: '/following-topics/feed',
      pageBuilder: genericMobilePageBuilder(
        builder: (_, state) => TopicFeedPage(
          feedId: state.pathParameters['feedId']!,
          profileId: state.uri.queryParameters['_profile'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: 'feeds/:feedId/edit',
      name: '/following-topics/feed/edit',
      pageBuilder: genericMobilePageBuilder(
        builder: (_, state) =>
            TopicFeedManagementPage(feedId: state.pathParameters['feedId']!),
      ),
    ),
  ],
);

final topicFeedRoutes = GoRoute(
  path: 'topic-feeds',
  name: '/topic-feeds',
  pageBuilder: genericMobilePageBuilder(
    builder: (context, state) => const FollowingTopicsPage(),
  ),
);

final legacyFollowingTopicRoutes = [
  GoRoute(
    path: legacyFollowingTopicsPath.substring(1),
    redirect: (context, state) => '/following-topics',
  ),
  GoRoute(
    path: legacyTopicFeedsPath.substring(1),
    redirect: (context, state) => '/following-topics',
  ),
];
