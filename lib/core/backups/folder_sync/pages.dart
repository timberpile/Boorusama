import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../foundation/platform.dart';
import '../auto/repo_android.dart';
import '../../bookmarks/providers.dart';
import '../../bookmarks/src/routes/route_utils.dart';
import '../../bookmarks/src/types/bookmark_view.dart';
import '../auto/providers.dart';
import 'providers.dart';
import 'service.dart';

class FolderSyncPage extends ConsumerWidget {
  const FolderSyncPage({this.intendedPublication, super.key});
  final SyncSourceCollection? intendedPublication;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(folderSyncStateProvider);
    final strings = context.t.folder_sync;
    final service = ref.read(folderSyncServiceProvider);
    return Scaffold(
      appBar: KurumiAppBar(title: Text(strings.title)),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(strings.failed)),
          data: (_) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(strings.description),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(strings.folder),
                  subtitle: Text(
                    (service.location == null
                            ? null
                            : ref
                                  .watch(
                                    autoBackupDirectoryDisplayPathProvider(
                                      service.location!,
                                    ),
                                  )
                                  .valueOrNull) ??
                        service.location ??
                        strings.not_configured,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: service.busy
                      ? null
                      : () => _perform(context, () async {
                          final path = isAndroid()
                              ? await AutoBackupRepositoryAndroid.pickDirectory()
                              : await FilePicker.getDirectoryPath();
                          if (path != null) {
                            await service.chooseFolder(path);
                            if (intendedPublication case final source?) {
                              await service.setPublication(
                                source,
                                enabled: true,
                              );
                            }
                          }
                        }),
                ),
              ),
              ListTile(
                title: Text(
                  service.busy
                      ? strings.scanning
                      : service.lastError != null
                      ? strings.failed
                      : strings.ready,
                ),
                subtitle: service.lastSync == null
                    ? null
                    : Text(service.lastSync!.toLocal().toString()),
                trailing: TextButton(
                  onPressed: service.configured && !service.busy
                      ? () => _perform(context, service.synchronize)
                      : null,
                  child: Text(strings.sync_now),
                ),
              ),
              _route(
                context,
                Icons.upload_outlined,
                strings.publish,
                () => const FolderSyncPublishPage(),
              ),
              _route(
                context,
                Icons.download_outlined,
                strings.receive,
                () => const FolderSyncReceivePage(),
              ),
              _route(
                context,
                Icons.history,
                strings.activity,
                () => const FolderSyncActivityPage(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _route(
    BuildContext context,
    IconData icon,
    String label,
    Widget Function() builder,
  ) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => builder())),
    ),
  );
}

Future<void> _perform(
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

class FolderSyncPublishPage extends ConsumerStatefulWidget {
  const FolderSyncPublishPage({super.key});
  @override
  ConsumerState<FolderSyncPublishPage> createState() =>
      _FolderSyncPublishPageState();
}

class _FolderSyncPublishPageState extends ConsumerState<FolderSyncPublishPage> {
  late Future<List<SyncSourceCollection>> _sources;
  @override
  void initState() {
    super.initState();
    _sources = ref.read(folderSyncServiceProvider).port.sources();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(folderSyncStateProvider);
    final service = ref.read(folderSyncServiceProvider);
    final metadata = service.snapshot;
    final rules = metadata['rules'] as Map<String, dynamic>? ?? {};
    final subscriptions =
        metadata['subscriptions'] as Map<String, dynamic>? ?? {};
    final strings = context.t.folder_sync;
    return Scaffold(
      appBar: KurumiAppBar(title: Text(strings.publish)),
      body: FutureBuilder<List<SyncSourceCollection>>(
        future: _sources,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? Text(strings.failed)
                  : const CircularProgressIndicator(),
            );
          }
          final all = snapshot.data!;
          return ListView.builder(
            itemCount: all.length,
            itemBuilder: (context, index) {
              final source = all[index];
              final rule = rules[source.key] as Map<String, dynamic>?;
              final selection = service.publicationSelection(source, all);
              final provenance = selection.direct && selection.inherited
                  ? '${strings.direct} + ${strings.via_parent}'
                  : selection.direct
                  ? strings.direct
                  : selection.inherited
                  ? strings.via_parent
                  : selection.excluded
                  ? strings.excluded
                  : '';
              final mirror = subscriptions.values.any(
                (s) => s['kind'] == source.kind && s['localId'] == source.id,
              );
              return Card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      secondary: Icon(
                        mirror
                            ? Icons.lock_outline
                            : source.container
                            ? Icons.folder_outlined
                            : Icons.bookmark_outline,
                      ),
                      title: Text(source.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mirror
                                ? strings.readonly
                                : '${source.kind == 'bookmarks' ? context.t.bookmark.title : context.t.following_topics.title}${provenance.isEmpty ? '' : ' · $provenance'}',
                          ),
                          if (!mirror &&
                              (selection.inherited || selection.canRestore))
                            TextButton.icon(
                              icon: Icon(
                                selection.inherited
                                    ? Icons.remove_circle_outline
                                    : Icons.restore,
                                size: 16,
                              ),
                              label: Text(
                                selection.inherited
                                    ? strings.exclude_inherited
                                    : strings.restore_inherited,
                              ),
                              onPressed: service.busy
                                  ? null
                                  : () => _perform(
                                      context,
                                      () => service.excludeInherited(
                                        source,
                                        excluded: selection.inherited,
                                      ),
                                    ),
                            ),
                        ],
                      ),
                      value: rule != null,
                      onChanged: mirror || service.busy
                          ? null
                          : (enabled) => _perform(
                              context,
                              () => service.setPublication(
                                source,
                                enabled: enabled ?? false,
                              ),
                            ),
                    ),
                    if (rule != null && source.container) ...[
                      SwitchListTile(
                        title: Text(strings.subtree),
                        value: rule['subtree'] == true,
                        onChanged: service.busy
                            ? null
                            : (value) => _perform(
                                context,
                                () => service.setPublication(
                                  source,
                                  enabled: true,
                                  subtree: value,
                                  includeFutureChildren: rule['future'] == true,
                                ),
                              ),
                      ),
                      if (rule['subtree'] == true)
                        SwitchListTile(
                          title: Text(strings.future),
                          value: rule['future'] == true,
                          onChanged: service.busy
                              ? null
                              : (value) => _perform(
                                  context,
                                  () => service.setPublication(
                                    source,
                                    enabled: true,
                                    subtree: true,
                                    includeFutureChildren: value,
                                  ),
                                ),
                        ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class FolderSyncReceivePage extends ConsumerStatefulWidget {
  const FolderSyncReceivePage({super.key});
  @override
  ConsumerState<FolderSyncReceivePage> createState() =>
      _FolderSyncReceivePageState();
}

class _FolderSyncReceivePageState extends ConsumerState<FolderSyncReceivePage> {
  late Future<List<Map<String, dynamic>>> _publishers;
  @override
  void initState() {
    super.initState();
    _publishers = ref.read(folderSyncServiceProvider).discover();
  }

  void _refresh() => setState(
    () => _publishers = ref.read(folderSyncServiceProvider).discover(),
  );
  @override
  Widget build(BuildContext context) {
    ref.watch(folderSyncStateProvider);
    final service = ref.read(folderSyncServiceProvider);
    final subscriptions =
        service.snapshot['subscriptions'] as Map<String, dynamic>? ?? {};
    final trust = service.snapshot['trust'] as Map<String, dynamic>? ?? {};
    final strings = context.t.folder_sync;
    return Scaffold(
      appBar: KurumiAppBar(
        title: Text(strings.receive),
        actions: [
          IconButton(
            tooltip: context.t.folder_sync.sync_now,
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _publishers,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? Text(strings.failed)
                  : const CircularProgressIndicator(),
            );
          }
          final publishers = snapshot.data!;
          if (publishers.isEmpty) {
            return Center(
              child: Text(
                service.configured
                    ? strings.no_publishers
                    : strings.not_configured,
              ),
            );
          }
          final rows = <Widget>[];
          for (final publisher in publishers) {
            final id = publisher['publisher'] as String;
            final approved = trust[id] == publisher['publicKey'];
            rows.add(
              ListTile(
                leading: Icon(
                  approved ? Icons.verified_user_outlined : Icons.security,
                ),
                title: Text(id, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: SelectableText(publisher['fingerprint'] as String),
                trailing: approved
                    ? null
                    : TextButton(
                        child: Text(strings.trust),
                        onPressed: () => _approve(publisher),
                      ),
              ),
            );
            for (final raw in publisher['collections'] as List) {
              if (raw is! Map<String, dynamic>) continue;
              final key = '$id/${raw['kind']}/${raw['source']}';
              final subscription = subscriptions[key] as Map<String, dynamic>?;
              rows.add(
                Card(
                  child: ListTile(
                    leading: Icon(
                      subscription != null
                          ? Icons.lock_outline
                          : Icons.bookmark_outline,
                    ),
                    title: Text(
                      subscription?['name'] as String? ??
                          raw['name'] as String? ??
                          '',
                    ),
                    subtitle: Text(
                      _status(
                        context,
                        subscription?['state'] as String? ??
                            raw['state'] as String? ??
                            'pending',
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: !approved || raw['state'] != 'active'
                          ? null
                          : () => subscription == null
                                ? _subscribe(publisher, raw)
                                : _manage(key),
                      child: Text(
                        subscription == null
                            ? strings.subscribe
                            : strings.manage,
                      ),
                    ),
                  ),
                ),
              );
            }
          }
          return ListView(padding: const EdgeInsets.all(16), children: rows);
        },
      ),
    );
  }

  Future<void> _approve(Map<String, dynamic> publisher) async {
    final strings = context.t.folder_sync;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => KurumiDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.trust, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(strings.trust_description),
            const SizedBox(height: 12),
            SelectableText(publisher['fingerprint'] as String),
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
                  child: Text(strings.trust),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if ((approved ?? false) && mounted) {
      await _perform(
        context,
        () => ref
            .read(folderSyncServiceProvider)
            .approvePublisher(
              publisher['publisher'] as String,
              publisher['publicKey'] as String,
            ),
      );
    }
  }

  Future<void> _subscribe(
    Map<String, dynamic> publisher,
    Map<String, dynamic> offer,
  ) async {
    final service = ref.read(folderSyncServiceProvider);
    final result = await showDialog<_SubscriptionChoice>(
      context: context,
      builder: (_) => _SubscriptionDialog(
        name: offer['name'] as String? ?? '',
        kind: offer['kind'] as String,
        sources: service.port.sources(),
      ),
    );
    if (result == null || !mounted) return;
    await _perform(context, () async {
      await service.subscribe(
        offer: offer,
        publisher: publisher['publisher'] as String,
        name: result.name,
        parentId: result.parentId,
        includeFutureChildren: result.future,
        copyStructure: result.copyStructure,
      );
      await service.synchronize();
    });
  }

  Future<void> _manage(String key) => showFolderSyncSubscriptionActions(
    context,
    ref.read(folderSyncServiceProvider),
    key,
  );
}

Future<void> showFolderSyncSubscriptionActions(
  BuildContext context,
  FolderSyncService service,
  String key,
) async {
  final subscribed =
      (service.snapshot['subscriptions'] as Map)[key]['subscribed'] != false;
  final action = await showDialog<String>(
    context: context,
    builder: (context) => KurumiDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!subscribed)
            ListTile(
              title: Text(context.t.folder_sync.subscribe),
              onTap: () => Navigator.pop(context, 'resume'),
            ),
          if (subscribed)
            ListTile(
              title: Text(context.t.folder_sync.unsubscribe),
              onTap: () => Navigator.pop(context, 'unsubscribe'),
            ),
          ListTile(
            title: Text(context.t.folder_sync.detach),
            onTap: () => Navigator.pop(context, 'detach'),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  await _perform(context, () async {
    if (action == 'resume') {
      await service.resubscribe(key);
      await service.synchronize();
    } else if (action == 'detach') {
      await service.detach(key);
    } else {
      await service.unsubscribe(key);
    }
  });
}

final class _SubscriptionChoice {
  const _SubscriptionChoice(
    this.name,
    this.parentId,
    this.future,
    this.copyStructure,
  );
  final String name;
  final String? parentId;
  final bool future;
  final bool copyStructure;
}

class _SubscriptionDialog extends StatefulWidget {
  const _SubscriptionDialog({
    required this.name,
    required this.kind,
    required this.sources,
  });
  final String name;
  final String kind;
  final Future<List<SyncSourceCollection>> sources;
  @override
  State<_SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<_SubscriptionDialog> {
  late final _name = TextEditingController(text: widget.name);
  String? _parent;
  var _future = false;
  var _copyStructure = true;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: KurumiDialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t.folder_sync.subscribe,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: context.t.folder_sync.local_name,
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<SyncSourceCollection>>(
              future: widget.sources,
              builder: (context, snapshot) => DropdownButtonFormField<String>(
                initialValue: _parent,
                decoration: InputDecoration(
                  labelText: context.t.folder_sync.destination,
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(context.t.folder_sync.home),
                  ),
                  for (final source
                      in snapshot.data ?? const <SyncSourceCollection>[])
                    if (source.kind == widget.kind &&
                        (source.container || source.kind == 'bookmarks'))
                      DropdownMenuItem(
                        value: source.id,
                        child: Text(
                          source.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                ],
                onChanged: (value) => _parent = value == '' ? null : value,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t.folder_sync.copy_structure),
              value: _copyStructure,
              onChanged: (value) => setState(() => _copyStructure = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t.folder_sync.future_receive),
              value: _future,
              onChanged: (value) => setState(() => _future = value),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.t.generic.action.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (_name.text.trim().isNotEmpty) {
                      Navigator.pop(
                        context,
                        _SubscriptionChoice(
                          _name.text.trim(),
                          _parent,
                          _future,
                          _copyStructure,
                        ),
                      );
                    }
                  },
                  child: Text(context.t.folder_sync.subscribe),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class FolderSyncActivityPage extends ConsumerWidget {
  const FolderSyncActivityPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(folderSyncStateProvider);
    final service = ref.read(folderSyncServiceProvider);
    final subscriptions =
        service.snapshot['subscriptions'] as Map<String, dynamic>? ?? {};
    final activities = (service.snapshot['activity'] as List? ?? const [])
        .reversed
        .toList();
    return Scaffold(
      appBar: KurumiAppBar(title: Text(context.t.folder_sync.activity)),
      body: activities.isEmpty
          ? Center(child: Text(context.t.folder_sync.empty_activity))
          : ListView.builder(
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final item = activities[index] as Map<String, dynamic>;
                final subscription =
                    subscriptions[item['collection']] as Map<String, dynamic>?;
                return ListTile(
                  leading: const Icon(Icons.sync),
                  title: Text(
                    subscription?['name'] as String? ??
                        _status(context, item['state'] as String),
                  ),
                  subtitle: Text(
                    '${_status(context, item['state'] as String)} · ${item['time']} · +${item['additions']} / −${item['removals']}',
                  ),
                  trailing: subscription == null
                      ? null
                      : const Icon(Icons.chevron_right),
                  onTap: subscription == null
                      ? null
                      : () async {
                          final localId = subscription['localId'] as String;
                          if (subscription['kind'] == 'bookmarks') {
                            final library = await ref.read(
                              bookmarkProvider.future,
                            );
                            final group = library.groupsById[localId];
                            if (group != null && context.mounted)
                              await goToBookmarkGroupPage(
                                ref,
                                BookmarkView.group(localId),
                                title: group.name,
                              );
                          } else {
                            await showDialog<void>(
                              context: context,
                              builder: (context) => KurumiDialog(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      context.t.folder_sync.definitions_changed,
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(context.t.generic.action.ok),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            await service.markSeen('following_topics', localId);
                          }
                        },
                );
              },
            ),
    );
  }
}

String _status(BuildContext context, String state) {
  final strings = context.t.folder_sync;
  return switch (state) {
    'active' || 'ready' => strings.ready,
    'pending' => strings.pending,
    'withdrawn' => strings.withdrawn,
    'deleted' => strings.deleted,
    'incomplete' => strings.incomplete,
    'update_required' => strings.update_required,
    'conflict' => strings.conflict,
    'unsubscribed' => strings.readonly,
    'profile_required' => strings.profile_required,
    'failed' => strings.failed,
    'discovery_failed' => strings.discovery_failed,
    'applied' => strings.applied,
    'publication_failed' => strings.publication_failed,
    _ => strings.unavailable,
  };
}
