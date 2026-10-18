// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../search/following_topics/types.dart';
import '../../groups/folder_tree.dart';
import '../types/backup_data_source.dart';
import 'search_backup_profile.dart';

class FollowingTopicExportScope extends Equatable implements BackupExportScope {
  const FollowingTopicExportScope.all()
    : searchIds = null,
      folderIds = const {},
      includeHome = true;

  FollowingTopicExportScope.selected({
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

class FollowingTopicBackupData extends Equatable {
  const FollowingTopicBackupData({
    required this.records,
    this.folders = const [],
    this.homeSearchIds = const [],
  });

  final List<String> homeSearchIds;
  final List<FollowingTopicBackupRecord> records;
  final List<FollowingTopicFolderBackupRecord> folders;

  @override
  List<Object?> get props => [records, folders, homeSearchIds];
}

class FollowingTopicBackupRecord extends Equatable {
  const FollowingTopicBackupRecord({
    required this.id,
    required this.name,
    required this.query,
    this.queryStructure,
    required this.position,
    required this.profile,
    this.folderId,
    this.folderPosition,
    this.autoUpdateEnabled = true,
  });

  final String id;
  final String? name;
  final String query;
  final SearchQueryStructure? queryStructure;
  final int position;
  final BackupProfileReference profile;
  final String? folderId;
  final int? folderPosition;
  final bool autoUpdateEnabled;

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
    autoUpdateEnabled,
  ];
}

class FollowingTopicFolderBackupRecord extends Equatable {
  const FollowingTopicFolderBackupRecord({
    required this.id,
    required this.name,
    required this.position,
    required this.searchIds,
    this.parentId,
    this.feedEnabled = false,
    this.feedMaxPosts = topicFeedRetention,
  });
  final String id;
  final String name;
  final int position;
  final List<String> searchIds;
  final String? parentId;
  final bool feedEnabled;
  final int feedMaxPosts;

  @override
  List<Object?> get props => [
    id,
    name,
    position,
    searchIds,
    parentId,
    feedEnabled,
    feedMaxPosts,
  ];
}

FollowingTopicBackupData filterFollowingTopicBackupData(
  FollowingTopicBackupData data,
  FollowingTopicExportScope scope,
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
  return FollowingTopicBackupData(
    records: [
      for (final r in data.records)
        if (includedIds.contains(r.id)) r,
    ],
    folders: [
      for (final f in data.folders)
        if (requiredFolders.contains(f.id))
          FollowingTopicFolderBackupRecord(
            id: f.id,
            name: f.name,
            parentId: f.parentId,
            position: f.position,
            searchIds: f.searchIds.where(includedIds.contains).toList(),
            feedEnabled: f.feedEnabled,
            feedMaxPosts: f.feedMaxPosts,
          ),
    ],
    homeSearchIds: data.homeSearchIds.where(includedIds.contains).toList(),
  );
}
