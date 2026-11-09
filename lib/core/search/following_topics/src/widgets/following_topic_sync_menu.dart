import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../../backups/folder_sync/providers.dart';
import '../../../../backups/folder_sync/widgets.dart';
import '../../../../bookmarks/src/widgets/bookmark_group_name_dialog.dart';
import '../providers/following_topics_notifier.dart';
import 'following_topic_card.dart';

/// Legacy callers still provide their action descriptors; one Kurumi presenter
/// owns every rendered row and appends collection actions in the same style.
class FollowingTopicSyncMenu extends ConsumerWidget {
  const FollowingTopicSyncMenu({
    required this.entries,
    required this.onAction,
    this.localId,
    this.enabledSync = true,
    this.folder = false,
    super.key,
  });
  final List<PopupMenuEntry<FollowingTopicAction>> entries;
  final ValueChanged<FollowingTopicAction> onAction;
  final String? localId;
  final bool enabledSync;
  final bool folder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var received = false;
    if (localId != null && ref.exists(folderSyncServiceProvider)) {
      ref.watch(folderSyncStateProvider);
      received =
          (ref.read(folderSyncServiceProvider).snapshot['subscriptions']
                      as Map<String, dynamic>? ??
                  {})
              .values
              .any(
                (s) =>
                    s['kind'] == 'following_topics' && s['localId'] == localId,
              );
    }
    return Tooltip(
      message: context.t.generic.action.more,
      child: KurumiPopupMenuButton(
        semanticLabel: context.t.generic.action.more,
        child: const SizedBox.square(
          dimension: 48,
          child: Icon(Icons.more_vert),
        ),
        items: [
          for (final entry in entries)
            if (entry is PopupMenuItem<FollowingTopicAction> &&
                !(received &&
                    const {
                      FollowingTopicAction.edit,
                      FollowingTopicAction.delete,
                    }.contains(entry.value)))
              KurumiPopupMenuItem(
                title: entry.child ?? const SizedBox.shrink(),
                onTap: entry.enabled && entry.value != null
                    ? () => onAction(entry.value!)
                    : null,
              ),
          if (received)
            KurumiPopupMenuItem(
              title: Text(context.t.generic.action.edit),
              icon: const Icon(Icons.edit_outlined),
              onTap: () async {
                final notifier = ref.read(followingTopicsProvider.notifier);
                final parentId = ref
                    .read(followingTopicsProvider)
                    .valueOrNull
                    ?.organization
                    .folders
                    .where((f) => f.id == localId)
                    .firstOrNull
                    ?.parentId;
                final name = await showBookmarkGroupNameDialog(
                  context,
                  title: context.t.folder_sync.local_name,
                );
                if (name == null || !context.mounted) return;
                if (folder)
                  await notifier.renameSharedFolder(
                    localId!,
                    name,
                    parentId: parentId,
                  );
                else
                  await notifier.rename(localId!, name);
              },
            ),
          if (enabledSync && localId != null)
            KurumiPopupMenuItem(
              title: Text(
                collectionSyncActionLabel(
                  context,
                  ref,
                  kind: 'following_topics',
                  localId: localId!,
                ),
              ),
              icon: Icon(received ? Icons.sync : Icons.upload_outlined),
              onTap: () => openFolderSyncForCollection(
                context,
                kind: 'following_topics',
                localId: localId!,
              ),
            ),
        ],
      ),
    );
  }
}
