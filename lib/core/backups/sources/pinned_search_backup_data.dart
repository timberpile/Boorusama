// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../search/subscriptions/types.dart';
import '../../groups/folder_tree.dart';
import '../types/backup_data_source.dart';
import 'search_backup_profile.dart';

class PinnedSearchExportScope extends Equatable implements BackupExportScope {
  const PinnedSearchExportScope.all()
    : searchIds = null,
      folderIds = const {},
      includeHome = true;

  PinnedSearchExportScope.selected({
    required Iterable<String> searchIds,
    required Iterable<String> folderIds,
    required this.includeHome,
  }) : searchIds = Set.unmodifiable(searchIds),
       folderIds = Set.unmodifiable(folderIds);

  final Set<String>? searchIds;
  final Set<String> folderIds;
  final bool includeHome;

  bool get isAll => searchIds == null;

  @override
  List<Object?> get props => [searchIds, folderIds, includeHome];
}

class PinnedSearchBackupData extends Equatable {
  const PinnedSearchBackupData({
    required this.records,
    this.folders = const [],
    this.homeSearchIds = const [],
  });

  final List<String> homeSearchIds;
  final List<PinnedSearchBackupRecord> records;
  final List<PinnedSearchFolderBackupRecord> folders;

  @override
  List<Object?> get props => [records, folders, homeSearchIds];
}

class PinnedSearchBackupRecord extends Equatable {
  const PinnedSearchBackupRecord({
    required this.id,
    required this.name,
    required this.query,
    this.queryStructure,
    required this.position,
    required this.profile,
    this.folderId,
    this.folderPosition,
  });

  final String id;
  final String? name;
  final String query;
  final SearchQueryStructure? queryStructure;
  final int position;
  final BackupProfileReference profile;
  final String? folderId;
  final int? folderPosition;

  @override
  List<Object?> get props => [
    id,
    name,
    query,
    queryStructure,
    position,
    profile,
    folderId,
    folderPosition,
  ];
}

class PinnedSearchFolderBackupRecord extends Equatable {
  const PinnedSearchFolderBackupRecord({
    required this.id,
    required this.name,
    required this.position,
    required this.searchIds,
    this.parentId,
  });
  final String id;
  final String name;
  final int position;
  final List<String> searchIds;
  final String? parentId;
  @override
  List<Object?> get props => [id, name, position, searchIds, parentId];
}

PinnedSearchBackupData filterPinnedSearchBackupData(
  PinnedSearchBackupData data,
  PinnedSearchExportScope scope,
) {
  if (scope.isAll) return data;

  final tree = FolderTree([
    for (final f in data.folders)
      CollectionFolder(
        id: f.id,
        name: f.name,
        parentId: f.parentId,
        position: f.position,
      ),
  ]);
  final chosenFolders = {
    for (final id in scope.folderIds)
      if (tree.byId.containsKey(id)) ...tree.subtree(id),
  };
  final includedIds = {
    ...scope.searchIds!,
    for (final f in data.folders)
      if (chosenFolders.contains(f.id)) ...f.searchIds,
    if (scope.includeHome) ...data.homeSearchIds,
  };
  final requiredFolders = {
    ...chosenFolders,
    for (final f in data.folders)
      if (f.searchIds.any(includedIds.contains)) f.id,
  };
  requiredFolders.addAll([
    for (final id in requiredFolders.toList())
      for (final f in tree.ancestors(id)) f.id,
  ]);
  return PinnedSearchBackupData(
    records: [
      for (final r in data.records)
        if (includedIds.contains(r.id)) r,
    ],
    folders: [
      for (final f in data.folders)
        if (requiredFolders.contains(f.id))
          PinnedSearchFolderBackupRecord(
            id: f.id,
            name: f.name,
            parentId: f.parentId,
            position: f.position,
            searchIds: f.searchIds.where(includedIds.contains).toList(),
          ),
    ],
    homeSearchIds: data.homeSearchIds.where(includedIds.contains).toList(),
  );
}
