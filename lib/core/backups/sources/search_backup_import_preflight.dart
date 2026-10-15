import 'package:collection/collection.dart';
import 'package:kurumi/material.dart';

import '../../configs/config/types.dart';
import '../preparation/preparation_pipeline.dart';
import '../preparation/version_checking.dart';
import '../widgets/search_backup_missing_profiles_dialog.dart';
import 'topic_feed_backup_data.dart';
import 'topic_feeds_source.dart';
import 'following_topic_backup_data.dart';
import 'following_topics_source.dart';
import '../../search/following_topics/src/compatibility/topic_storage_contract.dart';

final class SearchBackupImportApproval {
  SearchBackupImportApproval(Iterable<String> unmatchedRecordIds)
    : unmatchedRecordIds = Set.unmodifiable(unmatchedRecordIds);

  final Set<String> unmatchedRecordIds;
}

Future<Map<String, SearchBackupImportApproval>> preflightSearchBackups({
  required Map<String, ImportPreparation> prepared,
  required Set<String> selectedIds,
  required FollowingTopicsBackupSource? topicsSource,
  required TopicFeedsBackupSource? feedSource,
  required Future<List<BooruConfig>> Function() currentProfiles,
  required BuildContext? context,
}) async {
  final topicData = prepared[followingTopicsBackupSourceId]?.preparedData;
  final feedData = prepared[topicFeedsBackupSourceId]?.preparedData;
  if (topicData is! FollowingTopicBackupData &&
      feedData is! TopicFeedBackupData) {
    return const {};
  }
  final Future<List<BooruConfig>> Function() projectedProfiles;
  if (selectedIds.contains('profiles')) {
    final profileData = prepared['profiles']?.preparedData;
    if (profileData is! List<BooruConfig>) {
      throw StateError('Selected profiles could not be prepared');
    }
    projectedProfiles = () async => profileData;
  } else {
    projectedProfiles = currentProfiles;
  }

  Future<({Set<String> topics, Set<String> feeds})> preview() async {
    final profiles = await projectedProfiles();
    return (
      topics: topicData is FollowingTopicBackupData && topicsSource != null
          ? await topicsSource.unmatchedRecordIds(topicData, profiles)
          : <String>{},
      feeds: feedData is TopicFeedBackupData && feedSource != null
          ? await feedSource.unmatchedRecordIds(feedData, profiles)
          : <String>{},
    );
  }

  final first = await preview();
  if (context != null && !context.mounted) {
    throw const ImportCancelledException();
  }
  await confirmSearchBackupProfiles(
    unmatchedRecordIds: {...first.topics, ...first.feeds},
    topicCount: first.topics.length,
    feedCount: first.feeds.length,
    context: context,
  );
  final latest = await preview();
  const equality = SetEquality<String>();
  if (!equality.equals(first.topics, latest.topics) ||
      !equality.equals(first.feeds, latest.feeds)) {
    throw const ImportCancelledException();
  }
  return {
    if (topicData is FollowingTopicBackupData && topicsSource != null)
      followingTopicsBackupSourceId: SearchBackupImportApproval(first.topics),
    if (feedData is TopicFeedBackupData && feedSource != null)
      topicFeedsBackupSourceId: SearchBackupImportApproval(first.feeds),
  };
}
