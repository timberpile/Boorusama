import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'protocol.dart';

/// Receiver-local discovery receipts and bounded history, never transport data.
/// This log is informational; it grants no trust, subscription or write rights.
enum SyncEventKind {
  discovered,
  available,
  published,
  stopped,
  subscribed,
  unsubscribed,
  forgotten,
  received,
  copied,
  failed,
}

enum SyncFailureKind {
  permission,
  unavailable,
  missingRevision,
  unsupported,
  identityChanged,
  identityFile,
  invalidSignature,
  rollback,
  conflict,
  retryableIo,
  invalidData,
  sizeLimit,
  unknown,
}

final class SyncEvent extends Equatable {
  const SyncEvent({
    required this.kind,
    required this.at,
    this.publisher,
    this.source,
    this.sourceKind = 'bookmarks',
    this.added = 0,
    this.removed = 0,
    this.failure,
    this.fingerprint,
    this.notificationMembers = const {},
  });
  factory SyncEvent.fromJson(Map<String, dynamic> value) => SyncEvent(
    kind: SyncEventKind.values.byName(value['kind'] as String),
    at: DateTime.parse(value['at'] as String).toUtc(),
    publisher: value['publisher'] == null ? null : syncUuid(value['publisher']),
    source: value['source'] == null ? null : syncUuid(value['source']),
    sourceKind: value['sourceKind'] as String? ?? 'bookmarks',
    added: value['added'] as int? ?? 0,
    removed: value['removed'] as int? ?? 0,
    fingerprint: value['fingerprint'] as String?,
    notificationMembers: _notificationKeys(
      value['notificationMembers'] ?? const [],
    ),
    failure: value['failure'] == null
        ? null
        : SyncFailureKind.values.byName(value['failure'] as String),
  );
  final SyncEventKind kind;
  final DateTime at;
  final String? publisher;
  final String? source;
  final String sourceKind;
  final int added;
  final int removed;
  final SyncFailureKind? failure;
  final String? fingerprint;
  final Set<String> notificationMembers;
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'at': at.toUtc().toIso8601String(),
    'publisher': publisher,
    'source': source,
    'sourceKind': sourceKind,
    'added': added,
    'removed': removed,
    if (failure != null) 'failure': failure!.name,
    if (fingerprint != null) 'fingerprint': fingerprint,
    if (notificationMembers.isNotEmpty)
      'notificationMembers': notificationMembers.toList()..sort(),
  };
  @override
  List<Object?> get props => [
    kind,
    at,
    publisher,
    source,
    sourceKind,
    added,
    removed,
    failure,
    fingerprint,
    notificationMembers,
  ];
}

/// Bounded outbox committed with the existing mirror journal. Sequence cursors
/// in local history make delivery recoverable without acknowledging read state.
final class SyncActivityRecord extends Equatable {
  const SyncActivityRecord(this.sequence, this.event);
  final int sequence;
  final SyncEvent event;
  Map<String, Object?> toJson() => {
    'sequence': sequence,
    'event': event.toJson(),
  };
  @override
  List<Object?> get props => [sequence, event];
}

final class SyncActivityLog extends Equatable {
  factory SyncActivityLog.fromJson(Map<String, dynamic> json) {
    final sequence = json['sequence'];
    final entries = json['entries'];
    if (json['version'] != 1 ||
        sequence is! int ||
        sequence < 0 ||
        sequence > miteMiteMaxSequence ||
        entries is! List ||
        entries.length != (sequence < limit ? sequence : limit)) {
      throw const FormatException('Invalid mirror Activity outbox');
    }
    final records = <SyncActivityRecord>[];
    for (final (index, raw) in entries.indexed) {
      if (raw is! Map ||
          raw['sequence'] != sequence - entries.length + index + 1 ||
          raw['event'] is! Map) {
        throw const FormatException('Invalid mirror Activity sequence');
      }
      records.add(
        SyncActivityRecord(
          raw['sequence'] as int,
          SyncEvent.fromJson(Map<String, dynamic>.from(raw['event'] as Map)),
        ),
      );
    }
    if (!json.containsKey('notifications')) {
      return SyncActivityLog._(sequence, records);
    }
    final notification = json['notifications'];
    if (notification is! Map ||
        notification['version'] != 1 ||
        notification['pending'] is! List ||
        notification['known'] is! Map) {
      throw const FormatException('Invalid journaled notification intent');
    }
    final cursor = notification['cursor'];
    if (cursor is! int || cursor < 0 || cursor > sequence) {
      throw const FormatException('Invalid notification delivery cursor');
    }
    final pending = <SyncActivityRecord>[];
    var previous = cursor;
    for (final raw in notification['pending'] as List) {
      if (raw is! Map ||
          raw['sequence'] is! int ||
          (raw['sequence'] as int) <= previous ||
          (raw['sequence'] as int) > sequence ||
          raw['event'] is! Map) {
        throw const FormatException('Invalid journaled Post change sequence');
      }
      final event = SyncEvent.fromJson(
        Map<String, dynamic>.from(raw['event'] as Map),
      );
      _checkPostIntent(event);
      previous = raw['sequence'] as int;
      pending.add(SyncActivityRecord(previous, event));
    }
    final known = <String, Set<String>>{};
    for (final entry in (notification['known'] as Map).entries) {
      final key = syncString(entry.key);
      final parts = key.split('/');
      if (parts.length != 2) {
        throw const FormatException('Invalid notification source identity');
      }
      syncUuid(parts.first);
      syncUuid(parts.last);
      known[key] = _notificationKeys(entry.value);
    }
    for (final record in pending) {
      final event = record.event;
      if (!(known['${event.publisher}/${event.source}'] ?? const <String>{})
              .containsAll(event.notificationMembers) ||
          records.any(
            (other) => other.sequence == record.sequence && other != record,
          )) {
        throw const FormatException(
          'Inconsistent committed notification intent',
        );
      }
    }
    final result = SyncActivityLog._(
      sequence,
      records,
      notificationCursor: cursor,
      pendingPosts: pending,
      notificationKnown: known,
      notificationState: true,
    );
    result._checkBounds();
    return result;
  }
  const SyncActivityLog.empty()
    : sequence = 0,
      entries = const [],
      notificationCursor = 0,
      pendingPosts = const [],
      notificationKnown = const {},
      _notificationState = false;
  SyncActivityLog._(
    this.sequence,
    Iterable<SyncActivityRecord> entries, {
    this.notificationCursor = 0,
    Iterable<SyncActivityRecord> pendingPosts = const [],
    Map<String, Set<String>> notificationKnown = const {},
    bool notificationState = false,
  }) : entries = List.unmodifiable(entries),
       pendingPosts = List.unmodifiable(pendingPosts),
       notificationKnown = Map.unmodifiable(notificationKnown),
       _notificationState = notificationState;

  static const limit = 200;
  final int sequence;
  final List<SyncActivityRecord> entries;
  final int notificationCursor;
  final List<SyncActivityRecord> pendingPosts;
  final Map<String, Set<String>> notificationKnown;
  final bool _notificationState;

  SyncActivityLog append(
    Iterable<SyncEvent> events, {
    Map<String, Set<String>>? observedMembers,
  }) {
    final captured = events.toList();
    if (captured.isEmpty && observedMembers == null) return this;
    if (sequence > miteMiteMaxSequence - captured.length) {
      throw const FormatException('Mirror Activity sequence exhausted');
    }
    final added = [
      for (final (index, event) in captured.indexed)
        SyncActivityRecord(sequence + index + 1, event),
    ];
    final records = [...entries, ...added];
    final known = Map<String, Set<String>>.of(notificationKnown);
    void remember(String key, Set<String> identities) {
      final previous = known[key];
      if (previous == null || !previous.containsAll(identities)) {
        known[key] = Set.unmodifiable({...?previous, ...identities});
      }
    }

    for (final entry
        in observedMembers?.entries ??
            const Iterable<MapEntry<String, Set<String>>>.empty()) {
      final parts = entry.key.split('/');
      if (parts.length != 2) {
        throw const FormatException('Invalid observed notification source');
      }
      syncUuid(parts.first);
      syncUuid(parts.last);
      _notificationKeys(entry.value.toList());
      remember(entry.key, entry.value);
    }
    final pending = [...pendingPosts];
    for (final record in added) {
      if (record.event.notificationMembers.isEmpty) continue;
      _checkPostIntent(record.event);
      pending.add(record);
      final event = record.event;
      remember('${event.publisher}/${event.source}', event.notificationMembers);
    }
    final result = SyncActivityLog._(
      sequence + captured.length,
      records.skip(records.length > limit ? records.length - limit : 0),
      notificationCursor: notificationCursor,
      pendingPosts: pending,
      notificationKnown: known,
      notificationState:
          _notificationState || observedMembers != null || pending.isNotEmpty,
    );
    result._checkBounds();
    return result;
  }

  SyncActivityLog acknowledgePostsThrough(int cursor) {
    if (cursor < notificationCursor || cursor > sequence) {
      throw const FormatException('Invalid notification acknowledgement');
    }
    if (cursor == notificationCursor) return this;
    return SyncActivityLog._(
      sequence,
      entries,
      notificationCursor: cursor,
      pendingPosts: pendingPosts.where((record) => record.sequence > cursor),
      notificationKnown: notificationKnown,
      notificationState: true,
    );
  }

  SyncActivityLog withoutSources(Set<String> sources) {
    if (sources.isEmpty) return this;
    return SyncActivityLog._(
      sequence,
      entries,
      notificationCursor: notificationCursor,
      pendingPosts: pendingPosts.where(
        (record) => !sources.contains(
          '${record.event.publisher}/${record.event.source}',
        ),
      ),
      notificationKnown: {
        for (final entry in notificationKnown.entries)
          if (!sources.contains(entry.key)) entry.key: entry.value,
      },
      notificationState: _notificationState,
    );
  }

  bool follows(
    SyncActivityLog previous, {
    Set<String> purgedSources = const {},
  }) {
    if (sequence < previous.sequence ||
        notificationCursor < previous.notificationCursor ||
        previous._notificationState && !_notificationState) {
      return false;
    }
    final existing = {
      for (final record in previous.entries) record.sequence: record,
    };
    if (!entries.every(
      (record) =>
          !existing.containsKey(record.sequence) ||
          existing[record.sequence] == record,
    )) {
      return false;
    }
    for (final entry in previous.notificationKnown.entries) {
      if (purgedSources.contains(entry.key)) continue;
      if (identical(notificationKnown[entry.key], entry.value)) continue;
      if (!(notificationKnown[entry.key] ?? const <String>{}).containsAll(
        entry.value,
      )) {
        return false;
      }
    }
    final pending = {
      for (final record in pendingPosts) record.sequence: record,
    };
    return previous.pendingPosts.every(
      (record) =>
          record.sequence <= notificationCursor ||
          purgedSources.contains(
            '${record.event.publisher}/${record.event.source}',
          ) ||
          pending[record.sequence] == record,
    );
  }

  static final _orderedKnown = Expando<List<String>>();
  static final _knownBytes = Expando<int>();

  static List<String> _ordered(Set<String> keys) =>
      _orderedKnown[keys] ??= List.unmodifiable(keys.toList()..sort());

  Map<String, Object?> toJson() => _toJson(includeKnown: true);

  Map<String, Object?> _toJson({required bool includeKnown}) => {
    'version': 1,
    'sequence': sequence,
    'entries': [for (final entry in entries) entry.toJson()],
    if (_notificationState)
      'notifications': {
        'version': 1,
        'cursor': notificationCursor,
        'pending': [for (final entry in pendingPosts) entry.toJson()],
        'known': {
          if (includeKnown)
            for (final entry in notificationKnown.entries)
              entry.key: _ordered(entry.value),
        },
      },
  };

  void _checkBounds() {
    var bytes = utf8
        .encode(canonicalSyncJson(_toJson(includeKnown: false)))
        .length;
    if (notificationKnown.isNotEmpty) {
      // The empty known object already contributes its braces. Object order
      // changes neither the escaped UTF-8 length nor the separator count.
      bytes += notificationKnown.length - 1;
      for (final entry in notificationKnown.entries) {
        bytes += utf8.encode(jsonEncode(entry.key)).length + 1;
        bytes += _knownBytes[entry.value] ??= utf8
            .encode(jsonEncode(_ordered(entry.value)))
            .length;
      }
    }
    if (pendingPosts.length > miteMiteMaxEntries * 256 ||
        notificationKnown.length > miteMiteMaxEntries * miteMiteMaxEntries ||
        bytes > miteMiteMaxBytes) {
      throw const FormatException(
        'Journaled notification history exceeds bounds',
      );
    }
  }

  @override
  List<Object?> get props => [
    sequence,
    entries,
    notificationCursor,
    pendingPosts,
    notificationKnown,
    _notificationState,
  ];
}

Set<String> _notificationKeys(Object? raw) {
  if (raw is! List ||
      raw.any(
        (key) =>
            key is! String ||
            key.isEmpty ||
            key.length > miteMiteMaxMetadataBytes,
      )) {
    throw const FormatException('Invalid notification member identities');
  }
  final values = raw.cast<String>().toSet();
  if (values.length != raw.length) {
    throw const FormatException('Duplicate notification member identity');
  }
  return Set.unmodifiable(values);
}

void _checkPostIntent(SyncEvent event) {
  if (event.kind != SyncEventKind.received ||
      !const {'bookmarks', 'following_topics'}.contains(event.sourceKind) ||
      event.publisher == null ||
      event.source == null ||
      event.fingerprint == null ||
      !isSyncDigest(event.fingerprint!) ||
      event.notificationMembers.isEmpty ||
      event.notificationMembers.length > event.added) {
    throw const FormatException('Invalid committed Post notification intent');
  }
  syncUuid(event.publisher);
  syncUuid(event.source);
  _notificationKeys(event.notificationMembers.toList());
}
