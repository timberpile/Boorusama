import 'bookmark_scope.dart';
import 'protocol.dart';

/// Only explicit signed states carry withdrawal evidence. Absence has no state.
enum SyncPublicationState { active, withdrawn, deleted }

String syncLabel(Object? value) {
  final label = syncString(value);
  if (label.trim().isEmpty ||
      label.length > 160 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(label)) {
    throw const FormatException('Invalid sync label');
  }
  return label;
}

final class SyncCatalogEntry {
  SyncCatalogEntry({
    required this.id,
    required String name,
    required this.state,
    this.revision,
    String? parent,
    this.position = 0,
  }) : name = syncLabel(name),
       parent = parent == null ? null : syncUuid(parent) {
    if (position < 0 ||
        position > folderSyncMaxSequence ||
        parent == id.source ||
        (state == SyncPublicationState.active && revision == null) ||
        (revision != null && revision!.collection != id)) {
      throw const FormatException('Invalid sync collection advertisement');
    }
  }

  factory SyncCatalogEntry.fromJson(
    Map<String, dynamic> json,
    String publisher,
  ) {
    final rawRevision = json['revision'];
    final position = json['position'];
    if (position is! int ||
        (rawRevision != null && rawRevision is! Map<String, dynamic>)) {
      throw const FormatException('Invalid sync collection advertisement');
    }
    return SyncCatalogEntry(
      id: SyncCollectionId(
        publisher: publisher,
        kind: syncString(json['kind']),
        source: syncUuid(json['source']),
      ),
      name: syncLabel(json['name']),
      parent: json['parent'] == null ? null : syncUuid(json['parent']),
      position: position,
      state: switch (json['state']) {
        'active' => SyncPublicationState.active,
        'withdrawn' => SyncPublicationState.withdrawn,
        'deleted' => SyncPublicationState.deleted,
        _ => throw const SyncUpdateRequired(),
      },
      revision: rawRevision == null
          ? null
          : SyncRevision.fromJson(rawRevision as Map<String, dynamic>),
    );
  }

  final SyncCollectionId id;
  final String name;
  final String? parent;
  final int position;
  final SyncPublicationState state;
  final SyncRevision? revision;
  Map<String, Object?> toJson() => {
    'kind': id.kind,
    'source': id.source,
    'name': name,
    'parent': parent,
    'position': position,
    'state': state.name,
    'revision': revision?.toJson(),
  };
}

/// Complete typed discovery metadata. This object alone grants no trust or write
/// authority; the catalog gate and transaction must still validate freshness.
final class SyncCatalog {
  SyncCatalog({
    required String publisher,
    required this.sequence,
    required String name,
    required Iterable<SyncCatalogEntry> entries,
  }) : publisher = syncUuid(publisher),
       name = syncLabel(name),
       entries = List.unmodifiable(entries) {
    syncPositiveInteger(sequence);
    if (this.entries.length > folderSyncMaxEntries ||
        this.entries.any((entry) => entry.id.publisher != publisher) ||
        this.entries.map((entry) => entry.id).toSet().length !=
            this.entries.length) {
      throw const FormatException('Invalid sync catalog entries');
    }
    // The existing iterative scope validator catches cycles without recursion.
    for (final kind in syncSourceKinds) {
      BookmarkSyncScope(
        publisher: publisher,
        directRoots: const {},
        nodes: [
          for (final entry in this.entries.where(
            (entry) => entry.id.kind == kind,
          ))
            SyncBookmarkNode(
              source: entry.id.source,
              parent: entry.parent,
              position: entry.position,
            ),
        ],
      );
    }
  }

  factory SyncCatalog.fromJson(Map<String, dynamic> json) {
    if (json['protocol'] != folderSyncProtocol) {
      throw const SyncUpdateRequired();
    }
    final publisher = syncUuid(json['publisher']);
    final raw = json['collections'];
    if (raw is! List || raw.length > folderSyncMaxEntries) {
      throw const FormatException('Invalid sync catalog entries');
    }
    return SyncCatalog(
      publisher: publisher,
      sequence: syncPositiveInteger(json['sequence']),
      name: syncLabel(json['deviceName']),
      entries: [
        for (final entry in raw)
          if (entry is Map<String, dynamic>)
            SyncCatalogEntry.fromJson(entry, publisher)
          else
            throw const FormatException('Invalid sync catalog entry'),
      ],
    );
  }

  final String publisher;
  final int sequence;
  final String name;
  final List<SyncCatalogEntry> entries;
  String get path => 'devices/$publisher/catalog/$sequence.json';
  Map<String, Object?> toJson() => {
    'protocol': folderSyncProtocol,
    'publisher': publisher,
    'sequence': sequence,
    'deviceName': name,
    'collections': [for (final entry in entries) entry.toJson()],
  };
}
