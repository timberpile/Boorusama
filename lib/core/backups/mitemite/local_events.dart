import 'dart:convert';

import '../../../foundation/data_mutation_coordinator.dart';
import '../../cache/misc_data_store.dart';
import 'protocol.dart';
import 'notification_outbox.dart';
import 'activity_log.dart';

export 'activity_log.dart';

final class SyncDiscovery {
  const SyncDiscovery(this.publisher, this.fingerprint);
  final String publisher;
  final String fingerprint;
  String get key => '$publisher/$fingerprint';
}

final class SyncLocalEvents {
  SyncLocalEvents({
    required this.preferences,
    required this.mutations,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  static const _key = 'mitemite.v1.local_events';
  static const historyLimit = SyncActivityLog.limit;
  final DateTime Function() now;
  final MiscDataStore preferences;
  final DataMutationCoordinator mutations;

  Map<String, dynamic> _read() {
    final encoded = preferences.get(_key);
    if (encoded == null)
      return {
        'version': 1,
        'notificationOutbox': SyncNotificationOutbox.empty().toJson(),
        'discoveries': <String, dynamic>{},
        'events': <dynamic>[],
      };
    final value = jsonDecode(encoded);
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['discoveries'] is! Map<String, dynamic> ||
        value['events'] is! List) {
      throw const FormatException('Invalid local Sync events');
    }
    if ((value['discoveries'] as Map).length > miteMiteMaxEntries ||
        (value['events'] as List).length > historyLimit) {
      throw const FormatException('Local Sync events exceed bounds');
    }
    for (final entry
        in (value['discoveries'] as Map<String, dynamic>).entries) {
      _discovery(entry.key);
      if (entry.value is! bool)
        throw const FormatException('Invalid discovery delivery state');
    }
    if (value['notificationOutbox'] is! Map)
      throw const FormatException('Missing typed notification outbox');
    final cursors = value['activityCursors'];
    if (cursors != null &&
        (cursors is! Map ||
            cursors.length > 2 ||
            cursors.entries.any(
              (entry) =>
                  !const {
                    'bookmarks',
                    'following_topics',
                  }.contains(entry.key) ||
                  entry.value is! int ||
                  (entry.value as int) < 0 ||
                  (entry.value as int) > miteMiteMaxSequence,
            )))
      throw const FormatException('Invalid Activity delivery cursors');
    return value;
  }

  List<SyncEvent> get history => List.unmodifiable([
    for (final value in _read()['events'] as List)
      SyncEvent.fromJson(Map<String, dynamic>.from(value as Map)),
  ]);

  List<SyncDiscovery> get pendingDiscoveries => List.unmodifiable([
    for (final entry
        in (_read()['discoveries'] as Map<String, dynamic>).entries)
      if (entry.value == false) _discovery(entry.key),
  ]);

  SyncDiscovery _discovery(String key) {
    final parts = key.split('/');
    if (parts.length != 2 || !isSyncDigest(parts.last)) {
      throw const FormatException('Invalid discovery receipt');
    }
    return SyncDiscovery(syncUuid(parts.first), parts.last);
  }

  void _append(Map<String, dynamic> state, SyncEvent event) =>
      _appendMany(state, [event]);

  void _appendMany(Map<String, dynamic> state, Iterable<SyncEvent> events) {
    final combined = [
      for (final event in events.toList().reversed)
        (event.toJson()
          ..remove('notificationMembers')
          ..remove('fingerprint')),
      ...state['events'] as List,
    ];
    final ordered =
        [
          for (final (index, raw) in combined.indexed)
            (
              index: index,
              at: DateTime.parse((raw as Map)['at'] as String),
              json: raw,
            ),
        ]..sort((a, b) {
          final time = b.at.compareTo(a.at);
          return time != 0 ? time : a.index.compareTo(b.index);
        });
    state['events'] = [for (final row in ordered.take(historyLimit)) row.json];
  }

  Future<void> consume(
    String domain,
    SyncActivityLog log, {
    Set<String> forgottenPublishers = const {},
  }) => mutations.runExclusive(() async {
    if (!const {'bookmarks', 'following_topics'}.contains(domain))
      throw const FormatException('Invalid Activity domain');
    final state = _read();
    final cursors = Map<String, dynamic>.from(
      state['activityCursors'] as Map? ?? const {},
    );
    final cursor = cursors[domain] ?? 0;
    if (cursor is! int || cursor < 0 || cursor > log.sequence)
      throw const FormatException('Mirror Activity cursor rollback');
    final outbox = _outbox(state)..prune(now());
    for (final publisher in forgottenPublishers)
      outbox.removePublisher(publisher);
    if (cursor == log.sequence) {
      // A durable preference adapter may expose its new cached value after
      // a failed flush. Re-establish the barrier before the caller retires
      // exact domain-journal intent, even when the cursor already matches.
      await _save(state, outbox: outbox, force: log.pendingPosts.isNotEmpty);
      return;
    }
    final forgottenAt = <String, int>{
      for (final record in log.entries)
        if (record.event.kind == SyncEventKind.forgotten &&
            record.event.publisher != null)
          record.event.publisher!: record.sequence,
    };
    final fresh = [
      for (final entry in log.entries)
        if (entry.sequence > cursor) entry.event,
    ];
    _appendMany(state, fresh);
    for (final event in fresh) {
      if (event.kind == SyncEventKind.forgotten && event.publisher != null)
        outbox.removePublisher(event.publisher!);
    }
    {
      final changes = [
        for (final entry in log.pendingPosts)
          if (entry.sequence > cursor &&
              !forgottenPublishers.contains(entry.event.publisher) &&
              entry.sequence > (forgottenAt[entry.event.publisher] ?? 0))
            for (final member in entry.event.notificationMembers)
              SyncNoticeItem(
                publisher: entry.event.publisher!,
                fingerprint: entry.event.fingerprint!,
                at: entry.event.at,
                sourceKind: domain,
                source: entry.event.source!,
                member: member,
              ),
      ];
      if (domain == 'bookmarks') {
        outbox.receivePosts(changes);
      } else {
        outbox.receiveTopics(changes);
      }
    }
    cursors[domain] = log.sequence;
    state['activityCursors'] = cursors;
    await _save(state, outbox: outbox);
  });

  /// Roots describe a completed catalog, not an uncommitted publication intent.
  Future<void> reconcilePublications(
    Map<String, Set<String>> roots,
    DateTime at, {
    bool seedOnly = false,
  }) => mutations.runExclusive(() async {
    final state = _read();
    final previous = state['publishedRoots'] as Map?;
    if (previous != null && seedOnly) return;
    final next = <String, Object?>{};
    final changes = <SyncEvent>[];
    var changed = previous == null;
    for (final kind in const ['bookmarks', 'following_topics']) {
      final current = (roots[kind] ?? const <String>{}).map(syncUuid).toSet();
      if (current.length > miteMiteMaxEntries)
        throw const FormatException('Publication history exceeds bounds');
      final old = ((previous?[kind] as List?) ?? const [])
          .map(syncUuid)
          .toSet();
      if (previous != null) {
        for (final source in current.difference(old))
          changes.add(
            SyncEvent(
              kind: SyncEventKind.published,
              at: at,
              source: source,
              sourceKind: kind,
            ),
          );
        for (final source in old.difference(current))
          changes.add(
            SyncEvent(
              kind: SyncEventKind.stopped,
              at: at,
              source: source,
              sourceKind: kind,
            ),
          );
      }
      changed =
          changed || current.length != old.length || !current.containsAll(old);
      next[kind] = current.toList()..sort();
    }
    if (!changed) return;
    _appendMany(state, changes);
    state['publishedRoots'] = next;
    await _save(state);
  });

  DateTime? get lastAttempt => switch (_read()['lastAttempt']) {
    final String value => DateTime.parse(value).toUtc(),
    _ => null,
  };
  DateTime? get lastSuccess => switch (_read()['lastSuccess']) {
    final String value => DateTime.parse(value).toUtc(),
    _ => null,
  };

  Future<void> markAttempt(DateTime at) => mutations.runExclusive(() async {
    final state = _read();
    final value = at.toUtc().toIso8601String();
    if (state['lastAttempt'] == value) return;
    state['lastAttempt'] = value;
    await _save(state);
  });

  Future<void> recordFailure(SyncEvent event) =>
      _failures([event], snapshot: false);
  Future<void> reconcileFailures(
    List<SyncEvent> events, {
    required DateTime attemptedAt,
    DateTime? completedAt,
  }) => _failures(
    events,
    snapshot: true,
    attemptedAt: attemptedAt,
    completedAt: completedAt,
  );

  Future<void> _failures(
    List<SyncEvent> events, {
    required bool snapshot,
    DateTime? attemptedAt,
    DateTime? completedAt,
  }) => mutations.runExclusive(() async {
    final state = _read();
    final previous = Map<String, String>.from(
      state['failures'] as Map? ?? const {},
    );
    final next = snapshot
        ? <String, String>{}
        : Map<String, String>.of(previous);
    final changes = <SyncEvent>[];
    for (final event in events) {
      if (event.kind != SyncEventKind.failed || event.failure == null)
        throw const FormatException('Invalid Sync failure event');
      SyncEvent.fromJson(event.toJson());
      final key = canonicalSyncJson([
        event.sourceKind,
        event.publisher,
        event.source,
      ]);
      next[key] = event.failure!.name;
      if (previous[key] != event.failure!.name) changes.add(event);
    }
    if (next.length > miteMiteMaxEntries * 3)
      throw const FormatException('Failure receipts exceed bounds');
    final attempt = attemptedAt?.toUtc().toIso8601String();
    final completion = completedAt?.toUtc().toIso8601String();
    final changed =
        canonicalSyncJson(previous) != canonicalSyncJson(next) ||
        (attempt != null && state['lastAttempt'] != attempt) ||
        (completion != null && state['lastSuccess'] != completion);
    if (changes.isEmpty && !changed) return;
    if (changes.isNotEmpty) _appendMany(state, changes);
    state['failures'] = next;
    if (attempt != null) state['lastAttempt'] = attempt;
    if (completion != null) state['lastSuccess'] = completion;
    await _save(state);
  });

  Future<void> record(SyncEvent event) => mutations.runExclusive(() async {
    final state = _read();
    _append(state, event);
    await _save(state);
  });

  Future<void> discover(Iterable<SyncDiscovery> devices, DateTime at) {
    final captured = List<SyncDiscovery>.of(devices);
    return mutations.runExclusive(() async {
      final state = _read();
      final known = state['discoveries'] as Map<String, dynamic>;
      final outbox = _outbox(state)..prune(now());
      var changed = false;
      final changes = <SyncEvent>[];
      for (final device in captured) {
        _discovery(device.key);
        if (known.containsKey(device.key)) continue;
        if (known.length >= miteMiteMaxEntries) {
          throw const FormatException('Discovery receipt limit reached');
        }
        known[device.key] = false;
        outbox.discover(device.publisher, device.fingerprint, at);
        changes.add(
          SyncEvent(
            kind: SyncEventKind.discovered,
            at: at,
            publisher: device.publisher,
          ),
        );
        changed = true;
      }
      if (changed) {
        _appendMany(state, changes);
        await _save(state, outbox: outbox);
      }
    });
  }

  Future<void> acknowledgeDiscoveries(Set<String> keys) {
    final captured = Set<String>.of(keys);
    return mutations.runExclusive(() async {
      final state = _read();
      final known = state['discoveries'] as Map<String, dynamic>;
      final outbox = _outbox(state);
      for (final key in captured) {
        if (known[key] == false) known[key] = true;
      }
      for (final notice in outbox.pending) {
        if (notice.kind == SyncNoticeKind.device &&
            captured.contains(notice.items.single.publisherKey))
          outbox.acknowledge(notice);
      }
      await _save(state, outbox: outbox);
    });
  }

  int activityCursor(String domain) =>
      (_read()['activityCursors'] as Map?)?[domain] as int? ?? 0;
  List<SyncNotice> get pendingNotifications {
    final outbox = _outbox(_read())..prune(now());
    return outbox.pending;
  }

  Map<String, SyncNoticeItem> get unseenOffers => _outbox(_read()).unseenOffers;

  Future<void> acknowledgeOffers(Set<String> keys) {
    final captured = Set<String>.of(keys);
    return mutations.runExclusive(() async {
      final before = preferences.get(_key);
      final state = _read();
      final outbox = _outbox(state)..acknowledgeOffers(captured);
      try {
        await _save(state, outbox: outbox);
      } catch (error, stack) {
        // A failed flush can still expose the attempted value in Hive's cache.
        // Undo only this offer-receipt write, under the same mutation lock;
        // never replace a newer value from another writer. Domain cursors and
        // native delivery receipts are unchanged by acknowledging offers.
        if (before != null &&
            preferences.get(_key) == canonicalSyncJson(state)) {
          try {
            await preferences.put(_key, before);
          } catch (_) {
            // The adapter can fail its barrier again after restoring the cache.
            // Propagate the original failure; the visit remains retryable.
          }
        }
        Error.throwWithStackTrace(error, stack);
      }
    });
  }

  bool get notificationPermissionRequested =>
      _outbox(_read()).permissionRequested;

  Future<void> markNotificationPermissionRequested() =>
      mutations.runExclusive(() async {
        final state = _read();
        final outbox = _outbox(state)..permissionRequested = true;
        await _save(state, outbox: outbox);
      });

  Future<void> pruneNotificationOutbox() => mutations.runExclusive(() async {
    final state = _read();
    final outbox = _outbox(state)..prune(now());
    await _save(state, outbox: outbox);
  });

  Future<void> acknowledgeNotification(SyncNotice snapshot) =>
      mutations.runExclusive(() async {
        final state = _read();
        final outbox = _outbox(state);
        if (outbox.acknowledge(snapshot)) await _save(state, outbox: outbox);
      });

  Future<void> seedOfferBaseline({
    required String publisher,
    required String fingerprint,
    required int sequence,
    required Iterable<SyncCollectionId> roots,
    bool replace = false,
  }) {
    final captured = List<SyncCollectionId>.of(roots);
    return mutations.runExclusive(() async {
      final state = _read();
      final outbox = _outbox(state)..prune(now());
      outbox.seedOffers(
        publisher: publisher,
        fingerprint: fingerprint,
        sequence: sequence,
        roots: captured,
        replace: replace,
      );
      await _save(state, outbox: outbox);
    });
  }

  Future<void> observeOffers({
    required String publisher,
    required String fingerprint,
    required int sequence,
    required Iterable<SyncCollectionId> roots,
    required DateTime at,
  }) {
    final captured = List<SyncCollectionId>.of(roots);
    return mutations.runExclusive(() async {
      final state = _read();
      final outbox = _outbox(state)..prune(now());
      final added = outbox.observeOffers(
        publisher: publisher,
        fingerprint: fingerprint,
        sequence: sequence,
        roots: captured,
        at: at,
      );
      _appendMany(state, [
        for (final item in added)
          SyncEvent(
            kind: SyncEventKind.available,
            at: at,
            publisher: publisher,
            sourceKind: item.sourceKind!,
            source: item.source,
          ),
      ]);
      await _save(state, outbox: outbox);
    });
  }

  SyncNotificationOutbox _outbox(Map<String, dynamic> state) =>
      SyncNotificationOutbox.fromJson(state['notificationOutbox']);

  Future<void> _save(
    Map<String, dynamic> state, {
    SyncNotificationOutbox? outbox,
    bool force = false,
  }) async {
    final value = outbox ?? _outbox(state);
    value.prune(now());
    final pendingDevices = {
      for (final notice in value.pending)
        if (notice.kind == SyncNoticeKind.device)
          notice.items.single.publisherKey,
    };
    final discoveries = state['discoveries'] as Map<String, dynamic>;
    for (final key in discoveries.keys.toList()) {
      if (discoveries[key] == false && !pendingDevices.contains(key))
        discoveries[key] = true;
    }
    state['notificationOutbox'] = value.toJson();
    final encoded = canonicalSyncJson(state);
    if (force || preferences.get(_key) != encoded)
      await preferences.put(_key, encoded);
  }
}
