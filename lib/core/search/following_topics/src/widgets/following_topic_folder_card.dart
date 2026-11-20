// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../developer_options/providers.dart';
import '../../../../images/booru_image.dart';
import '../../../../navigation/destination_activity.dart';
import '../../../../widgets/popup_menu_action_label.dart';
import '../providers/following_topic_config_provider.dart';
import '../providers/untracked_topic_preview_provider.dart';
import '../types/topic_organization.dart';
import '../types/following_topic_sort.dart';
import '../types/following_topic.dart';
import 'following_topic_card.dart';
import 'topic_new_posts_badge.dart';

final class FollowingTopicFolderLastPost {
  const FollowingTopicFolderLastPost({
    required this.lastPostAt,
    required this.hasBaseline,
  });

  final DateTime? lastPostAt;
  final bool hasBaseline;
}

FollowingTopicFolderLastPost selectFollowingTopicFolderLastPost({
  required TopicFolder folder,
  required Map<String, FollowingTopic> topics,
}) {
  DateTime? latest;
  var hasBaseline = false;
  for (final id in folder.searchIds) {
    final topic = topics[id];
    if (topic == null) continue;
    hasBaseline = hasBaseline || topic.hasBaseline;
    latest = switch ((latest, topic.lastPostAt)) {
      (null, final timestamp?) => timestamp,
      (final current?, final timestamp?) when timestamp.isAfter(current) =>
        timestamp,
      _ => latest,
    };
  }
  return FollowingTopicFolderLastPost(
    lastPostAt: latest,
    hasBaseline: hasBaseline,
  );
}

bool canRefreshFollowingTopicFolder({
  required TopicFolder? folder,
  required Iterable<FollowingTopic> topics,
  required Set<String> refreshingIds,
  required Set<String> refreshableProfileIds,
}) {
  if (folder == null || folder.searchIds.isEmpty) return false;
  final memberIds = folder.searchIds.toSet();
  if (refreshingIds.any(memberIds.contains)) return false;
  return topics.any(
    (topic) =>
        memberIds.contains(topic.id) &&
        refreshableProfileIds.contains(topic.profileId),
  );
}

class FollowingTopicFolderCard extends StatelessWidget {
  const FollowingTopicFolderCard({
    required this.name,
    required this.itemCount,
    required this.newPostCount,
    this.newPostCountIsLowerBound = false,
    required this.previewTopics,
    required this.lastPostAt,
    required this.hasBaseline,
    required this.refreshing,
    this.remainingRefreshes = 0,
    required this.canRefresh,
    required this.showMoveActions,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onOpen,
    this.onOpenFeed,
    this.onSelect,
    this.selected = false,
    this.selecting = false,
    required this.onAction,
    this.syncActions,
    this.readOnly = false,
    this.definitionChanged = false,
    this.published = false,
    super.key,
  });

  final String name;
  final int itemCount;
  final int newPostCount;
  final bool newPostCountIsLowerBound;
  final Iterable<FollowingTopic> previewTopics;
  final DateTime? lastPostAt;
  final bool hasBaseline;
  final bool refreshing;
  final int remainingRefreshes;
  final bool canRefresh;
  final bool showMoveActions;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onOpen;
  final VoidCallback? onOpenFeed;
  final ValueChanged<FollowingTopicAction> onAction;
  final VoidCallback? onSelect;
  final bool selected;
  final bool selecting;
  final List<Widget>? syncActions;
  final bool readOnly;
  final bool definitionChanged;
  final bool published;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.following_topics;
    return Semantics(
      label: readOnly ? context.t.mitemite.received : null,
      selected: selecting ? selected : null,
      child: Card(
        color: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
        shape: selected
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              )
            : null,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          onLongPress: onSelect,
          child: Padding(
            padding: followingTopicCardContentPadding,
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
                    FollowingSyncStatus(
                      readOnly: readOnly,
                      published: published,
                      changed: definitionChanged,
                    ),
                    if (newPostCount > 0)
                      TopicNewPostsBadge(
                        count: newPostCount,
                        isLowerBound: newPostCountIsLowerBound,
                      ),
                    if (selected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    if (!selecting && onOpenFeed != null)
                      IconButton(
                        tooltip: strings.open_feed,
                        icon: const Icon(Symbols.rss_feed),
                        onPressed: onOpenFeed,
                      ),
                    if (!selecting && syncActions != null)
                      FollowingDefinitionMenu(
                        showMoveActions: showMoveActions,
                        folder: true,
                        syncActions: syncActions!,
                        readOnly: readOnly,
                        onRefresh: canRefresh
                            ? () => onAction(FollowingTopicAction.refresh)
                            : null,
                        onEdit: () => onAction(FollowingTopicAction.edit),
                        onDelete: () => onAction(FollowingTopicAction.delete),
                        onUp: showMoveActions && canMoveUp
                            ? () => onAction(FollowingTopicAction.moveUp)
                            : null,
                        onDown: showMoveActions && canMoveDown
                            ? () => onAction(FollowingTopicAction.moveDown)
                            : null,
                      ),
                    if (!selecting && syncActions == null)
                      PopupMenuButton<FollowingTopicAction>(
                        tooltip: context.t.generic.action.more,
                        icon: const Icon(Symbols.more_vert),
                        onSelected: onAction,
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: FollowingTopicAction.refresh,
                            enabled: canRefresh,
                            child: PopupMenuActionLabel(
                              icon: Icons.refresh,
                              label: strings.refresh,
                            ),
                          ),
                          PopupMenuItem(
                            value: FollowingTopicAction.edit,
                            child: PopupMenuActionLabel(
                              icon: Icons.tune,
                              label: strings.edit_folder,
                            ),
                          ),
                          if (showMoveActions)
                            PopupMenuItem(
                              value: FollowingTopicAction.moveUp,
                              enabled: canMoveUp,
                              child: PopupMenuActionLabel(
                                icon: Icons.arrow_upward,
                                label: strings.move_up,
                              ),
                            ),
                          if (showMoveActions)
                            PopupMenuItem(
                              value: FollowingTopicAction.moveDown,
                              enabled: canMoveDown,
                              child: PopupMenuActionLabel(
                                icon: Icons.arrow_downward,
                                label: strings.move_down,
                              ),
                            ),
                          PopupMenuItem(
                            value: FollowingTopicAction.delete,
                            child: PopupMenuActionLabel(
                              icon: Icons.delete_outline,
                              label: context.t.generic.action.delete,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                _FollowingFolderPreviewStrip(topics: previewTopics),
                FollowingTopicCardMetadata(
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
      ),
    );
  }
}

class _FollowingFolderPreviewStrip extends ConsumerWidget {
  const _FollowingFolderPreviewStrip({required this.topics});

  static const _slotCount = 4;
  final Iterable<FollowingTopic> topics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canLoadPreviews =
        ref.watch(automaticMediaLoadingEnabledProvider) &&
        NavigationActivity.of(context) &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    var candidateCount = 0;
    final tiles = <Widget>[];
    for (final topic in topics) {
      final storedUrl = topic.previews.firstOrNull?.thumbnailUrl;
      final canFetch = canLoadPreviews && candidateCount < _slotCount;
      final hasStoredUrl = storedUrl != null && storedUrl.isNotEmpty;
      if (!canFetch && !hasStoredUrl) continue;

      final config = ref.watch(followingTopicConfigProvider(topic.id));
      if (config == null || config.anonymousReadScope?.isCurrent == false) {
        continue;
      }
      if (config.anonymousReadScope == null &&
          storedUrl != null &&
          storedUrl.isNotEmpty) {
        candidateCount++;
        tiles.add(
          BooruImage(
            imageUrl: storedUrl,
            config: config.auth,
            fit: BoxFit.cover,
          ),
        );
      } else if (canFetch) {
        final key = ref.watch(
          untrackedTopicPreviewKeyProvider((topic, config)),
        );
        if (key == null) continue;
        // Empty and failed lookups still count against the first four
        // candidates. Later stored previews can fill their slots.
        candidateCount++;
        final previews = ref.watch(untrackedTopicPreviewProvider(key));
        if (previews.isLoading) {
          tiles.add(const KurumiImagePlaceholder());
        } else if (previews case AsyncData(value: [final url, ...])) {
          tiles.add(
            BooruImage(imageUrl: url, config: config.auth, fit: BoxFit.cover),
          );
        }
      }
      if (tiles.length == _slotCount) break;
    }

    if (tiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: followingTopicCardPreviewPadding,
      child: Row(
        children: [
          for (final tile in tiles)
            Expanded(
              child: Padding(
                padding: followingTopicCardThumbnailPadding,
                child: AspectRatio(aspectRatio: 1, child: tile),
              ),
            ),
          for (var i = tiles.length; i < _slotCount; i++) const Spacer(),
        ],
      ),
    );
  }
}
