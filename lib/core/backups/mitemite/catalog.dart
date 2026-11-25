import 'bookmark_scope.dart';
import 'protocol.dart';

/// Legacy catalogs use explicit retirement entries.
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
        position > miteMiteMaxSequence ||
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
    Set<SyncCollectionId>? publicationRoots,
    this.completeSnapshot = false,
  }) : publisher = syncUuid(publisher),
       name = syncLabel(name),
       entries = List.unmodifiable(entries),
       publicationRoots = publicationRoots == null
           ? null
           : Set.unmodifiable(publicationRoots) {
    syncPositiveInteger(sequence);
    if (this.entries.length > miteMiteMaxEntries ||
        this.entries.any((entry) => entry.id.publisher != publisher) ||
        this.entries.map((entry) => entry.id).toSet().length !=
            this.entries.length) {
      throw const FormatException('Invalid sync catalog entries');
    }
    final roots = this.publicationRoots;
    if (completeSnapshot &&
        (roots == null ||
            this.entries.any(
              (entry) => entry.state != SyncPublicationState.active,
            ))) {
      throw const FormatException('Invalid complete publication snapshot');
    }
    if (roots != null) {
      final active = {
        for (final entry in this.entries)
          if (entry.state == SyncPublicationState.active) entry.id,
      };
      if (roots.length > miteMiteMaxEntries ||
          roots.any(
            (root) =>
                root.publisher != this.publisher || !active.contains(root),
          )) {
        throw const FormatException('Invalid explicit publication roots');
      }
    }
    // Tombstone links describe historical topology, not live hierarchy edges.
    // Active entries may point to an unpublished parent without subscribing to it.
    for (final kind in syncSourceKinds) {
      BookmarkSyncScope(
        publisher: publisher,
        directRoots: const {},
        nodes: [
          for (final entry in this.entries.where(
            (entry) =>
                entry.id.kind == kind &&
                entry.state == SyncPublicationState.active,
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
    if (json['protocol'] != miteMiteProtocol) {
      throw const SyncUpdateRequired();
    }
    final publisher = syncUuid(json['publisher']);
    final raw = json['collections'];
    if (raw is! List || raw.length > miteMiteMaxEntries) {
      throw const FormatException('Invalid sync catalog entries');
    }
    return SyncCatalog(
      publisher: publisher,
      sequence: syncPositiveInteger(json['sequence']),
      name: syncLabel(json['deviceName']),
      publicationRoots: _readPublicationRoots(json),
      completeSnapshot: json['publicationScopeVersion'] == 2,
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
  final bool completeSnapshot;

  /// Null means an older publisher did not advertise directness. It is never
  /// inferred from hierarchy; existing subscriptions may still reconcile.
  final Set<SyncCollectionId>? publicationRoots;
  Iterable<SyncCatalogEntry> get offeredEntries => entries.where(
    (entry) =>
        entry.state == SyncPublicationState.active &&
        (publicationRoots?.contains(entry.id) ?? false),
  );

  static Set<SyncCollectionId>? _readPublicationRoots(
    Map<String, dynamic> json,
  ) {
    if (!json.containsKey('publicationScopeVersion') &&
        !json.containsKey('publicationRoots')) {
      return null;
    }
    final version = json['publicationScopeVersion'];
    if (version != 1 && version != 2) throw const SyncUpdateRequired();
    final raw = json['publicationRoots'];
    if (raw is! List || raw.length > miteMiteMaxEntries) {
      throw const FormatException('Invalid explicit publication roots');
    }
    final roots = <SyncCollectionId>{};
    for (final value in raw) {
      if (value is! Map<String, dynamic> ||
          !roots.add(SyncCollectionId.fromJson(value))) {
        throw const FormatException('Invalid or duplicate publication root');
      }
    }
    return roots;
  }

  String get path => 'devices/$publisher/catalog/$sequence.json';
  Map<String, Object?> toJson() => {
    'protocol': miteMiteProtocol,
    'publisher': publisher,
    'sequence': sequence,
    'deviceName': name,
    'collections': [for (final entry in entries) entry.toJson()],
    if (publicationRoots != null) ...{
      'publicationScopeVersion': completeSnapshot ? 2 : 1,
      'publicationRoots': [
        for (final root
            in publicationRoots!.toList()
              ..sort((a, b) => a.key.compareTo(b.key)))
          root.toJson(),
      ],
    },
  };
}
