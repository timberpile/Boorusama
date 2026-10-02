// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../search/subscriptions/types.dart';
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
  });

  final String id;
  final String? name;
  final String query;
  final SearchQueryStructure? queryStructure;
  final int position;
  final BackupProfileReference profile;

  @override
  List<Object?> get props => [
    id,
    name,
    query,
    queryStructure,
    position,
    profile,
  ];
}

class PinnedSearchFolderBackupRecord extends Equatable {
  const PinnedSearchFolderBackupRecord({
    required this.id,
    required this.name,
    required this.position,
    required this.searchIds,
  });
  final String id;
  final String name;
  final int position;
  final List<String> searchIds;
  @override
  List<Object?> get props => [id, name, position, searchIds];
}

PinnedSearchBackupData filterPinnedSearchBackupData(
  PinnedSearchBackupData data,
  PinnedSearchExportScope scope,
) {
  if (scope.isAll) return data;

  final includedIds = {
    ...scope.searchIds!,
    for (final folder in data.folders)
      if (scope.folderIds.contains(folder.id)) ...folder.searchIds,
    if (scope.includeHome) ...data.homeSearchIds,
  };
  final availableIds = data.records.map((record) => record.id).toSet();
  includedIds.retainAll(availableIds);

  final folders = [
    for (final folder in data.folders)
      if (scope.folderIds.contains(folder.id) ||
          folder.searchIds.any(includedIds.contains))
        PinnedSearchFolderBackupRecord(
          id: folder.id,
          name: folder.name,
          position: folder.position,
          searchIds: [
            for (final id in folder.searchIds)
              if (includedIds.contains(id)) id,
          ],
        ),
  ];

  return PinnedSearchBackupData(
    records: [
      for (final record in data.records)
        if (includedIds.contains(record.id)) record,
    ],
    folders: folders,
    homeSearchIds: [
      for (final id in data.homeSearchIds)
        if (includedIds.contains(id)) id,
    ],
  );
}
