import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../providers/following_topic_selectors.dart';
import '../providers/following_topics_notifier.dart';
import 'follow_topic_dialog.dart';
import 'follow_topic_folder_picker.dart';
import 'search_folder_dialog.dart';

class FollowTopicButton extends ConsumerWidget {
  const FollowTopicButton({
    required this.query,
    this.compact = false,
    super.key,
  });

  final String query;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.trim().isEmpty) return const SizedBox.shrink();
    final config = ref.watchConfig;
    final supported = ref.watch(
      followingTopicTrackingSupportedProvider(config.auth),
    );
    final state = ref.watch(followingTopicsProvider).valueOrNull;
    final count = ref.watch(
      followedTopicCountProvider((profileId: config.id, query: query)),
    );
    final strings = context.t.following_topics;
    final icon = Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: Icon(Symbols.rss_feed, fill: count > 0 ? 1 : 0),
    );
    final action = supported && state != null
        ? () => showTopicFolderFollowDialog(
            context,
            profileId: config.id,
            query: query,
          )
        : null;
    if (compact) {
      return TopicFollowPill(following: count > 0, onPressed: action);
    }
    return TextButton.icon(
      onPressed: action,
      icon: icon,
      label: Text(count > 0 ? strings.following : strings.follow),
    );
  }
}

/// Shared compact follow control for search results and artist pages.
class TopicFollowPill extends StatelessWidget {
  const TopicFollowPill({
    required this.following,
    required this.onPressed,
    super.key,
  });

  final bool following;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.following_topics;
    final colors = Theme.of(context).colorScheme;
    final label = following ? strings.following : strings.follow;
    return Tooltip(
      message: label,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: following
              ? colors.surfaceContainerHighest
              : colors.primary,
          foregroundColor: following
              ? colors.onSurfaceVariant
              : colors.onPrimary,
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

Future<void> showTopicFolderFollowDialog(
  BuildContext context, {
  required String profileId,
  required String query,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final notifier = container.read(followingTopicsProvider.notifier);
  String? folderId;
  var newFolder = false;
  await showFollowTopicDialog(
    context,
    query: query,
    extra: FollowTopicFolderPicker(
      onSelected: (id, create) {
        folderId = id;
        newFolder = create;
      },
    ),
    onSubmit: (dialogContext, name) async {
      if (newFolder) {
        final folderName = await showSearchFolderNameDialog(dialogContext);
        if (folderName == null || !dialogContext.mounted) return false;
        final topic = await notifier.saveTopicInNewFolder(
          profileId: profileId,
          query: query,
          name: name,
          folderName: folderName,
        );
        unawaited(notifier.refresh(topic.id));
      } else {
        await notifier.follow(
          profileId: profileId,
          query: query,
          name: name,
          folderId: folderId,
        );
      }
      return true;
    },
  );
}
