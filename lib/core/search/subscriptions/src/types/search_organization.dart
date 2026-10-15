import 'package:equatable/equatable.dart';
import '../../../../groups/folder_tree.dart';

/// searchIds is a derived view for existing cards and selectors, never stored.
final class SharedSearchFolder extends CollectionFolder {
  SharedSearchFolder({
    required super.id,
    required String name,
    Iterable<String> searchIds = const [],
    super.parentId,
    int? position,
  }) : _explicitPosition = position != null,
       searchIds = List.unmodifiable(searchIds),
       super(name: name.trim(), position: position ?? 0);
  final List<String> searchIds;
  final bool _explicitPosition;
  @override
  List<Object?> get props => [...super.props, searchIds];
}

final class SearchOrganization extends Equatable {
  factory SearchOrganization.fromJson(Map<dynamic, dynamic> json) {
    final rows = json['folders'];
    if (rows is! List) {
      throw const FormatException('Invalid search organization');
    }
    if (json['version'] == 2) {
      final assignments = json['placements'];
      if (assignments is! List) {
        throw const FormatException('Invalid search placements');
      }
      final result = SearchOrganization(
        folders: [
          for (final row in rows)
            (() {
              final f = CollectionFolder.fromJson(row as Map);
              return SharedSearchFolder(
                id: f.id,
                name: f.name,
                parentId: f.parentId,
                position: f.position,
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
    final result = SearchOrganization(
      folders: [
        for (final (position, row) in rows.indexed)
          SharedSearchFolder(
            id: (row as Map)['id'] as String,
            name: row['name'] as String,
            position: position,
            searchIds: (row['searchIds'] as List).cast<String>(),
          ),
      ],
      homeSearchIds: home.cast<String>(),
    );
    result.tree.validatePlacements(result.placements);
    return result;
  }
  SearchOrganization({
    required Iterable<SharedSearchFolder> folders,
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
        SharedSearchFolder(
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
        ),
    ]);
  }
  late final List<SharedSearchFolder> folders;
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

  SearchOrganization move({
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
    var next = placements
        .where((p) => p.folderId == destination)
        .fold(0, (n, p) => p.position >= n ? p.position + 1 : n);
    return SearchOrganization(
      folders: [
        for (final f in movedFolders)
          SharedSearchFolder(
            id: f.id,
            name: f.name,
            parentId: f.parentId,
            position: f.position,
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
