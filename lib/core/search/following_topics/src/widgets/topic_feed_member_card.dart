import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../configs/manage/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../widgets/popup_menu_action_label.dart';
import '../providers/feed_member_preview_provider.dart';
import '../types/topic_feed.dart';
import '../types/following_topic.dart';
import '../types/following_topic_sort.dart';
import 'following_topic_card.dart';
import 'feed_last_checked.dart';
import 'following_topic_profile_caption.dart';

class TopicFeedMemberCard extends ConsumerWidget {
  const TopicFeedMemberCard({
    required this.feed,
    required this.source,
    required this.refreshing,
    required this.onOpen,
    required this.onAction,
    super.key,
  });

  final TopicFeed feed;
  final FollowingTopic source;
  final bool refreshing;
  final VoidCallback onOpen;
  final ValueChanged<FollowingTopicAction> onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(booruConfigProvider);
    final owner = profiles
        .where((p) => p.id == source.profileId && p.id == feed.profileId)
        .firstOrNull;
    final previews =
        ref
            .watch(
              feedMemberPreviewProvider((feedId: feed.id, sourceId: source.id)),
            )
            .valueOrNull ??
        const [];
    final strings = context.t.following_topics;
    return FollowingTopicCard(
      topic: source,
      config: owner?.auth,
      refreshing: refreshing,
      onOpen: owner == null ? null : onOpen,
      onAction: onAction,
      actionItemBuilder: (context) => [
        PopupMenuItem(
          value: FollowingTopicAction.info,
          child: PopupMenuActionLabel(
            icon: Icons.info_outline,
            label: strings.info,
          ),
        ),
        PopupMenuItem(
          value: FollowingTopicAction.refresh,
          enabled: owner != null && !refreshing,
          child: PopupMenuActionLabel(
            icon: Icons.refresh,
            label: strings.refresh,
          ),
        ),
        PopupMenuItem(
          value: FollowingTopicAction.edit,
          enabled: owner != null,
          child: PopupMenuActionLabel(
            icon: Icons.edit_outlined,
            label: context.t.generic.action.edit,
          ),
        ),
        PopupMenuItem(
          value: FollowingTopicAction.delete,
          child: PopupMenuActionLabel(
            icon: Icons.person_remove_outlined,
            label: strings.remove_feed_member,
          ),
        ),
      ],
      metadata: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FollowingTopicCardMetadata(
            leading: owner == null
                ? null
                : followingTopicProfileCaption(owner, profiles),
            lastPostAt: source.lastPostAt,
            hasBaseline: source.hasBaseline,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FeedLastRefresh(refreshedAt: source.lastSuccessfulCheckAt),
          ),
        ],
      ),
      preview: previews.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: followingTopicCardPreviewPadding,
              child: Row(
                children: [
                  for (final image in previews)
                    Expanded(
                      child: Padding(
                        padding: followingTopicCardThumbnailPadding,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(8),
                            ),
                            child: Image(
                              image: image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  for (var i = previews.length; i < 4; i++) const Spacer(),
                ],
              ),
            ),
    );
  }
}
