import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import 'pages.dart';
import 'route_utils.dart';
import '../../bookmarks/providers.dart';
import 'providers.dart';

/// A compact existing-card slot, never a new announcement row.
class CollectionSyncIndicator extends ConsumerWidget {
  const CollectionSyncIndicator({
    required this.kind,
    required this.localId,
    this.numericOnly = false,
    this.color,
    super.key,
  });
  final String kind;
  final String localId;
  final bool numericOnly;
  final Color? color;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.exists(folderSyncServiceProvider)) return const SizedBox.shrink();
    ref.watch(folderSyncStateProvider);
    final service = ref.read(folderSyncServiceProvider);
    final metadata = service.snapshot;
    final subscriptions =
        metadata['subscriptions'] as Map<String, dynamic>? ?? {};
    final received = subscriptions.values
        .cast<Map>()
        .where((s) => s['kind'] == kind && s['localId'] == localId)
        .firstOrNull;
    final publication =
        (metadata['publications'] as Map<String, dynamic>? ??
        {})['$kind/$localId'];
    if (numericOnly) {
      final library = kind == 'bookmarks'
          ? ref.watch(bookmarkProvider).valueOrNull
          : null;
      final ids = library != null && library.groupsById.containsKey(localId)
          ? library.groupTree.subtreeIds(localId)
          : {localId};
      final affected = subscriptions.values.cast<Map>().where(
        (s) => s['kind'] == kind && ids.contains(s['localId']),
      );
      final unseen = {
        for (final s in affected)
          ...(s['unseen'] as List? ?? const []).cast<String>(),
      };
      final changed = affected.any((s) => s['changed'] == true);
      if (unseen.isEmpty && !changed) return const SizedBox.shrink();
      return Semantics(
        label: context.t.folder_sync.unseen,
        child: Container(
          padding: unseen.isNotEmpty
              ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
              : const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(10),
          ),
          child: unseen.isNotEmpty
              ? Text(
                  '+${unseen.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                )
              : null,
        ),
      );
    }
    if (received == null && publication?['state'] != 'active')
      return const SizedBox.shrink();
    final changed = received?['changed'] == true;
    final label = received == null
        ? context.t.folder_sync.published
        : context.t.folder_sync.readonly;
    if (kind == 'following_topics' && changed) {
      return Tooltip(
        message: context.t.folder_sync.definitions_changed,
        child: IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: Badge(
            smallSize: 5,
            child: Icon(Icons.sync_outlined, size: 16, color: color),
          ),
          onPressed: () async {
            await showDialog<void>(
              context: context,
              builder: (context) => KurumiDialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.t.folder_sync.definitions_changed),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.t.generic.action.ok),
                    ),
                  ],
                ),
              ),
            );
            await service.markSeen(kind, localId);
          },
        ),
      );
    }
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: received == null
            ? Icon(Icons.upload_outlined, size: 18, color: color)
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.sync, size: 18, color: color),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Icon(Icons.lock_outline, size: 9, color: color),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Acknowledges only a rendered Group's own received revision. Visiting an
/// ancestor leaves descendant unseen additions intact.
class CollectionSyncSeen extends ConsumerStatefulWidget {
  const CollectionSyncSeen({
    required this.localId,
    required this.child,
    super.key,
  });
  final String localId;
  final Widget child;
  @override
  ConsumerState<CollectionSyncSeen> createState() => _CollectionSyncSeenState();
}

class _CollectionSyncSeenState extends ConsumerState<CollectionSyncSeen> {
  Object? _last;
  @override
  Widget build(BuildContext context) {
    if (ref.exists(folderSyncServiceProvider)) {
      ref.watch(folderSyncStateProvider);
      final service = ref.read(folderSyncServiceProvider);
      final subscriptions =
          service.snapshot['subscriptions'] as Map<String, dynamic>? ?? {};
      final current = subscriptions.values
          .cast<Map>()
          .where(
            (s) => s['kind'] == 'bookmarks' && s['localId'] == widget.localId,
          )
          .firstOrNull;
      final revision = (widget.localId, current?['applied']);
      if (current != null && current['state'] == 'ready' && revision != _last) {
        _last = revision;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
            unawaited(service.markSeen('bookmarks', widget.localId));
          }
        });
      }
    }
    return widget.child;
  }
}

String collectionSyncActionLabel(
  BuildContext context,
  WidgetRef ref, {
  required String kind,
  required String localId,
}) {
  if (!ref.exists(folderSyncServiceProvider))
    return context.t.folder_sync.publish;
  final data = ref.read(folderSyncServiceProvider).snapshot;
  if ((data['subscriptions'] as Map<String, dynamic>? ?? {}).values.any(
    (s) => s['kind'] == kind && s['localId'] == localId,
  )) {
    return context.t.folder_sync.manage;
  }
  if ((data['rules'] as Map<String, dynamic>? ?? {}).containsKey(
        '$kind/$localId',
      ) ||
      (data['publications'] as Map<String, dynamic>? ??
              {})['$kind/$localId']?['state'] ==
          'active') {
    return context.t.folder_sync.manage_publication;
  }
  return context.t.folder_sync.publish;
}

Future<void> openFolderSyncForCollection(
  BuildContext context, {
  required String kind,
  required String localId,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final service = container.read(folderSyncServiceProvider);
  try {
    await service.initialize();
    final subscriptions =
        service.snapshot['subscriptions'] as Map<String, dynamic>? ?? {};
    final received = subscriptions.values.any(
      (s) => s['kind'] == kind && s['localId'] == localId,
    );
    final sources = await service.port.sources();
    final source = sources
        .where((s) => s.kind == kind && s.id == localId)
        .firstOrNull;
    if (!context.mounted) return;
    if (received) {
      await pushFolderSyncPage(
        context,
        (_) => const FolderSyncReceivePage(),
      );
    } else if (!service.configured) {
      await pushFolderSyncPage(
        context,
        (_) => FolderSyncPage(intendedPublication: source),
      );
    } else if (source != null) {
      final selection = service.publicationSelection(source, sources);
      if (!selection.direct && !selection.inherited)
        await service.setPublication(source, enabled: true);
      if (context.mounted) {
        await pushFolderSyncPage(
          context,
          (_) => const FolderSyncPublishPage(),
        );
      }
    }
  } catch (_) {
    if (context.mounted) {
      Kurumi.showErrorToast(context, context.t.folder_sync.failed);
    }
  }
}
