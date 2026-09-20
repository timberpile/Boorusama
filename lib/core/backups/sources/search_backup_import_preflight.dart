import 'package:collection/collection.dart';
import 'package:kurumi/material.dart';

import '../../configs/config/types.dart';
import '../preparation/preparation_pipeline.dart';
import '../preparation/version_checking.dart';
import '../widgets/search_backup_missing_profiles_dialog.dart';
import 'following_feed_backup_data.dart';
import 'following_feeds_source.dart';
import 'pinned_search_backup_data.dart';
import 'pinned_searches_source.dart';

final class SearchBackupImportApproval {
  SearchBackupImportApproval(Iterable<String> unmatchedRecordIds)
    : unmatchedRecordIds = Set.unmodifiable(unmatchedRecordIds);

  final Set<String> unmatchedRecordIds;
}

Future<Map<String, SearchBackupImportApproval>> preflightSearchBackups({
  required Map<String, ImportPreparation> prepared,
  required Set<String> selectedIds,
  required PinnedSearchesBackupSource? pinnedSource,
  required FollowingFeedsBackupSource? feedSource,
  required Future<List<BooruConfig>> Function() currentProfiles,
  required BuildContext? context,
}) async {
  final pinData = prepared['pinned_searches']?.preparedData;
  final feedData = prepared['following_feeds']?.preparedData;
  if (pinData is! PinnedSearchBackupData &&
      feedData is! FollowingFeedBackupData) {
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

  Future<({Set<String> pins, Set<String> feeds})> preview() async {
    final profiles = await projectedProfiles();
    return (
      pins: pinData is PinnedSearchBackupData && pinnedSource != null
          ? await pinnedSource.unmatchedRecordIds(pinData, profiles)
          : <String>{},
      feeds: feedData is FollowingFeedBackupData && feedSource != null
          ? await feedSource.unmatchedRecordIds(feedData, profiles)
          : <String>{},
    );
  }

  final first = await preview();
  if (context != null && !context.mounted) {
    throw const ImportCancelledException();
  }
  await confirmSearchBackupProfiles(
    unmatchedRecordIds: {...first.pins, ...first.feeds},
    pinnedCount: first.pins.length,
    feedCount: first.feeds.length,
    context: context,
  );
  final latest = await preview();
  const equality = SetEquality<String>();
  if (!equality.equals(first.pins, latest.pins) ||
      !equality.equals(first.feeds, latest.feeds)) {
    throw const ImportCancelledException();
  }
  return {
    if (pinData is PinnedSearchBackupData && pinnedSource != null)
      'pinned_searches': SearchBackupImportApproval(first.pins),
    if (feedData is FollowingFeedBackupData && feedSource != null)
      'following_feeds': SearchBackupImportApproval(first.feeds),
  };
}
