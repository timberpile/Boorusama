import '../../search/following_topics/src/types/following_topic_source.dart';
import 'activity_log.dart';
import 'failure.dart';
import 'receive_units.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../foundation/picker.dart';
import '../../../foundation/platform.dart';
import '../../bookmarks/providers.dart';
import '../../bookmarks/src/types/bookmark_group.dart';
import '../../bookmarks/src/types/bookmark_group_tree.dart';
import '../../bookmarks/src/types/bookmark_library_state.dart';
import '../../bookmarks/src/types/bookmark_mirror_state.dart';
import '../auto/repo_android.dart';
import 'bookmark_scope.dart';
import 'providers.dart';
import 'service.dart';

Future<bool> confirmSyncAction(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => KurumiDialog(
        semanticLabel: title,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(message),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.t.generic.action.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(title),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ) ??
    false;

String syncErrorMessage(BuildContext context, Object error) {
  if (error case SyncPartialReceiveFailure(:final failures))
    return '${context.t.mitemite.partial} ${syncErrorMessage(context, failures.values.first)}';
  if (error is FollowingLocalCopySourceUnavailable)
    return context.t.mitemite.following_paused;
  if (error is SyncPublicationPending)
    return context.t.mitemite.publication_pending;
  return syncFailureMessage(context, syncFailureKind(error));
}

String syncFailureMessage(BuildContext context, SyncFailureKind failure) {
  final t = context.t.mitemite;
  return switch (failure) {
    SyncFailureKind.permission => t.permission_required,
    SyncFailureKind.unavailable => t.unavailable,
    SyncFailureKind.missingRevision => t.revision_unavailable,
    SyncFailureKind.unsupported => t.update_required,
    SyncFailureKind.identityChanged => t.identity_changed,
    SyncFailureKind.identityFile => t.identity_file_unavailable,
    SyncFailureKind.invalidSignature => t.invalid_signature,
    SyncFailureKind.rollback => t.rollback_rejected,
    SyncFailureKind.conflict => t.conflict,
    SyncFailureKind.retryableIo => t.storage_failed,
    SyncFailureKind.invalidData => t.invalid_data,
    SyncFailureKind.unknown => t.failed,
  };
}

Future<void> runSyncAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted)
      Kurumi.showErrorToast(context, syncErrorMessage(context, error));
  }
}

/// Recheck captured resources after dialogs/awaits and before starting an action.
/// A replacement must not silently borrow the previous instance's authority.
bool isCurrentSyncService(BuildContext context, MiteMiteService service) =>
    context.mounted &&
    identical(
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(currentMiteMiteServiceProvider),
      service,
    );

Future<void> runCurrentSyncAction(
  BuildContext context,
  MiteMiteService service,
  Future<void> Function() action,
) => runSyncAction(context, () async {
  if (context.mounted && isCurrentSyncService(context, service)) await action();
});

Future<bool> chooseSyncFolder(
  BuildContext context,
  WidgetRef ref,
  MiteMiteService service,
) async {
  if (!context.mounted || !isCurrentSyncService(context, service)) return false;
  final location = ref.read(appPlatformProvider).isAndroid
      ? await AutoBackupRepositoryAndroid.pickDirectory()
      : await ref.read(appFilePickerProvider).pickDirectory();
  if (location == null ||
      !context.mounted ||
      !isCurrentSyncService(context, service))
    return false;
  try {
    await service.configure(location);
  } finally {
    if (context.mounted &&
        isCurrentSyncService(context, service) &&
        service.configured) {
      ref.read(miteMiteActivationProvider.notifier).state = true;
    }
  }
  return service.configured;
}

/// A contextual Publish keeps its captured target through folder setup and
/// confirmation. It never substitutes a generic root-selection screen.
Future<void> publishBookmarkGroup(
  BuildContext context,
  WidgetRef ref,
  String source,
) => runSyncAction(context, () async {
  final service = await ref.read(miteMiteServiceProvider.future);
  if (!context.mounted || !isCurrentSyncService(context, service)) return;
  if (!service.configured && !await chooseSyncFolder(context, ref, service))
    return;
  if (!context.mounted || !isCurrentSyncService(context, service)) return;
  var state = await ref.read(bookmarkProvider.future);
  if (!context.mounted || !isCurrentSyncService(context, service)) return;
  var group = state.groupsById[source];
  if (group == null || state.mirrors.isReceived(source))
    throw const BookmarkMirrorReadOnly();
  if (service.publishedRoots.contains(source)) return;
  if (!await confirmSyncAction(
    context,
    context.t.mitemite.publish,
    context.t.mitemite.confirm_publish(name: group.name),
  ))
    return;
  if (!context.mounted || !isCurrentSyncService(context, service)) return;
  // The dialog may have outlived a rename, deletion or ownership change.
  await ref.read(bookmarkProvider.notifier).refresh();
  if (!context.mounted || !isCurrentSyncService(context, service)) return;
  state = ref.read(bookmarkProvider).requireValue;
  group = state.groupsById[source];
  if (group == null || state.mirrors.isReceived(source))
    throw const BookmarkMirrorReadOnly();
  await service.publishGroup(source);
  if (context.mounted)
    Kurumi.showSuccessToast(context, context.t.mitemite.publication_done);
});

Set<String> syncPublicationCoverage(
  Iterable<BookmarkGroup> groups,
  Set<String> roots,
) {
  final tree = BookmarkGroupTree(groups);
  final ids = groups.map((g) => g.id).toSet();
  return {
    for (final root in roots)
      if (ids.contains(root)) ...tree.subtreeIds(root),
  };
}

Future<void> stopBookmarkPublication(
  BuildContext context,
  WidgetRef ref,
  MiteMiteService service,
  String source,
) => runSyncAction(context, () async {
  final state = await ref.read(bookmarkProvider.future);
  if (!context.mounted ||
      !isCurrentSyncService(context, service) ||
      !service.publishedRoots.contains(source))
    return;
  final local = state.groups
      .where((group) => !state.mirrors.isReceived(group.id))
      .toList();
  final before = syncPublicationCoverage(local, service.publishedRoots);
  final after = syncPublicationCoverage(
    local,
    {...service.publishedRoots}..remove(source),
  );
  final name = state.groupsById[source]?.name ?? source;
  if (!await confirmSyncAction(
    context,
    context.t.mitemite.stop_publishing,
    '${context.t.mitemite.confirm_stop(name: name)}\n\n'
    '${context.t.mitemite.publication_impact(removed: before.difference(after).length, retained: before.intersection(after).length)}',
  ))
    return;
  if (!context.mounted || !isCurrentSyncService(context, service)) return;
  await service.stopPublishingGroup(source);
  if (context.mounted)
    Kurumi.showSuccessToast(context, context.t.mitemite.publication_stopped);
});

/// The transaction recomputes this overlap-aware preview. Missing transport is
/// never deletion evidence and does not prevent explicit local management.
String syncRemovalMessage(
  BuildContext context,
  BookmarkLibraryState library,
  String publisher, [
  String? source,
]) {
  final owned = library.mirrors.owners.values
      .where((owner) => owner.publisher == publisher)
      .toList();
  final roots = library.mirrors.subscriptions[publisher] ?? const <String>{};
  final nodes = [
    for (final owner in owned)
      SyncBookmarkNode(
        source: owner.source,
        parent: owner.parentSource,
        position: owner.position,
      ),
  ];
  final known = nodes.map((node) => node.source).toSet();
  final count = source == null
      ? owned.length
      : !known.contains(source)
      ? 0
      : BookmarkSyncScope(
          publisher: publisher,
          nodes: nodes,
          directRoots: roots.intersection(known),
        ).uncoveredAfterUnsubscribe(source).length;
  return '${source == null ? context.t.mitemite.confirm_forget : context.t.mitemite.confirm_remove}\n\n'
      '${context.t.mitemite.remove_count(count: count)}';
}
