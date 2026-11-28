import '../../../backups/mitemite/activity_log.dart';

import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'bookmark.dart';
import '../../../../foundation/data_mutation_coordinator.dart';
import 'bookmark_group.dart';

String _uuid(Object? value) {
  if (value is! String ||
      value != value.toLowerCase() ||
      !Uuid.isValidUUID(fromString: value)) {
    throw const FormatException('Invalid Bookmark mirror identity');
  }
  return value;
}

int _number(Object? value) {
  if (value is! int || value < 0 || value > 9007199254740991) {
    throw const FormatException('Invalid Bookmark mirror revision');
  }
  return value;
}

String _digest(Object? value) {
  if (value is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw const FormatException('Invalid Bookmark mirror digest');
  }
  return value;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) {
    throw const FormatException('Invalid Bookmark mirror metadata');
  }
  return Map<String, dynamic>.from(value);
}

String bookmarkMirrorGroupDigest(BookmarkGroup group) {
  final members = group.bookmarkIds.toList()..sort();
  return sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'id': group.id,
            'name': group.name,
            'parent': group.parentGroupId,
            'folder': group.folderId,
            'position': group.position,
            'members': members,
            'addedAt': {
              for (final id in members)
                '$id': group.addedAt[id]?.toUtc().toIso8601String(),
            },
          }),
        ),
      )
      .toString();
}

/// Private local ownership, never accepted from ordinary transfer files.
final class BookmarkMirrorOwner extends Equatable {
  BookmarkMirrorOwner({
    required String publisher,
    required String source,
    required this.revision,
    required String payloadDigest,
    required String groupDigest,
    String? parentSource,
    this.position = 0,
    this.descriptorDigest,
    this.bookmarkBucketManifest,
    this.retired = false,
    Map<String, dynamic> reading = const {},
  }) : publisher = _uuid(publisher),
       source = _uuid(source),
       parentSource = parentSource == null ? null : _uuid(parentSource),
       payloadDigest = _digest(payloadDigest),
       groupDigest = _digest(groupDigest),
       _reading = jsonEncode(reading) {
    if (descriptorDigest != null) _digest(descriptorDigest);
    _number(revision);
    _number(position);
    if (revision == 0 || parentSource == source) {
      throw const FormatException('Invalid Bookmark mirror owner');
    }
  }
  BookmarkMirrorOwner.advanceBucketHead(
    BookmarkMirrorOwner previous, {
    required this.revision,
    required String descriptorDigest,
    required this.payloadDigest,
    required String bookmarkBucketManifest,
  }) : publisher = previous.publisher,
       source = previous.source,
       parentSource = previous.parentSource,
       position = previous.position,
       groupDigest = previous.groupDigest,
       retired = false,
       descriptorDigest = _digest(descriptorDigest),
       bookmarkBucketManifest = bookmarkBucketManifest,
       _reading = previous._reading {
    _number(revision);
    if (previous.retired || revision <= previous.revision) {
      throw const FormatException('Invalid Bookmark bucket head');
    }
    _digest(payloadDigest);
  }

  factory BookmarkMirrorOwner.fromJson(Object? value) {
    final map = _map(value);
    return BookmarkMirrorOwner(
      publisher: _uuid(map['publisher']),
      source: _uuid(map['source']),
      revision: _number(map['revision']),
      descriptorDigest: map['descriptorDigest'] as String?,
      bookmarkBucketManifest: map['bookmarkBucketManifest'] as String?,
      retired: map['retired'] as bool? ?? false,
      payloadDigest: _digest(map['payloadDigest']),
      groupDigest: _digest(map['groupDigest']),
      parentSource: map['parent'] as String?,
      position: _number(map['position']),
      reading: _map(map['reading']),
    );
  }
  final String publisher;
  final String source;
  final String? parentSource;
  final int position;
  final int revision;
  final String? descriptorDigest;
  final String? bookmarkBucketManifest;
  final bool retired;
  final String payloadDigest;
  final String groupDigest;
  final String _reading;

  Map<String, dynamic> get reading => _map(jsonDecode(_reading));
  bool hasSameReading(BookmarkMirrorOwner other) => _reading == other._reading;
  String get sourceKey => '$publisher/$source';
  Map<String, Object?> toJson({Map<String, Object?>? storedReading}) => {
    'publisher': publisher,
    'source': source,
    'parent': parentSource,
    'position': position,
    'revision': revision,
    'descriptorDigest': descriptorDigest,
    if (bookmarkBucketManifest != null)
      'bookmarkBucketManifest': bookmarkBucketManifest,
    'retired': retired,
    'payloadDigest': payloadDigest,
    'groupDigest': groupDigest,
    'reading': storedReading ?? reading,
  };
  BookmarkMirrorOwner withSeenState(Map<String, dynamic> value) =>
      BookmarkMirrorOwner(
        publisher: publisher,
        source: source,
        revision: revision,
        payloadDigest: payloadDigest,
        groupDigest: groupDigest,
        descriptorDigest: descriptorDigest,
        bookmarkBucketManifest: bookmarkBucketManifest,
        parentSource: parentSource,
        position: position,
        retired: retired,
        reading: value,
      );

  BookmarkMirrorOwner retire({
    int? revision,
    String? payloadDigest,
    String? descriptorDigest,
  }) => BookmarkMirrorOwner(
    publisher: publisher,
    source: source,
    revision: revision ?? this.revision,
    payloadDigest: payloadDigest ?? this.payloadDigest,
    groupDigest: groupDigest,
    descriptorDigest: descriptorDigest ?? this.descriptorDigest,
    bookmarkBucketManifest: bookmarkBucketManifest,
    parentSource: parentSource,
    position: position,
    reading: reading,
    retired: true,
  );
  @override
  List<Object?> get props => [
    publisher,
    source,
    parentSource,
    position,
    revision,
    descriptorDigest,
    bookmarkBucketManifest,
    retired,
    payloadDigest,
    groupDigest,
    _reading,
  ];
}

/// Ownership, explicit roots and receiver state commit in the SAME journal as
/// source-owned memberships. A separate preference write cannot authorize edits.
final class BookmarkMirrorState extends Equatable {
  BookmarkMirrorState({
    required this.epoch,
    this.activity = const SyncActivityLog.empty(),
    required Map<String, BookmarkMirrorOwner> owners,
    Map<String, BookmarkMirrorOwner> checkpoints = const {},
    Map<String, Set<String>> subscriptions = const {},
    Map<String, String> publisherNames = const {},
    Map<String, String> aliases = const {},
    Set<String> forgotten = const {},
  }) : owners = Map.unmodifiable(owners),
       checkpoints = Map.unmodifiable({
         ...checkpoints,
         for (final owner in owners.values) owner.sourceKey: owner,
       }),
       subscriptions = Map.unmodifiable(
         subscriptions.map(
           (publisher, roots) => MapEntry(
             _uuid(publisher),
             Set<String>.unmodifiable(roots.map(_uuid)),
           ),
         ),
       ),
       publisherNames = Map.unmodifiable(publisherNames),
       aliases = Map.unmodifiable(aliases),
       forgotten = Set.unmodifiable(forgotten.map(_uuid)) {
    _number(epoch);
    final sources = <String>{};
    for (final entry in owners.entries) {
      _uuid(entry.key);
      if (entry.key == defaultBookmarkGroupId ||
          !sources.add(entry.value.sourceKey)) {
        throw const FormatException('Mirror mapping is not canonical');
      }
    }
    for (final entry in this.checkpoints.entries) {
      if (entry.key != entry.value.sourceKey) {
        throw const FormatException('Invalid source checkpoint');
      }
    }
    for (final entry in {...publisherNames, ...aliases}.entries) {
      _uuid(entry.key);
      if (entry.value.trim().isEmpty ||
          entry.value.length > 160 ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(entry.value)) {
        throw const FormatException('Invalid mirror publisher label');
      }
    }
  }
  const BookmarkMirrorState.empty()
    : activity = const SyncActivityLog.empty(),
      epoch = 0,
      owners = const {},
      checkpoints = const {},
      subscriptions = const {},
      publisherNames = const {},
      aliases = const {},
      forgotten = const {};
  factory BookmarkMirrorState.fromJson(Object? value) {
    final map = _map(value);
    if (map['version'] != 1) {
      throw const FormatException('Unsupported Bookmark mirror schema');
    }
    return BookmarkMirrorState(
      activity: map['activity'] == null
          ? const SyncActivityLog.empty()
          : SyncActivityLog.fromJson(
              Map<String, dynamic>.from(map['activity'] as Map),
            ),
      epoch: _number(map['epoch']),
      owners: _map(
        map['owners'],
      ).map((key, value) => MapEntry(key, BookmarkMirrorOwner.fromJson(value))),
      checkpoints: _map(map['checkpoints'] ?? {}).map(
        (key, value) => MapEntry(key, BookmarkMirrorOwner.fromJson(value)),
      ),
      subscriptions: _map(map['subscriptions']).map((key, value) {
        if (value is! List) {
          throw const FormatException('Invalid mirror subscription roots');
        }
        return MapEntry(key, value.map(_uuid).toSet());
      }),
      publisherNames: _map(map['publisherNames']).cast<String, String>(),
      aliases: _map(map['aliases']).cast<String, String>(),
      forgotten: (map['forgotten'] as List? ?? const []).map(_uuid).toSet(),
    );
  }
  final Set<String> forgotten;
  final SyncActivityLog activity;
  final int epoch;
  final Map<String, BookmarkMirrorOwner> owners;

  /// Survives unsubscribe, signed cleanup and Forget/reapproval.
  final Map<String, BookmarkMirrorOwner> checkpoints;
  final Map<String, Set<String>> subscriptions;
  final Map<String, String> publisherNames;
  final Map<String, String> aliases;
  bool isReceived(String groupId) => owners.containsKey(groupId);
  String? localIdFor(String publisher, String source) => owners.entries
      .where(
        (entry) =>
            entry.value.publisher == publisher && entry.value.source == source,
      )
      .firstOrNull
      ?.key;
  Map<String, Object?> toJson({
    bool compact = false,
    Map<String, Object?> Function(BookmarkMirrorOwner)? encodeOwner,
  }) {
    Map<String, Object?> encode(BookmarkMirrorOwner owner) =>
        encodeOwner?.call(owner) ?? owner.toJson();
    final active = compact
        ? {for (final owner in owners.values) owner.sourceKey}
        : const <String>{};
    return {
      'version': 1,
      'epoch': epoch,
      'activity': activity.toJson(),
      'owners': owners.map((key, value) => MapEntry(key, encode(value))),
      'checkpoints': {
        for (final entry in checkpoints.entries)
          if (!active.contains(entry.key)) entry.key: encode(entry.value),
      },
      'subscriptions': subscriptions.map(
        (key, value) => MapEntry(key, value.toList()..sort()),
      ),
      'forgotten': forgotten.toList()..sort(),
      'publisherNames': publisherNames,
      'aliases': aliases,
    };
  }

  @override
  List<Object?> get props => [
    epoch,
    activity,
    owners,
    checkpoints,
    subscriptions,
    publisherNames,
    aliases,
    forgotten,
  ];
}

/// Read-only authority available to ordinary library views and write-through
/// wrappers. Reading ownership never grants the ability to commit mirror data.
abstract interface class BookmarkMirrorReader {
  Future<BookmarkMirrorState> readMirrorState();
}

/// A source-owned membership patch. Bucket ordinals are private index keys
/// here. The receive protocol verifies that portable members belong to them.
final class BookmarkMirrorMembershipPatch {
  const BookmarkMirrorMembershipPatch(this.buckets);

  final Map<int, Map<int, DateTime?>> buckets;
}

/// Narrow repository boundary for trusted receive orchestration. It can alter
/// received Groups, plus explicit fresh Local Copies without changing source
/// authority. Existing local Group ownership is never captured by an import.
abstract interface class BookmarkMirrorStore implements BookmarkMirrorReader {
  DataMutationCoordinator get coordinator;
  Future<void> commitMirrorOrganization({
    required BookmarkMirrorState expected,
    required BookmarkMirrorState next,
    Iterable<Bookmark> records = const [],
    Set<int> removeIds = const {},
    List<BookmarkGroup> groups = const [],
    Set<String> removeGroupIds = const {},

    /// Explicit Local Copy: only fresh Local Groups, with unchanged source authority.
    bool localCopy = false,
    Set<String> purgedSources = const {},
    bool streamRecords = false,
    Map<String, BookmarkMirrorMembershipPatch> membershipPatches = const {},
  });
}

final class BookmarkMirrorReadOnly implements Exception {
  const BookmarkMirrorReadOnly();
}
