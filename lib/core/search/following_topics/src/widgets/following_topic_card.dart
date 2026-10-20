// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:clock/clock.dart';
import 'package:timeago/timeago.dart' as timeago;

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../posts/links/link_file_labels.dart';
import '../../../../images/booru_image.dart';
import '../../../../widgets/time_pulse.dart';
import '../types/following_topic.dart';
import '../types/following_topic_sort.dart';
import 'search_refresh_error_text.dart';
import 'topic_new_posts_badge.dart';

enum FollowingTopicAction {
  info,
  refresh,
  shareLink,
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
    super.key,
  });

  final String? leading;
  final DateTime? lastPostAt;
  final bool hasBaseline;

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
        if (leading != null)
          const SizedBox(width: followingTopicCardMetadataGap),
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
    this.actionItemBuilder,
    this.metadata,
    this.preview,
    super.key,
  });

  final String? ownerCaption;
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

  @override
  Widget build(BuildContext context) {
    final strings = context.t.following_topics;

    return Semantics(
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
                      child: Text(
                        topic.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
                    if (!selecting)
                      PopupMenuButton<FollowingTopicAction>(
                        icon: const Icon(Symbols.more_vert),
                        onSelected: onAction,
                        itemBuilder: (context) =>
                            actionItemBuilder?.call(context) ??
                            [
                              PopupMenuItem(
                                value: FollowingTopicAction.info,
                                child: Text(strings.info),
                              ),
                              PopupMenuItem(
                                value: FollowingTopicAction.refresh,
                                enabled: !refreshing,
                                child: Text(strings.refresh),
                              ),
                              PopupMenuItem(
                                value: FollowingTopicAction.edit,
                                child: Text(context.t.generic.action.edit),
                              ),
                              PopupMenuItem(
                                value: FollowingTopicAction.shareLink,
                                child: Text(context.linkFileLabel),
                              ),
                              if (showMoveActions)
                                PopupMenuItem(
                                  value: FollowingTopicAction.moveUp,
                                  enabled: canMoveUp,
                                  child: Text(strings.move_up),
                                ),
                              if (showMoveActions)
                                PopupMenuItem(
                                  value: FollowingTopicAction.moveDown,
                                  enabled: canMoveDown,
                                  child: Text(strings.move_down),
                                ),
                              PopupMenuItem(
                                value: FollowingTopicAction.delete,
                                child: Text(strings.remove),
                              ),
                            ],
                      ),
                  ],
                ),
                if (topic.displayName != topic.query) Text(topic.query),
                if (preview != null)
                  preview!
                else if (topic.previews.isNotEmpty && config != null)
                  Padding(
                    padding: followingTopicCardPreviewPadding,
                    child: Row(
                      children: [
                        for (final preview in topic.previews.take(4))
                          Expanded(
                            child: Padding(
                              padding: followingTopicCardThumbnailPadding,
                              child: BooruImage(
                                imageUrl: preview.thumbnailUrl,
                                config: config!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        for (var i = topic.previews.length; i < 4; i++)
                          const Spacer(),
                      ],
                    ),
                  ),
                metadata ??
                    FollowingTopicCardMetadata(
                      leading: ownerCaption,
                      lastPostAt: topic.lastPostAt,
                      hasBaseline: topic.hasBaseline,
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
