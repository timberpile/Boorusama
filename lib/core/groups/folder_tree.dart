import 'package:equatable/equatable.dart';

/// Collection-local folder identity. Home is represented by a null parent.
class CollectionFolder extends Equatable {
  const CollectionFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.position = 0,
  });
  factory CollectionFolder.fromJson(Map<dynamic, dynamic> json) {
    if (json['id'] is! String ||
        json['name'] is! String ||
        (json['parentId'] != null && json['parentId'] is! String) ||
        json['position'] is! int) {
      throw const FormatException('Invalid folder record');
    }
    return CollectionFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parentId'] as String?,
      position: json['position'] as int,
    );
  }
  final String id;
  final String name;
  final String? parentId;
  final int position;
  CollectionFolder copyWith({
    String? name,
    String? parentId,
    bool home = false,
    int? position,
  }) => CollectionFolder(
    id: id,
    name: name ?? this.name,
    parentId: home ? null : parentId ?? this.parentId,
    position: position ?? this.position,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'parentId': parentId,
    'position': position,
  };
  @override
  List<Object?> get props => [id, name, parentId, position];
}

class FolderPlacement extends Equatable {
  const FolderPlacement({
    required this.itemId,
    this.folderId,
    this.position = 0,
  });
  factory FolderPlacement.fromJson(Map<dynamic, dynamic> json) {
    if (json['itemId'] is! String ||
        (json['folderId'] != null && json['folderId'] is! String) ||
        json['position'] is! int) {
      throw const FormatException('Invalid item placement');
    }
    return FolderPlacement(
      itemId: json['itemId'] as String,
      folderId: json['folderId'] as String?,
      position: json['position'] as int,
    );
  }
  final String itemId;
  final String? folderId;
  final int position;
  Map<String, Object?> toJson() => {
    'itemId': itemId,
    'folderId': folderId,
    'position': position,
  };
  @override
  List<Object?> get props => [itemId, folderId, position];
}

/// Iterative traversal supports deep trees without stack recursion.
class FolderTree {
  FolderTree(Iterable<CollectionFolder> folders)
    : folders = List.unmodifiable(folders) {
    byId = Map.unmodifiable({
      for (final folder in this.folders) folder.id: folder,
    });
    validate();
  }
  final List<CollectionFolder> folders;
  late final Map<String, CollectionFolder> byId;
  void validate() {
    if (byId.length != folders.length) {
      throw const FormatException('Duplicate folder ID');
    }
    final names = <(String?, String)>{};
    for (final f in folders) {
      if (f.id.trim().isEmpty ||
          f.name.trim().isEmpty ||
          f.name != f.name.trim() ||
          f.position < 0) {
        throw const FormatException('Invalid folder');
      }
      if (!names.add((f.parentId, f.name.toLowerCase()))) {
        throw const FormatException('Duplicate sibling folder name');
      }
      if (f.parentId != null && !byId.containsKey(f.parentId)) {
        throw const FormatException('Missing parent folder');
      }
    }
    final complete = <String>{};
    for (final folder in folders) {
      final path = <String>{};
      String? id = folder.id;
      while (id != null && !complete.contains(id)) {
        if (!path.add(id)) throw const FormatException('Folder cycle');
        id = byId[id]!.parentId;
      }
      complete.addAll(path);
    }
  }

  List<CollectionFolder> children(String? parentId) =>
      folders.where((f) => f.parentId == parentId).toList()..sort(
        (a, b) => a.position != b.position
            ? a.position.compareTo(b.position)
            : a.id.compareTo(b.id),
      );
  List<CollectionFolder> ancestors(String? id) {
    var current = id;
    final result = <CollectionFolder>[];
    while (current != null) {
      final f = byId[current];
      if (f == null) throw const FormatException('Unknown folder');
      result.add(f);
      current = f.parentId;
    }
    return result.reversed.toList();
  }

  Set<String> subtree(String id) {
    if (!byId.containsKey(id)) throw const FormatException('Unknown folder');
    final result = <String>{id};
    final pending = [id];
    final childIds = <String?, List<String>>{};
    for (final f in folders) {
      childIds.putIfAbsent(f.parentId, () => []).add(f.id);
    }
    while (pending.isNotEmpty) {
      for (final child in childIds[pending.removeLast()] ?? const <String>[]) {
        result.add(child);
        pending.add(child);
      }
    }
    return result;
  }

  void validatePlacements(Iterable<FolderPlacement> placements) {
    final ids = <String>{};
    for (final p in placements) {
      if (!ids.add(p.itemId) ||
          p.position < 0 ||
          (p.folderId != null && !byId.containsKey(p.folderId))) {
        throw const FormatException('Invalid item assignment');
      }
    }
  }

  List<CollectionFolder> move(Set<String> ids, String? destination) {
    if (destination != null && !byId.containsKey(destination)) {
      throw const FormatException('Unknown destination');
    }
    final selected = ids
        .where(
          (id) => !ancestors(byId[id]?.parentId).any((f) => ids.contains(f.id)),
        )
        .toSet();
    for (final id in ids) {
      if (!byId.containsKey(id) ||
          (destination != null && subtree(id).contains(destination))) {
        throw const FormatException('Invalid folder destination');
      }
    }
    var position = children(
      destination,
    ).fold(0, (next, f) => f.position >= next ? f.position + 1 : next);
    final moved = [
      for (final f in folders)
        selected.contains(f.id) && f.parentId != destination
            ? f.copyWith(
                parentId: destination,
                home: destination == null,
                position: position++,
              )
            : f,
    ];
    FolderTree(moved);
    return moved;
  }

  String path(String? id) => ancestors(id).map((f) => f.name).join(' / ');
  String uniqueName(String name, String? parent) {
    final names = children(parent).map((f) => f.name.toLowerCase()).toSet();
    if (!names.contains(name.toLowerCase())) return name;
    var n = 2;
    while (names.contains('$name ($n)'.toLowerCase())) {
      n++;
    }
    return '$name ($n)';
  }
}

class FolderHierarchyCopy {
  const FolderHierarchyCopy({
    required this.folders,
    required this.wrapperId,
    required this.folderIds,
  });
  final List<CollectionFolder> folders;
  final String wrapperId;
  final Map<String, String> folderIds;
}

FolderHierarchyCopy planFolderHierarchyCopy({
  required List<CollectionFolder> current,
  required List<CollectionFolder> incoming,
  required Iterable<String?> itemFolders,
  required String wrapperName,
  required String Function() newId,
}) {
  final source = FolderTree(incoming);
  final local = FolderTree(current);
  final needed = {
    for (final id in itemFolders)
      for (final f in source.ancestors(id)) f.id,
  };
  final mapping = {for (final id in needed) id: newId()};
  final wrapper = CollectionFolder(
    id: newId(),
    name: local.uniqueName(wrapperName, null),
    position: local
        .children(null)
        .fold(0, (n, f) => f.position >= n ? f.position + 1 : n),
  );
  final folders = [
    ...current,
    wrapper,
    for (final f in incoming)
      if (needed.contains(f.id))
        CollectionFolder(
          id: mapping[f.id]!,
          name: f.name,
          parentId: f.parentId == null ? wrapper.id : mapping[f.parentId],
          position: f.position,
        ),
  ];
  FolderTree(folders);
  return FolderHierarchyCopy(
    folders: folders,
    wrapperId: wrapper.id,
    folderIds: mapping,
  );
}
