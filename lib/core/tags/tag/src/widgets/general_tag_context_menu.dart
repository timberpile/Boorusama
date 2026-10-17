// Package imports:
import 'package:context_menus/context_menus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../foundation/clipboard.dart';
import '../../../../configs/config/providers.dart';
import '../../../../blacklists/providers.dart';
import '../../../../search/search/routes.dart';
import '../../../../search/following_topics/providers.dart';
import '../../../../search/following_topics/src/widgets/topic_follow_control.dart';
import '../../../favorites/providers.dart';

class GeneralTagContextMenu extends ConsumerWidget
    with TagContextMenuButtonConfigMixin {
  const GeneralTagContextMenu({
    required this.tag,
    required this.child,
    super.key,
    this.itemBindings = const {},
  });

  final String tag;
  final Widget child;
  final Map<String, void Function()> itemBindings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalNotifier = ref.watch(globalBlacklistedTagsProvider.notifier);
    final config = ref.watchConfig;
    final followCount = ref.watch(
      followedTopicCountProvider((profileId: config.id, query: tag)),
    );

    return ContextMenuRegion(
      contextMenu: GenericContextMenu(
        buttonConfigs: [
          copyButton(context, tag),
          searchButton(ref, tag),
          ContextMenuButtonConfig(
            followCount > 0
                ? context.t.following_topics.following
                : context.t.following_topics.follow,
            icon: followCount > 0
                ? Badge(
                    label: Text('$followCount'),
                    child: const Icon(Icons.rss_feed),
                  )
                : const Icon(Icons.rss_feed),
            onPressed: () => showTopicFollowFlow(
              context,
              ref,
              profileId: config.id,
              query: tag,
            ),
          ),
          ContextMenuButtonConfig(
            context.t.post.detail.add_to_favorites,
            onPressed: () {
              ref.read(favoriteTagsProvider.notifier).add(tag);
            },
          ),
          ContextMenuButtonConfig(
            context.t.tags.actions.add_to_blacklist_global,
            onPressed: () {
              globalNotifier.addTagWithToast(context, tag);
            },
          ),
          for (final entry in itemBindings.entries)
            ContextMenuButtonConfig(
              entry.key,
              onPressed: entry.value,
            ),
        ],
      ),
      child: child,
    );
  }
}

mixin TagContextMenuButtonConfigMixin {
  ContextMenuButtonConfig copyButton(BuildContext context, String tag) =>
      ContextMenuButtonConfig(
        context.t.tags.actions.copy_single,
        onPressed: () {
          AppClipboard.copyAndToast(
            context,
            tag,
            message: context.t.generic.copied,
          );
        },
      );

  ContextMenuButtonConfig searchButton(WidgetRef ref, String tag) =>
      ContextMenuButtonConfig(
        ref.context.t.tags.actions.search_single,
        onPressed: () {
          goToSearchPage(ref, tag: tag);
        },
      );
}
