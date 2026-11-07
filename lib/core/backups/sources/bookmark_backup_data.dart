// Package imports:
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

// Project imports:
import '../../bookmarks/types.dart';
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
      includeUngrouped = false;

  BookmarkExportScope.selected({
    required Iterable<String> groupIds,
    this.includeUngrouped = false,
    Iterable<String> folderIds = const [],
  }) : groupIds = Set.unmodifiable(groupIds),
       folderIds = Set.unmodifiable(folderIds);

  final Set<String>? groupIds;
  final Set<String> folderIds;
  final bool includeUngrouped;

  bool get isAll => groupIds == null;

  @override
  List<Object?> get props => [groupIds, includeUngrouped, folderIds];
}

class BookmarkGroupBackup extends Equatable {
  const BookmarkGroupBackup({
    required this.id,
    required this.name,
    required this.bookmarkIds,
    this.folderId,
    this.position = 0,
    this.addedAt = const {},
  });

  bool get isDefault => id == defaultBookmarkGroupId;

  final String? id;
  final String name;
  final List<int> bookmarkIds;
  final Map<int, DateTime> addedAt;
  final String? folderId;
  final int position;

  Map<String, dynamic> toJson() => {
    'id': ?id,
    if (isDefault) 'systemRole': 'default',
    'name': name,
    'bookmarkIds': bookmarkIds,
    'addedAt': addedAt.map(
      (id, date) => MapEntry('$id', date.toUtc().toIso8601String()),
    ),
    'folderId': folderId,
    'position': position,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    bookmarkIds,
    addedAt,
    folderId,
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
  }) : records = List.unmodifiable(records),
       groups = List.unmodifiable(groups),
       folders = List.unmodifiable(folders);

  final List<Bookmark> records;
  final List<BookmarkGroupBackup> groups;
  final List<CollectionFolder> folders;

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
    return {
      'groups': exportGroups.map((group) => group.toJson()).toList(),
      'folders': folders.map((folder) => folder.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [records, groups, folders];
}

BookmarkBackupData buildBookmarkBackupData({
  List<PostBookmark> bookmarks = const [],
  List<Bookmark>? records,
  required List<BookmarkGroup> groups,
  required BookmarkExportScope scope,
  List<CollectionFolder> folders = const [],
  List<CollectionBookmark> pools = const [],
}) {
  final data = records == null
      ? BookmarkBackupData(
          bookmarks: bookmarks,
          pools: pools,
          folders: folders,
          groups: [
            for (final g in groups)
              BookmarkGroupBackup(
                id: g.id,
                name: g.name,
                bookmarkIds: g.bookmarkIds.toList(),
                addedAt: g.addedAt,
                folderId: g.folderId,
                position: g.position,
              ),
          ],
        )
      : BookmarkBackupData.unified(
          records: records,
          groups: [],
          folders: folders,
        );
  final allRecords = data.records;
  final allGroups = records == null
      ? [
          for (final g in data.groups)
            BookmarkGroup(
              id: g.id!,
              name: g.name,
              bookmarkIds: g.bookmarkIds.toSet(),
              addedAt: g.addedAt,
              folderId: g.folderId,
              position: g.position,
            ),
        ]
      : groups;
  final tree = FolderTree(folders);
  final byId = {for (final bookmark in allRecords) bookmark.id: bookmark};
  final selectedFolders = {
    for (final id in scope.folderIds)
      if (tree.byId.containsKey(id)) ...tree.subtree(id),
  };
  final selectedGroups = {
    if (scope.includeUngrouped) defaultBookmarkGroupId,
    ...?scope.groupIds,
    for (final g in allGroups)
      if (selectedFolders.contains(g.folderId)) g.id,
  };
  final membershipsByBookmark = <int, Set<String>>{};
  for (final group in allGroups) {
    for (final bookmarkId in group.bookmarkIds) {
      membershipsByBookmark.putIfAbsent(bookmarkId, () => {}).add(group.id);
    }
  }
  final exportedBookmarks = scope.isAll
      ? allRecords
      : allRecords.where((bookmark) {
          final memberships = membershipsByBookmark[bookmark.id] ?? const {};
          return (scope.includeUngrouped && memberships.isEmpty) ||
              memberships.any(selectedGroups.contains);
        }).toList();
  final exportedIds = exportedBookmarks.map((bookmark) => bookmark.id).toSet();
  final exportedGroups = allGroups
      .where((group) => scope.isAll || selectedGroups.contains(group.id))
      .map(
        (group) => BookmarkGroupBackup(
          id: group.id,
          name: group.name,
          folderId: group.folderId,
          position: group.position,
          bookmarkIds: group.bookmarkIds.intersection(exportedIds).toList(),
          addedAt: {
            for (final id in group.bookmarkIds.intersection(exportedIds))
              id: group.addedAt[id] ?? bookmarkCreatedAt(byId[id]!),
          },
        ),
      )
      .toList();
  return BookmarkBackupData.unified(
    records: exportedBookmarks,
    groups: exportedGroups,
    folders: scope.isAll
        ? folders
        : folders
              .where(
                (f) =>
                    selectedFolders.contains(f.id) ||
                    scope.folderIds.any(
                      (id) =>
                          tree.byId.containsKey(id) &&
                          tree.ancestors(id).any((a) => a.id == f.id),
                    ) ||
                    exportedGroups.any(
                      (g) =>
                          tree.ancestors(g.folderId).any((a) => a.id == f.id),
                    ),
              )
              .toList(),
  );
}
