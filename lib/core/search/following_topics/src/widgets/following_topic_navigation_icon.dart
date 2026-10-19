// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../providers/following_topic_selectors.dart';

class FollowingTopicNavigationIcon extends ConsumerWidget {
  const FollowingTopicNavigationIcon({this.hasNewPosts, super.key});

  final bool? hasNewPosts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool showBadge =
        hasNewPosts ??
        ref.watch<bool>(
          followingTopicHasNewPostsProvider,
        );
    const icon = Icon(Symbols.rss_feed);
    return showBadge
        ? Semantics(
            label: context.t.following_topics.new_posts,
            child: const Badge(child: icon),
          )
        : icon;
  }
}
