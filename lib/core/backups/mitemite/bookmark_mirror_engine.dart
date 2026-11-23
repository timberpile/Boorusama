import 'activity_log.dart';
import 'receive_units.dart';

import 'package:collection/collection.dart';

import 'bookmark_package.dart';
import '../sources/bookmark_backup_data.dart';

import 'package:uuid/uuid.dart';

import '../../bookmarks/src/types/bookmark.dart';
import '../../bookmarks/src/types/bookmark_group.dart';
import '../../bookmarks/src/types/bookmark_group_repository.dart';
import '../../bookmarks/src/types/bookmark_group_tree.dart';
import '../../bookmarks/src/types/bookmark_mirror_state.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../bookmarks/src/types/unified_bookmark_store.dart';
import 'bookmark_scope.dart';
import 'catalog.dart';
import 'catalog_gate.dart';
import 'protocol.dart';
import 'reading_state.dart';
import 'receive_preparation.dart';

/// Applies approved Bookmark subscriptions through the existing unified payload,
/// organization and ownership journal. Discovery and archive preparation happen
/// before the shared mutation lock; the gate revalidates immediately before apply.
final class SyncBookmarkMirrorEngine {
  SyncBookmarkMirrorEngine({
    required this.store,
    required this.groups,
    required this.gate,
    required this.preparation,
    DateTime Function()? now,
    String Function()? newId,
    this.maxPreparedBytes = 64 * 1024 * 1024,
    this.ensureCurrent,
  }) : now = now ?? DateTime.now,
       newId = newId ?? (() => const Uuid().v4().toLowerCase()) {
    if (store is! BookmarkMirrorStore) {
      throw ArgumentError('Mirror-capable Bookmark storage required');
    }
    if (!identical(
      (store as BookmarkMirrorStore).coordinator,
      gate.mutations,
    )) {
      throw ArgumentError(
        'Mirror apply and catalog validation must share the domain coordinator',
      );
    }
  }
  final int maxPreparedBytes;
  final void Function()? ensureCurrent;
  final UnifiedBookmarkStore store;
  final BookmarkGroupRepository groups;
  final SyncCatalogGate gate;
  final SyncReceivePreparation preparation;
  final DateTime Function() now;
  final String Function() newId;
  BookmarkMirrorStore get mirrors => store as BookmarkMirrorStore;

  Future<T> _runScope<T>(Future<T> Function() operation) =>
      store.runReadWriteScope(() {
        ensureCurrent?.call();
        return operation();
      });

  Future<void> receive({
    required VerifiedSyncCatalog ticket,
    required List<int> publisherKey,
    Set<String>? directRoots,
  }) async {
    ensureCurrent?.call();
    if (syncDigest(publisherKey) != ticket.fingerprint)
      throw const FormatException('Publisher key does not match catalog');
    final initial = await mirrors.readMirrorState();
    final owned = initial.owners.values
        .where((owner) => owner.publisher == ticket.publisher)
        .toList();
    final roots = <String>{
      ...?initial.subscriptions[ticket.publisher],
      ...?directRoots,
    };
    final units = syncReceiveUnits(
      catalog: SyncCatalog.fromJson(ticket.content),
      kind: 'bookmarks',
      roots: roots,
      priorNodes: [
        for (final owner in owned)
          SyncBookmarkNode(
            source: owner.source,
            parent: owner.parentSource,
            position: owner.position,
          ),
      ],
      members: {
        for (final owner in owned)
          owner.source: SyncGroupReadingState.fromJson(owner.reading).members,
      },
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
    final sourceUnits = {
      for (final unit in units)
        for (final source in unit) source: unit,
    };
    final pending = [for (final unit in units) Set<String>.of(unit)];
    while (pending.isNotEmpty) {
      final unit = pending.removeAt(0);
      try {
        await _receiveUnit(
          ticket: ticket,
          publisherKey: publisherKey,
          directRoots: directRoots?.intersection(unit),
          sourceUnit: unit,
        );
      } on SyncReceiveCoupling catch (coupling) {
        final merged = {
          ...unit,
          for (final source in coupling.sources) ...?sourceUnits[source],
        };
        if (merged.length <= unit.length) throw const SyncConflict();
        pending.removeWhere((candidate) => candidate.any(merged.contains));
        failures.removeWhere((source, _) => merged.contains(source));
        pending.insert(0, merged);
      } catch (error) {
        final root = roots.where(unit.contains).toList()..sort();
        failures[root.firstOrNull ?? unit.first] = error;
      }
    }
    if (failures.isNotEmpty)
      throw SyncPartialReceiveFailure('bookmarks', failures);
  }

  Future<void> _receiveUnit({
    required VerifiedSyncCatalog ticket,
    required List<int> publisherKey,
    Set<String>? directRoots,
    Set<String>? sourceUnit,
  }) async {
    if (syncDigest(publisherKey) != ticket.fingerprint) {
      throw const FormatException('Publisher key does not match catalog');
    }
    final initial = await mirrors.readMirrorState();
    if (initial.forgotten.contains(ticket.publisher)) {
      throw const SyncTrustRequired();
    }
    // Receive may add roots, but cannot authorize removing an existing one.
    // Offline unsubscribe/Forget and verified source tombstones own cleanup.
    final roots = <String>{
      ...?initial.subscriptions[ticket.publisher],
      ...?directRoots,
    };
    final unitRoots = roots
        .where((id) => sourceUnit == null || sourceUnit.contains(id))
        .toSet();
    final catalog = SyncCatalog.fromJson(ticket.content);
    final entries = {
      for (final entry in catalog.entries)
        if (entry.id.kind == 'bookmarks') entry.id.source: entry,
    };
    final owned = {
      for (final entry in initial.owners.entries)
        if (entry.value.publisher == ticket.publisher &&
            (sourceUnit == null || sourceUnit.contains(entry.value.source)))
          entry.value.source: entry,
    };
    for (final root in unitRoots) {
      final entry = entries[root];
      if (entry == null) {
        throw const SyncConflict();
      }
    }
    final scope = BookmarkSyncScope(
      publisher: ticket.publisher,
      nodes: [
        for (final entry in entries.values)
          if (entry.state == SyncPublicationState.active)
            SyncBookmarkNode(
              source: entry.id.source,
              parent: entry.parent,
              position: entry.position,
            ),
      ],
      directRoots: {
        for (final root in unitRoots)
          if (entries[root]!.state == SyncPublicationState.active) root,
      },
    );
    final withdrawnRoots = {
      for (final root in unitRoots)
        if (entries[root]!.state != SyncPublicationState.active) root,
    };
    bool lostThroughWithdrawal(String source) {
      final seen = <String>{};
      String? current = source;
      while (current != null && seen.add(current)) {
        if (withdrawnRoots.contains(current)) return true;
        current = owned[current]?.value.parentSource;
      }
      return false;
    }

    for (final prior in owned.values) {
      final entry = entries[prior.value.source];
      if (entry == null && !lostThroughWithdrawal(prior.value.source)) {
        // Missing metadata never carries signed deletion authority.
        throw const SyncConflict();
      }
    }
    final retired = <String, BookmarkMirrorOwner>{};
    for (final entry in entries.values) {
      if (sourceUnit != null && !sourceUnit.contains(entry.id.source)) continue;
      if (entry.state == SyncPublicationState.active) continue;
      final prior =
          initial.checkpoints['${ticket.publisher}/${entry.id.source}'];
      if (prior == null) continue;
      final revision = entry.revision;
      if (revision != null) {
        if (revision.schema != ValidatedSyncBookmarkPackage.schema) {
          throw const SyncUpdateRequired();
        }
        _checkRevision(prior, revision);
      }
      retired[prior.sourceKey] = prior.retire(
        revision: revision?.revision,
        payloadDigest: revision?.sha256,
        descriptorDigest: revision == null
            ? null
            : syncDigest(syncJsonBytes(revision.toJson())),
      );
    }
    final prepared = <String, PreparedSyncBookmarkRevision>{};
    var retainedBytes = 0;
    var advertisedBytes = 0;
    for (final source in scope.covered) {
      final entry = entries[source]!;
      final before =
          owned[source]?.value ??
          initial.checkpoints['${ticket.publisher}/$source'];
      final revision = entry.revision!;
      if (revision.schema != ValidatedSyncBookmarkPackage.schema) {
        throw const SyncUpdateRequired();
      }
      final descriptorDigest = syncDigest(syncJsonBytes(revision.toJson()));
      if (before != null) {
        _checkRevision(before, revision);
        if (before.retired && revision.revision <= before.revision)
          throw const SyncReplayRejected();
      }
      if (owned.containsKey(source) &&
          before?.revision == revision.revision &&
          before?.payloadDigest == revision.sha256 &&
          before?.descriptorDigest == descriptorDigest) {
        continue;
      }
      advertisedBytes += revision.length;
      if (advertisedBytes > maxPreparedBytes) {
        throw const FormatException('Sync batch exceeds preparation budget');
      }
      final value = await preparation.prepare(
        catalog: ticket,
        collection: entry.id,
        publisherKey: publisherKey,
        maxPreparedBytes: maxPreparedBytes - retainedBytes,
      );
      if (value == null) throw const SyncRevisionUnavailable();
      retainedBytes += value.package.retainedByteLength;
      if (retainedBytes > maxPreparedBytes) {
        throw const FormatException('Sync batch exceeds preparation budget');
      }
      prepared[source] = value;
    }
    final materialized = {
      for (final entry in prepared.entries)
        entry.key: await entry.value.package.materialize(),
    };
    await gate.withCurrentCatalog(
      ticket,
      () => _runScope(() async {
        ensureCurrent?.call();
        final current = await mirrors.readMirrorState();
        if (current.epoch != initial.epoch) throw const SyncConflict();
        final allGroups = {
          for (final group in await groups.getGroups()) group.id: group,
        };
        final nextOwners = Map<String, BookmarkMirrorOwner>.of(current.owners);
        final localIds = <String, String>{};
        final usedIds = allGroups.keys.toSet();
        for (final source in scope.covered) {
          var id = owned[source]?.key;
          if (id == null) {
            id = newId();
            if (!usedIds.add(id) || id == defaultBookmarkGroupId) {
              throw const SyncConflict();
            }
          }
          localIds[source] = id;
        }
        final removeGroups = <String>{
          for (final prior in owned.values)
            if (!scope.covered.contains(prior.value.source)) prior.key,
        };
        final writes = <Bookmark>[];
        final known = <Object, Bookmark>{};
        final updated = <BookmarkGroup>[];
        final at = now().toUtc();
        for (final source in scope.covered) {
          final entry = entries[source]!;
          final id = localIds[source]!;
          final oldGroup = allGroups[id];
          final oldOwner = current.owners[id];
          final payload = prepared[source];
          final members = <int>{};
          final portableMembers = <String>{};
          final dates = <int, DateTime>{};
          if (payload != null) {
            final data = materialized[source]!;
            final sourceGroup = data.groups.single;
            for (final incoming in data.records) {
              final candidate = store.normalizeRecord(
                bookmarkWithId(incoming, 0),
              );
              final identity =
                  bookmarkContentIdentity(candidate) ??
                  (throw const SyncConflict());
              var saved =
                  known[identity] ??
                  await store.lookupContent(
                    identity,
                    engine: bookmarkEngine(candidate),
                  );
              if (saved == null) {
                final local = (await store.reserveIds(1)).single;
                saved = bookmarkWithId(candidate, local);
                writes.add(saved);
              } else {
                // Existing local observations and actor hints remain authoritative;
                // source-owned Group membership never overwrites unrelated saves.
                final normalized = store.normalizeRecord(
                  bookmarkWithId(candidate, saved.id),
                  previous: saved,
                );
                final different =
                    _memberSemantic(normalized, source) !=
                    _memberSemantic(saved, source);
                final memberships = allGroups.values.where(
                  (group) => group.bookmarkIds.contains(saved!.id),
                );
                final local = memberships.any(
                  (group) => !current.isReceived(group.id),
                );
                final foreign = memberships.any(
                  (group) =>
                      current.owners[group.id]?.publisher != ticket.publisher,
                );
                if (different && !local && foreign) throw const SyncConflict();
                if (different && !local && sourceUnit != null) {
                  final coupled = {
                    for (final group in memberships)
                      if (current.owners[group.id] case final owner?
                          when owner.publisher == ticket.publisher &&
                              !sourceUnit.contains(owner.source))
                        owner.source,
                  };
                  if (coupled.isNotEmpty) throw SyncReceiveCoupling(coupled);
                }
                if (different && !local) {
                  writes.removeWhere((record) => record.id == saved!.id);
                  writes.add(normalized);
                  saved = normalized;
                }
              }
              known[identity] = saved;
              members.add(saved.id);
              portableMembers.add(syncBookmarkMemberKey(saved));
              dates[saved.id] =
                  oldGroup?.addedAt[saved.id] ??
                  sourceGroup.addedAt[incoming.id] ??
                  at;
            }
          } else {
            if (oldGroup == null || oldOwner == null) {
              throw const SyncConflict();
            }
            members.addAll(oldGroup.bookmarkIds);
            dates.addAll(oldGroup.addedAt);
            portableMembers.addAll(
              SyncGroupReadingState.fromJson(oldOwner.reading).members,
            );
          }
          final target = BookmarkGroup(
            id: id,
            name: entry.name,
            bookmarkIds: members,
            addedAt: dates,
            parentGroupId: localIds[entry.parent],
            position: entry.position,
          );
          updated.add(target);
          final reading =
              (oldOwner == null
                      ? SyncGroupReadingState.empty(entry.id)
                      : SyncGroupReadingState.fromJson(oldOwner.reading))
                  .applyMembership(
                    revision: entry.revision!.revision,
                    members: portableMembers,
                  );
          nextOwners[id] = BookmarkMirrorOwner(
            publisher: ticket.publisher,
            source: source,
            parentSource: entry.parent,
            position: entry.position,
            revision: entry.revision!.revision,
            payloadDigest: entry.revision!.sha256,
            descriptorDigest: syncDigest(
              syncJsonBytes(entry.revision!.toJson()),
            ),
            groupDigest: bookmarkMirrorGroupDigest(target),
            reading: reading.toJson(),
          );
        }
        for (final id in removeGroups) {
          nextOwners.remove(id);
        }
        final desiredGroups = {
          for (final entry in allGroups.entries)
            if (!removeGroups.contains(entry.key)) entry.key: entry.value,
          for (final group in updated) group.id: group,
        };
        final retainedMembers = {
          for (final group in desiredGroups.values) ...group.bookmarkIds,
        };
        final removedMembers = {
          for (final prior in owned.values)
            ...?allGroups[prior.key]?.bookmarkIds,
        }.difference(retainedMembers);
        final changes = <SyncEvent>[
          for (final source in roots.difference(
            current.subscriptions[ticket.publisher] ?? const {},
          ))
            SyncEvent(
              kind: SyncEventKind.subscribed,
              at: at,
              publisher: ticket.publisher,
              source: source,
            ),
        ];
        final writtenIds = writes.map((record) => record.id).toSet();
        final observed = <String, Set<String>>{};
        bool alreadyCovered(String source) {
          final previousRoots =
              current.subscriptions[ticket.publisher] ?? const <String>{};
          final visited = <String>{};
          String? cursor = source;
          while (cursor != null && visited.add(cursor)) {
            final entry = entries[cursor];
            if (entry == null || entry.state != SyncPublicationState.active)
              return false;
            if (previousRoots.contains(cursor)) return true;
            cursor = entry.parent;
          }
          return false;
        }

        for (final group in updated) {
          final owner = nextOwners[group.id]!;
          final old = current.owners[group.id];
          final members = SyncGroupReadingState.fromJson(owner.reading).members;
          final previous = old == null
              ? const <String>{}
              : SyncGroupReadingState.fromJson(old.reading).members;
          final checkpoint = current.checkpoints[owner.sourceKey];
          final historical = checkpoint == null
              ? null
              : SyncGroupReadingState.fromJson(checkpoint.reading);
          final known = {
            ...?current.activity.notificationKnown[owner.sourceKey],
            ...previous,
            ...?historical?.members,
            ...?historical?.readMembers,
          };
          observed[owner.sourceKey] = {...known, ...members};
          if (old != null &&
              old.groupDigest == owner.groupDigest &&
              old.parentSource == owner.parentSource &&
              !group.bookmarkIds.any(writtenIds.contains))
            continue;
          // Initial manual hydration is a baseline. A future child of a prior
          // subscription is an incoming membership change, even if also linked
          // as a direct root. Reading flags never drive the addition set.
          final additions = old != null || alreadyCovered(owner.source)
              ? members.difference(known)
              : <String>{};
          changes.add(
            SyncEvent(
              kind: SyncEventKind.received,
              at: at,
              publisher: ticket.publisher,
              source: owner.source,
              added: members.difference(previous).length,
              removed: previous.difference(members).length,
              fingerprint: additions.isEmpty ? null : ticket.fingerprint,
              notificationMembers: Set.unmodifiable(additions),
            ),
          );
        }
        for (final id in removeGroups) {
          final owner = current.owners[id]!;
          changes.add(
            SyncEvent(
              kind: SyncEventKind.received,
              at: at,
              publisher: ticket.publisher,
              source: owner.source,
              removed: SyncGroupReadingState.fromJson(owner.reading)
                  .members
                  .length,
            ),
          );
        }
        final next = BookmarkMirrorState(
          activity: current.activity.append(changes, observedMembers: observed),
          epoch: current.epoch + 1,
          owners: nextOwners,
          checkpoints: {...current.checkpoints, ...retired},
          subscriptions: {...current.subscriptions, ticket.publisher: roots},
          publisherNames: {
            ...current.publisherNames,
            ticket.publisher: catalog.name,
          },
          aliases: current.aliases,
          forgotten: current.forgotten,
        );
        if (const DeepCollectionEquality().equals(
              current.toJson()..remove('epoch'),
              next.toJson()..remove('epoch'),
            ) &&
            updated.every((group) => allGroups[group.id] == group) &&
            writes.isEmpty) {
          return;
        }
        await mirrors.commitMirrorOrganization(
          expected: current,
          next: next,
          records: writes,
          groups: updated,
          removeGroupIds: removeGroups,
          removeIds: removedMembers,
        );
      }),
    );
  }

  void _checkRevision(BookmarkMirrorOwner before, SyncRevision revision) {
    final descriptor = syncDigest(syncJsonBytes(revision.toJson()));
    if (revision.revision < before.revision ||
        (revision.revision == before.revision &&
            (revision.sha256 != before.payloadDigest ||
                (before.descriptorDigest != null &&
                    descriptor != before.descriptorDigest)))) {
      throw const SyncReplayRejected();
    }
  }

  String _memberSemantic(Bookmark record, String source) =>
      syncBookmarkSemanticHash(
        BookmarkBackupData.unified(
          records: [record],
          groups: [
            BookmarkGroupBackup(
              id: source,
              name: 'Source',
              bookmarkIds: [record.id],
            ),
          ],
        ),
        preparation.codec,
      );

  /// Management remains available without shared storage. A confirmed action
  /// removes an explicit root only after recomputing the complete overlap union.
  Future<void> unsubscribe(String publisher, String source) =>
      _runScope(() async {
        final current = await mirrors.readMirrorState();
        final roots = Set<String>.of(
          current.subscriptions[publisher] ?? const {},
        );
        if (!roots.remove(source)) {
          throw StateError('Only explicit subscription roots may be removed');
        }
        await _removeUncovered(current, publisher, roots, forget: false);
      });

  Future<void> approvePublisher(String publisher) => _runScope(
    () async {
      if (gate.approvedKey(publisher) == null) throw const SyncTrustRequired();
      final current = await mirrors.readMirrorState();
      if (!current.forgotten.contains(publisher)) return;
      final forgotten = Set<String>.of(current.forgotten)..remove(publisher);
      await mirrors.commitMirrorOrganization(
        expected: current,
        next: BookmarkMirrorState(
          activity: current.activity,
          epoch: current.epoch + 1,
          owners: current.owners,
          checkpoints: current.checkpoints,
          subscriptions: current.subscriptions,
          publisherNames: current.publisherNames,
          aliases: current.aliases,
          forgotten: forgotten,
        ),
      );
    },
  );

  Future<void> forgetDevice(String publisher) => _runScope(
    () async {
      final current = await mirrors.readMirrorState();
      await _removeUncovered(current, publisher, {}, forget: true);
      // The domain journal already blocks resurrection if this preference write
      // fails or the process stops here. Reapproval must clear both boundaries.
      await gate.revokePublisher(publisher);
    },
  );

  Future<void> _removeUncovered(
    BookmarkMirrorState current,
    String publisher,
    Set<String> roots, {
    required bool forget,
  }) async {
    final owned = {
      for (final entry in current.owners.entries)
        if (entry.value.publisher == publisher) entry.value.source: entry,
    };
    final scope = BookmarkSyncScope(
      publisher: publisher,
      nodes: [
        for (final entry in owned.values)
          SyncBookmarkNode(
            source: entry.value.source,
            parent: entry.value.parentSource,
            position: entry.value.position,
          ),
      ],
      directRoots: roots.where(owned.containsKey).toSet(),
    );
    final local = {
      for (final source in scope.covered) source: owned[source]!.key,
    };
    final remove = {
      for (final entry in owned.values)
        if (!scope.covered.contains(entry.value.source)) entry.key,
    };
    final before = {
      for (final group in await groups.getGroups()) group.id: group,
    };
    final owners = Map<String, BookmarkMirrorOwner>.of(current.owners)
      ..removeWhere((id, _) => remove.contains(id));
    final changed = <BookmarkGroup>[];
    for (final source in scope.covered) {
      final id = local[source]!;
      final old = before[id] ?? (throw const SyncConflict());
      final owner = owners[id]!;
      final parent = local[owner.parentSource];
      final group = old.copyWith(home: true).copyWith(parentGroupId: parent);
      changed.add(group);
      owners[id] = BookmarkMirrorOwner(
        publisher: owner.publisher,
        source: owner.source,
        revision: owner.revision,
        payloadDigest: owner.payloadDigest,
        descriptorDigest: owner.descriptorDigest,
        groupDigest: bookmarkMirrorGroupDigest(group),
        parentSource: owner.parentSource,
        position: owner.position,
        reading: owner.reading,
      );
    }
    final retained = {
      for (final group in before.values)
        if (!remove.contains(group.id)) ...group.bookmarkIds,
    };
    final orphaned = {for (final id in remove) ...?before[id]?.bookmarkIds}
        .difference(retained);
    final subscriptions = Map<String, Set<String>>.of(current.subscriptions);
    final names = Map<String, String>.of(current.publisherNames);
    final aliases = Map<String, String>.of(current.aliases);
    if (forget) {
      subscriptions.remove(publisher);
      names.remove(publisher);
      aliases.remove(publisher);
    } else {
      subscriptions[publisher] = roots;
    }
    await mirrors.commitMirrorOrganization(
      expected: current,
      next: BookmarkMirrorState(
        activity: current.activity.append([
          if (forget && !current.forgotten.contains(publisher))
            SyncEvent(
              kind: SyncEventKind.forgotten,
              at: now(),
              publisher: publisher,
            ),
          if (!forget)
            for (final source
                in (current.subscriptions[publisher] ?? const <String>{})
                    .difference(roots))
              SyncEvent(
                kind: SyncEventKind.unsubscribed,
                at: now(),
                publisher: publisher,
                source: source,
              ),
        ]),
        epoch: current.epoch + 1,
        owners: owners,
        checkpoints: current.checkpoints,
        subscriptions: subscriptions,
        publisherNames: names,
        aliases: aliases,
        forgotten: forget
            ? {...current.forgotten, publisher}
            : current.forgotten,
      ),
      groups: changed,
      removeGroupIds: remove,
      removeIds: orphaned,
    );
  }

  Future<BookmarkGroup> createLocalCopy(String groupId) => _runScope(() async {
    final current = await mirrors.readMirrorState();
    if (!current.isReceived(groupId)) {
      throw StateError('Received Group required');
    }
    final all = await groups.getGroups();
    final copies = BookmarkGroupTree(all).duplicateSubtrees({
      groupId: all.singleWhere((group) => group.id == groupId).name,
    }, createId: newId);
    final rootIds = copies.roots.map((group) => group.id).toSet();
    final local = [
      for (final group in copies.groups)
        rootIds.contains(group.id) ? group.copyWith(home: true) : group,
    ];
    final root = local.singleWhere((group) => rootIds.contains(group.id));
    await mirrors.commitMirrorOrganization(
      expected: current,
      next: BookmarkMirrorState(
        epoch: current.epoch + 1,
        owners: current.owners,
        checkpoints: current.checkpoints,
        subscriptions: current.subscriptions,
        publisherNames: current.publisherNames,
        aliases: current.aliases,
        forgotten: current.forgotten,
        activity: current.activity.append([
          SyncEvent(kind: SyncEventKind.copied, at: now(), source: root.id),
        ]),
      ),
      groups: local,
      localCopy: true,
    );
    return root;
  });

  Future<void> setAlias(String publisher, String? alias) => _runScope(() async {
    syncUuid(publisher);
    if (gate.approvedKey(publisher) == null) throw const SyncTrustRequired();
    final current = await mirrors.readMirrorState();
    final aliases = Map<String, String>.of(current.aliases);
    final normalized = alias?.trim();
    if (normalized == null || normalized.isEmpty) {
      aliases.remove(publisher);
    } else {
      aliases[publisher] = syncLabel(normalized);
    }
    if (const MapEquality<String, String>().equals(current.aliases, aliases))
      return;
    await mirrors.commitMirrorOrganization(
      expected: current,
      next: BookmarkMirrorState(
        activity: current.activity,
        epoch: current.epoch + 1,
        owners: current.owners,
        checkpoints: current.checkpoints,
        subscriptions: current.subscriptions,
        publisherNames: current.publisherNames,
        aliases: aliases,
        forgotten: current.forgotten,
      ),
    );
  });

  /// Clear only intent already copied atomically into the local notification
  /// outbox. Failure leaves the domain journal recoverable without reapplying
  /// payloads; a persisted preference cursor makes an acknowledgement retry safe.
  Future<void> acknowledgePostNotifications(int cursor) => _runScope(() async {
    final current = await mirrors.readMirrorState();
    if (current.activity.pendingPosts.isEmpty ||
        cursor <= current.activity.notificationCursor)
      return;
    final activity = current.activity.acknowledgePostsThrough(cursor);
    await mirrors.commitMirrorOrganization(
      expected: current,
      next: BookmarkMirrorState(
        activity: activity,
        epoch: current.epoch + 1,
        owners: current.owners,
        checkpoints: current.checkpoints,
        subscriptions: current.subscriptions,
        publisherNames: current.publisherNames,
        aliases: current.aliases,
        forgotten: current.forgotten,
      ),
    );
  });

  Future<void> acknowledgeArrival(String localId, int renderedRevision) =>
      _updateReading(
        localId,
        (state) => state.acknowledgeArrival(renderedRevision: renderedRevision),
      );
  Future<void> markRead(String localId, Set<String> identities) =>
      _updateReading(localId, (state) => state.markRead(identities));
  Future<void> markReadTargets(Iterable<BookmarkReadTarget> targets) {
    final captured = List<BookmarkReadTarget>.unmodifiable(
      targets.expand((t) => t.allTargets),
    );
    return _runScope(() async {
      final current = await mirrors.readMirrorState();
      final selected = <String, Set<String>>{};
      for (final target in captured) {
        if (target.isCurrentMirrors(current))
          selected.putIfAbsent(target.groupId, () => {}).add(target.member);
      }
      final owners = Map<String, BookmarkMirrorOwner>.of(current.owners);
      var changed = false;
      for (final entry in selected.entries) {
        final owner = owners[entry.key]!;
        final before = SyncGroupReadingState.fromJson(owner.reading);
        final after = before.markRead(entry.value);
        if (identical(before, after)) continue;
        changed = true;
        owners[entry.key] = BookmarkMirrorOwner(
          publisher: owner.publisher,
          source: owner.source,
          revision: owner.revision,
          payloadDigest: owner.payloadDigest,
          descriptorDigest: owner.descriptorDigest,
          groupDigest: owner.groupDigest,
          parentSource: owner.parentSource,
          position: owner.position,
          retired: owner.retired,
          reading: after.toJson(),
        );
      }
      if (!changed) return;
      await mirrors.commitMirrorOrganization(
        expected: current,
        next: BookmarkMirrorState(
          activity: current.activity,
          epoch: current.epoch + 1,
          owners: owners,
          checkpoints: current.checkpoints,
          subscriptions: current.subscriptions,
          publisherNames: current.publisherNames,
          aliases: current.aliases,
          forgotten: current.forgotten,
        ),
      );
    });
  }

  Future<void> _updateReading(
    String localId,
    SyncGroupReadingState Function(SyncGroupReadingState) change,
  ) => _runScope(() async {
    final current = await mirrors.readMirrorState();
    final owner = current.owners[localId];
    if (owner == null) return;
    final before = SyncGroupReadingState.fromJson(owner.reading);
    final reading = change(before);
    if (identical(reading, before) ||
        const DeepCollectionEquality().equals(
          reading.toJson(),
          before.toJson(),
        )) {
      return;
    }
    final owners = {
      ...current.owners,
      localId: BookmarkMirrorOwner(
        publisher: owner.publisher,
        source: owner.source,
        revision: owner.revision,
        payloadDigest: owner.payloadDigest,
        descriptorDigest: owner.descriptorDigest,
        groupDigest: owner.groupDigest,
        parentSource: owner.parentSource,
        position: owner.position,
        retired: owner.retired,
        reading: reading.toJson(),
      ),
    };
    await mirrors.commitMirrorOrganization(
      expected: current,
      next: BookmarkMirrorState(
        activity: current.activity,
        epoch: current.epoch + 1,
        owners: owners,
        checkpoints: current.checkpoints,
        subscriptions: current.subscriptions,
        publisherNames: current.publisherNames,
        aliases: current.aliases,
        forgotten: current.forgotten,
      ),
    );
  });
}

final class SyncRevisionUnavailable implements Exception {
  const SyncRevisionUnavailable();
}
