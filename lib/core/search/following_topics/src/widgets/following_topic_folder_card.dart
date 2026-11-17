import 'package:kurumi/kurumi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/following_topic_config_provider.dart';
import '../providers/following_topics_notifier.dart';
import '../providers/untracked_topic_preview_provider.dart';

// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../images/booru_image.dart';
import '../../../../widgets/popup_menu_action_label.dart';
import '../types/topic_organization.dart';
import '../types/following_topic_sort.dart';
import '../types/following_topic.dart';
import 'following_topic_card.dart';
import 'topic_new_posts_badge.dart';

final class FollowingTopicFolderPreview {
  const FollowingTopicFolderPreview({
    required this.thumbnailUrl,
    required this.config,
    this.topicId,
  });

  final String thumbnailUrl;
  final BooruConfigAuth config;
  final String? topicId;
}

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

List<FollowingTopicFolderPreview> selectFollowingTopicFolderPreviews({
  required TopicFolder folder,
  required Map<String, FollowingTopic> topics,
  required Map<String, BooruConfig> profiles,
}) {
  final previews = <FollowingTopicFolderPreview>[];
  for (final id in folder.searchIds) {
    final topic = topics[id];
    final profile = topic == null ? null : profiles[topic.profileId];
    final preview = topic?.previews.firstOrNull;
    if (profile == null || preview == null) continue;
    previews.add(
      FollowingTopicFolderPreview(
        thumbnailUrl: preview.thumbnailUrl,
        config: profile.auth,
        topicId: id,
      ),
    );
    if (previews.length == 4) break;
  }
  return previews;
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
  final List<FollowingTopicFolderPreview> previews;
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
                if (previews.isNotEmpty)
                  Padding(
                    padding: followingTopicCardPreviewPadding,
                    child: Row(
                      children: [
                        for (final preview in previews.take(4))
                          Expanded(
                            child: Padding(
                              padding: followingTopicCardThumbnailPadding,
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: _FollowingFolderPreviewImage(
                                  preview: preview,
                                ),
                              ),
                            ),
                          ),
                        for (var i = previews.length; i < 4; i++)
                          const Spacer(),
                      ],
                    ),
                  ),
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

class _FollowingFolderPreviewImage extends ConsumerWidget {
  const _FollowingFolderPreviewImage({required this.preview});
  final FollowingTopicFolderPreview preview;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (preview.config.anonymousReadScope == null) {
      return BooruImage(
        imageUrl: preview.thumbnailUrl,
        config: preview.config,
        fit: BoxFit.cover,
      );
    }
    final id = preview.topicId;
    if (id == null) return const KurumiImagePlaceholder();
    final config = ref.watch(followingTopicConfigProvider(id));
    final topic = ref
        .watch(followingTopicsProvider)
        .valueOrNull
        ?.topics
        .where((topic) => topic.id == id)
        .firstOrNull;
    if (config == null || topic == null) return const KurumiImagePlaceholder();
    final url = ref
        .watch(
          untrackedTopicPreviewProvider((
            config: config,
            query: topic.query,
            structure: topic.queryStructure,
            revision: topic.runtimeRevision,
            attemptedAt: topic.lastAttemptAt,
          )),
        )
        .valueOrNull
        ?.firstOrNull;
    return url == null
        ? const KurumiImagePlaceholder()
        : BooruImage(imageUrl: url, config: config.auth, fit: BoxFit.cover);
  }
}
