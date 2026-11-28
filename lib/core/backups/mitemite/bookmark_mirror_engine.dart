import 'dart:convert';
import 'dart:developer' as developer;

import 'package:sqlite3/sqlite3.dart';

import '../../../foundation/cooperative_work.dart';
import '../../../foundation/filesystem.dart';
import '../../bookmarks/src/data/hive/unified_bookmark_repository.dart';
import '../../bookmarks/src/data/stored_bookmark_codec.dart';
import '../../bookmarks/src/data/bookmark_id_allocator.dart';
import '../export_import/package/bookmark_transfer_format.dart';
import '../export_import/package/export_package_exception.dart';
import 'activity_log.dart';
import 'receive_units.dart';

import 'package:collection/collection.dart';

import 'bookmark_package.dart';
import 'bookmark_buckets.dart';
import '../sources/bookmark_backup_data.dart';

import 'package:uuid/uuid.dart';

import '../../bookmarks/src/types/bookmark.dart';
import '../../bookmarks/src/types/bookmark_group.dart';
import '../../bookmarks/src/types/bookmark_group_repository.dart';
import '../../bookmarks/src/types/bookmark_group_tree.dart';
import '../../bookmarks/src/types/bookmark_mirror_state.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../bookmarks/src/types/unified_bookmark_store.dart';
import '../export_import/import/import_progress.dart';
import 'bookmark_scope.dart';
import 'bookmark_subscription_import.dart';
import 'catalog.dart';
import 'catalog_gate.dart';
import 'protocol.dart';
import 'seen_state.dart';
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
    this.maxStagedBytes = bookmarkTransferExpandedBytes,
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
  final int maxStagedBytes;
  final void Function()? ensureCurrent;
  final UnifiedBookmarkStore store;
  final BookmarkGroupRepository groups;
  final SyncCatalogGate gate;
  final SyncReceivePreparation preparation;
  final DateTime Function() now;
  final String Function() newId;
  BookmarkMirrorStore get mirrors => store as BookmarkMirrorStore;

  String? _chunkCache(String publisher, [String? source]) {
    if (store case final BookmarkHiveRepository repo) {
      if (repo.bookmarkPublicationIndexPath case final path?) {
        final parent = '$path.received/${syncUuid(publisher)}';
        return source == null ? parent : '$parent/${syncUuid(source)}';
      }
    }
    return null;
  }

  Future<void> _removeChunkCache(String publisher, [String? source]) async {
    final path = _chunkCache(publisher, source);
    if (path == null) return;
    await _discardScratch(() async {
      if (await preparation.fs.directoryExists(path)) {
        await preparation.fs.deleteDirectory(path, recursive: true);
      }
    });
  }

  Future<T> _runScope<T>(Future<T> Function() operation) =>
      store.runReadWriteScope(() {
        ensureCurrent?.call();
        return operation();
      });

  Future<void> receive({
    required VerifiedSyncCatalog ticket,
    required List<int> publisherKey,
    Set<String>? directRoots,
    BookmarkSubscriptionImport? transfer,
  }) async {
    ensureCurrent?.call();
    transfer?.checkCancelled();
    if (syncDigest(publisherKey) != ticket.fingerprint) {
      throw const FormatException('Publisher key does not match catalog');
    }
    final initial = await mirrors.readMirrorState();
    final owned = initial.owners.values
        .where((owner) => owner.publisher == ticket.publisher)
        .toList();
    final roots = <String>{
      ...?initial.subscriptions[ticket.publisher],
      ...?directRoots,
    };
    if (roots.length == 1 &&
        initial.checkpoints.values
            .where((checkpoint) => checkpoint.publisher == ticket.publisher)
            .every((checkpoint) => !checkpoint.retired)) {
      final prior = BookmarkSyncScope(
        publisher: ticket.publisher,
        nodes: [
          for (final owner in owned)
            SyncBookmarkNode(
              source: owner.source,
              parent: owner.parentSource,
              position: owner.position,
            ),
        ],
        directRoots: {
          if (owned.any((owner) => roots.contains(owner.source))) roots.single,
        },
      );
      if (prior.covered.length == owned.length) {
        return _receiveUnit(
          ticket: ticket,
          publisherKey: publisherKey,
          directRoots: directRoots,
          transfer: transfer,
        );
      }
    }
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
          owner.source: SyncGroupSeenState.fromJson(owner.reading).members,
      },
      checkpoints: {
        for (final owner in initial.checkpoints.values)
          if (owner.publisher == ticket.publisher) owner.source,
      },
    );
    if (units.length <= 1) {
      return _receiveUnit(
        ticket: ticket,
        publisherKey: publisherKey,
        directRoots: directRoots,
        transfer: transfer,
      );
    }
    final failures = <String, Object>{};
    final sourceUnits = {
      for (final unit in units)
        for (final source in unit) source: unit,
    };
    final pending = [for (final unit in units) Set<String>.of(unit)];
    final requested = transfer?.collection.source;
    if (requested != null) {
      final index = pending.indexWhere((unit) => unit.contains(requested));
      if (index > 0) pending.insert(0, pending.removeAt(index));
    }
    while (pending.isNotEmpty) {
      final unit = pending.removeAt(0);
      try {
        await _receiveUnit(
          ticket: ticket,
          publisherKey: publisherKey,
          directRoots: directRoots?.intersection(unit),
          sourceUnit: unit,
          transfer: requested != null && unit.contains(requested)
              ? transfer
              : null,
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
      } on BookmarkSubscriptionCancelled {
        rethrow;
      } catch (error) {
        final root = roots.where(unit.contains).toList()..sort();
        failures[root.firstOrNull ?? unit.first] = error;
      }
    }
    if (failures.isNotEmpty) {
      throw SyncPartialReceiveFailure('bookmarks', failures);
    }
  }

  Future<void> _receiveUnit({
    required VerifiedSyncCatalog ticket,
    required List<int> publisherKey,
    Set<String>? directRoots,
    Set<String>? sourceUnit,
    BookmarkSubscriptionImport? transfer,
  }) async {
    void checkCurrent() {
      ensureCurrent?.call();
      transfer?.checkCancelled();
    }

    checkCurrent();
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
      if (entry == null && !catalog.completeSnapshot) {
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
          if (entries[root]?.state == SyncPublicationState.active) root,
      },
    );
    final withdrawnRoots = {
      for (final root in unitRoots)
        if (entries[root]?.state != SyncPublicationState.active) root,
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
      if (!catalog.completeSnapshot &&
          entry == null &&
          !lostThroughWithdrawal(prior.value.source)) {
        // Missing metadata never carries signed deletion authority.
        throw const SyncConflict();
      }
    }
    final purgedSources = {
      if (catalog.completeSnapshot)
        for (final checkpoint in initial.checkpoints.values)
          if (checkpoint.publisher == ticket.publisher &&
              (sourceUnit == null || sourceUnit.contains(checkpoint.source)) &&
              !entries.containsKey(checkpoint.source))
            checkpoint.sourceKey,
    };
    final retired = <String, BookmarkMirrorOwner>{};
    for (final entry in entries.values) {
      if (sourceUnit != null && !sourceUnit.contains(entry.id.source)) continue;
      if (entry.state == SyncPublicationState.active) continue;
      final prior =
          initial.checkpoints['${ticket.publisher}/${entry.id.source}'];
      if (prior == null) continue;
      final revision = entry.revision;
      if (revision != null) {
        if (!ValidatedSyncBookmarkPackage.supportsSchema(revision.schema)) {
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
    final prepared = <String, StagedSyncBookmarkRevision>{};
    _SyncBookmarkWrites? writePlan;
    var stagedBytes = 0;
    var advertisedBytes = 0;
    try {
      transfer?.setGroupsToCheck(scope.covered);
      for (final source in scope.covered) {
        final entry = entries[source]!;
        final before =
            owned[source]?.value ??
            initial.checkpoints['${ticket.publisher}/$source'];
        final revision = entry.revision!;
        if (!ValidatedSyncBookmarkPackage.supportsSchema(revision.schema)) {
          throw const SyncUpdateRequired();
        }
        final descriptorDigest = syncDigest(syncJsonBytes(revision.toJson()));
        if (before != null) {
          _checkRevision(before, revision);
          if (before.retired && revision.revision <= before.revision) {
            throw const SyncReplayRejected();
          }
        }
        if (owned.containsKey(source) &&
            before?.revision == revision.revision &&
            before?.payloadDigest == revision.sha256 &&
            before?.descriptorDigest == descriptorDigest) {
          transfer?.groupChecked(source);
          continue;
        }
        advertisedBytes += revision.length;
        if (advertisedBytes > maxStagedBytes) {
          throw const ExportPackageLimitException(
            'Bookmark sync batch exceeds staging limit',
          );
        }
        final priorManifest = owned.containsKey(source)
            ? before?.bookmarkBucketManifest
            : null;
        final value = await preparation.stageBookmark(
          catalog: ticket,
          collection: entry.id,
          publisherKey: publisherKey,
          maxStagedBytes: maxStagedBytes - stagedBytes,
          previousManifest:
              priorManifest != null &&
                  syncDigest(utf8.encode(priorManifest)) ==
                      before!.payloadDigest
              ? priorManifest
              : null,
          privateChunkCache: _chunkCache(ticket.publisher, source),
          ensureCurrent: checkCurrent,
          progress: transfer?.progress,
        );
        if (value == null) throw const SyncRevisionUnavailable();
        prepared[source] = value;
        stagedBytes += value.stagedBytes;
        if (stagedBytes > maxStagedBytes) {
          throw const ExportPackageLimitException(
            'Bookmark sync batch exceeds staging limit',
          );
        }
        transfer?.groupChecked(source);
      }
      final recordCount = prepared.values.fold<int>(
        0,
        (sum, revision) => sum + revision.recordCount,
      );
      checkCurrent();
      transfer?.progress.show(
        ImportProgressPhase.preparing,
        total: recordCount,
      );
      var planned = 0;
      final writes = writePlan =
          recordCount >= 4096 || stagedBytes >= 8 * 1024 * 1024
          ? await _SyncBookmarkWrites.stage(
              preparation.fs,
              preparation.codec.records,
            )
          : _SyncBookmarkWrites();
      await gate.withCurrentCatalog(
        ticket,
        () => _runScope(() async {
          checkCurrent();
          final current = await mirrors.readMirrorState();
          if (current.epoch != initial.epoch) throw const SyncConflict();
          final allGroups = {
            for (final group in await groups.getGroups()) group.id: group,
          };
          final nextOwners = Map<String, BookmarkMirrorOwner>.of(
            current.owners,
          );
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
          final known = <Object, int>{};
          final work = CooperativeWork();
          final batchIds = recordCount >= 256;
          var reserved = const <int>[];
          var nextReserved = 0;
          Future<int> reserveId() async {
            if (nextReserved == reserved.length) {
              try {
                reserved = await store.reserveIds(batchIds ? 256 : 1);
              } on BookmarkIdExhaustedException {
                reserved = await store.reserveIds(1);
              }
              nextReserved = 0;
            }
            return reserved[nextReserved++];
          }

          final updated = <BookmarkGroup>[];
          final touched = <BookmarkGroup>[];
          final contentOnly = <String>{};
          final membershipPatches = <String, BookmarkMirrorMembershipPatch>{};
          final possiblyRemoved = <int>{
            for (final id in removeGroups) ...?allGroups[id]?.bookmarkIds,
          };
          final at = now().toUtc();
          for (final source in scope.covered) {
            final entry = entries[source]!;
            final id = localIds[source]!;
            final oldGroup = allGroups[id];
            final oldOwner = current.owners[id];
            final payload = prepared[source];
            if (payload == null &&
                oldGroup != null &&
                oldOwner != null &&
                oldGroup.name == entry.name &&
                oldGroup.position == entry.position &&
                oldGroup.parentGroupId == localIds[entry.parent] &&
                oldOwner.parentSource == entry.parent) {
              continue;
            }
            final members = <int>{};
            final portableMembers = <String>{};
            final dates = <int, DateTime>{};
            final replacedIds = <int>{};
            final replacedKeys = <String>{};
            final memberBuckets = <int, int>{};
            if (payload != null) {
              if (payload.partialBuckets) {
                if (oldGroup == null || oldOwner == null) {
                  throw const SyncConflict();
                }
                await payload.visitReplacedMembers((record) async {
                  final identity = bookmarkContentIdentity(record);
                  if (identity == null) throw const SyncConflict();
                  final saved = await store.lookupContent(
                    identity,
                    engine: bookmarkEngine(record),
                  );
                  if (saved == null ||
                      !oldGroup.bookmarkIds.contains(saved.id) ||
                      !replacedIds.add(saved.id)) {
                    throw const SyncConflict();
                  }
                  final key = syncBookmarkMemberKey(record);
                  replacedKeys.add(key);
                  memberBuckets[saved.id] = syncBookmarkBucket(
                    key,
                    payload.manifest!.bucketCount,
                  );
                });
              }
              await payload.visitRecords((incoming, addedAt) async {
                final candidate = store.normalizeRecord(
                  bookmarkWithId(incoming, 0),
                );
                final identity =
                    bookmarkContentIdentity(candidate) ??
                    (throw const SyncConflict());
                var saved =
                    writes.read(known[identity]) ??
                    await store.lookupContent(
                      identity,
                      engine: bookmarkEngine(candidate),
                    );
                if (saved == null) {
                  final local = await reserveId();
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
                  final memberships = different
                      ? allGroups.values.where(
                          (group) => group.bookmarkIds.contains(saved!.id),
                        )
                      : const <BookmarkGroup>[];
                  final local = memberships.any(
                    (group) => !current.isReceived(group.id),
                  );
                  final foreign = memberships.any(
                    (group) =>
                        current.owners[group.id]?.publisher != ticket.publisher,
                  );
                  if (different && !local && foreign) {
                    throw const SyncConflict();
                  }
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
                    writes.add(normalized);
                    saved = normalized;
                  }
                }
                if (writes.ids.contains(saved.id)) known[identity] = saved.id;
                members.add(saved.id);
                final memberKey = syncBookmarkMemberKey(saved);
                portableMembers.add(memberKey);
                if (payload.partialBuckets) {
                  memberBuckets[saved.id] = syncBookmarkBucket(
                    memberKey,
                    payload.manifest!.bucketCount,
                  );
                }
                dates[saved.id] = payload.manifest != null
                    ? addedAt ?? (throw const SyncConflict())
                    : oldGroup?.addedAt[saved.id] ?? addedAt ?? at;
                if (transfer != null) {
                  transfer.progress.show(
                    ImportProgressPhase.preparing,
                    completed: ++planned,
                    total: recordCount,
                  );
                }
                if (work.checkpoint() case final pause?) {
                  await pause;
                  checkCurrent();
                }
              }, ensureCurrent: checkCurrent);
              if (payload.partialBuckets) {
                final old = oldGroup!;
                final owner = oldOwner!;
                final sameEdges =
                    const SetEquality<int>().equals(replacedIds, members) &&
                    dates.entries.every(
                      (change) => old.addedAt[change.key] == change.value,
                    );
                final samePlacement =
                    old.name == entry.name &&
                    old.position == entry.position &&
                    old.parentGroupId == localIds[entry.parent] &&
                    owner.parentSource == entry.parent;
                if (sameEdges && samePlacement) {
                  final head = entry.revision!;
                  nextOwners[id] = BookmarkMirrorOwner.advanceBucketHead(
                    owner,
                    revision: head.revision,
                    descriptorDigest: syncDigest(syncJsonBytes(head.toJson())),
                    payloadDigest: head.sha256,
                    bookmarkBucketManifest: canonicalSyncJson(
                      payload.manifest!.toJson(),
                    ),
                  );
                  if (members.any(writes.ids.contains)) contentOnly.add(source);
                  continue;
                }
                if (samePlacement) {
                  final edits = <int, Map<int, DateTime?>>{};
                  for (final id in {...replacedIds, ...members}) {
                    if (old.addedAt[id] != dates[id]) {
                      (edits[memberBuckets[id]!] ??= {})[id] = dates[id];
                    }
                  }
                  if (edits.isNotEmpty) {
                    membershipPatches[id] = BookmarkMirrorMembershipPatch(
                      edits,
                    );
                  }
                }
                possiblyRemoved.addAll(replacedIds.difference(members));
                members.addAll(old.bookmarkIds.difference(replacedIds));
                dates.addEntries(
                  old.addedAt.entries.where(
                    (entry) => !replacedIds.contains(entry.key),
                  ),
                );
                portableMembers.addAll(
                  SyncGroupSeenState.fromJson(owner.reading).members
                      .difference(replacedKeys),
                );
              } else if (oldGroup != null) {
                possiblyRemoved.addAll(
                  oldGroup.bookmarkIds.difference(members),
                );
              }
              possiblyRemoved.removeAll(members);
            } else {
              if (oldGroup == null || oldOwner == null) {
                throw const SyncConflict();
              }
              members.addAll(oldGroup.bookmarkIds);
              dates.addAll(oldGroup.addedAt);
              portableMembers.addAll(
                SyncGroupSeenState.fromJson(oldOwner.reading).members,
              );
            }
            final sameOrganization =
                oldGroup != null &&
                oldGroup.name == entry.name &&
                oldGroup.position == entry.position &&
                oldGroup.parentGroupId == localIds[entry.parent] &&
                const SetEquality<int>().equals(
                  oldGroup.bookmarkIds,
                  members,
                ) &&
                const MapEquality<int, DateTime>().equals(
                  oldGroup.addedAt,
                  dates,
                );
            final target = sameOrganization
                ? oldGroup
                : BookmarkGroup(
                    id: id,
                    name: entry.name,
                    bookmarkIds: members,
                    addedAt: dates,
                    parentGroupId: localIds[entry.parent],
                    position: entry.position,
                  );
            if (!sameOrganization && !membershipPatches.containsKey(id)) {
              updated.add(target);
            }
            touched.add(target);
            final reading =
                (oldOwner == null
                        ? SyncGroupSeenState.empty(entry.id)
                        : SyncGroupSeenState.fromJson(oldOwner.reading))
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
              bookmarkBucketManifest: payload == null
                  ? oldOwner?.bookmarkBucketManifest
                  : payload.manifest == null
                  ? null
                  : canonicalSyncJson(payload.manifest!.toJson()),
              groupDigest: sameOrganization && oldOwner != null
                  ? oldOwner.groupDigest
                  : bookmarkMirrorGroupDigest(target),
              reading: reading.toJson(),
            );
          }
          removeGroups.forEach(nextOwners.remove);
          final desiredGroups = {
            for (final entry in allGroups.entries)
              if (!removeGroups.contains(entry.key)) entry.key: entry.value,
            for (final group in touched) group.id: group,
          };
          final removedMembers = possiblyRemoved
              .where(
                (id) => !desiredGroups.values.any(
                  (group) => group.bookmarkIds.contains(id),
                ),
              )
              .toSet();
          final changes = <SyncEvent>[
            for (final source in contentOnly)
              SyncEvent(
                kind: SyncEventKind.received,
                at: at,
                publisher: ticket.publisher,
                source: source,
              ),
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
          final writtenIds = writes.ids;
          final observed = <String, Set<String>>{};
          bool alreadyCovered(String source) {
            final previousRoots =
                current.subscriptions[ticket.publisher] ?? const <String>{};
            final visited = <String>{};
            String? cursor = source;
            while (cursor != null && visited.add(cursor)) {
              final entry = entries[cursor];
              if (entry == null || entry.state != SyncPublicationState.active) {
                return false;
              }
              if (previousRoots.contains(cursor)) return true;
              cursor = entry.parent;
            }
            return false;
          }

          for (final group in touched) {
            final owner = nextOwners[group.id]!;
            final old = current.owners[group.id];
            final members = SyncGroupSeenState.fromJson(owner.reading).members;
            final previous = old == null
                ? const <String>{}
                : SyncGroupSeenState.fromJson(old.reading).members;
            final checkpoint = current.checkpoints[owner.sourceKey];
            final historical = checkpoint == null
                ? null
                : SyncGroupSeenState.fromJson(checkpoint.reading);
            final known = {
              ...?current.activity.notificationKnown[owner.sourceKey],
              ...previous,
              ...?historical?.members,
              ...?historical?.seenMembers,
            };
            observed[owner.sourceKey] = {...known, ...members};
            if (old != null &&
                old.groupDigest == owner.groupDigest &&
                old.parentSource == owner.parentSource &&
                !group.bookmarkIds.any(writtenIds.contains)) {
              continue;
            }
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
                removed: SyncGroupSeenState.fromJson(owner.reading)
                    .members
                    .length,
              ),
            );
          }
          final next = BookmarkMirrorState(
            activity: current.activity
                .append(changes, observedMembers: observed)
                .withoutSources(purgedSources),
            epoch: current.epoch + 1,
            owners: nextOwners,
            checkpoints: {...current.checkpoints, ...retired}
              ..removeWhere((key, _) => purgedSources.contains(key)),
            subscriptions: {...current.subscriptions, ticket.publisher: roots},
            publisherNames: {
              ...current.publisherNames,
              ticket.publisher: catalog.name,
            },
            aliases: current.aliases,
            forgotten: current.forgotten,
          );
          if (prepared.isEmpty &&
              writes.ids.isEmpty &&
              const DeepCollectionEquality().equals(
                current.toJson()..remove('epoch'),
                next.toJson()..remove('epoch'),
              ) &&
              updated.every((group) => allGroups[group.id] == group)) {
            return;
          }
          await withBookmarkCommitGuard(
            () => mirrors.commitMirrorOrganization(
              expected: current,
              next: next,
              records: writes.records,
              streamRecords: writes.isStaged,
              groups: updated,
              removeGroupIds: removeGroups,
              purgedSources: purgedSources,
              removeIds: removedMembers,
              membershipPatches: membershipPatches,
            ),
            () {
              checkCurrent();
              transfer?.beginSaving();
            },
          );
        }),
      );
      for (final source in owned.keys.where(
        (id) => !scope.covered.contains(id),
      )) {
        await _removeChunkCache(ticket.publisher, source);
      }
      for (final entry in prepared.entries) {
        if (entry.value.manifest != null) {
          await _discardScratch(entry.value.pruneCommittedCache);
        } else if (owned[entry.key]?.value.bookmarkBucketManifest != null) {
          await _removeChunkCache(ticket.publisher, entry.key);
        }
      }
    } catch (_) {
      transfer?.checkCancelled();
      rethrow;
    } finally {
      await Future.wait([
        if (writePlan != null) _discardScratch(writePlan.dispose),
        for (final value in prepared.values) _discardScratch(value.dispose),
      ]);
    }
  }

  Future<void> _discardScratch(Future<void> Function() dispose) async {
    try {
      await dispose();
    } on Exception {
      developer.log('Unable to clean up Bookmark receive scratch files');
    }
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
      if (old.parentGroupId == parent) continue;
      final group = old.copyWith(home: true).copyWith(parentGroupId: parent);
      changed.add(group);
      owners[id] = BookmarkMirrorOwner(
        publisher: owner.publisher,
        source: owner.source,
        revision: owner.revision,
        payloadDigest: owner.payloadDigest,
        descriptorDigest: owner.descriptorDigest,
        bookmarkBucketManifest: owner.bookmarkBucketManifest,
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
    final purgedSources = {
      if (forget)
        for (final checkpoint in current.checkpoints.values)
          if (checkpoint.publisher == publisher) checkpoint.sourceKey,
    };
    await mirrors.commitMirrorOrganization(
      expected: current,
      next: BookmarkMirrorState(
        activity: current.activity
            .append([
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
            ])
            .withoutSources(purgedSources),
        epoch: current.epoch + 1,
        owners: owners,
        checkpoints: {...current.checkpoints}
          ..removeWhere((key, _) => purgedSources.contains(key)),
        subscriptions: subscriptions,
        publisherNames: names,
        aliases: aliases,
        forgotten: forget
            ? {...current.forgotten, publisher}
            : current.forgotten,
      ),
      groups: changed,
      removeGroupIds: remove,
      purgedSources: purgedSources,
      removeIds: orphaned,
    );
    if (forget) {
      await _removeChunkCache(publisher);
    } else {
      for (final id in remove) {
        await _removeChunkCache(publisher, current.owners[id]!.source);
      }
    }
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
    if (const MapEquality<String, String>().equals(current.aliases, aliases)) {
      return;
    }
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
        cursor <= current.activity.notificationCursor) {
      return;
    }
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
  Future<void> markSeen(String localId, Set<String> identities) =>
      _updateReading(localId, (state) => state.markSeen(identities));
  Future<void> markSeenTargets(Iterable<BookmarkSeenTarget> targets) {
    final captured = List<BookmarkSeenTarget>.unmodifiable(
      targets.expand((t) => t.allTargets),
    );
    return _runScope(() async {
      final current = await mirrors.readMirrorState();
      final resolver = BookmarkSeenTargetResolver(current);
      final selected = <String, Set<String>>{};
      final work = CooperativeWork();
      for (final target in captured) {
        if (resolver.contains(target)) {
          selected.putIfAbsent(target.groupId, () => {}).add(target.member);
        }
        if (work.checkpoint() case final pause?) {
          await pause;
          ensureCurrent?.call();
        }
      }
      final owners = Map<String, BookmarkMirrorOwner>.of(current.owners);
      var changed = false;
      for (final entry in selected.entries) {
        final before = resolver.forGroup(entry.key)!;
        final after = before.markSeen(entry.value);
        if (identical(before, after)) continue;
        changed = true;
        owners[entry.key] = owners[entry.key]!.withSeenState(after.toJson());
      }
      if (!changed) return;
      await withBookmarkCommitGuard(
        () => mirrors.commitMirrorOrganization(
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
        ),
        ensureCurrent,
      );
    });
  }

  Future<void> _updateReading(
    String localId,
    SyncGroupSeenState Function(SyncGroupSeenState) change,
  ) => _runScope(() async {
    final current = await mirrors.readMirrorState();
    final owner = current.owners[localId];
    if (owner == null) return;
    final before = SyncGroupSeenState.fromJson(owner.reading);
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
      localId: owner.withSeenState(reading.toJson()),
    };
    await withBookmarkCommitGuard(
      () => mirrors.commitMirrorOrganization(
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
      ),
      ensureCurrent,
    );
  });
}

final class SyncRevisionUnavailable implements Exception {
  const SyncRevisionUnavailable();
}

/// The pending merged writes must be addressable by local ID because multiple
/// revisions can carry the same content with different observations.
final class _SyncBookmarkWrites {
  _SyncBookmarkWrites() : _disk = null;
  _SyncBookmarkWrites._(this._disk);

  static Future<_SyncBookmarkWrites> stage(
    AppFileSystem fs,
    StoredBookmarkCodec codec,
  ) async {
    final directory = await fs.createTempDirectory(
      'boorusama_sync_write_plan_',
    );
    try {
      final db = sqlite3.open('$directory/writes.sqlite');
      try {
        db.execute('PRAGMA journal_mode = OFF');
        db.execute('PRAGMA cache_size = -2048');
        db.execute(
          'CREATE TABLE writes (id INTEGER PRIMARY KEY, wire TEXT NOT NULL)',
        );
        db.execute('BEGIN');
        return _SyncBookmarkWrites._((
          fs: fs,
          directory: directory,
          db: db,
          codec: codec,
          read: db.prepare('SELECT wire FROM writes WHERE id = ?'),
          upsert: db.prepare('INSERT OR REPLACE INTO writes VALUES (?, ?)'),
        ));
      } catch (_) {
        db.close();
        rethrow;
      }
    } catch (_) {
      await fs.deleteDirectory(directory, recursive: true);
      rethrow;
    }
  }

  final ({
    AppFileSystem fs,
    String directory,
    Database db,
    StoredBookmarkCodec codec,
    PreparedStatement read,
    PreparedStatement upsert,
  })?
  _disk;
  final _memory = <int, Bookmark>{};
  final ids = <int>{};

  bool get isStaged => _disk != null;

  void add(Bookmark record) {
    if (_disk case final disk?) {
      disk.upsert.execute([record.id, jsonEncode(disk.codec.encode(record))]);
    } else {
      _memory[record.id] = record;
    }
    ids.add(record.id);
  }

  Bookmark? read(int? id) {
    if (id == null) return null;
    if (_disk case final disk?) {
      final rows = disk.read.select([id]);
      return rows.isEmpty
          ? null
          : disk.codec.decode(jsonDecode(rows.single['wire'] as String));
    }
    return _memory[id];
  }

  Iterable<Bookmark> get records sync* {
    if (_disk case final disk?) {
      final statement = disk.db.prepare('SELECT wire FROM writes ORDER BY id');
      try {
        final cursor = statement.selectCursor();
        while (cursor.moveNext()) {
          yield disk.codec.decode(jsonDecode(cursor.current['wire'] as String));
        }
      } finally {
        statement.close();
      }
      return;
    }
    yield* _memory.values;
  }

  Future<void> dispose() async {
    if (_disk case final disk?) {
      disk.upsert.close();
      disk.read.close();
      disk.db.close();
      await disk.fs.deleteDirectory(disk.directory, recursive: true);
    }
  }
}
