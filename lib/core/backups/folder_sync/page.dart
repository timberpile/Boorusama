import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../foundation/picker.dart';
import '../../../foundation/platform.dart';
import '../../bookmarks/providers.dart';
import '../../bookmarks/src/types/bookmark_group_tree.dart';
import '../../bookmarks/src/types/bookmark_library_state.dart';
import '../auto/repo_android.dart';
import 'bookmark_scope.dart';
import 'catalog.dart';
import 'protocol.dart';
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

Future<void> runSyncAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      Kurumi.showErrorToast(context, context.t.folder_sync.failed);
    }
  }
}

class FolderSyncPage extends ConsumerWidget {
  const FolderSyncPage({this.section, super.key});
  final String? section;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(folderSyncServiceProvider);
    return ready.when(
      loading: () => Scaffold(
        appBar: KurumiAppBar(title: Text(context.t.folder_sync.title)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: KurumiAppBar(title: Text(context.t.folder_sync.title)),
        body: Center(child: Text(context.t.folder_sync.failed)),
      ),
      data: (service) => ListenableBuilder(
        listenable: service,
        builder: (context, _) => _page(context, ref, service),
      ),
    );
  }

  Widget _page(BuildContext context, WidgetRef ref, FolderSyncService service) {
    final t = context.t.folder_sync;
    final library = ref.watch(bookmarkProvider).valueOrNull;
    final title = switch (section) {
      'publish' => t.publish,
      'receive' => t.receive,
      'activity' => t.activity,
      _ => t.title,
    };
    Future<void> chooseFolder() => runSyncAction(context, () async {
      final location = ref.read(appPlatformProvider).isAndroid
          ? await AutoBackupRepositoryAndroid.pickDirectory()
          : await ref.read(appFilePickerProvider).pickDirectory();
      if (location == null) return;
      try {
        await service.configure(location);
      } finally {
        if (context.mounted && service.configured) {
          ref.read(folderSyncActivationProvider.notifier).state = true;
        }
      }
    });
    final children = <Widget>[];
    if (section != null && !service.configured) {
      children.add(
        ListTile(
          title: Text(t.choose_folder),
          subtitle: Text(t.not_configured),
          leading: const Icon(Icons.folder_open),
          onTap: service.busy ? null : chooseFolder,
        ),
      );
    }
    if (section == null) {
      children.addAll([
        ListTile(
          title: Text(t.shared_folder),
          subtitle: Text(
            service.location ?? t.not_configured,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.folder_open),
          onTap: service.busy ? null : chooseFolder,
        ),
        ListTile(
          title: Text(t.device_name),
          subtitle: Text(service.name),
          trailing: const Icon(Icons.edit_outlined),
          onTap: service.busy ? null : () => _name(context, service),
        ),
        ListTile(
          title: Text(
            service.busy
                ? t.working
                : service.failure != null
                ? t.failed
                : service.configured
                ? t.ready
                : t.not_configured,
          ),
          subtitle: service.lastSync == null
              ? null
              : Text('${t.last_sync}: ${service.lastSync!.toLocal()}'),
          trailing: IconButton(
            tooltip: t.sync_now,
            onPressed: !service.configured || service.busy
                ? null
                : () => runSyncAction(context, service.synchronize),
            icon: const Icon(Icons.sync),
          ),
        ),
        for (final entry in [
          ('publish', t.publish, Icons.upload),
          ('receive', t.receive, Icons.download),
          ('activity', t.activity, Icons.history),
        ])
          ListTile(
            title: Text(entry.$2),
            leading: Icon(entry.$3),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FolderSyncPage(section: entry.$1),
              ),
            ),
          ),
      ]);
    } else if (section == 'publish') {
      final groups =
          library?.groups
              .where((group) => !library.mirrors.isReceived(group.id))
              .toList() ??
          [];
      if (groups.isEmpty) {
        children.add(ListTile(title: Text(t.empty_publication)));
      }
      final tree = BookmarkGroupTree(groups);
      for (final group in groups) {
        final direct = service.publishedRoots.contains(group.id);
        final inherited = tree
            .ancestors(group.id)
            .any((parent) => service.publishedRoots.contains(parent.id));
        children.add(
          CheckboxListTile(
            title: Text(group.name),
            subtitle: Text(
              direct && inherited
                  ? t.both
                  : direct
                  ? t.direct
                  : inherited
                  ? t.inherited
                  : t.all_children,
            ),
            value: direct,
            onChanged: service.busy || !service.configured
                ? null
                : (selected) => runSyncAction(context, () async {
                    final roots = {...service.publishedRoots};
                    if (selected ?? false) {
                      roots.add(group.id);
                    } else {
                      roots.remove(group.id);
                    }
                    await service.publishRoots(roots);
                  }),
          ),
        );
      }
    } else if (section == 'receive') {
      if (service.devices.isEmpty) {
        children.add(ListTile(title: Text(t.empty_devices)));
      }
      for (final device in service.devices) {
        final approved = service.gate.approvedKey(device.id) != null;
        final roots =
            library?.mirrors.subscriptions[device.id] ?? const <String>{};
        children.add(
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  title: Text(device.catalog.name),
                  subtitle: Text(device.fingerprint, softWrap: true),
                  trailing: approved
                      ? null
                      : TextButton(
                          onPressed: service.busy
                              ? null
                              : () => runSyncAction(context, () async {
                                  if (await confirmSyncAction(
                                    context,
                                    t.trust,
                                    '${t.trust_prompt}\n\n${device.catalog.name}\n${device.fingerprint}',
                                  )) {
                                    await service.approve(device);
                                  }
                                }),
                          child: Text(t.trust),
                        ),
                ),
                for (final entry in device.catalog.entries.where(
                  (entry) =>
                      entry.id.kind == 'bookmarks' &&
                      entry.state == SyncPublicationState.active,
                ))
                  ListTile(
                    title: Text(entry.name),
                    subtitle: Text(
                      roots.contains(entry.id.source)
                          ? t.direct
                          : t.all_children,
                    ),
                    trailing: TextButton(
                      onPressed: !approved || service.busy
                          ? null
                          : () => runSyncAction(context, () async {
                              if (roots.contains(entry.id.source)) {
                                if (await confirmSyncAction(
                                  context,
                                  t.unsubscribe,
                                  syncRemovalMessage(
                                    context,
                                    library!,
                                    device.id,
                                    entry.id.source,
                                  ),
                                )) {
                                  await service.unsubscribe(
                                    device.id,
                                    entry.id.source,
                                  );
                                }
                              } else {
                                await service.subscribe(device.id, {
                                  ...roots,
                                  entry.id.source,
                                });
                              }
                            }),
                      child: Text(
                        roots.contains(entry.id.source)
                            ? t.unsubscribe
                            : t.subscribe,
                      ),
                    ),
                  ),
                if (approved)
                  TextButton(
                    onPressed: service.busy
                        ? null
                        : () => runSyncAction(context, () async {
                            if (await confirmSyncAction(
                              context,
                              t.forget,
                              syncRemovalMessage(context, library!, device.id),
                            )) {
                              await service.forget(device.id);
                            }
                          }),
                    child: Text(t.forget),
                  ),
                if (service.deviceFailures[device.id] != null)
                  ListTile(
                    title: Text(
                      service.deviceFailures[device.id] is SyncUpdateRequired
                          ? t.update_required
                          : t.unavailable,
                    ),
                  ),
              ],
            ),
          ),
        );
      }
      // Persisted subscriptions remain manageable when the transport is offline.
      for (final entry
          in library?.mirrors.subscriptions.entries ??
              const Iterable<MapEntry<String, Set<String>>>.empty()) {
        if (service.devices.any((device) => device.id == entry.key)) continue;
        children.add(
          ListTile(
            title: Text(
              library?.mirrors.publisherNames[entry.key] ?? entry.key,
            ),
            subtitle: Text(
              service.deviceFailures[entry.key] is SyncUpdateRequired
                  ? t.update_required
                  : t.unavailable,
            ),
            trailing: TextButton(
              child: Text(t.forget),
              onPressed: () => runSyncAction(context, () async {
                if (await confirmSyncAction(
                  context,
                  t.forget,
                  syncRemovalMessage(context, library!, entry.key),
                )) {
                  await service.forget(entry.key);
                }
              }),
            ),
          ),
        );
        for (final source in entry.value) {
          final localId = library!.mirrors.localIdFor(entry.key, source);
          children.add(
            ListTile(
              title: Text(library.groupsById[localId]?.name ?? source),
              subtitle: Text(t.direct),
              trailing: TextButton(
                child: Text(t.unsubscribe),
                onPressed: service.busy
                    ? null
                    : () => runSyncAction(context, () async {
                        if (await confirmSyncAction(
                          context,
                          t.unsubscribe,
                          syncRemovalMessage(
                            context,
                            library,
                            entry.key,
                            source,
                          ),
                        )) {
                          await service.unsubscribe(entry.key, source);
                        }
                      }),
              ),
            ),
          );
        }
      }
    } else {
      for (final entry
          in library?.mirrors.owners.entries ??
              const Iterable<MapEntry<String, dynamic>>.empty()) {
        final reading = entry.value.reading as Map<String, dynamic>;
        final arrivals = (reading['arrivals'] as List?)?.length ?? 0;
        children.add(
          ListTile(
            title: Text(library?.groupsById[entry.key]?.name ?? entry.key),
            subtitle: Text('${t.new_arrivals}: $arrivals'),
          ),
        );
      }
    }
    return Scaffold(
      appBar: KurumiAppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(12), children: children),
      ),
    );
  }

  Future<void> _name(BuildContext context, FolderSyncService service) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _SyncNameDialog(initial: service.name),
    );
    if (name != null && context.mounted) {
      await runSyncAction(context, () => service.rename(name));
    }
  }
}

/// Calculate the overlap-aware confirmation from the last committed tree. The
/// transaction repeats this calculation; missing transport never owns cleanup.
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
  return '${source == null ? context.t.folder_sync.confirm_forget : context.t.folder_sync.confirm_remove}\n\n${context.t.folder_sync.remove_count(count: count)}';
}

class _SyncNameDialog extends StatefulWidget {
  const _SyncNameDialog({required this.initial});
  final String initial;
  @override
  State<_SyncNameDialog> createState() => _SyncNameDialogState();
}

class _SyncNameDialogState extends State<_SyncNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KurumiDialog(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            maxLength: 160,
            decoration: InputDecoration(
              labelText: context.t.folder_sync.device_name,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: Text(context.t.generic.action.save),
          ),
        ],
      ),
    ),
  );
}
