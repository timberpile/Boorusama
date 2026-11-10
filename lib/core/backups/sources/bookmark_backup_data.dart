// Package imports:
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

// Project imports:
import '../../bookmarks/types.dart';
import '../../bookmarks/src/services/bookmark_hierarchy_conversion.dart';
import '../../bookmarks/src/data/bookmark_collection_projection.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../bookmarks/src/types/legacy_group_bookmark.dart';
import '../../groups/folder_tree.dart';
import '../types/backup_data_source.dart';
import '../types/types.dart';

class BookmarkExportScope extends Equatable implements BackupExportScope {
  const BookmarkExportScope.all()
    : groupIds = null,
      folderIds = const {},
      includeUngrouped = false,
      directGroupIds = const {};

  BookmarkExportScope.selected({
    required Iterable<String> groupIds,
    this.includeUngrouped = false,
    Iterable<String> folderIds = const [],
    Iterable<String> directGroupIds = const [],
  }) : directGroupIds = Set.unmodifiable(directGroupIds),
       groupIds = Set.unmodifiable(groupIds),
       folderIds = Set.unmodifiable(folderIds);

  final Set<String>? groupIds;
  final Set<String> directGroupIds;
  final Set<String> folderIds;
  final bool includeUngrouped;

  bool get isAll => groupIds == null;

  @override
  List<Object?> get props => [
    groupIds,
    directGroupIds,
    includeUngrouped,
    folderIds,
  ];
}

class BookmarkGroupBackup extends Equatable {
  const BookmarkGroupBackup({
    required this.id,
    required this.name,
    required this.bookmarkIds,
    this.folderId,
    this.parentGroupId,
    this.position = 0,
    this.addedAt = const {},
  });

  bool get isDefault => id == defaultBookmarkGroupId;

  final String? id;
  final String name;
  final List<int> bookmarkIds;
  final Map<int, DateTime> addedAt;
  final String? folderId;
  final String? parentGroupId;
  final int position;

  Map<String, dynamic> toJson({bool hierarchy = false}) => {
    'id': ?id,
    if (isDefault) 'systemRole': 'default',
    'name': name,
    'bookmarkIds': bookmarkIds,
    'addedAt': addedAt.map(
      (id, date) => MapEntry('$id', date.toUtc().toIso8601String()),
    ),
    if (hierarchy) 'parentGroupId': parentGroupId else 'folderId': folderId,
    'position': position,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    bookmarkIds,
    addedAt,
    folderId,
    parentGroupId,
    position,
  ];
}

class BookmarkBackupData extends Equatable {
  /// Compatibility input for v4-v9 readers and Post-only callers. Collection
  /// UUIDs are converted to collision-free file IDs immediately; only records
  /// and BookmarkGroup membership rows remain authoritative.
  factory BookmarkBackupData({
    required List<PostBookmark> bookmarks,
    required List<BookmarkGroupBackup> groups,
    List<CollectionFolder> folders = const [],
    List<CollectionBookmark> pools = const [],
  }) {
    final groupIds = groups.map((g) => g.id).toSet();
    final localPoolIds = <String>{};
    if (pools.any(
      (p) =>
          !Uuid.isValidUUID(fromString: p.localId) ||
          !localPoolIds.add(p.localId) ||
          p.groupIds.isEmpty ||
          !groupIds.containsAll(p.groupIds),
    )) {
      throw const InvalidBackupFormatException(
        'Invalid legacy Collection memberships',
      );
    }
    final records = <Bookmark>[...bookmarks];
    final used = bookmarks.map((b) => b.id).toSet();
    var next = 0;
    final poolIds = <String, int>{};
    for (final pool in pools) {
      while (used.contains(next)) {
        next++;
      }
      final id = next++;
      used.add(id);
      poolIds[pool.localId] = id;
      records.add(LegacyGroupBookmark.fromMetadata(id: id, metadata: pool));
    }
    return BookmarkBackupData.unified(
      records: records,
      folders: folders,
      groups: [
        for (final group in groups)
          BookmarkGroupBackup(
            id: group.id,
            name: group.name,
            folderId: group.folderId,
            parentGroupId: group.parentGroupId,
            position: group.position,
            bookmarkIds: [
              ...group.bookmarkIds,
              for (final pool in pools)
                if (pool.groupIds.contains(group.id)) poolIds[pool.localId]!,
            ],
            addedAt: {
              ...group.addedAt,
              for (final pool in pools)
                if (pool.groupIds.contains(group.id))
                  poolIds[pool.localId]!:
                      pool.addedAt[group.id] ?? pool.createdAt,
            },
          ),
      ],
    );
  }

  BookmarkBackupData.unified({
    required Iterable<Bookmark> records,
    required Iterable<BookmarkGroupBackup> groups,
    Iterable<CollectionFolder> folders = const [],
    Map<String, String> legacyFolderGroupIds = const {},
  }) : legacyFolderGroupIds = Map.unmodifiable(legacyFolderGroupIds),
       records = List.unmodifiable(records),
       groups = List.unmodifiable(groups),
       folders = List.unmodifiable(folders);

  final Map<String, String> legacyFolderGroupIds;
  final List<Bookmark> records;
  final List<BookmarkGroupBackup> groups;
  final List<CollectionFolder> folders;

  BookmarkBackupData asHierarchy() {
    if (groups.any((group) => group.id == null)) return this;
    final definitions = [
      for (final group in groups)
        BookmarkGroup(
          id: group.id!,
          name: group.isDefault ? 'Default' : group.name,
          bookmarkIds: group.bookmarkIds.toSet(),
          addedAt: group.addedAt,
          folderId: group.folderId,
          parentGroupId: group.parentGroupId,
          position: group.position,
        ),
    ];
    final legacy =
        folders.isNotEmpty ||
        definitions.any((group) => group.folderId != null);
    final conversion = legacy
        ? BookmarkHierarchyConversion.convert(
            groups: definitions,
            folders: folders,
          )
        : null;
    final result = conversion?.groups ?? definitions;
    BookmarkGroupTree(result);
    return BookmarkBackupData.unified(
      records: records,
      legacyFolderGroupIds: {
        ...legacyFolderGroupIds,
        ...?conversion?.folderIdMapping,
      },
      groups: [
        for (final group in result)
          BookmarkGroupBackup(
            id: group.id,
            name: group.name,
            bookmarkIds: group.bookmarkIds.toList(),
            addedAt: group.addedAt,
            parentGroupId: group.parentGroupId,
            position: group.position,
          ),
      ],
    );
  }

  List<PostBookmark> get bookmarks =>
      records.whereType<PostBookmark>().toList();
  List<CollectionBookmark> get pools => [
    for (final record in records)
      if (bookmarkCollectionProjection(
            record,
            memberships: {
              for (final group in groups)
                if (group.id != null && group.bookmarkIds.contains(record.id))
                  group.id!:
                      group.addedAt[record.id] ?? bookmarkCreatedAt(record),
            },
          )
          case final projection?)
        projection,
  ];

  Map<String, dynamic> get extraFields {
    final byId = {for (final bookmark in records) bookmark.id: bookmark};
    if (groups.any(
      (group) =>
          group.id == null ||
          group.bookmarkIds.any((id) => !byId.containsKey(id)),
    )) {
      throw const InvalidBackupFormatException(
        'Group identity or Bookmark reference is missing',
      );
    }
    final exportGroups = <BookmarkGroupBackup>[
      for (final group in groups)
        BookmarkGroupBackup(
          id: group.id,
          name: group.name,
          folderId: group.folderId,
          parentGroupId: group.parentGroupId,
          position: group.position,
          bookmarkIds: group.bookmarkIds,
          addedAt: {
            for (final id in group.bookmarkIds)
              id:
                  group.addedAt[id] ??
                  (byId[id] == null ? null : bookmarkCreatedAt(byId[id]!)) ??
                  (throw const InvalidBackupFormatException(
                    'Group references an absent bookmark',
                  )),
          },
        ),
    ];
    final assigned = {for (final group in exportGroups) ...group.bookmarkIds};
    final ungrouped = byId.keys.toSet().difference(assigned);
    // Legacy ungrouped data gets the same Default membership as library repair.
    if (ungrouped.isNotEmpty) {
      final index = exportGroups.indexWhere((group) => group.isDefault);
      final previous = index < 0 ? null : exportGroups[index];
      final defaultGroup = BookmarkGroupBackup(
        id: defaultBookmarkGroupId,
        name: previous?.name ?? 'Default',
        bookmarkIds: [...?previous?.bookmarkIds, ...ungrouped],
        position: previous?.position ?? 0,
        addedAt: {
          ...?previous?.addedAt,
          for (final id in ungrouped) id: bookmarkCreatedAt(byId[id]!),
        },
      );
      if (index < 0) {
        exportGroups.add(defaultGroup);
      } else {
        exportGroups[index] = defaultGroup;
      }
    }
    final hierarchy = normalizeBookmarkBackupGroups(exportGroups, folders);
    return {
      'organizationSchema': 'nestedGroups',
      'groups': hierarchy
          .map((group) => group.toJson(hierarchy: true))
          .toList(),
    };
  }

  @override
  List<Object?> get props => [records, groups, folders];
}

/// Compatibility rows are converted once before writing/previewing; a valid
/// parent hierarchy never shares authority with a separate folders array.
List<BookmarkGroupBackup> normalizeBookmarkBackupGroups(
  List<BookmarkGroupBackup> groups,
  List<CollectionFolder> folders,
) {
  final definitions = [
    for (final group in groups)
      BookmarkGroup(
        id:
            group.id ??
            (throw const InvalidBackupFormatException(
              'Missing group identity',
            )),
        name: group.isDefault ? 'Default' : group.name,
        bookmarkIds: group.bookmarkIds.toSet(),
        addedAt: group.addedAt,
        folderId: group.folderId,
        parentGroupId: group.parentGroupId,
        position: group.position,
      ),
  ];
  final legacy =
      folders.isNotEmpty || definitions.any((g) => g.folderId != null);
  final result = legacy
      ? BookmarkHierarchyConversion.convert(
          groups: definitions,
          folders: folders,
        ).groups
      : definitions;
  BookmarkGroupTree(result);
  return [
    for (final group in result)
      BookmarkGroupBackup(
        id: group.id,
        name: group.name,
        bookmarkIds: group.bookmarkIds.toList(),
        addedAt: group.addedAt,
        parentGroupId: group.parentGroupId,
        position: group.position,
      ),
  ];
}

BookmarkBackupData buildBookmarkBackupData({
  List<PostBookmark> bookmarks = const [],
  List<Bookmark>? records,
  required List<BookmarkGroup> groups,
  required BookmarkExportScope scope,
  List<CollectionFolder> folders = const [],
  List<CollectionBookmark> pools = const [],
}) {
  final legacyData = records == null
      ? BookmarkBackupData(
          bookmarks: bookmarks,
          pools: pools,
          folders: folders,
          groups: [
            for (final group in groups)
              BookmarkGroupBackup(
                id: group.id,
                name: group.name,
                bookmarkIds: group.bookmarkIds.toList(),
                addedAt: group.addedAt,
                folderId: group.folderId,
                parentGroupId: group.parentGroupId,
                position: group.position,
              ),
          ],
        )
      : null;
  final allRecords = records ?? legacyData!.records;
  final inputGroups = records == null
      ? legacyData!.groups
      : [
          for (final group in groups)
            BookmarkGroupBackup(
              id: group.id,
              name: group.name,
              bookmarkIds: group.bookmarkIds.toList(),
              addedAt: group.addedAt,
              folderId: group.folderId,
              parentGroupId: group.parentGroupId,
              position: group.position,
            ),
        ];
  final normalized = normalizeBookmarkBackupGroups(inputGroups, folders);
  final tree = BookmarkGroupTree([
    for (final group in normalized)
      BookmarkGroup(
        id: group.id!,
        name: group.name,
        bookmarkIds: group.bookmarkIds.toSet(),
        addedAt: group.addedAt,
        parentGroupId: group.parentGroupId,
        position: group.position,
      ),
  ]);
  final folderAliases = folders.isEmpty
      ? const <String, String>{}
      : BookmarkHierarchyConversion.convert(
          groups: groups,
          folders: folders,
        ).folderIdMapping;
  final selected = scope.isAll
      ? tree.groupsById.keys.toSet()
      : <String>{
          for (final id in {
            ...?scope.groupIds,
            for (final id in scope.folderIds) folderAliases[id] ?? id,
          })
            ...tree.subtreeIds(id),
          ...scope.directGroupIds.where(tree.groupsById.containsKey),
          if (scope.includeUngrouped) defaultBookmarkGroupId,
        };
  final definitions = <String>{
    ...selected,
    for (final id in selected) ...tree.ancestors(id).map((g) => g.id),
  };
  final selectedIds = {
    for (final id in selected) ...?tree.groupsById[id]?.bookmarkIds,
  };
  final assigned = {for (final group in normalized) ...group.bookmarkIds};
  if (scope.includeUngrouped)
    selectedIds.addAll(
      allRecords.map((r) => r.id).toSet().difference(assigned),
    );
  final exported = scope.isAll
      ? allRecords
      : allRecords.where((r) => selectedIds.contains(r.id)).toList();
  final exportedIds = exported.map((r) => r.id).toSet();
  final byId = {for (final record in allRecords) record.id: record};
  return BookmarkBackupData.unified(
    records: exported,
    groups: [
      for (final group in normalized)
        if (definitions.contains(group.id))
          BookmarkGroupBackup(
            id: group.id,
            name: group.name,
            parentGroupId: group.parentGroupId,
            position: group.position,
            bookmarkIds: selected.contains(group.id)
                ? group.bookmarkIds.where(exportedIds.contains).toList()
                : const [],
            addedAt: {
              if (selected.contains(group.id))
                for (final id in group.bookmarkIds.where(exportedIds.contains))
                  id: group.addedAt[id] ?? bookmarkCreatedAt(byId[id]!),
            },
          ),
    ],
  );
}
