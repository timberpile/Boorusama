import 'activity_log.dart';
import 'receive_units.dart';

import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import '../../groups/folder_tree.dart';
import '../../content/anonymous_source_policy.dart';
import '../../search/following_topics/src/types/following_mirror_state.dart';
import '../../search/following_topics/types.dart';
import '../sources/search_backup_profile.dart';
import 'bookmark_scope.dart';
import 'bookmark_mirror_engine.dart' show SyncRevisionUnavailable;
import 'catalog.dart';
import 'catalog_gate.dart';
import 'following_package.dart';
import 'following_publication.dart';
import 'protocol.dart';
import 'receive_preparation.dart';

/// Uses the shared trust/transport boundary and the Following repository's
/// recoverable definition transaction. Runtime refresh/read state stays local.
final class SyncFollowingMirrorEngine {
  SyncFollowingMirrorEngine({
    required this.store,
    required this.gate,
    required this.preparation,
    required this.profiles,
    this.ensureCurrent,
    this.anonymousPolicy = _defaultAnonymousPolicy,
    DateTime Function()? now,
    String Function()? newId,
    this.maxPreparedBytes = 64 * 1024 * 1024,
  }) : now = now ?? DateTime.now,
       newId = newId ?? (() => const Uuid().v4().toLowerCase());

  final FollowingMirrorStore store;
  final SyncCatalogGate gate;
  final SyncReceivePreparation preparation;
  final List<BackupProfileReference> Function() profiles;
  final void Function()? ensureCurrent;
  final AnonymousSourcePolicy Function() anonymousPolicy;
  static AnonymousSourcePolicy _defaultAnonymousPolicy() =>
      const AnonymousSourcePolicy();
  final DateTime Function() now;
  final String Function() newId;
  final int maxPreparedBytes;

  Future<void> receive({
    required VerifiedSyncCatalog ticket,
    required List<int> publisherKey,
    Set<String>? directRoots,
  }) async {
    ensureCurrent?.call();
    if (syncDigest(publisherKey) != ticket.fingerprint)
      throw const FormatException('Publisher key does not match catalog');
    final initial = (await store.readMirrorSnapshot()).mirrors;
    final owned = initial.owners.values
        .where((owner) => owner.publisher == ticket.publisher)
        .toList();
    final roots = <String>{
      ...?initial.subscriptions[ticket.publisher],
      ...?directRoots,
    };
    final units = syncReceiveUnits(
      catalog: SyncCatalog.fromJson(ticket.content),
      kind: 'following_topics',
      roots: roots,
      priorNodes: [
        for (final owner in owned)
          SyncBookmarkNode(
            source: owner.source,
            parent: owner.parentSource,
            position: owner.position,
          ),
      ],

      checkpoints: {
        for (final owner in initial.checkpoints.values)
          if (owner.publisher == ticket.publisher) owner.source,
      },
    );
    if (units.length <= 1)
      return _receiveUnit(
        ticket: ticket,
        publisherKey: publisherKey,
        directRoots: directRoots,
      );
    final failures = <String, Object>{};
    for (final unit in units) {
      try {
        await _receiveUnit(
          ticket: ticket,
          publisherKey: publisherKey,
          directRoots: directRoots?.intersection(unit),
          sourceUnit: unit,
        );
      } catch (error) {
        final root = roots.where(unit.contains).toList()..sort();
        failures[root.firstOrNull ?? unit.first] = error;
      }
    }
    if (failures.isNotEmpty)
      throw SyncPartialReceiveFailure('following_topics', failures);
  }

  Future<void> _receiveUnit({
    required VerifiedSyncCatalog ticket,
    required List<int> publisherKey,
    Set<String>? directRoots,
    Set<String>? sourceUnit,
  }) async {
    ensureCurrent?.call();
    if (syncDigest(publisherKey) != ticket.fingerprint) {
      throw const FormatException('Publisher key does not match catalog');
    }
    final before = await store.readMirrorSnapshot();
    final initial = before.mirrors;
    final catalog = SyncCatalog.fromJson(ticket.content);
    final roots = <String>{
      ...?initial.subscriptions[ticket.publisher],
      ...?directRoots,
    };
    final unitRoots = roots
        .where((id) => sourceUnit == null || sourceUnit.contains(id))
        .toSet();
    final additions = roots.difference(
      initial.subscriptions[ticket.publisher] ?? {},
    );
    if (additions.isNotEmpty) {
      final offers = catalog.publicationRoots;
      if (offers == null) throw const SyncUpdateRequired();
      if (additions.any(
        (source) => !offers.contains(
          SyncCollectionId(
            publisher: ticket.publisher,
            kind: 'following_topics',
            source: source,
          ),
        ),
      ))
        throw const SyncConflict();
    }
    final entries = {
      for (final e in catalog.entries)
        if (e.id.kind == 'following_topics') e.id.source: e,
    };
    final owned = {
      for (final e in initial.owners.entries)
        if (e.value.publisher == ticket.publisher &&
            (sourceUnit == null || sourceUnit.contains(e.value.source)))
          e.value.source: e,
    };
    if (unitRoots.any((id) => !entries.containsKey(id)))
      throw const SyncConflict();
    final scope = BookmarkSyncScope(
      publisher: ticket.publisher,
      nodes: [
        for (final e in entries.values)
          if (e.state == SyncPublicationState.active)
            SyncBookmarkNode(
              source: e.id.source,
              parent: e.parent,
              position: e.position,
            ),
      ],
      directRoots: {
        for (final id in unitRoots)
          if (entries[id]!.state == SyncPublicationState.active) id,
      },
    );
    final withdrawn = {
      for (final id in unitRoots)
        if (entries[id]!.state != SyncPublicationState.active) id,
    };
    bool throughWithdrawal(String source) {
      final seen = <String>{};
      String? current = source;
      while (current != null && seen.add(current)) {
        if (withdrawn.contains(current)) return true;
        current = owned[current]?.value.parentSource;
      }
      return false;
    }

    for (final owner in owned.values) {
      if (!entries.containsKey(owner.value.source) &&
          !throughWithdrawal(owner.value.source))
        throw const SyncConflict();
    }
    final checkpoints = Map<String, FollowingMirrorOwner>.of(
      initial.checkpoints,
    );
    for (final entry in entries.values) {
      if (sourceUnit != null && !sourceUnit.contains(entry.id.source)) continue;
      if (entry.state == SyncPublicationState.active) continue;
      final old = checkpoints['${ticket.publisher}/${entry.id.source}'];
      if (old == null) continue;
      final revision = entry.revision;
      if (revision != null) _checkRevision(old, revision);
      checkpoints[old.sourceKey] = FollowingMirrorOwner(
        publisher: old.publisher,
        source: old.source,
        kind: old.kind,
        revision: revision?.revision ?? old.revision,
        payloadDigest: revision?.sha256 ?? old.payloadDigest,
        descriptorDigest: revision == null
            ? old.descriptorDigest
            : _descriptor(revision),
        definitionDigest: old.definitionDigest,
        seenDefinitionDigest: old.seenDefinitionDigest,
        parentSource: old.parentSource,
        position: old.position,
        profile: old.profile,
        retired: true,
      );
    }
    final packages = <String, ValidatedSyncFollowingPackage>{};
    var retained = 0;
    var advertised = 0;
    for (final source in scope.covered) {
      final entry = entries[source]!;
      final revision = entry.revision!;
      final old =
          owned[source]?.value ?? checkpoints['${ticket.publisher}/$source'];
      if (revision.schema != ValidatedSyncFollowingPackage.schema)
        throw const SyncUpdateRequired();
      if (old != null) {
        _checkRevision(old, revision);
        if (old.retired && revision.revision <= old.revision)
          throw const SyncReplayRejected();
      }
      if (owned.containsKey(source) &&
          old!.revision == revision.revision &&
          old.payloadDigest == revision.sha256 &&
          old.descriptorDigest == _descriptor(revision))
        continue;
      advertised += revision.length;
      if (advertised > maxPreparedBytes)
        throw const FormatException('Sync batch exceeds preparation budget');
      final package = await preparation.prepareFollowing(
        catalog: ticket,
        collection: entry.id,
        publisherKey: publisherKey,
        maxPreparedBytes: maxPreparedBytes - retained,
      );
      if (package == null) throw const SyncRevisionUnavailable();
      retained += package.retainedByteLength;
      if (retained > maxPreparedBytes)
        throw const FormatException('Sync batch exceeds preparation budget');
      packages[source] = package;
    }
    ensureCurrent?.call();
    final oldTopics = {for (final topic in before.topics) topic.id: topic};
    final folders = {
      for (final folder in before.organization.folders) folder.id: folder,
    };
    final materialized = {
      for (final entry in packages.entries)
        entry.key: await entry.value.materialize(),
    };
    final placements = {
      for (final p in before.organization.placements) p.itemId: p,
    };
    final used = {...oldTopics.keys, ...folders.keys};
    final local = <String, String>{};
    for (final source in scope.covered) {
      final id = owned[source]?.key ?? newId();
      if (owned[source] == null && !used.add(id)) throw const SyncConflict();
      local[source] = id;
    }
    final remove = {
      for (final e in owned.values)
        if (!scope.covered.contains(e.value.source)) e.key,
    };
    folders.removeWhere((id, _) => remove.contains(id));
    placements.removeWhere((id, _) => remove.contains(id));
    final owners = Map<String, FollowingMirrorOwner>.of(initial.owners)
      ..removeWhere((id, _) => remove.contains(id));
    final topics = <FollowingTopic>[];
    final compatibleProfiles = List<BackupProfileReference>.of(profiles());
    final kinds = {
      for (final source in scope.covered)
        source: packages[source] == null
            ? owned[source]!.value.kind
            : materialized[source]!.records.isNotEmpty
            ? FollowingMirrorKind.topic
            : FollowingMirrorKind.folder,
    };
    final children = <String, List<FollowingDefinitionChild>>{};
    for (final source in scope.covered) {
      final entry = entries[source]!;
      final parent = entry.parent;
      if (parent == null || !scope.covered.contains(parent)) continue;
      if (kinds[parent] != FollowingMirrorKind.folder)
        throw const SyncConflict();
      (children[parent] ??= []).add(
        FollowingDefinitionChild(
          source: source,
          kind: kinds[source]!,
          position: entry.position,
        ),
      );
    }
    for (final source in scope.covered) {
      final entry = entries[source]!;
      final revision = entry.revision!;
      final id = local[source]!;
      final old = owners[id];
      final data = materialized[source];
      final record = data?.records.firstOrNull;
      final sourceFolder = data?.folders.firstOrNull;
      final kind = data == null
          ? old!.kind
          : record != null
          ? FollowingMirrorKind.topic
          : FollowingMirrorKind.folder;
      if (old != null && old.kind != kind) throw const SyncConflict();
      final parent = local[entry.parent];
      FollowingTopic? topic;
      TopicFolder? folder;
      BackupProfileReference? reference;
      if (kind == FollowingMirrorKind.topic) {
        final previous = oldTopics[id];
        reference =
            record?.profile ?? parseBackupProfile(old!.profile, 'profile');
        topic = FollowingTopic.create(
          id: id,
          profileId:
              _bind(reference, compatibleProfiles, previous?.profileId) ?? id,
          query: record?.query ?? previous!.query,
          queryStructure:
              record?.queryStructure ??
              (record == null ? previous!.queryStructure : null),
          name: record == null ? previous!.name : record.name,
          position: entry.position,
          createdAt: previous?.createdAt ?? now().toUtc(),
        );
        if (syncFollowingLabel(topic.displayName) != entry.name)
          throw const SyncConflict();
        topics.add(topic);
        placements[id] = FolderPlacement(
          itemId: id,
          folderId: parent,
          position: entry.position,
        );
      } else {
        final previous = folders[id];
        folder = TopicFolder(
          id: id,
          nameScope: followingFolderNameScope(ticket.publisher, entry.parent),
          name: sourceFolder?.name ?? previous!.name,
          parentId: parent,
          position: entry.position,
          feedEnabled: sourceFolder?.feedEnabled ?? previous!.feedEnabled,
          feedMaxPosts: sourceFolder?.feedMaxPosts ?? previous!.feedMaxPosts,
        );
        if (syncFollowingLabel(folder.name) != entry.name)
          throw const SyncConflict();
        folders[id] = folder;
      }
      final nextChildren = orderedFollowingDefinitionChildren(
        children[source] ?? const [],
      );
      final definition = followingDefinitionDigest(
        kind: kind,
        parentSource: entry.parent,
        position: entry.position,
        topic: topic,
        folder: folder,
        profile: reference?.toJson(),
        children: nextChildren,
      );
      owners[id] = FollowingMirrorOwner(
        publisher: ticket.publisher,
        source: source,
        kind: kind,
        revision: revision.revision,
        payloadDigest: revision.sha256,
        descriptorDigest: _descriptor(revision),
        parentSource: entry.parent,
        position: entry.position,
        profile: reference?.toJson(),
        definitionDigest: definition,
        seenDefinitionDigest: old?.seenDefinitionDigest,
      );
    }
    final receivedIds = local.values.toSet();
    for (final e in owners.entries.where((e) => receivedIds.contains(e.key))) {
      final parentId = local[e.value.parentSource];
      if (parentId != null &&
          owners[parentId]?.kind != FollowingMirrorKind.folder)
        throw const SyncConflict();
    }
    final organization = TopicOrganization(
      folders: folders.values,
      placements: placements.values,
    );
    final previousDefinitions = followingSnapshotDefinitionDigests(before);
    final establishedFolders = {
      for (final source
          in initial.subscriptions[ticket.publisher] ?? const <String>{})
        if (initial.owners.values.any(
          (owner) =>
              owner.publisher == ticket.publisher &&
              owner.source == source &&
              owner.kind == FollowingMirrorKind.folder,
        ))
          source,
    };
    final sourceParents = {
      for (final owner in owners.values)
        if (owner.publisher == ticket.publisher)
          owner.source: owner.parentSource,
    };
    bool introducedTopic(String id) {
      final owner = owners[id]!;
      if (owner.kind != FollowingMirrorKind.topic ||
          initial.owners.containsKey(id) ||
          (initial
                  .activity
                  .notificationKnown['${ticket.publisher}/${owner.source}']
                  ?.contains(owner.source) ??
              false))
        return false;
      var parent = owner.parentSource;
      final visited = <String>{};
      while (parent != null && visited.add(parent)) {
        if (establishedFolders.contains(parent)) return true;
        parent = sourceParents[parent];
      }
      return false;
    }

    final changes = <SyncEvent>[
      for (final source in roots.difference(
        initial.subscriptions[ticket.publisher] ?? const {},
      ))
        SyncEvent(
          kind: SyncEventKind.subscribed,
          at: now(),
          publisher: ticket.publisher,
          source: source,
          sourceKind: 'following_topics',
        ),
      for (final id in receivedIds)
        if (previousDefinitions[id] != owners[id]!.definitionDigest)
          SyncEvent(
            kind: SyncEventKind.received,
            at: now(),
            publisher: ticket.publisher,
            source: owners[id]!.source,
            sourceKind: 'following_topics',
            added: initial.owners.containsKey(id) ? 0 : 1,
            fingerprint: introducedTopic(id) ? ticket.fingerprint : null,
            notificationMembers: introducedTopic(id)
                ? {owners[id]!.source}
                : const {},
          ),
      for (final id in remove)
        SyncEvent(
          kind: SyncEventKind.received,
          at: now(),
          publisher: ticket.publisher,
          source: initial.owners[id]!.source,
          sourceKind: 'following_topics',
          removed: 1,
        ),
    ];
    final next = FollowingMirrorState(
      activity: initial.activity.append(
        changes,
        observedMembers: {
          for (final id in receivedIds)
            if (owners[id]!.kind == FollowingMirrorKind.topic)
              '${ticket.publisher}/${owners[id]!.source}': {owners[id]!.source},
        },
      ),
      epoch: initial.epoch + 1,
      owners: owners,
      checkpoints: checkpoints,
      subscriptions: {...initial.subscriptions, ticket.publisher: roots},
      publisherNames: {
        ...initial.publisherNames,
        ticket.publisher: catalog.name,
      },
    );
    await gate.withCurrentCatalog(ticket, () async {
      ensureCurrent?.call();
      final current = await store.readMirrorSnapshot();
      if (current.mirrors != initial ||
          current.structureDigest != before.structureDigest)
        throw const SyncConflict();
      if (const DeepCollectionEquality().equals(
            initial.toJson()..remove('epoch'),
            next.toJson()..remove('epoch'),
          ) &&
          organization == before.organization &&
          topics.every((t) {
            final old = oldTopics[t.id];
            return old != null &&
                old.name == t.name &&
                old.query == t.query &&
                old.queryStructure == t.queryStructure &&
                old.profileId == t.profileId &&
                old.position == t.position;
          }))
        return;
      await store.commitMirrorDefinitions(
        expected: initial,
        expectedStructureDigest: before.structureDigest,
        next: next,
        topics: topics,
        organization: organization,
        removeTopicIds: remove.where(oldTopics.containsKey).toSet(),
      );
    });
  }

  String? _bind(
    BackupProfileReference source,
    List<BackupProfileReference> local,
    String? previous,
  ) {
    final compatible = local
        .where(
          (p) =>
              p.booruType == source.booruType &&
              normalizeBackupProfileUrl(p.url) ==
                  normalizeBackupProfileUrl(source.url),
        )
        .toList();
    if (compatible.any((p) => p.id == previous)) return previous;
    if (compatible.any((p) => p.id == source.id)) return source.id;
    return compatible.length == 1 ? compatible.single.id : null;
  }

  String _descriptor(SyncRevision revision) =>
      syncDigest(syncJsonBytes(revision.toJson()));
  void _checkRevision(FollowingMirrorOwner before, SyncRevision revision) {
    if (revision.schema != ValidatedSyncFollowingPackage.schema)
      throw const SyncUpdateRequired();
    if (revision.revision < before.revision ||
        (revision.revision == before.revision &&
            (revision.sha256 != before.payloadDigest ||
                _descriptor(revision) != before.descriptorDigest))) {
      throw const SyncReplayRejected();
    }
  }

  Future<String> createLocalCopy(String localId) async {
    ensureCurrent?.call();
    final snapshot = await store.readMirrorSnapshot();
    final current = snapshot.mirrors;
    final root = current.owners[localId];
    if (root == null) throw const FollowingMirrorReadOnly();
    final owned = {
      for (final e in current.owners.entries)
        if (e.value.publisher == root.publisher) e.value.source: e,
    };
    final scope = BookmarkSyncScope(
      publisher: root.publisher,
      nodes: [
        for (final e in owned.values)
          SyncBookmarkNode(
            source: e.value.source,
            parent: e.value.parentSource,
            position: e.value.position,
          ),
      ],
      directRoots: {root.source},
    );
    final ids = <String, String>{};
    final used = {
      ...snapshot.topics.map((t) => t.id),
      ...snapshot.organization.folders.map((f) => f.id),
    };
    for (final source in scope.covered) {
      final id = newId();
      if (!used.add(id)) throw const SyncConflict();
      ids[owned[source]!.key] = id;
    }
    final topicById = {for (final t in snapshot.topics) t.id: t};
    final folderById = {for (final f in snapshot.organization.folders) f.id: f};
    final homePosition = [
      for (final f in snapshot.organization.folders)
        if (f.parentId == null) f.position,
      for (final p in snapshot.organization.placements)
        if (p.folderId == null) p.position,
    ].fold(0, (int n, p) => p >= n ? p + 1 : n);
    String localFolderName(TopicFolder folder) {
      if (folder.id != localId) return folder.name;
      return FolderTree(
        snapshot.organization.folders.where(
          (folder) => !current.isReceived(folder.id),
        ),
      ).uniqueName(folder.name, null);
    }

    final addedTopics = <FollowingTopic>[];
    final addedFolders = <TopicFolder>[];
    final placements = <FolderPlacement>[];
    for (final entry in ids.entries) {
      final oldId = entry.key;
      final owner = current.owners[oldId]!;
      final parent = current.localIdFor(
        root.publisher,
        owner.parentSource ?? root.source,
      );
      final position = oldId == localId ? homePosition : owner.position;
      if (owner.kind == FollowingMirrorKind.folder) {
        final folder = folderById[oldId]!;
        addedFolders.add(
          TopicFolder(
            id: entry.value,
            name: localFolderName(folder),
            parentId: oldId == localId ? null : ids[parent],
            position: position,
            feedEnabled: folder.feedEnabled,
            feedMaxPosts: folder.feedMaxPosts,
          ),
        );
      } else {
        final topic = topicById[oldId]!;
        final reference = parseBackupProfile(owner.profile, 'profile');
        final source = FollowingTopicSource(
          booruType: reference.booruType,
          url: reference.url,
        );
        final compatible = profiles()
            .where(
              (profile) => source.matches(
                profile.booruType,
                normalizeBackupProfileUrl(profile.url),
              ),
            )
            .toList();
        final profileId = compatible.length == 1 ? compatible.single.id : null;
        if (profileId == null && source.anonymous(anonymousPolicy()) == null) {
          throw const FollowingLocalCopySourceUnavailable();
        }
        addedTopics.add(
          FollowingTopic.create(
            id: entry.value,
            profileId: profileId ?? entry.value,
            localSource: source,
            query: topic.query,
            queryStructure: topic.queryStructure,
            name: topic.name,
            position: position,
            createdAt: now().toUtc(),
          ),
        );
        placements.add(
          FolderPlacement(
            itemId: entry.value,
            folderId: oldId == localId ? null : ids[parent],
            position: position,
          ),
        );
      }
    }
    ensureCurrent?.call();
    await store.commitMirrorDefinitions(
      expected: current,
      expectedStructureDigest: snapshot.structureDigest,
      next: FollowingMirrorState(
        activity: current.activity.append([
          SyncEvent(
            kind: SyncEventKind.copied,
            at: now(),
            source: ids[localId]!,
            sourceKind: 'following_topics',
          ),
        ]),
        epoch: current.epoch + 1,
        owners: current.owners,
        checkpoints: current.checkpoints,
        subscriptions: current.subscriptions,
        publisherNames: current.publisherNames,
      ),
      topics: addedTopics,
      organization: TopicOrganization(
        folders: [...snapshot.organization.folders, ...addedFolders],
        placements: [...snapshot.organization.placements, ...placements],
      ),
    );
    return ids[localId]!;
  }

  /// Offline explicit-root removal preserves all overlapping coverage and
  /// checkpoints. Revoking trust is the shared service's separate responsibility.
  Future<void> unsubscribe(
    String publisher,
    String source, {
    bool forget = false,
  }) async {
    ensureCurrent?.call();
    final before = await store.readMirrorSnapshot();
    final current = before.mirrors;
    final roots = Set<String>.of(current.subscriptions[publisher] ?? {});
    if (forget) {
      roots.clear();
    } else if (!roots.remove(source)) {
      throw StateError('Only explicit subscription roots may be removed');
    }
    final owned = {
      for (final e in current.owners.entries)
        if (e.value.publisher == publisher) e.value.source: e,
    };
    final scope = BookmarkSyncScope(
      publisher: publisher,
      nodes: [
        for (final e in owned.values)
          SyncBookmarkNode(
            source: e.value.source,
            parent: e.value.parentSource,
            position: e.value.position,
          ),
      ],
      directRoots: roots.where(owned.containsKey).toSet(),
    );
    final remove = {
      for (final e in owned.values)
        if (!scope.covered.contains(e.value.source)) e.key,
    };
    final local = {
      for (final source in scope.covered) source: owned[source]!.key,
    };
    final subscriptions = Map<String, Set<String>>.of(current.subscriptions);
    final names = Map<String, String>.of(current.publisherNames);
    if (forget) {
      subscriptions.remove(publisher);
      names.remove(publisher);
    } else {
      subscriptions[publisher] = roots;
    }
    await store.commitMirrorDefinitions(
      expected: current,
      expectedStructureDigest: before.structureDigest,
      next: FollowingMirrorState(
        activity: current.activity.append([
          if (!forget)
            SyncEvent(
              kind: SyncEventKind.unsubscribed,
              at: now(),
              publisher: publisher,
              source: source,
              sourceKind: 'following_topics',
            ),
        ]),
        epoch: current.epoch + 1,
        owners: {...current.owners}
          ..removeWhere((id, _) => remove.contains(id)),
        checkpoints: current.checkpoints,
        subscriptions: subscriptions,
        publisherNames: names,
      ),
      topics: const [],
      removeTopicIds: {
        for (final t in before.topics)
          if (remove.contains(t.id)) t.id,
      },
      organization: TopicOrganization(
        folders: [
          for (final f in before.organization.folders)
            if (!remove.contains(f.id))
              current.owners[f.id]?.publisher == publisher
                  ? TopicFolder(
                      id: f.id,
                      nameScope: f.nameScope,
                      name: f.name,
                      parentId: local[current.owners[f.id]!.parentSource],
                      position: f.position,
                      feedEnabled: f.feedEnabled,
                      feedMaxPosts: f.feedMaxPosts,
                    )
                  : f,
        ],
        placements: [
          for (final p in before.organization.placements)
            if (!remove.contains(p.itemId))
              current.owners[p.itemId]?.publisher == publisher
                  ? FolderPlacement(
                      itemId: p.itemId,
                      folderId: local[current.owners[p.itemId]!.parentSource],
                      position: p.position,
                    )
                  : p,
        ],
      ),
    );
  }
}
