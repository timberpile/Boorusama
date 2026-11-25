import '../../../../backups/mitemite/activity_log.dart';

import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'following_topic.dart';
import 'topic_organization.dart';

enum FollowingMirrorKind { topic, folder }

/// Received roots retain their source sibling namespace even when their parent
/// is not subscribed locally. This is presentation validation, never authority.
String followingFolderNameScope(String publisher, String? parentSource) =>
    '$publisher/${parentSource ?? 'home'}';

/// Source identities/order only. Local binding, Post NEW and cache are absent.
final class FollowingDefinitionChild extends Equatable {
  FollowingDefinitionChild({
    required String source,
    required this.kind,
    required this.position,
  }) : source = _uuid(source) {
    if (position < 0) throw const FollowingMirrorConflict();
  }
  final String source;
  final FollowingMirrorKind kind;
  final int position;
  Map<String, Object> toJson() => {
    'source': source,
    'kind': kind.name,
    'position': position,
  };
  @override
  List<Object?> get props => [source, kind, position];
}

List<FollowingDefinitionChild> orderedFollowingDefinitionChildren(
  Iterable<FollowingDefinitionChild> children,
) => List.unmodifiable(
  children.toList()..sort((a, b) {
    final position = a.position.compareTo(b.position);
    if (position != 0) return position;
    final kind = a.kind.name.compareTo(b.kind.name);
    return kind != 0 ? kind : a.source.compareTo(b.source);
  }),
);

String followingDefinitionDigest({
  required FollowingMirrorKind kind,
  required String? parentSource,
  required int position,
  FollowingTopic? topic,
  TopicFolder? folder,
  Map<String, dynamic>? profile,
  Iterable<FollowingDefinitionChild> children = const [],
}) => sha256
    .convert(
      utf8.encode(
        jsonEncode({
          'kind': kind.name,
          'parent': parentSource,
          'position': position,
          if (kind == FollowingMirrorKind.topic) ...{
            'name': topic!.name,
            'query': topic.query,
            'queryStructure': topic.queryStructure?.toJson(),
            'profile': followingDefinitionProfile(profile),
          } else ...{
            'name': folder!.name,
            'feedEnabled': folder.feedEnabled,
            'feedMaxPosts': folder.feedMaxPosts,
            'children': orderedFollowingDefinitionChildren(children)
                .map((child) => child.toJson())
                .toList(),
          },
        }),
      ),
    )
    .toString();

Map<String, Object?>? followingDefinitionProfile(
  Map<String, dynamic>? profile,
) => profile == null
    ? null
    : {'booruType': profile['booruType'], 'url': profile['url']};

final class FollowingMirrorReadOnly implements Exception {
  const FollowingMirrorReadOnly();
}

final class FollowingMirrorConflict implements Exception {
  const FollowingMirrorConflict();
}

String _uuid(Object? value) {
  if (value is! String ||
      value != value.toLowerCase() ||
      !Uuid.isValidUUID(fromString: value)) {
    throw const FormatException('Invalid Following mirror identity');
  }
  return value;
}

String _digest(Object? value) {
  if (value is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw const FormatException('Invalid Following mirror digest');
  }
  return value;
}

/// Publisher-owned definition identity and receiver-local definition receipt.
/// Post refresh, NEW, cache and reading live in the existing Topic/Feed state.
final class FollowingMirrorOwner extends Equatable {
  FollowingMirrorOwner({
    required String publisher,
    required String source,
    required this.kind,
    required this.revision,
    required String payloadDigest,
    required String descriptorDigest,
    required String definitionDigest,
    String? seenDefinitionDigest,
    String? parentSource,
    this.position = 0,
    this.retired = false,
    Map<String, dynamic>? profile,
  }) : publisher = _uuid(publisher),
       source = _uuid(source),
       parentSource = parentSource == null ? null : _uuid(parentSource),
       payloadDigest = _digest(payloadDigest),
       descriptorDigest = _digest(descriptorDigest),
       definitionDigest = _digest(definitionDigest),
       seenDefinitionDigest = seenDefinitionDigest == null
           ? null
           : _digest(seenDefinitionDigest),
       _profile = profile == null ? null : jsonEncode(profile) {
    if (revision < 1 || position < 0 || parentSource == source) {
      throw const FormatException('Invalid Following mirror revision');
    }
  }

  factory FollowingMirrorOwner.fromJson(Map<String, dynamic> json) {
    if (json['definitionSchema'] != 'profileAndChildren') {
      throw const FormatException(
        'Unsupported Following mirror definition schema',
      );
    }
    return FollowingMirrorOwner(
      publisher: json['publisher'] as String,
      source: json['source'] as String,
      kind: FollowingMirrorKind.values.byName(json['kind'] as String),
      revision: json['revision'] as int,
      payloadDigest: json['payloadDigest'] as String,
      descriptorDigest: json['descriptorDigest'] as String,
      definitionDigest: json['definitionDigest'] as String,
      seenDefinitionDigest: json['seenDefinitionDigest'] as String?,
      parentSource: json['parent'] as String?,
      position: json['position'] as int,
      retired: json['retired'] as bool? ?? false,
      profile: (json['profile'] as Map?)?.cast<String, dynamic>(),
    );
  }

  final String publisher;
  final String source;
  final FollowingMirrorKind kind;
  final String? parentSource;
  final int position;
  final int revision;
  final String payloadDigest;
  final String descriptorDigest;
  final String definitionDigest;
  final String? seenDefinitionDigest;
  final bool retired;
  final String? _profile;
  Map<String, dynamic>? get profile =>
      _profile == null ? null : jsonDecode(_profile) as Map<String, dynamic>;
  String get sourceKey => '$publisher/$source';
  String get folderNameScope =>
      followingFolderNameScope(publisher, parentSource);
  bool get hasDefinitionChange => seenDefinitionDigest != definitionDigest;

  FollowingMirrorOwner copyWith({
    bool? retired,
    bool acknowledge = false,
  }) => FollowingMirrorOwner(
    publisher: publisher,
    source: source,
    kind: kind,
    parentSource: parentSource,
    position: position,
    revision: revision,
    payloadDigest: payloadDigest,
    descriptorDigest: descriptorDigest,
    definitionDigest: definitionDigest,
    seenDefinitionDigest: acknowledge ? definitionDigest : seenDefinitionDigest,
    retired: retired ?? this.retired,
    profile: profile,
  );

  Map<String, Object?> toJson() => {
    'publisher': publisher,
    'source': source,
    'kind': kind.name,
    'parent': parentSource,
    'position': position,
    'revision': revision,
    'payloadDigest': payloadDigest,
    'descriptorDigest': descriptorDigest,
    'definitionDigest': definitionDigest,
    'definitionSchema': 'profileAndChildren',
    'seenDefinitionDigest': seenDefinitionDigest,
    'retired': retired,
    'profile': profile,
  };

  @override
  List<Object?> get props => [
    publisher,
    source,
    kind,
    parentSource,
    position,
    revision,
    payloadDigest,
    descriptorDigest,
    definitionDigest,
    seenDefinitionDigest,
    retired,
    _profile,
  ];
}

final class FollowingMirrorState extends Equatable {
  FollowingMirrorState({
    required this.epoch,
    this.activity = const SyncActivityLog.empty(),
    required Map<String, FollowingMirrorOwner> owners,
    Map<String, FollowingMirrorOwner> checkpoints = const {},
    Map<String, Set<String>> subscriptions = const {},
    Map<String, String> publisherNames = const {},
  }) : owners = Map.unmodifiable(owners),
       checkpoints = Map.unmodifiable({
         ...checkpoints,
         for (final owner in owners.values) owner.sourceKey: owner,
       }),
       subscriptions = Map.unmodifiable({
         for (final e in subscriptions.entries)
           _uuid(e.key): Set<String>.unmodifiable(e.value.map(_uuid)),
       }),
       publisherNames = Map.unmodifiable(publisherNames) {
    if (epoch < 0 || owners.length > 10000 || this.checkpoints.length > 10000) {
      throw const FormatException('Invalid Following mirror metadata bounds');
    }
    final identities = <String>{};
    for (final entry in owners.entries) {
      _uuid(entry.key);
      if (entry.value.retired || !identities.add(entry.value.sourceKey)) {
        throw const FormatException('Invalid Following mirror ownership');
      }
    }
    for (final entry in this.checkpoints.entries) {
      if (entry.key != entry.value.sourceKey) {
        throw const FormatException('Invalid Following mirror checkpoint');
      }
    }
  }
  const FollowingMirrorState.empty()
    : activity = const SyncActivityLog.empty(),
      epoch = 0,
      owners = const {},
      checkpoints = const {},
      subscriptions = const {},
      publisherNames = const {};

  factory FollowingMirrorState.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported Following mirror metadata');
    }
    Map<String, FollowingMirrorOwner> owners(Object? value) => {
      for (final entry in (value! as Map).entries)
        entry.key as String: FollowingMirrorOwner.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        ),
    };
    return FollowingMirrorState(
      activity: json['activity'] == null
          ? const SyncActivityLog.empty()
          : SyncActivityLog.fromJson(
              Map<String, dynamic>.from(json['activity'] as Map),
            ),
      epoch: json['epoch'] as int,
      owners: owners(json['owners']),
      checkpoints: owners(json['checkpoints']),
      subscriptions: {
        for (final entry in (json['subscriptions'] as Map).entries)
          entry.key as String: (entry.value as List).cast<String>().toSet(),
      },
      publisherNames: (json['publisherNames'] as Map).cast<String, String>(),
    );
  }

  final SyncActivityLog activity;
  final int epoch;
  final Map<String, FollowingMirrorOwner> owners;
  final Map<String, FollowingMirrorOwner> checkpoints;
  final Map<String, Set<String>> subscriptions;
  final Map<String, String> publisherNames;
  bool isReceived(String id) => owners.containsKey(id);
  String? localIdFor(String publisher, String source) => owners.entries
      .where((e) => e.value.publisher == publisher && e.value.source == source)
      .firstOrNull
      ?.key;
  Map<String, Object?> toJson() => {
    'version': 1,
    'epoch': epoch,
    'activity': activity.toJson(),
    'owners': {for (final e in owners.entries) e.key: e.value.toJson()},
    'checkpoints': {
      for (final e in checkpoints.entries) e.key: e.value.toJson(),
    },
    'subscriptions': {
      for (final e in subscriptions.entries) e.key: e.value.toList()..sort(),
    },
    'publisherNames': publisherNames,
  };
  @override
  List<Object?> get props => [
    epoch,
    activity,
    owners,
    checkpoints,
    subscriptions,
    publisherNames,
  ];
}

final class FollowingMirrorSnapshot {
  const FollowingMirrorSnapshot({
    required this.mirrors,
    required this.topics,
    required this.organization,
    required this.structureDigest,
  });
  final FollowingMirrorState mirrors;
  final List<FollowingTopic> topics;
  final TopicOrganization organization;
  final String structureDigest;
}

/// Index actual topology once, including checks against unexpected local or
/// foreign children. Using only owner metadata would miss unauthorized moves.
Map<String, List<FollowingDefinitionChild>> followingFolderDefinitionChildren(
  FollowingMirrorSnapshot snapshot,
) {
  final result = <String, List<FollowingDefinitionChild>>{
    for (final entry in snapshot.mirrors.owners.entries)
      if (entry.value.kind == FollowingMirrorKind.folder) entry.key: [],
  };
  void add(String id, String? parent, FollowingMirrorKind kind, int position) {
    final parentOwner = snapshot.mirrors.owners[parent];
    if (parentOwner == null) return;
    final owner = snapshot.mirrors.owners[id];
    if (parentOwner.kind != FollowingMirrorKind.folder ||
        owner == null ||
        owner.publisher != parentOwner.publisher ||
        owner.parentSource != parentOwner.source ||
        owner.kind != kind) {
      throw const FollowingMirrorConflict();
    }
    result[parent]!.add(
      FollowingDefinitionChild(
        source: owner.source,
        kind: kind,
        position: position,
      ),
    );
  }

  for (final folder in snapshot.organization.folders) {
    add(
      folder.id,
      folder.parentId,
      FollowingMirrorKind.folder,
      folder.position,
    );
  }
  for (final placement in snapshot.organization.placements) {
    add(
      placement.itemId,
      placement.folderId,
      FollowingMirrorKind.topic,
      placement.position,
    );
  }
  return Map.unmodifiable({
    for (final entry in result.entries)
      entry.key: orderedFollowingDefinitionChildren(entry.value),
  });
}

/// Compute the stored definition digest for each source-owned row.
Map<String, String> followingSnapshotDefinitionDigests(
  FollowingMirrorSnapshot snapshot,
) {
  final topics = {for (final topic in snapshot.topics) topic.id: topic};
  final folders = {
    for (final folder in snapshot.organization.folders) folder.id: folder,
  };
  final placements = {
    for (final p in snapshot.organization.placements) p.itemId: p,
  };
  final localIds = {
    for (final e in snapshot.mirrors.owners.entries) e.value.sourceKey: e.key,
  };
  final children = followingFolderDefinitionChildren(snapshot);
  final result = <String, String>{};
  for (final entry in snapshot.mirrors.owners.entries) {
    final owner = entry.value;
    final topic = topics[entry.key];
    final folder = folders[entry.key];
    final placement = placements[entry.key];
    if (owner.kind == FollowingMirrorKind.topic
        ? topic == null || placement == null
        : folder == null || folder.nameScope != owner.folderNameScope) {
      throw const FollowingMirrorConflict();
    }
    final parent = owner.kind == FollowingMirrorKind.topic
        ? placement!.folderId
        : folder!.parentId;
    final expectedParent = owner.parentSource == null
        ? null
        : localIds['${owner.publisher}/${owner.parentSource}'];
    if (parent != expectedParent ||
        (parent != null &&
            snapshot.mirrors.owners[parent]?.publisher != owner.publisher)) {
      throw const FollowingMirrorConflict();
    }
    // An independently subscribed root keeps its remote parent identity even
    // while that parent is absent locally. Virtual root links do not copy it.
    result[entry.key] = followingDefinitionDigest(
      kind: owner.kind,
      profile: owner.profile,
      parentSource: owner.parentSource,
      position: owner.kind == FollowingMirrorKind.topic
          ? placement!.position
          : folder!.position,
      topic: topic,
      folder: folder,
      children: children[entry.key] ?? const [],
    );
  }
  return Map.unmodifiable(result);
}

/// History delivery need not deserialize every cached Post or query structure.
abstract interface class FollowingMirrorActivityReader {
  Future<SyncActivityLog> readMirrorActivity();
}

/// Retires durable native intent only after receiver-local outbox persistence.
abstract interface class FollowingNotificationReceiptStore {
  Future<void> acknowledgeMirrorNotifications(int cursor);
}

/// A production store can acknowledge one Feed entry in one journal commit.
abstract interface class FollowingDefinitionReceiptStore {
  Future<void> acknowledgeMirrorDefinitions(Map<String, String> captured);
}

/// Deliberately separate from ordinary definition editing and runtime refresh.
abstract interface class FollowingMirrorStore {
  Future<FollowingMirrorSnapshot> readMirrorSnapshot();
  Future<void> commitMirrorDefinitions({
    required FollowingMirrorState expected,
    required String expectedStructureDigest,
    required FollowingMirrorState next,
    required List<FollowingTopic> topics,
    required TopicOrganization organization,
    Set<String> removeTopicIds = const {},
    Set<String> purgedSources = const {},
  });
  Future<void> acknowledgeMirrorDefinition(
    String localId, {
    String? definitionDigest,
  });
}

/// Receiver-local definition receipts, shared by canonical overlapping roots.
Map<String, String> unseenFollowingTopicDefinitions(
  FollowingMirrorState mirrors,
  TopicOrganization organization,
  String localId,
) {
  final root = mirrors.owners[localId];
  if (root == null) return const {};
  final ids = root.kind == FollowingMirrorKind.topic
      ? {localId}
      : organization.recursiveIds(localId).toSet();
  return Map.unmodifiable({
    for (final id in ids)
      if (mirrors.owners[id] case final owner?)
        if (owner.kind == FollowingMirrorKind.topic &&
            owner.publisher == root.publisher &&
            owner.hasDefinitionChange)
          id: owner.definitionDigest,
  });
}
