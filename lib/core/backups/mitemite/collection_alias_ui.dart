import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../bookmarks/src/types/bookmark_group.dart';
import '../../bookmarks/src/types/bookmark_mirror_state.dart';
import '../../bookmarks/src/widgets/bookmark_group_label.dart';
import '../../search/following_topics/src/types/following_mirror_state.dart';
import 'actions.dart';
import 'name_dialog.dart';
import 'protocol.dart';
import 'providers.dart';
import 'service.dart';

SyncCollectionId? bookmarkAliasSource(
  BookmarkMirrorState mirrors,
  String localId,
) {
  final owner = mirrors.owners[localId];
  return owner == null
      ? null
      : SyncCollectionId(
          publisher: owner.publisher,
          kind: 'bookmarks',
          source: owner.source,
        );
}

SyncCollectionId? followingAliasSource(
  FollowingMirrorState mirrors,
  String localId,
) {
  final owner = mirrors.owners[localId];
  return owner == null || owner.kind != FollowingMirrorKind.folder
      ? null
      : SyncCollectionId(
          publisher: owner.publisher,
          kind: 'following_topics',
          source: owner.source,
        );
}

String bookmarkAliasLabel(
  BuildContext context,
  BookmarkGroup group,
  BookmarkMirrorState mirrors,
  Map<SyncCollectionId, String> aliases,
) =>
    aliases[bookmarkAliasSource(mirrors, group.id)] ??
    group.displayName(context);

String followingAliasLabel(
  String canonical,
  String localId,
  FollowingMirrorState mirrors,
  Map<SyncCollectionId, String> aliases,
) => aliases[followingAliasSource(mirrors, localId)] ?? canonical;

List<Widget> collectionAliasMenu(
  BuildContext context,
  WidgetRef ref, {
  required SyncCollectionId id,
  required String sourceName,
}) {
  final t = context.t.mitemite;
  final alias = ref.read(syncCollectionAliasesProvider)[id];
  Future<void> save(String? value) => runSyncAction(context, () async {
    final service = await ref.read(miteMiteServiceProvider.future);
    if (!context.mounted || !isCurrentSyncService(context, service)) return;
    await service.setCollectionAlias(id, value);
  });
  return [
    KurumiPopupMenuItem(
      title: Text(
        alias == null ? t.set_collection_alias : t.edit_collection_alias,
      ),
      icon: const Icon(Icons.edit_outlined),
      onTap: () async {
        final value = await showSyncNameDialog(
          context,
          title: alias == null
              ? t.set_collection_alias
              : t.edit_collection_alias,
          initial: alias ?? '',
          hint: t.collection_alias_hint,
          sourceName: sourceName,
          allowEmpty: true,
        );
        if (value != null && context.mounted) await save(value);
      },
    ),
  ];
}
