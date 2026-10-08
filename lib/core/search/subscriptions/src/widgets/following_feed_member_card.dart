import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../configs/manage/providers.dart';
import '../../../../configs/config/types.dart';
import '../providers/feed_member_preview_provider.dart';
import '../types/search_following_feed.dart';
import '../types/search_subscription.dart';
import '../types/pinned_search_sort.dart';
import 'pinned_search_card.dart';
import 'feed_last_checked.dart';
import 'pinned_search_profile_caption.dart';

class FollowingFeedMemberCard extends ConsumerWidget {
  const FollowingFeedMemberCard({
    required this.feed,
    required this.source,
    required this.refreshing,
    required this.onOpen,
    required this.onAction,
    super.key,
  });

  final SearchFollowingFeed feed;
  final SearchSubscription source;
  final bool refreshing;
  final VoidCallback onOpen;
  final ValueChanged<PinnedSearchAction> onAction;

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
    final strings = context.t.pinned_searches;
    return PinnedSearchCard(
      subscription: source,
      config: owner?.auth,
      refreshing: refreshing,
      onOpen: owner == null ? null : onOpen,
      onAction: onAction,
      actionItemBuilder: (context) => [
        PopupMenuItem(
          value: PinnedSearchAction.info,
          child: Text(strings.info),
        ),
        PopupMenuItem(
          value: PinnedSearchAction.refresh,
          enabled: owner != null && !refreshing,
          child: Text(strings.refresh),
        ),
        PopupMenuItem(
          value: PinnedSearchAction.edit,
          enabled: owner != null,
          child: Text(context.t.generic.action.edit),
        ),
        PopupMenuItem(
          value: PinnedSearchAction.delete,
          child: Text(strings.remove_feed_member),
        ),
      ],
      metadata: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PinnedSearchCardMetadata(
            leading: owner == null
                ? null
                : pinnedSearchProfileCaption(owner, profiles),
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
              padding: pinnedSearchCardPreviewPadding,
              child: Row(
                children: [
                  for (final image in previews)
                    Expanded(
                      child: Padding(
                        padding: pinnedSearchCardThumbnailPadding,
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
