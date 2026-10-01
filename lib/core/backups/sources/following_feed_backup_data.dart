import 'package:equatable/equatable.dart';

import '../types/backup_data_source.dart';
import 'search_backup_profile.dart';

class FollowingFeedExportScope extends Equatable implements BackupExportScope {
  const FollowingFeedExportScope.all() : feedIds = null;

  FollowingFeedExportScope.selected(Iterable<String> feedIds)
    : feedIds = Set.unmodifiable(feedIds);

  final Set<String>? feedIds;

  bool get isAll => feedIds == null;

  @override
  List<Object?> get props => [feedIds];
}

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

FollowingFeedBackupData filterFollowingFeedBackupData(
  FollowingFeedBackupData data,
  FollowingFeedExportScope scope,
) => scope.isAll
    ? data
    : FollowingFeedBackupData(
        feeds: [
          for (final feed in data.feeds)
            if (scope.feedIds!.contains(feed.id)) feed,
        ],
      );
