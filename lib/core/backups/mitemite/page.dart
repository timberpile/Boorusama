import 'package:material_symbols_icons/symbols.dart';

import '../../bookmarks/src/widgets/bookmark_folder_picker_contents.dart';
import '../../bookmarks/src/widgets/bookmark_group_label.dart';
import 'collection_alias_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import 'name_dialog.dart';
import 'relative_date.dart';

import '../../bookmarks/providers.dart';
import '../../bookmarks/src/routes/route_utils.dart';
import '../../bookmarks/src/types/bookmark_library_state.dart';
import '../../bookmarks/src/types/bookmark_group_tree.dart';
import '../../bookmarks/src/types/bookmark_view.dart';
import 'actions.dart';
import 'catalog.dart';
import 'local_events.dart';
import 'protocol.dart';
import 'providers.dart';
import 'service.dart';
import 'following_actions.dart';
import 'location_subtitle.dart';
import 'offer_visit.dart';
import '../../search/following_topics/src/pages/following_topics_page.dart';

export 'actions.dart'
    show
        confirmSyncAction,
        runSyncAction,
        syncRemovalMessage,
        publishBookmarkGroup;

/// All management surfaces observe the same service and durable library. No
/// screen-local Subscribe toggle can claim a write that has not committed.
class MiteMitePage extends ConsumerWidget {
  const MiteMitePage({this.section, this.focusPublisher, super.key});
  final String? section;
  final String? focusPublisher;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(miteMiteServiceProvider)
      .unwrapPrevious()
      .when(
        loading: () => Scaffold(
          appBar: KurumiAppBar(title: Text(context.t.mitemite.title)),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: KurumiAppBar(title: Text(context.t.mitemite.title)),
          body: Center(child: Text(syncErrorMessage(context, error))),
        ),
        data: (service) {
          ref.watch(miteMiteManagementViewProvider(section));
          final page = _page(context, ref, service);
          if (section != 'receive') return page;
          final offered = <SyncCollectionId>{};
          final pinnedFingerprints = <String, String>{};
          for (final device in service.devices) {
            final pinned = service.gate.approvedKey(device.id);
            if (pinned == null ||
                syncDigest(pinned) != device.fingerprint ||
                device.catalog?.publicationRoots == null)
              continue;
            pinnedFingerprints[device.id] = device.fingerprint;
            offered.addAll(
              device.catalog!.offeredEntries.map((entry) => entry.id),
            );
          }
          final displayed = <String>{
            for (final entry in service.events.unseenOffers.entries)
              if (pinnedFingerprints[entry.value.publisher] ==
                      entry.value.fingerprint &&
                  offered.contains(
                    SyncCollectionId(
                      publisher: entry.value.publisher,
                      kind: entry.value.sourceKind!,
                      source: entry.value.source!,
                    ),
                  ))
                entry.key,
          };
          // Exit acknowledgement runs after route disposal. Its service lifetime
          // belongs to the container, independently of this page's context.
          final container = ProviderScope.containerOf(context, listen: false);
          return SyncOfferVisit(
            ready:
                ref.watch(bookmarkProvider).hasValue &&
                !service.busy &&
                !service.isReconciling &&
                service.activityFailure == null,
            keys: displayed,
            onLeave: (keys) async {
              if (identical(
                container.read(currentMiteMiteServiceProvider),
                service,
              )) {
                await service.acknowledgeOffers(keys);
              }
            },
            child: page,
          );
        },
      );

  Widget _page(BuildContext context, WidgetRef ref, MiteMiteService service) {
    final t = context.t.mitemite;
    var library = ref.watch(bookmarkProvider).valueOrNull;
    final committed = service.receiverMirrors;
    if (library != null &&
        committed != null &&
        committed.epoch > library.mirrors.epoch) {
      library = library.withMirrors(committed);
    }
    final title = switch (section) {
      'publish' => t.published_page,
      'receive' => t.receive,
      'devices' => t.devices,
      'activity' => t.activity,
      _ => t.title,
    };
    final children = <Widget>[];
    if (service.activityFailure != null &&
        (section == null || section == 'activity')) {
      children.add(
        ListTile(
          leading: const Icon(Icons.history),
          title: Text(t.activity_pending),
          subtitle: Text(t.activity_pending_detail),
          trailing: TextButton(
            onPressed: service.isActionPending('activity')
                ? null
                : () => runCurrentSyncAction(
                    context,
                    service,
                    service.retryActivity,
                  ),
            child: Text(context.t.generic.action.retry),
          ),
        ),
      );
    }
    if (service.retentionFailure != null && section == null) {
      children.add(
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: Text(t.maintenance_pending),
          subtitle: Text(t.maintenance_pending_detail),
          trailing: TextButton(
            onPressed: () =>
                runCurrentSyncAction(context, service, service.synchronize),
            child: Text(context.t.generic.action.retry),
          ),
        ),
      );
    }
    if (service.reloadFailure != null) {
      children.add(
        ListTile(
          leading: const Icon(Icons.sync_problem),
          title: Text(t.refresh_pending),
          subtitle: Text(t.refresh_pending_detail),
          trailing: TextButton(
            onPressed: service.isActionPending('projection')
                ? null
                : () => runCurrentSyncAction(
                    context,
                    service,
                    service.retryProjection,
                  ),
            child: Text(context.t.generic.action.retry),
          ),
        ),
      );
    }
    if (section != null && !service.configured) {
      children.add(
        ListTile(
          title: Text(t.choose_folder),
          subtitle: Text(t.not_configured),
          leading: const Icon(Icons.folder_open),
          onTap: service.isActionPending('location')
              ? null
              : () => runCurrentSyncAction(context, service, () async {
                  await chooseSyncFolder(context, ref, service);
                }),
        ),
      );
    }
    if (section == null) {
      children.addAll([
        ListTile(
          title: Text(t.shared_folder),
          subtitle: MiteMiteLocationSubtitle(
            location: service.location,
            lastUpdated: (service.location, service.folderAccessFailed),
          ),
          trailing: const Icon(Icons.folder_open),
          onTap: service.isActionPending('location')
              ? null
              : () => runCurrentSyncAction(context, service, () async {
                  await chooseSyncFolder(context, ref, service);
                }),
        ),
        if (service.failure case final failure?)
          ListTile(
            leading: const Icon(Icons.sync_problem),
            title: Text(syncErrorMessage(context, failure)),
          )
        else if (service.followingFailure != null ||
            service.deviceFailures.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.sync_problem),
            title: Text(t.partial),
          ),
        ListTile(
          title: Text(t.local_identity),
          titleTextStyle: Kurumi.themeOf(context).textTheme.titleMedium,
          subtitle: Text(service.name),
          trailing: IconButton(
            tooltip: t.device_name,
            icon: const Icon(Icons.edit_outlined),
            onPressed: service.isActionPending('name')
                ? null
                : () async {
                    final name = await showSyncNameDialog(
                      context,
                      title: t.device_name,
                      initial: service.name,
                    );
                    if (name != null && context.mounted) {
                      await runCurrentSyncAction(
                        context,
                        service,
                        () => service.rename(name),
                      );
                    }
                  },
          ),
        ),
        ExpansionTile(
          title: Text(t.device_details),
          children: [
            for (final detail in [
              (t.last_sync, service.lastSuccess),
              (t.last_attempt, service.lastSync),
            ])
              ListTile(
                title: Text(detail.$1),
                subtitle: MiteMiteRelativeDate(date: detail.$2),
              ),
            for (final detail in [
              (t.device_id, service.identity.id),
              (t.fingerprint, syncDigest(service.identity.publicKey)),
            ])
              ListTile(
                title: Text(detail.$1),
                subtitle: SelectableText(detail.$2),
                trailing: IconButton(
                  tooltip: '${context.t.post.action.copy}: ${detail.$1}',
                  icon: const Icon(Icons.copy),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: detail.$2)),
                ),
              ),
          ],
        ),
        KurumiSwitchListTile(
          title: Text(t.notifications_label),
          value: service.discoveryNotifications,
          onChanged: service.isActionPending('notifications')
              ? null
              : (enabled) => runSyncAction(
                  context,
                  () => service.setDiscoveryNotifications(enabled),
                ),
        ),
        if (service.outgoingFailure != null)
          ListTile(
            leading: const Icon(Icons.upload),
            title: Text(syncErrorMessage(context, service.outgoingFailure!)),
          ),
        for (final entry in [
          (
            'publish',
            t.published_page,
            Icons.upload,
            service.publishedRoots.length +
                service.publishedFollowingRoots.length,
          ),
          (
            'receive',
            t.receive,
            Icons.download,
            (library?.mirrors.subscriptions.values.fold<int>(
                      0,
                      (n, v) => n + v.length,
                    ) ??
                    0) +
                (service.receiverFollowing?.mirrors.subscriptions.values
                        .fold<int>(0, (n, v) => n + v.length) ??
                    0),
          ),
          (
            'devices',
            t.devices,
            Icons.devices,
            {
              ...service.devices.map((device) => device.id),
              ...?library?.mirrors.subscriptions.keys,
              ...?service.receiverFollowing?.mirrors.subscriptions.keys,
            }.length,
          ),
          (
            'activity',
            t.activity,
            Icons.history,
            service.events.history.length,
          ),
        ])
          ListTile(
            title: Text(entry.$2),
            leading: Icon(entry.$3),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${entry.$4}'),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MiteMitePage(section: entry.$1),
              ),
            ),
          ),
      ]);
    } else if (section == 'publish') {
      if (library == null) {
        children.add(const Center(child: CircularProgressIndicator()));
      } else {
        children.addAll(_publications(context, ref, service, library));
      }
    } else if (section == 'receive') {
      children.addAll(_devices(context, ref, service, library));
    } else if (section == 'devices') {
      children.addAll(
        _devices(context, ref, service, library, subscriptions: false),
      );
    } else {
      children.addAll(_activity(context, ref, service, library));
    }
    return Scaffold(
      appBar: KurumiAppBar(
        title: Text(title),
        actions: [
          if (section == null)
            IconButton(
              tooltip: t.sync_now,
              icon: service.isReconciling
                  ? SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: t.working,
                      ),
                    )
                  : const Icon(Icons.sync),
              onPressed: !service.configured
                  ? null
                  : () => runCurrentSyncAction(
                      context,
                      service,
                      service.synchronize,
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(12), children: children),
      ),
    );
  }

  List<Widget> _publications(
    BuildContext context,
    WidgetRef ref,
    MiteMiteService service,
    BookmarkLibraryState library,
  ) {
    final t = context.t.mitemite;
    final local = library.groups
        .where((g) => !library.mirrors.isReceived(g.id))
        .toList();
    final tree = BookmarkGroupTree(local);
    final rows = <Widget>[];
    if (service.publishedRoots.isEmpty &&
        service.publishedFollowingRoots.isEmpty)
      rows.add(ListTile(title: Text(t.empty_publication)));
    // Only direct rules are managed here. Covered children stay in the payload
    // tree, not as misleading, separately published top-level rows.
    for (final source in service.publishedRoots.toList()..sort()) {
      final group = library.groupsById[source];
      final inherited =
          group != null &&
          tree
              .ancestors(source)
              .any((parent) => service.publishedRoots.contains(parent.id));
      rows.add(
        ListTile(
          key: ValueKey('sync-publication:$source'),
          leading: const Icon(Symbols.bookmarks),
          title: BookmarkPickerLabel(
            label: group?.displayName(context) ?? source,
            detail: group == null || tree.ancestors(source).isEmpty
                ? null
                : tree
                      .ancestors(source)
                      .map((g) => g.displayName(context))
                      .join(' / '),
          ),
          subtitle: group == null
              ? Text(t.missing_collection)
              : inherited
              ? Text(t.both)
              : null,
          trailing: _publicationMenu(
            context,
            service,
            'publication:bookmarks:$source',
            () => stopBookmarkPublication(context, ref, service, source),
          ),
        ),
      );
    }
    for (final source in service.publishedFollowingRoots.toList()..sort()) {
      final following = service.receiverFollowing;
      final label =
          following?.topics
              .where((t) => t.id == source)
              .firstOrNull
              ?.displayName ??
          following?.organization.folders
              .where((f) => f.id == source)
              .firstOrNull
              ?.name ??
          source;
      final folder = following?.organization.folders
          .where((f) => f.id == source)
          .firstOrNull;
      final parentId = folder != null
          ? folder.parentId
          : following?.organization.placements
                .where((p) => p.itemId == source)
                .firstOrNull
                ?.folderId;
      final parentPath = following == null || parentId == null
          ? null
          : following.organization.tree.path(parentId);
      rows.add(
        ListTile(
          key: ValueKey('sync-publication:following_topics/$source'),
          leading: const Icon(Symbols.rss_feed),
          title: BookmarkPickerLabel(label: label, detail: parentPath),
          subtitle:
              following != null &&
                  followingPublicationReasons(
                    following.organization,
                    source,
                    service.publishedFollowingRoots,
                  ).any((r) => r != source)
              ? Text(t.both)
              : null,
          trailing: _publicationMenu(
            context,
            service,
            'publication:following_topics:$source',
            () => stopFollowingPublication(context, service, source, label),
          ),
        ),
      );
    }
    if (service.outgoingFailure != null)
      rows.add(ListTile(title: Text(t.publication_pending)));
    return rows;
  }

  Widget _publicationMenu(
    BuildContext context,
    MiteMiteService service,
    String target,
    VoidCallback stop,
  ) => KurumiPopupMenuButton(
    semanticLabel: context.t.generic.action.more,
    icon: const Icon(Icons.more_horiz),
    items: [
      KurumiPopupMenuItem(
        title: Text(context.t.mitemite.stop_publishing),
        onTap: service.isActionPending(target) ? null : stop,
      ),
    ],
  );

  List<Widget> _devices(
    BuildContext context,
    WidgetRef ref,
    MiteMiteService service,
    BookmarkLibraryState? library, {
    bool subscriptions = true,
  }) {
    final rows = <Widget>[];
    final t = context.t.mitemite;
    final pinnedFingerprints = {
      for (final device in service.devices)
        if (service.gate.approvedKey(device.id) case final pinned?)
          if (syncDigest(pinned) == device.fingerprint)
            device.id: device.fingerprint,
    };
    final newOffers = <SyncCollectionId>{
      if (subscriptions)
        for (final item in service.events.unseenOffers.values)
          if (pinnedFingerprints[item.publisher] == item.fingerprint)
            SyncCollectionId(
              publisher: item.publisher,
              kind: item.sourceKind!,
              source: item.source!,
            ),
    };
    final visibleIds = service.devices.map((d) => d.id).toSet();
    final offline = <String>{
      ...?library?.mirrors.subscriptions.keys,
      ...?service.receiverFollowing?.mirrors.subscriptions.keys,
      ...service.deviceFailures.keys,
    }.difference(visibleIds);
    if (visibleIds.isEmpty && offline.isEmpty)
      rows.add(ListTile(title: Text(t.empty_devices)));
    final devices = service.devices.toList();
    if (focusPublisher != null)
      devices.sort(
        (a, b) => (a.id == focusPublisher ? 0 : 1).compareTo(
          b.id == focusPublisher ? 0 : 1,
        ),
      );
    for (final device in devices) {
      final approved = service.gate.approvedKey(device.id) != null;
      final alias = library?.mirrors.aliases[device.id];
      final children = <Widget>[
        ListTile(
          title: Text(alias ?? device.name),
          subtitle: subscriptions
              ? null
              : SelectableText(
                  '${t.device_id}: ${device.id}\n${t.fingerprint}: ${device.fingerprint}',
                ),
          trailing: approved
              ? null
              : TextButton(
                  child: Text(t.trust),
                  onPressed: service.isActionPending('trust:${device.id}')
                      ? null
                      : () => runCurrentSyncAction(context, service, () async {
                          if (await confirmSyncAction(
                                context,
                                t.trust,
                                '${t.trust_prompt}\n\n${device.name}\n${t.device_id}: ${device.id}\n${t.fingerprint}: ${device.fingerprint}',
                              ) &&
                              context.mounted &&
                              isCurrentSyncService(context, service)) {
                            await service.approve(device);
                          }
                        }),
                ),
        ),
      ];
      // Discovery is not consent. Do not mount collection widgets, labels or
      // revision previews (including semantics) before explicit key approval.
      if (approved) {
        if (subscriptions) {
          final catalog = device.catalog;
          final offered =
              catalog?.offeredEntries.toList() ?? <SyncCatalogEntry>[];
          final roots =
              library?.mirrors.subscriptions[device.id] ?? const <String>{};
          final followingRoots =
              service.receiverFollowing?.mirrors.subscriptions[device.id] ??
              const <String>{};
          if (catalog == null) {
            children.add(ListTile(title: Text(t.no_collections)));
          } else if (catalog.publicationRoots == null) {
            children.add(
              ListTile(
                title: Text(t.update_required),
                subtitle: Text(t.legacy_scope),
              ),
            );
          } else if (offered.isEmpty &&
              roots.isEmpty &&
              followingRoots.isEmpty) {
            children.add(ListTile(title: Text(t.no_collections)));
          }
          for (final entry in offered) {
            children.add(
              _subscription(
                context,
                ref,
                service,
                library,
                publisher: device.id,
                source: entry.id.source,
                name: entry.name,
                offered: true,
                isNew: newOffers.contains(entry.id),
                sourceKind: entry.id.kind,
                subscribed:
                    (entry.id.kind == 'bookmarks'
                            ? roots
                            : service
                                      .receiverFollowing
                                      ?.mirrors
                                      .subscriptions[device.id] ??
                                  const <String>{})
                        .contains(entry.id.source),
              ),
            );
          }
          // An existing child subscription is still manageable when its former
          // direct publication disappears but it remains covered by a parent.
          for (final source in roots.difference(
            offered
                .where((e) => e.id.kind == 'bookmarks')
                .map((e) => e.id.source)
                .toSet(),
          )) {
            final id = library?.mirrors.localIdFor(device.id, source);
            children.add(
              _subscription(
                context,
                ref,
                service,
                library,
                publisher: device.id,
                source: source,
                name: library?.groupsById[id]?.name ?? source,
                offered: false,
                subscribed: true,
              ),
            );
          }
          for (final source in followingRoots.difference(
            offered
                .where((e) => e.id.kind == 'following_topics')
                .map((e) => e.id.source)
                .toSet(),
          )) {
            children.add(
              _followingExistingSubscription(
                context,
                ref,
                service,
                library,
                device.id,
                source,
              ),
            );
          }
        }
        if (!subscriptions)
          children.add(
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  child: Text(context.t.generic.action.edit),
                  onPressed: service.isActionPending('alias:${device.id}')
                      ? null
                      : () async {
                          await runCurrentSyncAction(
                            context,
                            service,
                            () => editSyncDeviceAlias(
                              context,
                              service: service,
                              publisher: device.id,
                              alias: alias,
                            ),
                          );
                        },
                ),
                TextButton(
                  child: Text(t.forget),
                  onPressed:
                      service.isActionPending('forget:${device.id}') ||
                          library == null
                      ? null
                      : () => _forget(context, service, library, device.id),
                ),
              ],
            ),
          );
      } else {
        children.add(ListTile(title: Text(t.not_trusted)));
      }
      final error = service.deviceFailures[device.id];
      if (error != null)
        children.add(ListTile(title: Text(syncErrorMessage(context, error))));
      rows.add(
        Card(
          key: ValueKey('sync-device:${device.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );
    }
    for (final publisher in offline.toList()..sort()) {
      final error = service.deviceFailures[publisher];
      rows.add(
        ListTile(
          title: Text(
            library?.mirrors.aliases[publisher] ??
                library?.mirrors.publisherNames[publisher] ??
                publisher,
          ),
          subtitle: Text(
            '${subscriptions ? '' : '${t.device_id}: $publisher\n'}${error == null ? t.unavailable : syncErrorMessage(context, error)}',
          ),
          trailing:
              subscriptions ||
                  library == null ||
                  !library.mirrors.subscriptions.containsKey(publisher) &&
                      !(service.receiverFollowing?.mirrors.subscriptions
                              .containsKey(publisher) ??
                          false)
              ? null
              : TextButton(
                  child: Text(t.forget),
                  onPressed: service.isActionPending('forget:$publisher')
                      ? null
                      : () => _forget(context, service, library, publisher),
                ),
        ),
      );
      if (!subscriptions) continue;
      for (final source
          in library?.mirrors.subscriptions[publisher] ?? const <String>{}) {
        final id = library!.mirrors.localIdFor(publisher, source);
        rows.add(
          _subscription(
            context,
            ref,
            service,
            library,
            publisher: publisher,
            source: source,
            name: library.groupsById[id]?.name ?? source,
            offered: false,
            subscribed: true,
          ),
        );
      }
      for (final source
          in service.receiverFollowing?.mirrors.subscriptions[publisher] ??
              const <String>{}) {
        rows.add(
          _followingExistingSubscription(
            context,
            ref,
            service,
            library,
            publisher,
            source,
          ),
        );
      }
    }
    return rows;
  }

  Widget _followingExistingSubscription(
    BuildContext context,
    WidgetRef ref,
    MiteMiteService service,
    BookmarkLibraryState? library,
    String publisher,
    String source,
  ) {
    final snapshot = service.receiverFollowing;
    final id = snapshot?.mirrors.localIdFor(publisher, source);
    final label =
        snapshot?.topics.where((t) => t.id == id).firstOrNull?.displayName ??
        snapshot?.organization.folders
            .where((f) => f.id == id)
            .firstOrNull
            ?.name ??
        source;
    return _subscription(
      context,
      ref,
      service,
      library,
      publisher: publisher,
      source: source,
      sourceKind: 'following_topics',
      name: label,
      offered: false,
      subscribed: true,
    );
  }

  Widget _subscription(
    BuildContext context,
    WidgetRef ref,
    MiteMiteService service,
    BookmarkLibraryState? library, {
    required String publisher,
    required String source,
    required String name,
    required bool offered,
    required bool subscribed,
    String sourceKind = 'bookmarks',
    bool isNew = false,
  }) {
    final t = context.t.mitemite;
    final pending = service.isSubscriptionPending(
      SyncCollectionId(publisher: publisher, kind: sourceKind, source: source),
    );
    final button = TextButton(
      child: Text(
        pending
            ? t.working
            : subscribed
            ? t.unsubscribe
            : t.subscribe,
      ),
      onPressed:
          pending ||
              library == null ||
              (!subscribed && !offered) ||
              (sourceKind == 'following_topics' &&
                  service.followingStore == null)
          ? null
          : () => runCurrentSyncAction(context, service, () async {
              if (sourceKind == 'following_topics') {
                if (subscribed) {
                  await unsubscribeFollowingDefinition(
                    context,
                    service,
                    publisher,
                    source,
                  );
                } else {
                  await service.subscribeFollowing(publisher, {source});
                }
                return;
              }
              if (subscribed) {
                if (await confirmSyncAction(
                      context,
                      t.unsubscribe,
                      syncRemovalMessage(context, library, publisher, source),
                    ) &&
                    context.mounted &&
                    isCurrentSyncService(context, service)) {
                  await service.unsubscribe(publisher, source);
                }
              } else {
                // The service unions additions under its operation lock; no
                // stale full root set is round-tripped from this screen.
                await service.subscribe(publisher, {source});
              }
            }),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow =
            constraints.maxWidth <
            320 * (MediaQuery.textScalerOf(context).scale(14) / 14);
        return ListTile(
          key: ValueKey(
            'sync-subscription:${sourceKind == 'bookmarks' ? '' : '$sourceKind/'}$publisher/$source',
          ),
          leading: sourceKind == 'following_topics'
              ? const Icon(Icons.rss_feed)
              : const Icon(Icons.bookmarks),
          title: Row(
            children: [
              Expanded(child: Text(name)),
              if (offered && isNew)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Badge(label: Text(t.new_offer_badge)),
                ),
            ],
          ),
          subtitle: narrow
              ? Align(alignment: AlignmentDirectional.centerEnd, child: button)
              : null,
          trailing: narrow ? null : button,
        );
      },
    );
  }

  Future<void> _forget(
    BuildContext context,
    MiteMiteService service,
    BookmarkLibraryState library,
    String publisher,
  ) => runCurrentSyncAction(context, service, () async {
    if (await confirmSyncAction(
          context,
          context.t.mitemite.forget,
          '${syncRemovalMessage(context, library, publisher)}\n${context.t.mitemite.following_category}: ${service.receiverFollowing == null ? 0 : followingReceivedScope(service.receiverFollowing!.mirrors, publisher).covered.length}',
        ) &&
        context.mounted &&
        isCurrentSyncService(context, service)) {
      await service.forget(publisher);
    }
  });

  List<Widget> _activity(
    BuildContext context,
    WidgetRef ref,
    MiteMiteService service,
    BookmarkLibraryState? library,
  ) {
    final t = context.t.mitemite;
    final aliases = ref.watch(syncCollectionAliasesProvider);
    final events = service.events.history;
    if (events.isEmpty) return [ListTile(title: Text(t.empty_activity))];
    return [
      for (final event in events)
        Builder(
          builder: (context) {
            final id = event.publisher == null
                ? event.source
                : event.source == null
                ? null
                : library?.mirrors.localIdFor(event.publisher!, event.source!);
            final group = event.sourceKind == 'bookmarks'
                ? library?.groupsById[id]
                : null;
            final following = service.receiverFollowing;
            final followingId = event.sourceKind != 'following_topics'
                ? null
                : event.publisher == null
                ? event.source
                : following?.mirrors.localIdFor(
                    event.publisher!,
                    event.source ?? '',
                  );
            final topic = following?.topics
                .where((t) => t.id == followingId)
                .firstOrNull;
            final folder = following?.organization.folders
                .where((f) => f.id == followingId)
                .firstOrNull;
            final label = switch (event.kind) {
              SyncEventKind.discovered => t.event_discovered,
              SyncEventKind.available => t.event_available,
              SyncEventKind.published => t.event_published,
              SyncEventKind.stopped => t.event_stopped,
              SyncEventKind.subscribed => t.event_subscribed,
              SyncEventKind.unsubscribed => t.event_unsubscribed,
              SyncEventKind.forgotten => t.event_forgotten,
              SyncEventKind.received => t.event_received,
              SyncEventKind.copied => t.event_copied,
              SyncEventKind.failed =>
                event.sourceKind == 'outgoing'
                    ? t.event_publication_failed
                    : event.sourceKind == 'retention'
                    ? t.maintenance_pending
                    : t.event_failed,
            };
            return ListTile(
              title: Text(
                '$label${group != null
                    ? ' · ${bookmarkAliasLabel(context, group, library!.mirrors, aliases)}'
                    : topic != null
                    ? ' · ${topic.displayName}'
                    : folder != null
                    ? ' · ${followingAliasLabel(folder.name, folder.id, following!.mirrors, aliases)}'
                    : ''}',
              ),
              subtitle: MiteMiteRelativeDate(
                date: event.at,
                builder: (context, relative) => Text(
                  '$relative'
                  '${event.publisher == null ? '' : '\n${library?.mirrors.aliases[event.publisher] ?? library?.mirrors.publisherNames[event.publisher] ?? event.publisher}'}'
                  '${event.kind != SyncEventKind.received ? '' : '\n${t.event_changes(added: event.added, removed: event.removed)}'}'
                  '${event.failure == null ? '' : '\n${syncFailureMessage(context, event.failure!)}'}',
                ),
              ),
              trailing:
                  group != null ||
                      (followingId != null &&
                          (topic != null || folder != null)) ||
                      event.kind == SyncEventKind.discovered ||
                      (event.kind == SyncEventKind.failed &&
                          event.publisher != null)
                  ? const Icon(Icons.chevron_right)
                  : null,
              onTap: followingId != null && (topic != null || folder != null)
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FollowingTopicsPage(
                          folderId:
                              folder?.id ??
                              following?.organization.placements
                                  .where((p) => p.itemId == topic?.id)
                                  .firstOrNull
                                  ?.folderId,
                        ),
                      ),
                    )
                  : group != null
                  ? () => goToBookmarkGroupPage(
                      ref,
                      BookmarkView.group(group.id),
                      title: group.name,
                    )
                  : event.kind == SyncEventKind.discovered ||
                        (event.kind == SyncEventKind.failed &&
                            event.publisher != null)
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MiteMitePage(section: 'receive'),
                      ),
                    )
                  : null,
            );
          },
        ),
    ];
  }
}
