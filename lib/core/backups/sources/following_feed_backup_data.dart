import 'package:equatable/equatable.dart';

import 'search_backup_profile.dart';

class FollowingFeedBackupData extends Equatable {
  FollowingFeedBackupData({required List<FollowingFeedBackupRecord> feeds})
    : feeds = List.unmodifiable(feeds);

  final List<FollowingFeedBackupRecord> feeds;

  @override
  List<Object?> get props => [feeds];
}

class FollowingFeedBackupRecord extends Equatable {
  FollowingFeedBackupRecord({
    required this.id,
    required this.name,
    required this.position,
    required List<String> queries,
    required this.profile,
  }) : queries = List.unmodifiable(queries);

  final String id;
  final String name;
  final int position;
  final List<String> queries;
  final BackupProfileReference profile;

  @override
  List<Object?> get props => [id, name, position, queries, profile];
}
