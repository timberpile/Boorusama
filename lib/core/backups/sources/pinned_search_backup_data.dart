// Package imports:
import 'package:equatable/equatable.dart';
import 'search_backup_profile.dart';

class PinnedSearchBackupData extends Equatable {
  const PinnedSearchBackupData({
    required this.records,
    this.folders = const [],
    this.feeds = const [],
    this.homeSearchIds = const [],
  });

  final List<String> homeSearchIds;
  final List<PinnedSearchBackupRecord> records;
  final List<PinnedSearchFolderBackupRecord> folders;
  final List<PinnedSearchFeedBackupRecord> feeds;

  @override
  List<Object?> get props => [records, folders, feeds, homeSearchIds];
}

class PinnedSearchBackupRecord extends Equatable {
  const PinnedSearchBackupRecord({
    required this.id,
    required this.name,
    required this.query,
    required this.position,
    required this.profile,
  });

  final String id;
  final String? name;
  final String query;
  final int position;
  final BackupProfileReference profile;

  @override
  List<Object?> get props => [id, name, query, position, profile];
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

class PinnedSearchFeedBackupRecord extends Equatable {
  const PinnedSearchFeedBackupRecord({
    required this.id,
    required this.name,
    required this.position,
    required this.queries,
    required this.profile,
  });
  final String id;
  final String name;
  final int position;
  final List<String> queries;
  final BackupProfileReference profile;
  @override
  List<Object?> get props => [id, name, position, queries, profile];
}
