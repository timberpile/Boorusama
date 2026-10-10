// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:clock/clock.dart';
import 'package:timeago/timeago.dart' as timeago;

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../images/booru_image.dart';
import '../../../../widgets/time_pulse.dart';
import '../types/search_subscription.dart';
import '../types/pinned_search_sort.dart';
import 'search_refresh_error_text.dart';

enum PinnedSearchAction {
  info,
  refresh,
  rename,
  edit,
  moveUp,
  moveDown,
  moveFolder,
  delete,
}

const pinnedSearchCardContentPadding = EdgeInsets.fromLTRB(8, 4, 8, 8);
const pinnedSearchCardPreviewPadding = EdgeInsets.only(top: 3, bottom: 4);
const pinnedSearchCardThumbnailPadding = EdgeInsets.all(1);
const pinnedSearchCardMetadataGap = 4.0;

class PinnedSearchLastPost extends StatelessWidget {
  const PinnedSearchLastPost({
    required this.lastPostAt,
    required this.hasBaseline,
    super.key,
  });

  final DateTime? lastPostAt;
  final bool hasBaseline;

  @override
  Widget build(BuildContext context) {
    Widget buildText() {
      final strings = context.t.pinned_searches;
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

class PinnedSearchCardMetadata extends StatelessWidget {
  const PinnedSearchCardMetadata({
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
        if (leading != null) const SizedBox(width: pinnedSearchCardMetadataGap),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * (leading == null ? 1 : 2 / 3),
          ),
          child: PinnedSearchLastPost(
            lastPostAt: lastPostAt,
            hasBaseline: hasBaseline,
          ),
        ),
      ],
    ),
  );
}

class PinnedSearchCard extends StatelessWidget {
  const PinnedSearchCard({
    required this.subscription,
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
  final SearchSubscription subscription;
  final BooruConfigAuth? config;
  final List<PopupMenuEntry<PinnedSearchAction>> Function(BuildContext)?
  actionItemBuilder;
  final Widget? metadata;
  final Widget? preview;
  final bool refreshing;
  final VoidCallback? onOpen;
  final bool showMoveActions;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<PinnedSearchAction> onAction;
  final VoidCallback? onSelect;
  final bool selected;
  final bool selecting;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.pinned_searches;

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
            padding: pinnedSearchCardContentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subscription.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (subscription.hasNewPosts)
                      Semantics(
                        label: strings.new_posts,
                        excludeSemantics: true,
                        child: Badge(label: Text(strings.new_badge)),
                      ),
                    if (selected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    if (!selecting)
                      PopupMenuButton<PinnedSearchAction>(
                        icon: const Icon(Symbols.more_vert),
                        onSelected: onAction,
                        itemBuilder: (context) =>
                            actionItemBuilder?.call(context) ??
                            [
                              PopupMenuItem(
                                value: PinnedSearchAction.info,
                                child: Text(strings.info),
                              ),
                              PopupMenuItem(
                                value: PinnedSearchAction.refresh,
                                enabled: !refreshing,
                                child: Text(strings.refresh),
                              ),
                              PopupMenuItem(
                                value: PinnedSearchAction.edit,
                                child: Text(context.t.generic.action.edit),
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
                                value: PinnedSearchAction.moveFolder,
                                child: Text(strings.move_to_folder),
                              ),
                              PopupMenuItem(
                                value: PinnedSearchAction.delete,
                                child: Text(strings.remove),
                              ),
                            ],
                      ),
                  ],
                ),
                if (subscription.displayName != subscription.query)
                  Text(subscription.query),
                if (preview != null)
                  preview!
                else if (subscription.previews.isNotEmpty && config != null)
                  Padding(
                    padding: pinnedSearchCardPreviewPadding,
                    child: Row(
                      children: [
                        for (final preview in subscription.previews.take(4))
                          Expanded(
                            child: Padding(
                              padding: pinnedSearchCardThumbnailPadding,
                              child: BooruImage(
                                imageUrl: preview.thumbnailUrl,
                                config: config!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        for (var i = subscription.previews.length; i < 4; i++)
                          const Spacer(),
                      ],
                    ),
                  ),
                metadata ??
                    PinnedSearchCardMetadata(
                      leading: ownerCaption,
                      lastPostAt: subscription.lastPostAt,
                      hasBaseline: subscription.hasBaseline,
                    ),
                if (refreshing) Text(strings.refreshing),
                if (subscription.lastErrorKind case final kind?)
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
