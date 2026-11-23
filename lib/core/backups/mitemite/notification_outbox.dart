import 'dart:convert';

import 'protocol.dart';

enum SyncNoticeKind { device, offers, posts, followingOffers, topics }

/// Exact local change identity; never part of a shared signed package.
final class SyncNoticeItem {
  SyncNoticeItem({
    required String publisher,
    required String fingerprint,
    required this.at,
    this.sourceKind,
    String? source,
    this.member,
  }) : publisher = syncUuid(publisher),
       fingerprint = _fingerprint(fingerprint),
       source = source == null ? null : syncUuid(source) {
    if (sourceKind != null && !syncSourceKinds.contains(sourceKind) ||
        member != null &&
            (member!.isEmpty || member!.length > miteMiteMaxMetadataBytes)) {
      throw const FormatException('Invalid notification change identity');
    }
  }

  factory SyncNoticeItem.fromJson(Map<String, dynamic> json) => SyncNoticeItem(
    publisher: syncString(json['publisher']),
    fingerprint: syncString(json['fingerprint']),
    at: DateTime.parse(syncString(json['at'])).toUtc(),
    sourceKind: json['kind'] as String?,
    source: json['source'] as String?,
    member: json['member'] as String?,
  );

  final String publisher;
  final String fingerprint;
  final DateTime at;
  final String? sourceKind;
  final String? source;
  final String? member;
  String get key =>
      canonicalSyncJson([publisher, fingerprint, sourceKind, source, member]);
  String get publisherKey => '$publisher/$fingerprint';
  Map<String, Object?> toJson() => {
    'publisher': publisher,
    'fingerprint': fingerprint,
    'at': at.toUtc().toIso8601String(),
    if (sourceKind != null) 'kind': sourceKind,
    if (source != null) 'source': source,
    if (member != null) 'member': member,
  };
}

String _fingerprint(String value) {
  if (!isSyncDigest(value))
    throw const FormatException('Invalid notification fingerprint');
  return value;
}

final class SyncNotice {
  SyncNotice({
    required this.bucket,
    required this.kind,
    required this.batch,
    required this.generation,
    required Iterable<SyncNoticeItem> items,
  }) : items = List.unmodifiable(items) {
    syncPositiveInteger(batch);
    syncPositiveInteger(generation);
    if (this.items.isEmpty ||
        this.items.map((item) => item.key).toSet().length !=
            this.items.length) {
      throw const FormatException('Invalid notification batch');
    }
    final first = this.items.first;
    switch (kind) {
      case SyncNoticeKind.device:
        if (bucket != 'device:' + first.publisherKey ||
            this.items.length != 1 ||
            first.source != null ||
            first.sourceKind != null ||
            first.member != null) {
          throw const FormatException('Invalid device notification');
        }
      case SyncNoticeKind.offers:
      case SyncNoticeKind.followingOffers:
        final prefix = kind == SyncNoticeKind.offers
            ? 'offers:'
            : 'followingOffers:';
        final sourceKind = kind == SyncNoticeKind.offers
            ? 'bookmarks'
            : 'following_topics';
        if (bucket != prefix + first.publisherKey ||
            this.items.any(
              (item) =>
                  item.publisherKey != first.publisherKey ||
                  item.source == null ||
                  item.sourceKind != sourceKind ||
                  item.member != null,
            )) {
          throw const FormatException('Invalid collection notification');
        }
      case SyncNoticeKind.posts:
      case SyncNoticeKind.topics:
        final sourceKind = kind == SyncNoticeKind.posts
            ? 'bookmarks'
            : 'following_topics';
        if (bucket != (kind == SyncNoticeKind.posts ? 'posts' : 'topics') ||
            this.items.any(
              (item) =>
                  item.sourceKind != sourceKind ||
                  item.source == null ||
                  item.member == null,
            )) {
          throw const FormatException('Invalid Post notification');
        }
    }
  }

  factory SyncNotice.fromJson(Map<String, dynamic> json) => SyncNotice(
    bucket: syncString(json['bucket']),
    kind: SyncNoticeKind.values.byName(syncString(json['kind'])),
    batch: syncPositiveInteger(json['batch']),
    generation: syncPositiveInteger(json['generation']),
    items: (json['items'] as List).map(
      (item) => SyncNoticeItem.fromJson(Map<String, dynamic>.from(item as Map)),
    ),
  );

  final String bucket;
  final SyncNoticeKind kind;
  final int batch;
  final int generation;
  final List<SyncNoticeItem> items;
  String get token => syncDigest(syncJsonBytes(toJson()));
  int get postCount => {
    for (final item in items) canonicalSyncJson([item.publisher, item.member]),
  }.length;
  int get groupCount => {
    for (final item in items)
      canonicalSyncJson([item.publisher, item.sourceKind, item.source]),
  }.length;
  int get deviceCount => items.map((item) => item.publisher).toSet().length;
  Map<String, Object?> toJson() => {
    'bucket': bucket,
    'kind': kind.name,
    'batch': batch,
    'generation': generation,
    'items': [
      for (final item
          in (items.toList()..sort((a, b) => a.key.compareTo(b.key))))
        item.toJson(),
    ],
  };
}

/// One bounded, versioned, receiver-local outbox for all MiteMite notices.
/// Disabled/denied/channel-blocked delivery retains up to 24 hours of intent.
/// Snapshot tokens prevent an async acknowledgement from erasing a later merge.
final class SyncNotificationOutbox {
  SyncNotificationOutbox.empty();
  static const freshness = Duration(hours: 24);
  static const maximumItems = miteMiteMaxEntries * 256;
  int _sequence = 0;
  bool permissionRequested = false;
  final _pending = <String, SyncNotice>{};
  final _offers = <String, ({int sequence, Set<String> known})>{};
  final _unseenOffers = <String, SyncNoticeItem>{};

  Map<String, SyncNoticeItem> get unseenOffers =>
      Map.unmodifiable(_unseenOffers);

  void acknowledgeOffers(Set<String> captured) {
    _unseenOffers.removeWhere((key, _) => captured.contains(key));
  }

  factory SyncNotificationOutbox.fromJson(Object? raw) {
    if (raw == null) return SyncNotificationOutbox.empty();
    if (raw is! Map ||
        raw['version'] != 1 ||
        raw['pending'] is! List ||
        raw['offers'] is! Map ||
        raw['unseenOffers'] is! List ||
        raw['permissionRequested'] is! bool) {
      throw const FormatException('Invalid notification outbox');
    }
    if (utf8.encode(canonicalSyncJson(raw)).length > miteMiteMaxBytes) {
      throw const FormatException('Notification outbox exceeds byte bounds');
    }
    final result = SyncNotificationOutbox.empty();
    final sequence = raw['sequence'];
    if (sequence is! int || sequence < 0 || sequence > miteMiteMaxSequence) {
      throw const FormatException('Invalid notification batch sequence');
    }
    result._sequence = sequence;
    result.permissionRequested = raw['permissionRequested'] as bool;
    for (final value in raw['pending'] as List) {
      final notice = SyncNotice.fromJson(
        Map<String, dynamic>.from(value as Map),
      );
      if (notice.batch > sequence ||
          result._pending.containsKey(notice.bucket)) {
        throw const FormatException('Invalid pending notification sequence');
      }
      result._pending[notice.bucket] = notice;
    }
    for (final entry in (raw['offers'] as Map).entries) {
      final parts = (entry.key as String).split('/');
      if (parts.length != 2)
        throw const FormatException('Invalid offer checkpoint');
      syncUuid(parts.first);
      _fingerprint(parts.last);
      final value = entry.value as Map;
      final known = (value['known'] as List).map(syncString).toSet();
      // This is cumulative receipt history, not one catalog's active roots.
      // Retain the same aggregate byte bounds used by the writer; otherwise
      // accepted offer observations can produce a snapshot we cannot reopen.
      if (known.length != (value['known'] as List).length) {
        throw const FormatException('Invalid offered collection history');
      }
      for (final key in known) {
        final identity = jsonDecode(key) as List;
        if (identity.length != 2 || !syncSourceKinds.contains(identity.first)) {
          throw const FormatException('Invalid offered collection identity');
        }
        syncUuid(identity.last);
      }
      result._offers[entry.key as String] = (
        sequence: _offerSequence(value['sequence']),
        known: known,
      );
    }
    for (final rawItem in raw['unseenOffers'] as List) {
      final item = SyncNoticeItem.fromJson(
        Map<String, dynamic>.from(rawItem as Map),
      );
      if (item.source == null ||
          item.sourceKind == null ||
          item.member != null ||
          !(result._offers[item.publisherKey]?.known.contains(
                canonicalSyncJson([item.sourceKind, item.source]),
              ) ??
              false) ||
          result._unseenOffers.containsKey(item.key)) {
        throw const FormatException('Invalid unseen offer receipt');
      }
      result._unseenOffers[item.key] = item;
    }
    result._checkBounds();
    return result;
  }

  List<SyncNotice> get pending => List.unmodifiable(_pending.values);

  void discover(String publisher, String fingerprint, DateTime at) =>
      _merge(SyncNoticeKind.device, 'device:$publisher/$fingerprint', [
        SyncNoticeItem(publisher: publisher, fingerprint: fingerprint, at: at),
      ]);

  /// Explicit Trust records its already authenticated snapshot before pinning
  /// the key. A failed outbox write cannot leave an approved key without a
  /// baseline; identity-only trust uses sequence zero and an empty root set.
  void seedOffers({
    required String publisher,
    required String fingerprint,
    required int sequence,
    required Iterable<SyncCollectionId> roots,
    bool replace = false,
  }) {
    final key = syncUuid(publisher) + '/' + _fingerprint(fingerprint);
    if (_offers.containsKey(key) && !replace) return;
    if (replace) {
      _offers.removeWhere((old, _) => old.startsWith('$publisher/'));
      _unseenOffers.removeWhere((_, item) => item.publisher == publisher);
      _pending.removeWhere(
        (_, notice) =>
            (notice.kind == SyncNoticeKind.offers ||
                notice.kind == SyncNoticeKind.followingOffers) &&
            notice.items.first.publisher == publisher,
      );
    }
    final known = <String>{};
    for (final root in roots) {
      if (root.publisher != publisher)
        throw const FormatException('Foreign notification offer baseline');
      known.add(canonicalSyncJson([root.kind, root.source]));
    }
    if (known.length > miteMiteMaxEntries)
      throw const FormatException('Too many notification offer baselines');
    _offers[key] = (sequence: _offerSequence(sequence), known: known);
    _checkBounds();
  }

  /// Caller must supply only an authenticated, pinned catalog's direct roots.
  /// First trust is a baseline; rename, replay and re-advertisement do not alert.
  List<SyncNoticeItem> observeOffers({
    required String publisher,
    required String fingerprint,
    required int sequence,
    required Iterable<SyncCollectionId> roots,
    required DateTime at,
  }) {
    syncPositiveInteger(sequence);
    final key = syncUuid(publisher) + '/' + _fingerprint(fingerprint);
    final before = _offers[key];
    if (before != null && sequence < before.sequence)
      throw const SyncReplayRejected();
    final current = <String, SyncCollectionId>{};
    for (final root in roots) {
      if (root.publisher != publisher)
        throw const FormatException('Foreign notification offer');
      current[canonicalSyncJson([root.kind, root.source])] = root;
    }
    if (current.length > miteMiteMaxEntries)
      throw const FormatException('Too many notification offers');
    final added = before == null
        ? <SyncNoticeItem>[]
        : [
            for (final entry in current.entries)
              if (!before.known.contains(entry.key))
                SyncNoticeItem(
                  publisher: publisher,
                  fingerprint: fingerprint,
                  at: at,
                  sourceKind: entry.value.kind,
                  source: entry.value.source,
                ),
          ];
    _offers[key] = (
      sequence: sequence,
      known: {...?before?.known, ...current.keys},
    );
    _unseenOffers.removeWhere(
      (_, item) =>
          item.publisherKey == key &&
          !current.containsKey(
            canonicalSyncJson([item.sourceKind, item.source]),
          ),
    );
    for (final item in added) {
      _unseenOffers[item.key] = item;
    }
    _merge(
      SyncNoticeKind.offers,
      'offers:$key',
      added.where((item) => item.sourceKind == 'bookmarks'),
    );
    _merge(
      SyncNoticeKind.followingOffers,
      'followingOffers:$key',
      added.where((item) => item.sourceKind == 'following_topics'),
    );
    _checkBounds();
    return added;
  }

  void receivePosts(Iterable<SyncNoticeItem> items) =>
      _merge(SyncNoticeKind.posts, 'posts', items);

  void receiveTopics(Iterable<SyncNoticeItem> items) =>
      _merge(SyncNoticeKind.topics, 'topics', items);

  void _merge(
    SyncNoticeKind kind,
    String bucket,
    Iterable<SyncNoticeItem> changes,
  ) {
    final old = _pending[bucket];
    final combined = {
      for (final item in old?.items ?? const <SyncNoticeItem>[]) item.key: item,
    };
    var changed = false;
    for (final item in changes) {
      if (!combined.containsKey(item.key)) {
        combined[item.key] = item;
        changed = true;
      }
    }
    if (!changed) return;
    final batch = old?.batch ?? ++_sequence;
    _pending[bucket] = SyncNotice(
      bucket: bucket,
      kind: kind,
      batch: batch,
      generation: (old?.generation ?? 0) + 1,
      items: combined.values,
    );
    _checkBounds();
  }

  bool acknowledge(SyncNotice snapshot) {
    if (_pending[snapshot.bucket]?.token != snapshot.token) return false;
    _pending.remove(snapshot.bucket);
    return true;
  }

  void removePublisher(String publisher) {
    syncUuid(publisher);
    _offers.removeWhere((key, _) => key.startsWith('$publisher/'));
    _unseenOffers.removeWhere((_, item) => item.publisher == publisher);
    for (final entry in _pending.entries.toList()) {
      _replaceItems(
        entry.value,
        entry.value.items.where((item) => item.publisher != publisher),
      );
    }
  }

  void prune(DateTime now) {
    final oldest = now.toUtc().subtract(freshness);
    for (final entry in _pending.entries.toList()) {
      _replaceItems(
        entry.value,
        entry.value.items.where((item) => !item.at.isBefore(oldest)),
      );
    }
  }

  void _replaceItems(SyncNotice before, Iterable<SyncNoticeItem> items) {
    final retained = items.toList();
    if (retained.length == before.items.length) return;
    if (retained.isEmpty) {
      _pending.remove(before.bucket);
    } else {
      _pending[before.bucket] = SyncNotice(
        bucket: before.bucket,
        kind: before.kind,
        batch: before.batch,
        generation: before.generation + 1,
        items: retained,
      );
    }
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'unseenOffers': [for (final item in _unseenOffers.values) item.toJson()],
    'sequence': _sequence,
    'permissionRequested': permissionRequested,
    'pending': [for (final notice in _pending.values) notice.toJson()],
    'offers': {
      for (final entry in _offers.entries)
        entry.key: {
          'sequence': entry.value.sequence,
          'known': entry.value.known.toList()..sort(),
        },
    },
  };

  void _checkBounds() {
    if (_pending.length > miteMiteMaxEntries * 3 + 2 ||
        _unseenOffers.length > maximumItems ||
        _offers.length > miteMiteMaxEntries ||
        _pending.values.fold<int>(0, (n, notice) => n + notice.items.length) >
            maximumItems ||
        utf8.encode(canonicalSyncJson(toJson())).length > miteMiteMaxBytes) {
      throw const FormatException('Notification outbox exceeds bounds');
    }
  }
}

int _offerSequence(Object? value) {
  if (value == 0) return 0;
  return syncPositiveInteger(value);
}
