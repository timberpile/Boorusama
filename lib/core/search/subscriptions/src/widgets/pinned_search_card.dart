// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../images/booru_image.dart';
import '../types/search_subscription.dart';
import 'search_refresh_error_text.dart';

enum PinnedSearchAction {
  info,
  refresh,
  rename,
  moveUp,
  moveDown,
  moveFolder,
  delete,
}

class PinnedSearchCard extends StatelessWidget {
  const PinnedSearchCard({
    required this.subscription,
    required this.config,
    required this.refreshing,
    required this.onOpen,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onAction,
    this.ownerCaption,
    super.key,
  });

  final String? ownerCaption;
  final SearchSubscription subscription;
  final BooruConfigAuth config;
  final bool refreshing;
  final VoidCallback? onOpen;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<PinnedSearchAction> onAction;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.pinned_searches;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                  PopupMenuButton<PinnedSearchAction>(
                    icon: const Icon(Symbols.more_vert),
                    onSelected: onAction,
                    itemBuilder: (context) => [
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
                        value: PinnedSearchAction.rename,
                        child: Text(strings.rename),
                      ),
                      PopupMenuItem(
                        value: PinnedSearchAction.moveUp,
                        enabled: canMoveUp,
                        child: Text(strings.move_up),
                      ),
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
                        child: Text(context.t.generic.action.delete),
                      ),
                    ],
                  ),
                ],
              ),
              if (subscription.displayName != subscription.query)
                Text(subscription.query),
              if (subscription.previews.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      for (final preview in subscription.previews.take(4))
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: BooruImage(
                              imageUrl: preview.thumbnailUrl,
                              config: config,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      for (var i = subscription.previews.length; i < 4; i++)
                        const Spacer(),
                    ],
                  ),
                ),
              if (ownerCaption case final caption?)
                Text(caption, style: Theme.of(context).textTheme.bodySmall),
              if (refreshing) Text(strings.refreshing),
              if (subscription.lastErrorKind case final kind?)
                Text(
                  searchRefreshErrorText(context, kind),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
