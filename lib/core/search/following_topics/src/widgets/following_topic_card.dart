import '../../../../backups/mitemite/mitemite_icon.dart';

// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:clock/clock.dart';
import 'package:timeago/timeago.dart' as timeago;

// Project imports:
import '../../../../boorus/booru/types.dart';
import '../../../../configs/config/types.dart';
import '../../../../widgets/time_pulse.dart';
import '../../../../widgets/popup_menu_action_label.dart';
import '../types/following_topic.dart';
import '../types/following_topic_sort.dart';
import 'following_topic_query_text.dart';
import 'following_topic_preview.dart';
import 'search_refresh_error_text.dart';
import 'topic_new_posts_badge.dart';

enum FollowingTopicAction {
  info,
  refresh,
  rename,
  edit,
  moveUp,
  moveDown,
  moveFolder,
  delete,
}

const followingTopicCardContentPadding = EdgeInsets.fromLTRB(8, 4, 8, 8);
const followingTopicCardPreviewPadding = EdgeInsets.only(top: 3, bottom: 4);
const followingTopicCardThumbnailPadding = EdgeInsets.all(1);
const followingTopicCardMetadataGap = 4.0;

class FollowingTopicLastPost extends StatelessWidget {
  const FollowingTopicLastPost({
    required this.lastPostAt,
    required this.hasBaseline,
    super.key,
  });

  final DateTime? lastPostAt;
  final bool hasBaseline;

  @override
  Widget build(BuildContext context) {
    Widget buildText() {
      final strings = context.t.following_topics;
      final value = switch (lastPostAt) {
        final timestamp? => timeago.format(
          timestamp.toLocal(),
          locale: context.locale.toLanguageTag(),
          clock: clock.now().toLocal(),
        ),
        _ when !hasBaseline => strings.last_post_not_checked,
        _ => strings.last_post_no_posts,
      };
      return Text(
        strings.last_post.replaceAll('{time}', value),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return switch (lastPostAt) {
      final timestamp? => TimePulse(
        initial: timestamp,
        updateInterval: const Duration(minutes: 1),
        builder: (_, _) => buildText(),
      ),
      _ => buildText(),
    };
  }
}

class FollowingTopicCardMetadata extends StatelessWidget {
  const FollowingTopicCardMetadata({
    required this.lastPostAt,
    required this.hasBaseline,
    this.leading,
    this.showLastPost = true,
    super.key,
  });

  final String? leading;
  final DateTime? lastPostAt;
  final bool hasBaseline;
  final bool showLastPost;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Row(
      children: [
        if (leading case final text?)
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (leading != null && showLastPost)
          const SizedBox(width: followingTopicCardMetadataGap),
        if (showLastPost)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * (leading == null ? 1 : 2 / 3),
            ),
            child: FollowingTopicLastPost(
              lastPostAt: lastPostAt,
              hasBaseline: hasBaseline,
            ),
          ),
      ],
    ),
  );
}

class FollowingTopicCard extends StatelessWidget {
  const FollowingTopicCard({
    required this.topic,
    required this.config,
    required this.refreshing,
    required this.onOpen,
    this.onSelect,
    this.selected = false,
    this.selecting = false,
    this.showMoveActions = false,
    this.canMoveUp = false,
    this.canMoveDown = false,
    required this.onAction,
    this.ownerCaption,
    this.sourceNotice,
    this.onManageSource,
    this.actionItemBuilder,
    this.metadata,
    this.preview,
    this.syncActions,
    this.readOnly = false,
    this.definitionChanged = false,
    this.published = false,
    this.onToggleAutoUpdate,
    super.key,
  });

  final String? ownerCaption;
  final String? sourceNotice;
  final VoidCallback? onManageSource;
  final FollowingTopic topic;
  final BooruConfigAuth? config;
  final List<PopupMenuEntry<FollowingTopicAction>> Function(BuildContext)?
  actionItemBuilder;
  final Widget? metadata;
  final Widget? preview;
  final bool refreshing;
  final VoidCallback? onOpen;
  final bool showMoveActions;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<FollowingTopicAction> onAction;
  final VoidCallback? onSelect;
  final bool selected;
  final bool selecting;
  final List<Widget>? syncActions;
  final bool readOnly;
  final bool definitionChanged;
  final bool published;
  final VoidCallback? onToggleAutoUpdate;

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
                      child: topic.name == null
                          ? FollowingTopicQueryText(
                              query: topic.query,
                              auth: config,
                              style: Theme.of(context).textTheme.titleMedium,
                            )
                          : Text(
                              topic.name!,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    FollowingSyncStatus(
                      readOnly: readOnly,
                      published: published,
                      changed: definitionChanged,
                    ),
                    if (topic.hasNewPosts)
                      TopicNewPostsBadge(
                        count: topic.newPostCountEstimate,
                        isLowerBound: topic.newPostCountIsLowerBound,
                      ),
                    if (selected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    if (!selecting && syncActions != null)
                      FollowingDefinitionMenu(
                        showMoveActions: showMoveActions,
                        syncActions: syncActions!,
                        readOnly: readOnly,
                        onInfo: () => onAction(FollowingTopicAction.info),
                        onRefresh: refreshing || config == null
                            ? null
                            : () => onAction(FollowingTopicAction.refresh),
                        onEdit: () => onAction(FollowingTopicAction.edit),
                        onDelete: () => onAction(FollowingTopicAction.delete),
                        onUp: showMoveActions && canMoveUp
                            ? () => onAction(FollowingTopicAction.moveUp)
                            : null,
                        onDown: showMoveActions && canMoveDown
                            ? () => onAction(FollowingTopicAction.moveDown)
                            : null,
                        onToggleAutoUpdate: onToggleAutoUpdate,
                        autoUpdate: topic.autoUpdateEnabled,
                      ),
                    if (!selecting && syncActions == null)
                      PopupMenuButton<FollowingTopicAction>(
                        icon: const Icon(Symbols.more_vert),
                        tooltip: context.t.generic.action.more,
                        onSelected: onAction,
                        itemBuilder: (context) =>
                            actionItemBuilder?.call(context) ??
                            [
                              PopupMenuItem(
                                value: FollowingTopicAction.info,
                                child: PopupMenuActionLabel(
                                  icon: Icons.info_outline,
                                  label: strings.info,
                                ),
                              ),
                              PopupMenuItem(
                                value: FollowingTopicAction.refresh,
                                enabled: !refreshing,
                                child: PopupMenuActionLabel(
                                  icon: Icons.refresh,
                                  label: strings.refresh,
                                ),
                              ),
                              PopupMenuItem(
                                value: FollowingTopicAction.edit,
                                child: PopupMenuActionLabel(
                                  icon: Icons.edit_outlined,
                                  label: context.t.generic.action.edit,
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
                                  icon: Icons.person_remove_outlined,
                                  label: strings.remove,
                                ),
                              ),
                            ],
                      ),
                  ],
                ),
                if (topic.name != null && topic.name != topic.query)
                  FollowingTopicQueryText(query: topic.query, auth: config),
                if (config != null)
                  FollowingTopicPreview(
                    topic: topic,
                    auth: config!,
                    fallback: preview,
                  )
                else
                  ?preview,
                metadata ??
                    FollowingTopicCardMetadata(
                      leading: ownerCaption,
                      lastPostAt: topic.lastPostAt,
                      hasBaseline: topic.hasBaseline,
                      showLastPost: config?.booruType != BooruType.nhentai,
                    ),
                if (sourceNotice case final notice?)
                  Text(notice, style: Theme.of(context).textTheme.bodySmall),
                if (!selecting && onManageSource != null)
                  TextButton(
                    onPressed: onManageSource,
                    child: Text(context.t.navigation.profiles),
                  ),
                if (refreshing) Text(strings.refreshing),
                if (topic.lastErrorKind case final kind?)
                  Text(
                    searchRefreshErrorText(context, kind),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
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

class FollowingSyncStatus extends StatelessWidget {
  const FollowingSyncStatus({
    required this.readOnly,
    required this.published,
    required this.changed,
    super.key,
  });
  final bool readOnly;
  final bool published;
  final bool changed;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (changed && readOnly)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Semantics(
            label: context.t.mitemite.unseen,
            child: Badge(
              backgroundColor: Colors.blue.shade700,
              textColor: Colors.white,
              label: Text(context.t.mitemite.unseen.toUpperCase()),
            ),
          ),
        ),
      if (published && !readOnly)
        Tooltip(
          message: context.t.mitemite.published,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: MiteMiteIcon(size: 18),
          ),
        ),
    ],
  );
}

class FollowingDefinitionMenu extends StatelessWidget {
  const FollowingDefinitionMenu({
    required this.syncActions,
    required this.readOnly,
    this.onInfo,
    this.onRefresh,
    this.onEdit,
    this.onDelete,
    this.onUp,
    this.onDown,
    this.onToggleAutoUpdate,
    this.autoUpdate = true,
    this.folder = false,
    this.showMoveActions = false,
    super.key,
  });
  final List<Widget> syncActions;
  final bool readOnly;
  final VoidCallback? onInfo;
  final VoidCallback? onRefresh;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onToggleAutoUpdate;
  final bool autoUpdate;
  final bool folder;
  final bool showMoveActions;
  @override
  Widget build(BuildContext context) {
    final t = context.t.following_topics;
    return Semantics(
      container: true,
      child: KurumiPopupMenuButton(
        tooltip: context.t.generic.action.more,
        icon: const Icon(Icons.more_vert),
        semanticLabel: context.t.generic.action.more,
        iconPadding: const EdgeInsets.all(12),
        items: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  ((MediaQuery.sizeOf(context).height -
                              MediaQuery.viewInsetsOf(context).vertical -
                              MediaQuery.paddingOf(context).vertical -
                              72) /
                          2)
                      .clamp(48, 480),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    <Widget>[
                          ...syncActions,
                          if (onInfo != null)
                            KurumiPopupMenuItem(
                              title: Text(t.info),
                              icon: const Icon(Icons.info_outline),
                              onTap: onInfo,
                            ),
                          KurumiPopupMenuItem(
                            title: Text(t.refresh),
                            icon: const Icon(Icons.refresh),
                            onTap: onRefresh,
                          ),
                          if (onToggleAutoUpdate != null)
                            KurumiPopupMenuItem(
                              title: Text(
                                autoUpdate
                                    ? t.auto_update_disable
                                    : t.auto_update_enable,
                              ),
                              icon: const Icon(Icons.update),
                              onTap: onToggleAutoUpdate,
                            ),
                          if (!readOnly) ...[
                            KurumiPopupMenuItem(
                              title: Text(
                                folder
                                    ? t.edit_folder
                                    : context.t.generic.action.edit,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              onTap: onEdit,
                            ),
                            if (showMoveActions)
                              KurumiPopupMenuItem(
                                title: Text(t.move_up),
                                icon: const Icon(Icons.arrow_upward),
                                onTap: onUp,
                              ),
                            if (showMoveActions)
                              KurumiPopupMenuItem(
                                title: Text(t.move_down),
                                icon: const Icon(Icons.arrow_downward),
                                onTap: onDown,
                              ),
                            KurumiPopupMenuItem(
                              title: Text(
                                folder
                                    ? context.t.generic.action.delete
                                    : t.remove,
                              ),
                              icon: const Icon(Icons.delete_outline),
                              onTap: onDelete,
                            ),
                          ],
                        ]
                        .map(
                          (item) => ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: item,
                          ),
                        )
                        .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
