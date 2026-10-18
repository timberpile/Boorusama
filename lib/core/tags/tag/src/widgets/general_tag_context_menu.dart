// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../foundation/clipboard.dart';
import '../../../../blacklists/providers.dart';
import '../../../../configs/config/providers.dart';
import '../../../../search/search/routes.dart';
import '../../../../search/following_topics/providers.dart';
import '../../../../search/following_topics/src/widgets/topic_follow_control.dart';
import '../../../favorites/providers.dart';

class GeneralTagContextMenu extends ConsumerWidget
    with TagContextMenuItemsMixin {
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

    return KurumiContextMenu(
      menuItemsBuilder: (_) => [
        copyButton(context, tag),
        searchButton(ref, tag),
        KurumiContextMenuTile(
          title: followCount > 0
              ? context.t.following_topics.following
              : context.t.following_topics.follow,
          trailing: followCount > 0
              ? Badge(
                  label: Text('$followCount'),
                  child: const Icon(Icons.rss_feed),
                )
              : const Icon(Icons.rss_feed),
          onTap: () => showTopicFollowFlow(
            context,
            ref,
            profileId: config.id,
            query: tag,
          ),
        ),
        KurumiContextMenuTile(
          title: context.t.post.detail.add_to_favorites,
          onTap: () {
            ref.read(favoriteTagsProvider.notifier).add(tag);
          },
        ),
        KurumiContextMenuTile(
          title: context.t.tags.actions.add_to_blacklist_global,
          onTap: () {
            globalNotifier.addTagWithToast(context, tag);
          },
        ),
        for (final entry in itemBindings.entries)
          KurumiContextMenuTile(
            title: entry.key,
            onTap: entry.value,
          ),
      ],
      child: child,
    );
  }
}

mixin TagContextMenuItemsMixin {
  Widget copyButton(BuildContext context, String tag) => KurumiContextMenuTile(
    title: context.t.tags.actions.copy_single,
    onTap: () {
      AppClipboard.copyAndToast(
        context,
        tag,
        message: context.t.generic.copied,
      );
    },
  );

  Widget searchButton(WidgetRef ref, String tag) => KurumiContextMenuTile(
    title: ref.context.t.tags.actions.search_single,
    onTap: () {
      goToSearchPage(ref, tag: tag);
    },
  );
}
