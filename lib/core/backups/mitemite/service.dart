import 'retention.dart';
import 'collection_aliases.dart';
import 'reading_state.dart';
import 'failure.dart';
import 'receive_units.dart';
import 'identity_file.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../foundation/data_mutation_coordinator.dart';
import '../../../foundation/filesystem.dart';
import '../../bookmarks/src/types/bookmark_group.dart';
import '../../bookmarks/src/types/bookmark.dart';
import '../../bookmarks/src/types/bookmark_group_repository.dart';
import '../../bookmarks/src/types/bookmark_group_tree.dart';
import '../../bookmarks/src/types/bookmark_mirror_state.dart';
import '../../bookmarks/src/types/unified_bookmark_store.dart';
import '../../cache/misc_data_store.dart';
import '../../content/anonymous_source_policy.dart';
import '../../search/following_topics/src/types/following_mirror_state.dart';
import '../sources/search_backup_profile.dart';
import '../sources/bookmark_backup_codec.dart';
import '../sources/bookmark_backup_data.dart';
import 'bookmark_mirror_engine.dart';
import 'bookmark_package.dart';
import 'catalog.dart';
import 'catalog_gate.dart';
import 'local_events.dart';
import 'protocol.dart';
import 'publication.dart';
import 'receive_preparation.dart';
import 'revision_transport.dart';
import 'storage.dart';
import 'following_mirror_engine.dart';
import 'following_package.dart';
import 'following_publication.dart';

part 'service_following.dart';
part 'service_aliases.dart';
part 'service_maintenance.dart';

enum SyncTrigger { manual, poll, localChange, watcher, startup, resume, audit }

enum SyncDomain { bookmarks, following }

/// Untrusted discovery never grants approval or applies a package.
final class DiscoveredSyncDevice {
  const DiscoveredSyncDevice(this.id, this.key, [this.catalog]);
  final String id;
  final List<int> key;
  final SyncCatalog? catalog;
  String get name => catalog?.name ?? id;
  String get fingerprint => syncDigest(key);
}

typedef SyncStorageFactory = Future<MiteMiteStorage> Function(
  String location,
);

/// Coordinates real repositories, immutable packages and the shared journal.
/// Transport relocation changes only the location; identity/trust/counters stay
/// in installation-local storage. No missing advertisement authorizes removal.
final class MiteMiteService extends ChangeNotifier {
  MiteMiteService({
    required this.preferences,
    required this.store,
    required this.groups,
    required this.fs,
    required this.codec,
    required this.storageFor,
    required this.identity,
    required this.mutations,
    this.onApplied,
    this.onDomainsApplied,
    this.followingStore,
    this.profiles,
    this.anonymousPolicy = _defaultAnonymousPolicy,
    DateTime Function()? now,
    Duration Function()? elapsed,
  }) : now = now ?? DateTime.now {
    _elapsed = elapsed ?? () => _clock.elapsed;
    _foregroundSince = _elapsed();
    if (store is! BookmarkMirrorStore ||
        !identical((store as BookmarkMirrorStore).coordinator, mutations)) {
      throw ArgumentError(
        'Sync requires the real coordinated mirror repository',
      );
    }
    lastSync = events.lastAttempt;
    lastSuccess = events.lastSuccess;
    final raw = preferences.get(_settingsKey);
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != 1) {
        throw const FormatException('Unsupported Sync settings');
      }
      location = data['location'] as String?;
      name = syncLabel(data['name']);
      publishedRoots = Set.unmodifiable((data['roots'] as List).map(syncUuid));
      publishedFollowingRoots = Set.unmodifiable(
        ((data['followingRoots'] as List?) ?? const []).map(syncUuid),
      );
      discoveryNotifications = data['discoveryNotifications'] as bool? ?? true;
    }
  }
  static const _settingsKey = 'mitemite.v1.settings';
  static const _completedPublicationsKey = 'mitemite.v1.completed_publications';
  final MiscDataStore preferences;
  final UnifiedBookmarkStore store;
  final BookmarkGroupRepository groups;
  final AppFileSystem fs;
  final BookmarkBackupCodec codec;
  final SyncStorageFactory storageFor;
  final SyncSigningIdentity identity;
  final DataMutationCoordinator mutations;
  final Future<void> Function()? onApplied;
  final Future<void> Function(Set<SyncDomain>)? onDomainsApplied;
  final Future<FollowingMirrorStore> Function()? followingStore;
  final List<BackupProfileReference> Function()? profiles;
  final AnonymousSourcePolicy Function() anonymousPolicy;
  static AnonymousSourcePolicy _defaultAnonymousPolicy() =>
      const AnonymousSourcePolicy();
  Future<FollowingMirrorStore>? _following;
  FollowingMirrorSnapshot? receiverFollowing;
  final DateTime Function() now;
  final _operations = DataMutationCoordinator();
  final _preparation = DataMutationCoordinator();
  String? location;
  String name = 'Boorusama';
  bool discoveryNotifications = true;
  Set<String> publishedRoots = const {};
  Set<String> publishedFollowingRoots = const {};
  List<DiscoveredSyncDevice> devices = const [];
  Map<String, Object> deviceFailures = const {};
  // Transport serialization is independent of interactive UI availability.
  bool busy = false;
  final _pendingActions = <String, int>{};
  Future<void>? _updateRequest;
  bool _sourceRequested = true;
  bool _sourcePass = false;
  int _storageGeneration = 0;
  final _verifiedCatalogs =
      <String, ({Uint8List bytes, VerifiedSyncCatalog ticket})>{};
  ({String intent, Uint8List bytes})? _verifiedOwnCatalog;
  final _pendingProjection = <SyncDomain>{};
  late final _collectionAliases = SyncCollectionAliases(preferences);
  bool _aliasesRecovered = false;
  final _repairSources = <String>{};
  Future<void>? _maintenance;
  Future<void> get maintenanceCompletion => _maintenance ?? Future.value();
  bool _auditDue = true;
  bool _foreground = true;
  final _clock = Stopwatch()..start();
  late final Duration Function() _elapsed;
  Duration? _foregroundSince;
  Duration _activeBefore = Duration.zero;
  Duration _nextAudit = const Duration(minutes: 15);

  Future<void>? _reconciliation;
  bool get isReconciling => _updateRequest != null || _reconciliation != null;
  bool get hasPendingActions => _pendingActions.isNotEmpty;
  Set<String> get pendingActionKeys => Set.unmodifiable(_pendingActions.keys);
  bool get folderAccessFailed =>
      [failure, outgoingFailure, ...deviceFailures.values]
          .whereType<Object>()
          .any((error) => syncFailureKind(error) == SyncFailureKind.permission);
  bool isActionPending(String key) => _pendingActions.containsKey(key);

  static String _subscriptionKey(SyncCollectionId collection) =>
      'subscription:${collection.key}';

  bool isSubscriptionPending(SyncCollectionId collection) =>
      isActionPending(_subscriptionKey(collection));

  Future<void> _subscriptionAction(
    String publisher,
    String kind,
    Set<String> roots,
    Future<void> Function(Set<String>) action,
  ) async {
    // Pending rows and the queued write must refer to the same captured roots.
    final captured = Set<String>.unmodifiable(roots);
    await _action(
      'subscription:$kind:$publisher',
      () => action(captured),
      additionalKeys: {
        for (final source in captured)
          _subscriptionKey(
            SyncCollectionId(publisher: publisher, kind: kind, source: source),
          ),
      },
    );
  }

  Future<T> _action<T>(
    String key,
    Future<T> Function() action, {
    bool local = false,
    Set<String> additionalKeys = const {},
  }) async {
    _ensureCurrent();
    final keys = {key, ...additionalKeys};
    for (final pending in keys) {
      _pendingActions.update(pending, (count) => count + 1, ifAbsent: () => 1);
    }
    _notify();
    try {
      return await (local ? mutations.runExclusive(action) : _run(action));
    } finally {
      for (final pending in keys) {
        final remaining = _pendingActions[pending]! - 1;
        if (remaining == 0) {
          _pendingActions.remove(pending);
        } else {
          _pendingActions[pending] = remaining;
        }
      }
      _notify();
    }
  }

  bool applying = false;
  Object? failure;
  Object? outgoingFailure;
  Object? retentionFailure;
  Object? followingFailure;
  Object? reloadFailure;
  Object? activityFailure;
  BookmarkMirrorState? _receiverMirrors;
  BookmarkMirrorState? get receiverMirrors => _receiverMirrors;
  DateTime? lastSync;
  DateTime? lastSuccess;
  ({DateTime attemptedAt, DateTime? completedAt, List<SyncEvent> failures})?
  _pendingOutcome;
  final _pendingActionFailures = <SyncEvent>[];
  final _pendingDiscoveries = <String, SyncDiscovery>{};
  late final events = SyncLocalEvents(
    preferences: preferences,
    mutations: mutations,
    now: now,
  );
  bool _disposed = false;
  bool get configured => location != null;
  SyncCatalogGate get gate =>
      SyncCatalogGate(store: preferences, mutations: mutations);
  BookmarkMirrorStore get mirrors => store as BookmarkMirrorStore;

  Future<void> _save(
    String? nextLocation,
    String nextName,
    Set<String> roots, {
    Set<String>? followingRoots,
    bool? notifications,
  }) => mutations.runExclusive(() async {
    _ensureCurrent();
    final nextFollowingRoots = Set<String>.of(
      followingRoots ?? publishedFollowingRoots,
    );
    final nextNotifications = notifications ?? discoveryNotifications;
    await preferences.put(
      _settingsKey,
      canonicalSyncJson({
        'version': 1,
        'location': nextLocation,
        'name': nextName,
        'discoveryNotifications': nextNotifications,
        'roots': roots.toList()..sort(),
        'followingRoots': nextFollowingRoots.toList()..sort(),
      }),
    );
    // Commit the in-memory settings while still owning the metadata transaction.
    // Local preference changes can then complete during deferred transport I/O.
    if (location != nextLocation) {
      _storageGeneration++;
      _verifiedCatalogs.clear();
      _verifiedOwnCatalog = null;
      _repairSources.clear();
      _auditDue = true;
      _sourceRequested = true;
    }
    location = nextLocation;
    name = nextName;
    publishedRoots = Set.unmodifiable(roots);
    publishedFollowingRoots = Set.unmodifiable(nextFollowingRoots);
    discoveryNotifications = nextNotifications;
  });

  void _ensureCurrent() {
    if (_disposed) throw StateError('Sync service disposed');
  }

  Future<MiteMiteStorage> _open(String location) async {
    _ensureCurrent();
    final storage = await storageFor(location);
    _ensureCurrent();
    return _CurrentStorage(storage, _ensureCurrent);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _run<T>(Future<T> Function() action) =>
      _operations.runExclusive(() async {
        if (_disposed) throw StateError('Sync service disposed');
        busy = true;
        failure = null;
        _notify();
        try {
          await _recoverForgets();
          await _flushActivity();
          try {
            return await action();
          } finally {
            await _flushActivity();
          }
        } catch (error) {
          failure = error;
          if (!_disposed) {
            _pendingActionFailures.addAll(
              _failureEvents(
                error is SyncPublicationPending && outgoingFailure != null
                    ? outgoingFailure!
                    : error,
                sourceKind:
                    error is SyncPublicationPending ||
                        error is SyncOwnIdentityUnavailable
                    ? 'outgoing'
                    : 'transport',
              ),
            );
            if (_pendingActionFailures.length > SyncLocalEvents.historyLimit) {
              _pendingActionFailures.removeRange(
                0,
                _pendingActionFailures.length - SyncLocalEvents.historyLimit,
              );
            }
            await _flushActivity();
          }
          rethrow;
        } finally {
          busy = false;
          _notify();
        }
      });

  Future<void> _flushActivity() async {
    _ensureCurrent();
    if (_pendingForgets().isNotEmpty) return;
    Object? pending;
    Future<void> deliver(Future<void> Function() action) async {
      _ensureCurrent();
      try {
        await action();
      } catch (error) {
        _ensureCurrent();
        pending ??= error;
      }
    }

    await deliver(_flushPublicationActivity);
    final discoveries = [
      ..._pendingDiscoveries.values,
      for (final device in devices)
        SyncDiscovery(device.id, device.fingerprint),
    ];
    await deliver(() async {
      await events.discover(discoveries, lastSync ?? now());
      for (final device in discoveries) _pendingDiscoveries.remove(device.key);
    });
    await deliver(() async {
      final state = await mirrors.readMirrorState();
      await events.consume(
        'bookmarks',
        state.activity,
        forgottenPublishers: state.forgotten,
      );
      if (state.activity.pendingPosts.isNotEmpty) {
        await _applied(
          () => _engine(_OfflineStorage())
              .acknowledgePostNotifications(events.activityCursor('bookmarks')),
          presentation: false,
        );
      }
    });
    if (followingStore != null) {
      await deliver(() async {
        final repository = await _followingRepository();
        final activity = repository is FollowingMirrorActivityReader
            ? await (repository as FollowingMirrorActivityReader)
                  .readMirrorActivity()
            : (await repository.readMirrorSnapshot()).mirrors.activity;
        await events.consume('following_topics', activity);
        if (activity.pendingPosts.isNotEmpty &&
            repository is FollowingNotificationReceiptStore) {
          await _applied(
            () => (repository as FollowingNotificationReceiptStore)
                .acknowledgeMirrorNotifications(
                  events.activityCursor('following_topics'),
                ),
            domains: const {SyncDomain.following},
            presentation: false,
          );
        }
      });
    }
    if (_pendingOutcome case final outcome?) {
      await deliver(() async {
        await events.reconcileFailures(
          outcome.failures,
          attemptedAt: outcome.attemptedAt,
          completedAt: outcome.completedAt,
        );
        _pendingOutcome = null;
      });
    }
    if (_pendingActionFailures.isNotEmpty) {
      final captured = List<SyncEvent>.of(_pendingActionFailures);
      await deliver(() async {
        for (final event in captured) await events.recordFailure(event);
        _pendingActionFailures.removeRange(0, captured.length);
      });
    }
    activityFailure = pending;
  }

  Future<void> retryActivity() => _action('activity', () async {});

  Future<void> _flushPublicationActivity() async {
    final completed = preferences.get(_completedPublicationsKey);
    if (completed == null) {
      await events.reconcilePublications(
        {
          'bookmarks': publishedRoots,
          'following_topics': publishedFollowingRoots,
        },
        now(),
        seedOnly: true,
      );
      return;
    }
    final data = jsonDecode(completed) as Map<String, dynamic>;
    if (data['version'] != 1)
      throw const FormatException('Invalid publication completion receipt');
    final roots = data['roots'] as Map<String, dynamic>;
    await events.reconcilePublications({
      for (final kind in const ['bookmarks', 'following_topics'])
        kind: (roots[kind] as List).map(syncUuid).toSet(),
    }, data['at'] is String ? DateTime.parse(data['at'] as String) : now());
  }

  /// Explicit setup only. Verify the new transport before replacing settings.
  Future<void> configure(String nextLocation, {String? deviceName}) =>
      _action('location', () async {
        final nextName = syncLabel(deviceName ?? name);
        final storage = await _open(nextLocation);
        await storage.list('');
        await writeOwnSyncIdentity(storage, identity);
        await _save(nextLocation, nextName, publishedRoots);
        location = nextLocation;
        name = nextName;
        await _sync(storage, verifyExisting: true);
      });

  Future<void> rename(String nextName) => _action('name', () async {
    final checked = syncLabel(nextName);
    await _save(location, checked, publishedRoots);
    name = checked;
    if (location != null) await _sync(await _open(location!));
  });

  Future<void> setDiscoveryNotifications(bool enabled) =>
      _action('notifications', () async {
        await _save(location, name, publishedRoots, notifications: enabled);
      }, local: true);

  Future<void> publishRoots(Set<String> roots) =>
      _run(() => _setPublishedRoots(roots));

  /// Read the current root set only after admission; two queued contextual
  /// actions cannot overwrite each other's selections with a stale screen set.
  Future<void> publishGroup(String source) =>
      _action('publication:bookmarks:$source', () async {
        final id = syncUuid(source);
        if (publishedRoots.contains(id)) return;
        await _setPublishedRoots({...publishedRoots, id});
      });

  Future<void> stopPublishingGroup(String source) =>
      _action('publication:bookmarks:$source', () async {
        final id = syncUuid(source);
        if (!publishedRoots.contains(id)) return;
        await _setPublishedRoots({...publishedRoots}..remove(id));
      });

  Future<void> _setPublishedRoots(Set<String> roots) async {
    final captured = Set<String>.of(roots.map(syncUuid));
    await store.runReadWriteScope(() async {
      final local = {for (final group in await groups.getGroups()) group.id};
      final ownership = await mirrors.readMirrorState();
      if (!local.containsAll(captured.difference(publishedRoots)) ||
          captured.any(ownership.isReceived)) {
        throw const BookmarkMirrorReadOnly();
      }
      await _save(location, name, captured);
    });
    publishedRoots = Set.unmodifiable(captured);
    await markDirty();
    if (location != null) {
      await _sync(await _open(location!));
      if (outgoingFailure != null) throw const SyncPublicationPending();
    }
  }

  static const _dirtyKey = 'mitemite.v1.dirty_epoch';
  static const _publishedKey = 'mitemite.v1.published_epoch';
  int _epoch(String key) {
    final raw = preferences.get(key);
    if (raw == null) return 0;
    final value = int.tryParse(raw);
    if (value == null || value < 0 || value > miteMiteMaxSequence) {
      throw const FormatException('Invalid local publication epoch');
    }
    return value;
  }

  bool get hasUnpublishedChanges => _epoch(_dirtyKey) > _epoch(_publishedKey);
  Future<void> markDirty() => mutations.runExclusive(() async {
    _ensureCurrent();
    final next = _epoch(_dirtyKey) + 1;
    syncPositiveInteger(next);
    await preferences.put(_dirtyKey, '$next');
  });

  Future<void> acknowledgeDiscoveries(Set<String> keys) => _run(
    () => events.acknowledgeDiscoveries(keys),
  );

  Future<void> setDeviceAlias(String publisher, String? alias) =>
      _action('alias:$publisher', () async {
        await _applied(
          () => _engine(_OfflineStorage()).setAlias(publisher, alias),
        );
      });

  Future<void> synchronize({SyncTrigger trigger = SyncTrigger.manual}) {
    if (const {
      SyncTrigger.startup,
      SyncTrigger.resume,
      SyncTrigger.localChange,
      SyncTrigger.audit,
    }.contains(trigger))
      _sourceRequested = true;
    final active = _updateRequest;
    if (active != null) return active;
    late final Future<void> request;
    request =
        () async {
          do {
            _sourcePass = _sourceRequested;
            _sourceRequested = false;
            await _run(() async {
              if (location == null) return;
              await _sync(await _open(location!), reconcileSource: _sourcePass);
            });
          } while (_sourceRequested && !_disposed);
        }().whenComplete(() {
          if (identical(_updateRequest, request)) _updateRequest = null;
          _notify();
          if (!_disposed)
            unawaited(
              _scheduleMaintenance(force: trigger == SyncTrigger.audit),
            );
        });
    _updateRequest = request;
    _notify();
    return trigger == SyncTrigger.audit
        ? request.then((_) => _scheduleMaintenance(force: true))
        : request;
  }

  SyncBookmarkMirrorEngine _engine(MiteMiteStorage storage) =>
      SyncBookmarkMirrorEngine(
        store: store,
        groups: groups,
        gate: gate,
        preparation: SyncReceivePreparation(
          storage: storage,
          fs: fs,
          codec: codec,
        ),
        now: now,
        ensureCurrent: _ensureCurrent,
      );

  Future<void> _applied(
    Future<void> Function() operation, {
    Set<SyncDomain> domains = const {SyncDomain.bookmarks},
    bool presentation = true,
  }) async {
    _ensureCurrent();
    final before = <SyncDomain, int>{};
    for (final domain in domains) {
      try {
        before[domain] = await _projectionEpoch(domain);
      } catch (_) {
        _aliasesRecovered = false;
        if (presentation) _pendingProjection.add(domain);
      }
    }
    applying = true;
    var completed = false;
    try {
      await operation();
      completed = true;
    } finally {
      try {
        final changed = <SyncDomain>{};
        for (final domain in domains) {
          try {
            final after = await _projectionEpoch(domain);
            if (presentation && after != before[domain]) {
              _pendingProjection.add(domain);
              changed.add(domain);
            }
          } catch (_) {
            _aliasesRecovered = false;
            if (presentation) _pendingProjection.add(domain);
          }
        }
        try {
          if (completed && (changed.isNotEmpty || !_aliasesRecovered)) {
            try {
              await _pruneCollectionAliases(
                changed.isEmpty ? domains : changed,
              );
            } catch (_) {
              _aliasesRecovered = false;
              rethrow;
            }
          }
        } finally {
          await _refreshProjection(domains: const {});
        }
      } finally {
        applying = false;
      }
    }
  }

  Future<int> _projectionEpoch(SyncDomain domain) async {
    if (domain == SyncDomain.bookmarks) {
      final snapshot = await mirrors.readMirrorState();
      if (_receiverMirrors?.epoch != snapshot.epoch)
        _receiverMirrors = snapshot;
      return snapshot.epoch;
    }
    final snapshot = await (await _followingRepository()).readMirrorSnapshot();
    if (receiverFollowing?.structureDigest != snapshot.structureDigest ||
        receiverFollowing?.mirrors.epoch != snapshot.mirrors.epoch)
      receiverFollowing = snapshot;
    return snapshot.mirrors.epoch;
  }

  Future<void> _refreshProjection({
    Set<SyncDomain> domains = const {
      SyncDomain.bookmarks,
      SyncDomain.following,
    },
  }) async {
    _pendingProjection.addAll(
      domains.where(
        (domain) => domain == SyncDomain.bookmarks || followingStore != null,
      ),
    );
    Object? pending;
    for (final domain in Set<SyncDomain>.of(_pendingProjection)) {
      try {
        await _projectionEpoch(domain);
        _ensureCurrent();
        if (onDomainsApplied case final callback?) {
          await callback({domain});
        } else {
          await onApplied?.call();
        }
        _pendingProjection.remove(domain);
      } catch (error) {
        pending ??= error;
      }
    }
    _ensureCurrent();
    reloadFailure = pending;
  }

  Future<void> retryProjection() => _action('projection', () async {
    await _refreshProjection();
    if (reloadFailure case final error?) throw error;
  });

  Future<void> acknowledgeOffers(Set<String> captured) => captured.isEmpty
      ? Future<void>.value()
      : _action('offer-seen', () async {
          final unseen = events.unseenOffers;
          final eligible = <String>{
            for (final key in captured)
              if (unseen[key] case final item?)
                if (gate.approvedKey(item.publisher) case final pinned?)
                  if (syncDigest(pinned) == item.fingerprint) key,
          };
          await events.acknowledgeOffers(eligible);
        });

  Future<void> approve(DiscoveredSyncDevice device) => _action(
    'trust:${device.id}',
    () async {
      final live = devices.where((d) => d.id == device.id).firstOrNull;
      if (live == null || live.fingerprint != device.fingerprint)
        throw const SyncTrustRequired();
      // Persist the current authenticated offer baseline before granting trust.
      // A failed receipt write cannot pin a key then lose its initial baseline.
      if (gate.approvedKey(device.id) == null &&
          (live.catalog == null || live.catalog!.publicationRoots != null)) {
        await events.seedOfferBaseline(
          publisher: device.id,
          fingerprint: device.fingerprint,
          sequence: live.catalog?.sequence ?? 0,
          roots: live.catalog?.publicationRoots ?? const <SyncCollectionId>{},
          replace: true,
        );
      }
      await gate.approvePublisher(publisher: device.id, publicKey: device.key);
      final storage = await _open(location!);
      await _engine(storage).approvePublisher(device.id);
      await _sync(storage);
    },
  );
  Future<void> subscribe(String publisher, Set<String> roots) =>
      _subscriptionAction(publisher, 'bookmarks', roots, (roots) async {
        final storage = await _open(location!);
        final device = devices.singleWhere((device) => device.id == publisher);
        final ticket = await _ticket(storage, device);
        final prior =
            (await mirrors.readMirrorState()).subscriptions[publisher] ??
            const <String>{};
        final additions = roots.difference(prior);
        if (additions.isNotEmpty) {
          final offers = SyncCatalog.fromJson(ticket.content).publicationRoots;
          if (offers == null) throw const SyncUpdateRequired();
          if (additions.any(
            (source) => !offers.contains(
              SyncCollectionId(
                publisher: publisher,
                kind: 'bookmarks',
                source: source,
              ),
            ),
          )) {
            throw const SyncConflict();
          }
        }
        await _receive(storage, device, ticket, roots: roots);
      });
  Future<void> unsubscribe(String publisher, String source) =>
      _subscriptionAction(publisher, 'bookmarks', {source}, (_) async {
        // Management requires no working shared directory.
        await _applied(
          () => _engine(_OfflineStorage()).unsubscribe(publisher, source),
        );
      });
  Future<void> forget(String publisher) =>
      _action('forget:$publisher', () async {
        final id = syncUuid(publisher);
        await mutations.runExclusive(
          () => preferences.put(
            _forgetKey,
            canonicalSyncJson(
              [..._pendingForgets(), id].toSet().toList()..sort(),
            ),
          ),
        );
        await _recoverForgets();
      });
  Future<BookmarkGroup> localCopy(String groupId) => _run(() async {
    late BookmarkGroup copied;
    await _applied(() async {
      copied = await _engine(_OfflineStorage()).createLocalCopy(groupId);
    });

    return copied;
  });
  Future<void> acknowledge(String groupId, int revision) => _run(
    () => _applied(
      () => _engine(_OfflineStorage()).acknowledgeArrival(groupId, revision),
    ),
  );
  Future<void> markRead(String groupId, Set<String> identities) => _run(
    () => _applied(
      () => _engine(_OfflineStorage()).markRead(groupId, identities),
    ),
  );

  Future<void> markReadTargets(Iterable<BookmarkReadTarget> targets) {
    final captured = List<BookmarkReadTarget>.unmodifiable([
      for (final item in targets)
        for (final target in item.allTargets)
          BookmarkReadTarget(
            groupId: target.groupId,
            publisher: target.publisher,
            source: target.source,
            member: target.member,
            scopeGroupId: target.scopeGroupId,
            scopeSource: target.scopeSource,
          ),
    ]);
    return _run(
      () =>
          _applied(() => _engine(_OfflineStorage()).markReadTargets(captured)),
    );
  }

  Future<VerifiedSyncCatalog> _ticket(
    MiteMiteStorage storage,
    DiscoveredSyncDevice device,
  ) async {
    final catalog = device.catalog;
    if (catalog == null) throw const SyncRevisionUnavailable();
    final bytes = await storage.read(
      catalog.path,
      maxBytes: miteMiteMaxMetadataBytes,
    );
    if (bytes == null) throw const SyncRevisionUnavailable();
    return _verifyCatalog(device.id, catalog.sequence, bytes);
  }

  Future<void> _receive(
    MiteMiteStorage storage,
    DiscoveredSyncDevice device,
    VerifiedSyncCatalog ticket, {
    Set<String>? roots,
  }) => _applied(
    () => _engine(storage)
        .receive(ticket: ticket, publisherKey: device.key, directRoots: roots),
  );

  List<SyncEvent> _failureEvents(
    Object error, {
    required String sourceKind,
    String? publisher,
    String? source,
  }) {
    if (error is SyncPartialReceiveFailure)
      return [
        for (final entry in error.failures.entries)
          ..._failureEvents(
            entry.value,
            sourceKind: error.sourceKind,
            publisher: publisher,
            source: entry.key,
          ),
      ];
    String? identity(String? value) {
      if (value == null) return null;
      try {
        return syncUuid(value);
      } catch (_) {
        return null;
      }
    }

    return [
      SyncEvent(
        kind: SyncEventKind.failed,
        at: now(),
        publisher: identity(publisher),
        source: identity(source),
        sourceKind: sourceKind,
        failure: syncFailureKind(error),
      ),
    ];
  }

  Future<void> _sync(
    MiteMiteStorage storage, {
    bool reconcileSource = true,
    bool verifyExisting = false,
  }) {
    late final Future<void> running;
    running =
        _reconcile(
              storage,
              reconcileSource: reconcileSource,
              verifyExisting: verifyExisting,
            )
            .then((_) async {
              if (!_aliasesRecovered) {
                await _pruneCollectionAliases(const {
                  SyncDomain.bookmarks,
                  SyncDomain.following,
                });
                _aliasesRecovered = true;
              }
            })
            .whenComplete(() {
              if (identical(_reconciliation, running)) _reconciliation = null;
              _notify();
            });
    _reconciliation = running;
    _notify();
    return running;
  }

  Future<void> _reconcile(
    MiteMiteStorage storage, {
    required bool reconcileSource,
    required bool verifyExisting,
  }) async {
    final attempt = now().toUtc();
    lastSync = attempt;
    try {
      await events.markAttempt(attempt);
    } catch (error) {
      activityFailure = error;
    }
    final failures = <SyncEvent>[];
    followingFailure = null;
    if (followingStore != null) {
      try {
        await _projectionEpoch(SyncDomain.following);
      } catch (error) {
        followingFailure = error;
        failures.addAll(_failureEvents(error, sourceKind: 'following_topics'));
      }
    }
    final dirty = _epoch(_dirtyKey);
    final retryOutgoing = outgoingFailure != null;
    outgoingFailure = null;
    try {
      await writeOwnSyncIdentity(storage, identity);
      if (reconcileSource ||
          hasUnpublishedChanges ||
          retryOutgoing ||
          _repairSources.isNotEmpty ||
          !await _ownCatalogPresent(storage)) {
        await _publish(storage, verifyExisting: verifyExisting);
      }
      await mutations.runExclusive(() async {
        _ensureCurrent();
        await preferences.put(_publishedKey, '$dirty');
      });
    } catch (error) {
      // A failed outgoing archive must not starve healthy incoming devices.
      outgoingFailure = error;
      failures.addAll(_failureEvents(error, sourceKind: 'outgoing'));
    }
    final found = <DiscoveredSyncDevice>[];
    final errors = <String, Object>{};
    for (final publisher in await storage.list('devices')) {
      if (publisher == identity.id) continue;
      try {
        syncUuid(publisher);
        final bytes = await storage.read(
          'devices/$publisher/identity.json',
          maxBytes: miteMiteMaxMetadataBytes,
        );
        if (bytes == null) continue;
        final document = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        if (document['id'] != publisher ||
            document['protocol'] != miteMiteProtocol) {
          throw const SyncUpdateRequired();
        }
        final key = base64Decode(syncString(document['publicKey']));
        if (key.length != 32) {
          throw const FormatException('Invalid signing key');
        }
        final discovery = SyncDiscovery(publisher, syncDigest(key));
        _pendingDiscoveries[discovery.key] = discovery;
        final approved = gate.approvedKey(publisher);
        if (approved != null && syncDigest(approved) != syncDigest(key)) {
          throw const SyncTrustRequired();
        }
        final numbers = [
          for (final file in await storage.list('devices/$publisher/catalog'))
            if (RegExp(r'^[1-9][0-9]{0,15}\.json$').hasMatch(file))
              int.parse(file.split('.').first),
        ]..sort();
        if (numbers.isEmpty) {
          found.add(DiscoveredSyncDevice(publisher, List.unmodifiable(key)));
          continue;
        }
        final sequence = numbers.last;
        final catalogBytes = await storage.read(
          'devices/$publisher/catalog/$sequence.json',
          maxBytes: miteMiteMaxMetadataBytes,
        );
        if (catalogBytes == null) continue;
        // An approved publisher advances OBSERVED before compatibility checks.
        VerifiedSyncCatalog? verified;
        final content = approved == null
            ? await verifySyncDocument(catalogBytes, key)
            : (verified = await _verifyCatalog(
                publisher,
                sequence,
                catalogBytes,
              )).content;
        final previous = devices
            .where(
              (device) =>
                  device.id == publisher &&
                  device.fingerprint == discovery.fingerprint,
            )
            .firstOrNull;
        final catalog =
            approved != null && previous?.catalog?.sequence == sequence
            ? previous!.catalog!
            : SyncCatalog.fromJson(content);
        if (catalog.publisher != publisher || catalog.sequence != sequence) {
          throw const FormatException('Catalog identity mismatch');
        }
        final device = identical(previous?.catalog, catalog)
            ? previous!
            : DiscoveredSyncDevice(publisher, List.unmodifiable(key), catalog);
        found.add(device);
        if (approved != null) {
          final ticket = verified!;
          if (catalog.publicationRoots case final roots?) {
            try {
              await events.observeOffers(
                publisher: publisher,
                fingerprint: ticket.fingerprint,
                sequence: catalog.sequence,
                roots: roots,
                at: attempt,
              );
            } catch (error) {
              activityFailure = error;
            }
          }
          try {
            final subscriptions =
                (await mirrors.readMirrorState()).subscriptions[publisher];
            if (subscriptions?.isNotEmpty ?? false)
              await _receive(storage, device, ticket);
          } catch (error) {
            errors[publisher] = error;
            failures.addAll(
              _failureEvents(
                error,
                sourceKind: 'bookmarks',
                publisher: publisher,
              ),
            );
          }
          if (followingStore != null) {
            try {
              final following = await (await _followingRepository())
                  .readMirrorSnapshot();
              if (following.mirrors.subscriptions[publisher]?.isNotEmpty ??
                  false) {
                await _receiveFollowing(storage, device, ticket);
              }
            } catch (error) {
              errors[publisher] ??= error;
              failures.addAll(
                _failureEvents(
                  error,
                  sourceKind: 'following_topics',
                  publisher: publisher,
                ),
              );
            }
          }
        }
      } catch (error) {
        errors[publisher] = error;
        failures.addAll(
          _failureEvents(error, sourceKind: 'transport', publisher: publisher),
        );
      }
    }
    if (retentionFailure != null)
      failures.addAll(
        _failureEvents(retentionFailure!, sourceKind: 'retention'),
      );
    final foundIds = found.map((device) => device.id).toSet();
    _verifiedCatalogs.removeWhere(
      (publisher, _) =>
          !foundIds.contains(publisher) || gate.approvedKey(publisher) == null,
    );
    Map<String, Set<String>> bookmarkSubscriptions;
    try {
      bookmarkSubscriptions = (await mirrors.readMirrorState()).subscriptions;
    } catch (error) {
      bookmarkSubscriptions = _receiverMirrors?.subscriptions ?? const {};
      failures.addAll(_failureEvents(error, sourceKind: 'bookmarks'));
      reloadFailure = error;
    }
    final knownErrors = errors.keys.toSet();
    for (final (kind, subscriptions) in [
      ('bookmarks', bookmarkSubscriptions),
      (
        'following_topics',
        receiverFollowing?.mirrors.subscriptions ??
            const <String, Set<String>>{},
      ),
    ]) {
      for (final entry in subscriptions.entries) {
        if (entry.value.isEmpty ||
            foundIds.contains(entry.key) ||
            knownErrors.contains(entry.key))
          continue;
        const error = SyncPublisherUnavailable();
        errors[entry.key] = error;
        for (final source in entry.value)
          failures.addAll(
            _failureEvents(
              error,
              sourceKind: kind,
              publisher: entry.key,
              source: source,
            ),
          );
      }
    }
    if (!listEquals(devices, found)) devices = List.unmodifiable(found);
    deviceFailures = Map.unmodifiable(errors);
    if (outgoingFailure == null &&
        retentionFailure == null &&
        errors.isEmpty &&
        reloadFailure == null &&
        followingFailure == null) {
      lastSuccess = now().toUtc();
    }
    _pendingOutcome = (
      attemptedAt: attempt,
      completedAt:
          failures.isEmpty &&
              reloadFailure == null &&
              followingFailure == null &&
              retentionFailure == null
          ? lastSuccess
          : null,
      failures: failures,
    );
    _notify();
  }

  Future<void> _completePublication(SyncCatalog catalog) =>
      mutations.runExclusive(() async {
        _ensureCurrent();
        final roots = catalog.publicationRoots;
        if (roots == null) throw const SyncUpdateRequired();
        final completed = {
          for (final kind in const ['bookmarks', 'following_topics'])
            kind: [
              for (final root in roots)
                if (root.kind == kind) root.source,
            ]..sort(),
        };
        final previous = preferences.get(_completedPublicationsKey);
        if (previous != null &&
            canonicalSyncJson(
                  (jsonDecode(previous) as Map<String, dynamic>)['roots'],
                ) ==
                canonicalSyncJson(completed))
          return;
        await preferences.put(
          _completedPublicationsKey,
          canonicalSyncJson({
            'version': 1,
            'roots': completed,
            'at': now().toUtc().toIso8601String(),
          }),
        );
      });

  Future<void> _publish(
    MiteMiteStorage storage, {
    bool verifyExisting = false,
  }) async {
    final intent = preferences.get(
      'mitemite.v1.outgoing.${identity.id}.catalog_intent',
    );
    final prior = intent == null
        ? null
        : SyncCatalog.fromJson(
            (jsonDecode(intent) as Map<String, dynamic>)['catalog']
                as Map<String, dynamic>,
          );
    final capturedProfiles = List<BackupProfileReference>.unmodifiable(
      profiles?.call() ?? const [],
    );
    SyncFollowingDefinitions? following;
    if (publishedFollowingRoots.isNotEmpty ||
        (prior?.entries.any((e) => e.id.kind == 'following_topics') ?? false)) {
      following = SyncFollowingDefinitions(
        snapshot: await (await _followingRepository()).readMirrorSnapshot(),
        publisher: identity.id,
        roots: publishedFollowingRoots,
        profiles: capturedProfiles,
      );
    }
    final snapshot = await store.runReadWriteScope(() async {
      final organization = await groups.getGroups();
      final ownership = await mirrors.readMirrorState();
      final local = {
        for (final group in organization)
          if (!ownership.isReceived(group.id)) group.id: group,
      };
      final tree = BookmarkGroupTree(local.values);
      final covered = {
        for (final root in publishedRoots)
          if (local.containsKey(root)) ...tree.subtreeIds(root),
      };
      final ids = {for (final id in covered) ...local[id]!.bookmarkIds};
      final records = <int, Bookmark>{};
      var count = 0;
      for (final id in ids) {
        final record = await store.read(id);
        if (record == null) throw const SyncConflict();
        records[id] = record;
        if (++count % 64 == 0) await Future<void>.delayed(Duration.zero);
      }
      return (
        local: local,
        covered: covered,
        records: records,
        revision: await store.readRevision(),
      );
    });
    final local = snapshot.local;
    final covered = snapshot.covered;
    final generation = _storageGeneration;
    final sourceFollowing = following;
    Future<void> validateSnapshot() async {
      _ensureCurrent();
      if (!listEquals(
        capturedProfiles,
        profiles?.call() ?? const <BackupProfileReference>[],
      ))
        throw const SyncConflict();
      if (sourceFollowing != null &&
          (await (await _followingRepository()).readMirrorSnapshot())
                  .structureDigest !=
              sourceFollowing.snapshot.structureDigest)
        throw const SyncConflict();
      if (generation != _storageGeneration ||
          await store.readRevision() != snapshot.revision) {
        throw const SyncConflict();
      }
    }

    final writer = SyncPublicationWriter(
      storage: storage,
      sequences: SyncPublicationSequences(
        store: preferences,
        mutations: mutations,
        ensureCurrent: _ensureCurrent,
      ),
      identity: identity,
    );
    final publisher = SyncBookmarkPublisher(
      writer: writer,
      builder: SyncBookmarkPackageBuilder(fs: fs, codec: codec),
      workQueue: _preparation,
    );
    final entries = <SyncCatalogEntry>[];
    for (final id in covered) {
      final group = local[id]!;
      final data = BookmarkBackupData.unified(
        records: [for (final id in group.bookmarkIds) snapshot.records[id]!],
        groups: [
          BookmarkGroupBackup(
            id: id,
            name: group.name,
            bookmarkIds: group.bookmarkIds.toList(),
            addedAt: group.addedAt,
          ),
        ],
      );
      final revision = await publisher.publishIfChanged(
        collection: SyncCollectionId(
          publisher: identity.id,
          kind: 'bookmarks',
          source: id,
        ),
        data: data,
        appVersion: 'Boorusama',
        createdAt: now(),
        verifyExisting:
            verifyExisting ||
            _repairSources.contains(
              SyncCollectionId(
                publisher: identity.id,
                kind: 'bookmarks',
                source: id,
              ).key,
            ),
        validateSnapshot: validateSnapshot,
      );
      entries.add(
        SyncCatalogEntry(
          id: revision.collection,
          name: group.name,
          state: SyncPublicationState.active,
          revision: revision,
          parent: group.parentGroupId,
          position: group.position,
        ),
      );
    }
    if (following != null) {
      final publisher = SyncFollowingPublisher(
        writer: writer,
        builder: SyncFollowingPackageBuilder(fs: fs),
        workQueue: _preparation,
      );
      for (final source in following.scope.covered) {
        final revision = await publisher.publishIfChanged(
          collection: SyncCollectionId(
            publisher: identity.id,
            kind: 'following_topics',
            source: source,
          ),
          data: following.definitions[source]!,
          appVersion: 'Boorusama',
          createdAt: now(),
          verifyExisting:
              verifyExisting ||
              _repairSources.contains(
                SyncCollectionId(
                  publisher: identity.id,
                  kind: 'following_topics',
                  source: source,
                ).key,
              ),
          validateSnapshot: validateSnapshot,
        );
        final node = following.nodes[source]!;
        entries.add(
          SyncCatalogEntry(
            id: revision.collection,
            name: following.labels[source]!,
            state: SyncPublicationState.active,
            revision: revision,
            parent: node.parent,
            position: node.position,
          ),
        );
      }
    }
    final active = entries.map((e) => e.id).toSet();
    for (final old in prior?.entries ?? <SyncCatalogEntry>[]) {
      if (active.contains(old.id)) continue;
      entries.add(
        SyncCatalogEntry(
          id: old.id,
          name: old.name,
          state:
              (old.id.kind == 'bookmarks'
                  ? local.containsKey(old.id.source)
                  : following?.nodes.containsKey(old.id.source) ?? false)
              ? SyncPublicationState.withdrawn
              : SyncPublicationState.deleted,
          revision: old.revision,
          parent: old.parent,
          position: old.position,
        ),
      );
    }
    final roots = <SyncCollectionId>{
      for (final source in publishedRoots)
        if (local.containsKey(source))
          SyncCollectionId(
            publisher: identity.id,
            kind: 'bookmarks',
            source: source,
          ),
      for (final source in following?.scope.directRoots ?? const <String>{})
        SyncCollectionId(
          publisher: identity.id,
          kind: 'following_topics',
          source: source,
        ),
    };
    Object? rootJson(Set<SyncCollectionId>? values) => values == null
        ? null
        : [
            for (final root
                in values.toList()..sort((a, b) => a.key.compareTo(b.key)))
              root.toJson(),
          ];
    final content = canonicalSyncJson({
      'publicationRoots': rootJson(roots),
      'name': name,
      'entries': entries.map((entry) => entry.toJson()).toList()
        ..sort(
          (a, b) => '${a['kind']}/${a['source']}'.compareTo(
            '${b['kind']}/${b['source']}',
          ),
        ),
    });
    final same =
        prior != null &&
        content ==
            canonicalSyncJson({
              'publicationRoots': rootJson(prior.publicationRoots),
              'name': prior.name,
              'entries': prior.entries.map((entry) => entry.toJson()).toList()
                ..sort(
                  (a, b) => '${a['kind']}/${a['source']}'.compareTo(
                    '${b['kind']}/${b['source']}',
                  ),
                ),
            });
    if (same) {
      try {
        final retained = await storage.read(
          prior.path,
          maxBytes: miteMiteMaxMetadataBytes,
        );
        if (retained != null) {
          final verified = await verifySyncDocument(
            retained,
            identity.publicKey,
          );
          if (canonicalSyncJson(verified) ==
              canonicalSyncJson(prior.toJson())) {
            await _completePublication(prior);
            _repairSources.clear();
            return;
          }
        }
      } on FormatException {
        // Repair our own incomplete/corrupt publication at a fresh sequence.
        // Existing immutable bytes must never be overwritten.
      }
    }
    // Even an empty configured publisher needs a signed discovery catalog.
    final complete = await writer.publishCatalog(
      name: name,
      entries: entries,
      publicationRoots: roots,
    );
    await _completePublication(complete);
    _repairSources.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final class _OfflineStorage implements MiteMiteStorage {
  Never _offline() =>
      throw StateError('Offline management must not use transport');
  @override
  Future<List<String>> list(String path) async => _offline();
  @override
  Future<Uint8List?> read(
    String path, {
    int maxBytes = miteMiteMaxBytes,
  }) async => _offline();
  @override
  Future<void> writeImmutable(String path, Uint8List bytes) async => _offline();
  @override
  Future<void> deleteOwnedRevision(
    String path, {
    required String owner,
  }) async => _offline();
}

/// Cancellation is checked again after each transport await, before authority
/// can advance or prepared data can reach a replaced repository generation.
final class _CurrentStorage implements MiteMiteStorage {
  _CurrentStorage(this.delegate, this.ensureCurrent);
  final MiteMiteStorage delegate;
  final void Function() ensureCurrent;
  @override
  Future<List<String>> list(String path) async {
    ensureCurrent();
    final result = await delegate.list(path);
    ensureCurrent();
    return result;
  }

  @override
  Future<Uint8List?> read(
    String path, {
    int maxBytes = miteMiteMaxBytes,
  }) async {
    ensureCurrent();
    final result = await delegate.read(path, maxBytes: maxBytes);
    ensureCurrent();
    return result;
  }

  @override
  Future<void> writeImmutable(String path, Uint8List bytes) async {
    ensureCurrent();
    await delegate.writeImmutable(path, bytes);
    ensureCurrent();
  }

  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) async {
    ensureCurrent();
    await delegate.deleteOwnedRevision(path, owner: owner);
    ensureCurrent();
  }
}

/// The local selection is durable, but shared bytes still require a retry.
final class SyncPublicationPending implements Exception {
  const SyncPublicationPending();
}
