import 'collection_alias_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../search/following_topics/src/providers/following_topics_notifier.dart';
import '../../search/following_topics/src/types/following_mirror_state.dart';
import '../../search/following_topics/src/types/topic_organization.dart';
import 'mitemite_icon.dart';
import 'actions.dart';
import 'bookmark_scope.dart';
import 'page.dart';
import 'providers.dart';
import 'service.dart';

BookmarkSyncScope followingReceivedScope(
  FollowingMirrorState state,
  String publisher,
) => BookmarkSyncScope(
  publisher: publisher,
  nodes: [
    for (final owner in state.owners.values)
      if (owner.publisher == publisher)
        SyncBookmarkNode(
          source: owner.source,
          parent: owner.parentSource,
          position: owner.position,
        ),
  ],
  directRoots: (state.subscriptions[publisher] ?? const {})
      .where((id) => state.localIdFor(publisher, id) != null)
      .toSet(),
);

Set<String> followingPublicationReasons(
  TopicOrganization organization,
  String id,
  Set<String> roots,
) {
  final folder = organization.folders.where((f) => f.id == id).firstOrNull;
  final parent =
      folder?.parentId ??
      organization.placements
          .where((p) => p.itemId == id)
          .firstOrNull
          ?.folderId;
  return {
    if (roots.contains(id)) id,
    for (final ancestor in organization.tree.ancestors(parent))
      if (roots.contains(ancestor.id)) ancestor.id,
  };
}

Future<void> unsubscribeFollowingDefinition(
  BuildContext context,
  MiteMiteService service,
  String publisher,
  String source,
) => runSyncAction(context, () async {
  final state = service.receiverFollowing?.mirrors;
  if (state == null) return;
  final scope = followingReceivedScope(state, publisher);
  final count = scope.directRoots.contains(source)
      ? scope.uncoveredAfterUnsubscribe(source).length
      : 0;
  if (await confirmSyncAction(
        context,
        context.t.mitemite.unsubscribe,
        context.t.mitemite.confirm_following_remove(count: count),
      ) &&
      context.mounted) {
    await service.unsubscribeFollowing(publisher, source);
  }
});

Future<void> stopFollowingPublication(
  BuildContext context,
  MiteMiteService service,
  String source,
  String label,
) => runSyncAction(context, () async {
  if (await confirmSyncAction(
        context,
        context.t.mitemite.stop_publishing,
        context.t.mitemite.confirm_following_stop(name: label),
      ) &&
      context.mounted) {
    await service.stopPublishingFollowing(source);
  }
});

Future<void> publishFollowingDefinition(
  BuildContext context,
  WidgetRef ref,
  String id,
) => runSyncAction(context, () async {
  final service = await ref.read(miteMiteServiceProvider.future);
  if (!context.mounted) return;
  if (!service.configured && !await chooseSyncFolder(context, ref, service))
    return;
  if (!context.mounted) return;
  final state = await ref.read(followingTopicsProvider.future);
  if (!context.mounted) return;
  if (state.mirrors.isReceived(id)) throw const FollowingMirrorReadOnly();
  final label = state.organization.folders
      .where((f) => f.id == id)
      .firstOrNull
      ?.name;
  if (label == null) throw const FollowingMirrorConflict();
  if (service.publishedFollowingRoots.contains(id)) return;
  if (await confirmSyncAction(
        context,
        context.t.mitemite.publish,
        context.t.mitemite.confirm_following_publish(name: label),
      ) &&
      context.mounted) {
    await service.publishFollowing(id);
    ref.invalidate(publishedFollowingRootsProvider);
  }
});

/// Shared by Topic, folder and owning Feed entry points. Operational controls
/// stay on their existing cards; these actions never edit a received definition.
List<Widget> followingSyncMenu(
  BuildContext context,
  WidgetRef ref,
  FollowingTopicsState state,
  String id,
) {
  final t = context.t.mitemite;
  final owner = state.mirrors.owners[id];
  if (owner == null) {
    if (!state.organization.folders.any((folder) => folder.id == id))
      return const [];
    final direct = ref.read(publishedFollowingRootsProvider).contains(id);
    return [
      KurumiPopupMenuItem(
        title: Text(direct ? t.manage_publication : t.publish),
        icon: const MiteMiteIcon(),
        onTap: () => direct
            ? openFollowingSyncManagement(context, 'publish')
            : publishFollowingDefinition(context, ref, id),
      ),
    ];
  }
  return [
    if (followingAliasSource(state.mirrors, id) case final source?)
      ...collectionAliasMenu(
        context,
        ref,
        id: source,
        sourceName: state.organization.folders
            .singleWhere((folder) => folder.id == id)
            .name,
      ),
    KurumiPopupMenuItem(
      title: Text(t.copy),
      icon: const Icon(Icons.copy),
      onTap: () => runSyncAction(context, () async {
        final service = await ref.read(miteMiteServiceProvider.future);
        await service.localFollowingCopy(id);
      }),
    ),
    if (state.mirrors.subscriptions[owner.publisher]?.contains(owner.source) ??
        false)
      KurumiPopupMenuItem(
        title: Text(t.unsubscribe),
        icon: const Icon(Icons.link_off),
        onTap: () => runSyncAction(context, () async {
          final service = await ref.read(miteMiteServiceProvider.future);
          if (context.mounted)
            await unsubscribeFollowingDefinition(
              context,
              service,
              owner.publisher,
              owner.source,
            );
        }),
      ),
  ];
}

void openFollowingSyncManagement(BuildContext context, String section) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => MiteMitePage(section: section)),
  );
}
