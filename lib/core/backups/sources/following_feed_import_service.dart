import 'package:equatable/equatable.dart';

import '../../configs/config/types.dart';
import '../../search/subscriptions/types.dart';
import 'following_feed_backup_data.dart';
import 'search_backup_profile.dart';

class FollowingFeedImportResult extends Equatable {
  const FollowingFeedImportResult({
    required this.importedCount,
    required this.alreadyExistedCount,
    required this.skippedProfileCount,
  });

  final int importedCount;
  final int alreadyExistedCount;
  final int skippedProfileCount;

  @override
  List<Object?> get props => [
    importedCount,
    alreadyExistedCount,
    skippedProfileCount,
  ];
}

class FollowingFeedImportPreview extends Equatable {
  FollowingFeedImportPreview({required Set<String> unmatchedRecordIds})
    : unmatchedRecordIds = Set.unmodifiable(unmatchedRecordIds);

  final Set<String> unmatchedRecordIds;

  @override
  List<Object?> get props => [unmatchedRecordIds];
}

class UnmatchedFollowingFeedProfilesException implements Exception {
  const UnmatchedFollowingFeedProfilesException(this.recordIds);

  final Set<String> recordIds;
}

class FeedBackupIdConflictException implements Exception {
  const FeedBackupIdConflictException(this.feedIds);

  final Set<String> feedIds;
}

class FollowingFeedImportService {
  const FollowingFeedImportService({required this.repository});

  final SearchSubscriptionRepository repository;

  FollowingFeedImportPreview preview(
    FollowingFeedBackupData data, {
    required List<BooruConfig> profiles,
  }) => FollowingFeedImportPreview(
    unmatchedRecordIds: {
      for (final record in data.feeds)
        if (resolveBackupProfile(record.profile, profiles) == null) record.id,
    },
  );

  Future<FollowingFeedImportResult> apply(
    FollowingFeedBackupData data, {
    required List<BooruConfig> profiles,
    bool allowMissingProfiles = false,
  }) async {
    final unmatched = preview(data, profiles: profiles).unmatchedRecordIds;
    if (unmatched.isNotEmpty && !allowMissingProfiles) {
      throw UnmatchedFollowingFeedProfilesException(unmatched);
    }

    final mapped = [
      for (final (index, record) in data.feeds.indexed)
        (
          index: index,
          record: record,
          profile: resolveBackupProfile(record.profile, profiles),
        ),
    ];
    final localFeeds = await repository.getFeeds();
    final localById = {for (final feed in localFeeds) feed.id: feed};
    final conflicts = <String>{};
    for (final item in mapped) {
      final profile = item.profile;
      final local = localById[item.record.id];
      if (profile != null && local != null && local.profileId != profile.id) {
        conflicts.add(item.record.id);
      }
    }
    if (conflicts.isNotEmpty) throw FeedBackupIdConflictException(conflicts);

    final sourcesById = {
      for (final source in await repository.getAll()) source.id: source,
    };
    final accepted = mapped.where((item) => item.profile != null).toList();
    final profileIds = {for (final item in accepted) item.profile!.id};
    final finalOrder = <int, List<String>>{};
    for (final profileId in profileIds) {
      final rows =
          accepted.where((item) => item.profile!.id == profileId).toList()
            ..sort((left, right) {
              final position = left.record.position.compareTo(
                right.record.position,
              );
              return position != 0
                  ? position
                  : left.index.compareTo(right.index);
            });
      final importedIds = rows.map((item) => item.record.id).toSet();
      final order = [
        for (final feed in localFeeds)
          if (feed.profileId == profileId && !importedIds.contains(feed.id))
            feed.id,
      ];
      var previousPosition = -1;
      var equalPositionOffset = 0;
      for (final row in rows) {
        equalPositionOffset = row.record.position == previousPosition
            ? equalPositionOffset + 1
            : 0;
        previousPosition = row.record.position;
        final index = (row.record.position + equalPositionOffset).clamp(
          0,
          order.length,
        );
        order.insert(index, row.record.id);
      }
      finalOrder[profileId] = order;
    }

    var imported = 0;
    var existing = 0;
    for (final item in accepted) {
      final record = item.record;
      final profileId = item.profile!.id;
      final local = localById[record.id];
      final previousQueries = [
        for (final id in local?.sourceIds ?? const <String>[])
          if (sourcesById[id] case final source?)
            normalizeSearchIdentity(source.query),
      ];
      final desiredPosition = finalOrder[profileId]!.indexOf(record.id);
      final unchanged =
          local != null &&
          local.name == record.name &&
          _sameQueries(previousQueries, record.queries) &&
          local.position == desiredPosition;
      if (unchanged) {
        existing++;
        continue;
      }
      if (local == null ||
          local.name != record.name ||
          !_sameQueries(previousQueries, record.queries)) {
        await repository.saveFeed(
          id: record.id,
          profileId: profileId,
          name: record.name,
          queries: record.queries,
        );
      }
      imported++;
    }
    for (final entry in finalOrder.entries) {
      await repository.setFeedOrder(entry.key, entry.value);
    }
    return FollowingFeedImportResult(
      importedCount: imported,
      alreadyExistedCount: existing,
      skippedProfileCount: mapped.length - accepted.length,
    );
  }
}

bool _sameQueries(List<String> left, List<String> right) =>
    left.length == right.length &&
    [
      for (var i = 0; i < left.length; i++) left[i] == right[i],
    ].every((same) => same);
