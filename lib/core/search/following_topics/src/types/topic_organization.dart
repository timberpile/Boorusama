import 'package:equatable/equatable.dart';
import '../../../../groups/folder_tree.dart';
import 'topic_feed.dart';

/// searchIds is a derived view for existing cards and selectors, never stored.
final class TopicFolder extends CollectionFolder {
  TopicFolder({
    required super.id,
    required String name,
    Iterable<String> searchIds = const [],
    super.parentId,
    int? position,
    this.feedEnabled = false,
    this.feedMaxPosts = topicFeedRetention,
  }) : assert(feedMaxPosts > 0),
       _explicitPosition = position != null,
       searchIds = List.unmodifiable(searchIds),
       super(name: name.trim(), position: position ?? 0);
  final List<String> searchIds;
  final bool feedEnabled;
  final int feedMaxPosts;
  final bool _explicitPosition;

  @override
  TopicFolder copyWith({
    String? name,
    String? parentId,
    bool home = false,
    int? position,
    bool? feedEnabled,
    int? feedMaxPosts,
  }) => TopicFolder(
    id: id,
    name: name ?? this.name,
    parentId: home ? null : parentId ?? this.parentId,
    position: position ?? this.position,
    searchIds: searchIds,
    feedEnabled: feedEnabled ?? this.feedEnabled,
    feedMaxPosts: feedMaxPosts ?? this.feedMaxPosts,
  );

  @override
  Map<String, Object?> toJson() => {
    ...super.toJson(),
    'feedEnabled': feedEnabled,
    'feedMaxPosts': feedMaxPosts,
  };

  @override
  List<Object?> get props => [
    ...super.props,
    searchIds,
    feedEnabled,
    feedMaxPosts,
  ];
}

final class TopicOrganization extends Equatable {
  factory TopicOrganization.fromJson(Map<dynamic, dynamic> json) {
    final rows = json['folders'];
    if (rows is! List) {
      throw const FormatException('Invalid search organization');
    }
    if (json['version'] == 2) {
      final assignments = json['placements'];
      if (assignments is! List) {
        throw const FormatException('Invalid search placements');
      }
      final result = TopicOrganization(
        folders: [
          for (final row in rows)
            (() {
              final f = CollectionFolder.fromJson(row as Map);
              return TopicFolder(
                id: f.id,
                name: f.name,
                parentId: f.parentId,
                position: f.position,
                feedEnabled: row['feedEnabled'] == true,
                feedMaxPosts: switch (row['feedMaxPosts']) {
                  final int limit when limit > 0 => limit,
                  _ => topicFeedRetention,
                },
              );
            })(),
        ],
        placements: [
          for (final row in assignments) FolderPlacement.fromJson(row as Map),
        ],
      );
      result.tree.validatePlacements(result.placements);
      return result;
    }
    final home = json['homeSearchIds'];
    if (home is! List) throw const FormatException('Invalid legacy Home');
    final result = TopicOrganization(
      folders: [
        for (final (position, row) in rows.indexed)
          TopicFolder(
            id: (row as Map)['id'] as String,
            name: row['name'] as String,
            position: position,
            searchIds: (row['searchIds'] as List).cast<String>(),
            feedEnabled: row['feedEnabled'] == true,
            feedMaxPosts: switch (row['feedMaxPosts']) {
              final int limit when limit > 0 => limit,
              _ => topicFeedRetention,
            },
          ),
      ],
      homeSearchIds: home.cast<String>(),
    );
    result.tree.validatePlacements(result.placements);
    return result;
  }
  TopicOrganization({
    required Iterable<TopicFolder> folders,
    Iterable<String> homeSearchIds = const [],
    Iterable<FolderPlacement>? placements,
  }) {
    final raw = folders.toList();
    this.placements = List.unmodifiable(
      placements ??
          [
            for (final (position, id) in homeSearchIds.indexed)
              FolderPlacement(itemId: id, position: position),
            for (final folder in raw)
              for (final (position, id) in folder.searchIds.indexed)
                FolderPlacement(
                  itemId: id,
                  folderId: folder.id,
                  position: position,
                ),
          ],
    );
    // Lists exposed to callers are projections of the single placement source.
    final nextPosition = <String?, int>{};
    this.folders = List.unmodifiable([
      for (final f in raw)
        TopicFolder(
          id: f.id,
          name: f.name,
          parentId: f.parentId,
          position: f._explicitPosition
              ? f.position
              : nextPosition.update(
                  f.parentId,
                  (p) => p + 1,
                  ifAbsent: () => 0,
                ),
          searchIds: directIds(f.id),
          feedEnabled: f.feedEnabled,
          feedMaxPosts: f.feedMaxPosts,
        ),
    ]);
  }
  late final List<TopicFolder> folders;
  late final List<FolderPlacement> placements;
  List<String> directIds(String? folderId) {
    final ordered = placements.where((p) => p.folderId == folderId).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return [for (final p in ordered) p.itemId];
  }

  List<String> get homeSearchIds => directIds(null);
  FolderTree get tree => FolderTree(folders);
  List<String> recursiveIds(String folderId) {
    final ids = tree.subtree(folderId);
    return [
      for (final f in folders.where((f) => ids.contains(f.id)))
        ...directIds(f.id),
    ];
  }

  TopicOrganization move({
    Set<String> folderIds = const {},
    Set<String> searchIds = const {},
    required String? destination,
  }) {
    final movedFolders = tree.move(folderIds, destination);
    final contained = {for (final id in folderIds) ...tree.subtree(id)};
    final selected = searchIds
        .where(
          (id) => !placements.any(
            (p) => p.itemId == id && contained.contains(p.folderId),
          ),
        )
        .toSet();
    if (!placements.map((p) => p.itemId).toSet().containsAll(searchIds)) {
      throw const FormatException('Unknown search');
    }
    final originalById = {for (final folder in folders) folder.id: folder};
    var next = placements
        .where((p) => p.folderId == destination)
        .fold(0, (n, p) => p.position >= n ? p.position + 1 : n);
    return TopicOrganization(
      folders: [
        for (final f in movedFolders)
          TopicFolder(
            id: f.id,
            name: f.name,
            parentId: f.parentId,
            position: f.position,
            feedEnabled: originalById[f.id]!.feedEnabled,
            feedMaxPosts: originalById[f.id]!.feedMaxPosts,
          ),
      ],
      placements: [
        for (final p in placements)
          selected.contains(p.itemId) && p.folderId != destination
              ? FolderPlacement(
                  itemId: p.itemId,
                  folderId: destination,
                  position: next++,
                )
              : p,
      ],
    );
  }

  Map<String, Object?> toJson() => {
    'version': 2,
    'folders': [for (final f in folders) f.toJson()],
    'placements': [for (final p in placements) p.toJson()],
  };
  @override
  List<Object?> get props => [folders, placements];
}
