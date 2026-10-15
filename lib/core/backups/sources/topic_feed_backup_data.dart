import 'package:equatable/equatable.dart';

import '../types/backup_data_source.dart';
import 'search_backup_profile.dart';

class TopicFeedExportScope extends Equatable implements BackupExportScope {
  const TopicFeedExportScope.all() : feedIds = null;

  TopicFeedExportScope.selected(Iterable<String> feedIds)
    : feedIds = Set.unmodifiable(feedIds);

  final Set<String>? feedIds;

  bool get isAll => feedIds == null;

  @override
  List<Object?> get props => [feedIds];
}

class TopicFeedBackupData extends Equatable {
  TopicFeedBackupData({required List<TopicFeedBackupRecord> feeds})
    : feeds = List.unmodifiable(feeds);

  final List<TopicFeedBackupRecord> feeds;

  @override
  List<Object?> get props => [feeds];
}

class TopicFeedBackupRecord extends Equatable {
  TopicFeedBackupRecord({
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

TopicFeedBackupData filterTopicFeedBackupData(
  TopicFeedBackupData data,
  TopicFeedExportScope scope,
) => scope.isAll
    ? data
    : TopicFeedBackupData(
        feeds: [
          for (final feed in data.feeds)
            if (scope.feedIds!.contains(feed.id)) feed,
        ],
      );
