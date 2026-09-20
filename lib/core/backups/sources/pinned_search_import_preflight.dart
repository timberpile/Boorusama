import 'package:kurumi/material.dart';

import '../../configs/config/types.dart';
import '../preparation/version_checking.dart';
import 'pinned_search_backup_data.dart';
import 'pinned_searches_source.dart';

final class PinnedSearchImportApproval {
  PinnedSearchImportApproval(Iterable<String> unmatchedRecordIds)
    : unmatchedRecordIds = Set.unmodifiable(unmatchedRecordIds);

  final Set<String> unmatchedRecordIds;
}

Future<PinnedSearchImportApproval?> preflightPinnedSearches({
  required Map<String, ImportPreparation> prepared,
  required Set<String> selectedIds,
  required PinnedSearchesBackupSource pinnedSource,
  required Future<List<BooruConfig>> Function() currentProfiles,
  required BuildContext? context,
}) async {
  final pinData = prepared['pinned_searches']?.preparedData;
  if (pinData is! PinnedSearchBackupData) return null;
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
  return pinnedSource.confirmImportPreview(pinData, projectedProfiles, context);
}
