// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../images/booru_image.dart';
import '../types/search_organization.dart';
import '../types/pinned_search_sort.dart';
import '../types/search_subscription.dart';
import 'pinned_search_card.dart';

final class PinnedSearchFolderPreview {
  const PinnedSearchFolderPreview({
    required this.thumbnailUrl,
    required this.config,
  });

  final String thumbnailUrl;
  final BooruConfigAuth config;
}

final class PinnedSearchFolderLastPost {
  const PinnedSearchFolderLastPost({
    required this.lastPostAt,
    required this.hasBaseline,
  });

  final DateTime? lastPostAt;
  final bool hasBaseline;
}

PinnedSearchFolderLastPost selectPinnedSearchFolderLastPost({
  required SharedSearchFolder folder,
  required Map<String, SearchSubscription> subscriptions,
}) {
  DateTime? latest;
  var hasBaseline = false;
  for (final id in folder.searchIds) {
    final subscription = subscriptions[id];
    if (subscription == null) continue;
    hasBaseline = hasBaseline || subscription.hasBaseline;
    latest = switch ((latest, subscription.lastPostAt)) {
      (null, final timestamp?) => timestamp,
      (final current?, final timestamp?) when timestamp.isAfter(current) =>
        timestamp,
      _ => latest,
    };
  }
  return PinnedSearchFolderLastPost(
    lastPostAt: latest,
    hasBaseline: hasBaseline,
  );
}

List<PinnedSearchFolderPreview> selectPinnedSearchFolderPreviews({
  required SharedSearchFolder folder,
  required Map<String, SearchSubscription> subscriptions,
  required Map<String, BooruConfig> profiles,
}) {
  final previews = <PinnedSearchFolderPreview>[];
  for (final id in folder.searchIds) {
    final subscription = subscriptions[id];
    final profile = subscription == null
        ? null
        : profiles[subscription.profileId];
    final preview = subscription?.previews.firstOrNull;
    if (profile == null || preview == null) continue;
    previews.add(
      PinnedSearchFolderPreview(
        thumbnailUrl: preview.thumbnailUrl,
        config: profile.auth,
      ),
    );
    if (previews.length == 4) break;
  }
  return previews;
}

bool canRefreshPinnedSearchFolder({
  required SharedSearchFolder? folder,
  required Iterable<SearchSubscription> subscriptions,
  required Set<String> refreshingIds,
  required Set<String> refreshableProfileIds,
}) {
  if (folder == null || folder.searchIds.isEmpty) return false;
  final memberIds = folder.searchIds.toSet();
  if (refreshingIds.any(memberIds.contains)) return false;
  return subscriptions.any(
    (subscription) =>
        memberIds.contains(subscription.id) &&
        refreshableProfileIds.contains(subscription.profileId),
  );
}

class PinnedSearchFolderCard extends StatelessWidget {
  const PinnedSearchFolderCard({
    required this.name,
    required this.itemCount,
    required this.hasNewPosts,
    required this.previews,
    required this.lastPostAt,
    required this.hasBaseline,
    required this.refreshing,
    this.remainingRefreshes = 0,
    required this.canRefresh,
    required this.showMoveActions,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onOpen,
    required this.onAction,
    super.key,
  });

  final String name;
  final int itemCount;
  final bool hasNewPosts;
  final List<PinnedSearchFolderPreview> previews;
  final DateTime? lastPostAt;
  final bool hasBaseline;
  final bool refreshing;
  final int remainingRefreshes;
  final bool canRefresh;
  final bool showMoveActions;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onOpen;
  final ValueChanged<PinnedSearchAction> onAction;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.pinned_searches;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: pinnedSearchCardContentPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Symbols.folder),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasNewPosts)
                    Semantics(
                      label: strings.new_posts,
                      excludeSemantics: true,
                      child: Badge(label: Text(strings.new_badge)),
                    ),
                  PopupMenuButton<PinnedSearchAction>(
                    tooltip: context.t.generic.action.more,
                    icon: const Icon(Symbols.more_vert),
                    onSelected: onAction,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: PinnedSearchAction.refresh,
                        enabled: canRefresh,
                        child: Text(strings.refresh),
                      ),
                      PopupMenuItem(
                        value: PinnedSearchAction.rename,
                        child: Text(strings.rename),
                      ),
                      if (showMoveActions)
                        PopupMenuItem(
                          value: PinnedSearchAction.moveUp,
                          enabled: canMoveUp,
                          child: Text(strings.move_up),
                        ),
                      if (showMoveActions)
                        PopupMenuItem(
                          value: PinnedSearchAction.moveDown,
                          enabled: canMoveDown,
                          child: Text(strings.move_down),
                        ),
                      PopupMenuItem(
                        value: PinnedSearchAction.delete,
                        child: Text(context.t.generic.action.delete),
                      ),
                    ],
                  ),
                ],
              ),
              if (previews.isNotEmpty)
                Padding(
                  padding: pinnedSearchCardPreviewPadding,
                  child: Row(
                    children: [
                      for (final preview in previews.take(4))
                        Expanded(
                          child: Padding(
                            padding: pinnedSearchCardThumbnailPadding,
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: BooruImage(
                                imageUrl: preview.thumbnailUrl,
                                config: preview.config,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      for (var i = previews.length; i < 4; i++) const Spacer(),
                    ],
                  ),
                ),
              PinnedSearchCardMetadata(
                leading: strings.folder_item_count.replaceAll(
                  '{count}',
                  '$itemCount',
                ),
                lastPostAt: lastPostAt,
                hasBaseline: hasBaseline,
              ),
              if (refreshing)
                Text(
                  strings.refreshing_remaining.replaceAll(
                    '{count}',
                    '$remainingRefreshes',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
