import '../export_import/import/search_runtime_snapshot.dart';
import 'package:equatable/equatable.dart';

import '../export_import/import/collection_import_action.dart';
import '../export_import/models/import_action.dart';
import '../../configs/config/types.dart';
import '../../search/following_topics/types.dart';
import 'topic_feed_backup_data.dart';
import 'search_backup_profile.dart';

class TopicFeedImportResult extends Equatable {
  const TopicFeedImportResult({
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

class TopicFeedImportPreview extends Equatable {
  TopicFeedImportPreview({required Set<String> unmatchedRecordIds})
    : unmatchedRecordIds = Set.unmodifiable(unmatchedRecordIds);

  final Set<String> unmatchedRecordIds;

  @override
  List<Object?> get props => [unmatchedRecordIds];
}

class UnmatchedTopicFeedProfilesException implements Exception {
  const UnmatchedTopicFeedProfilesException(this.recordIds);

  final Set<String> recordIds;
}

class FeedBackupIdConflictException implements Exception {
  const FeedBackupIdConflictException(this.feedIds);

  final Set<String> feedIds;
}

class TopicFeedImportService {
  const TopicFeedImportService({required this.repository});

  final FollowingTopicRepository repository;

  TopicFeedImportPreview preview(
    TopicFeedBackupData data, {
    required List<BooruConfig> profiles,
    BackupProfileIdResolver? profileIdResolver,
  }) => TopicFeedImportPreview(
    unmatchedRecordIds: {
      for (final record in data.feeds)
        if (resolveBackupProfileId(
              record.profile,
              profiles,
              resolver: profileIdResolver,
            ) ==
            null)
          record.id,
    },
  );

  Future<TopicFeedImportResult> replace(
    TopicFeedBackupData data, {
    required List<BooruConfig> profiles,
    BackupProfileIdResolver? profileIdResolver,
  }) async {
    final snapshots = SearchRuntimeSnapshotService(repository);
    final previous = await snapshots.capture();
    try {
      return await _replace(
        data,
        profiles: profiles,
        profileIdResolver: profileIdResolver,
      );
    } catch (error, stack) {
      await snapshots.restore(previous);
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<TopicFeedImportResult> _replace(
    TopicFeedBackupData data, {
    required List<BooruConfig> profiles,
    BackupProfileIdResolver? profileIdResolver,
  }) async {
    final folderIds = (await repository.getOrganization()).folders
        .map((folder) => folder.id)
        .toSet();
    final mapped = [
      for (final record in data.feeds)
        (
          record: record,
          profileId: resolveBackupProfileId(
            record.profile,
            profiles,
            resolver: profileIdResolver,
          ),
        ),
    ];
    final unmatched = {
      for (final item in mapped)
        if (item.profileId == null) item.record.id,
    };
    if (unmatched.isNotEmpty) {
      throw UnmatchedTopicFeedProfilesException(unmatched);
    }

    final desiredProfileById = {
      for (final item in mapped) item.record.id: item.profileId!,
    };
    for (final feed in await repository.getFeeds()) {
      if (folderIds.contains(feed.id)) continue;
      final desiredProfile = desiredProfileById[feed.id];
      if (desiredProfile != null && desiredProfile != feed.profileId) {
        await repository.deleteFeed(feed.id);
      }
    }
    final result = await apply(
      data,
      profiles: profiles,
      profileIdResolver: profileIdResolver,
    );
    final desiredIds = desiredProfileById.keys.toSet();
    for (final feed in await repository.getFeeds()) {
      if (folderIds.contains(feed.id)) continue;
      if (!desiredIds.contains(feed.id)) await repository.deleteFeed(feed.id);
    }

    for (final profileId in desiredProfileById.values.toSet()) {
      final records =
          mapped.where((item) => item.profileId == profileId).toList()
            ..sort((left, right) {
              final byPosition = left.record.position.compareTo(
                right.record.position,
              );
              return byPosition != 0
                  ? byPosition
                  : data.feeds
                        .indexOf(left.record)
                        .compareTo(
                          data.feeds.indexOf(right.record),
                        );
            });
      await repository.setFeedOrder(
        profileId,
        [
          for (final feed in await repository.getFeeds())
            if (folderIds.contains(feed.id) && feed.profileId == profileId)
              feed.id,
          for (final item in records) item.record.id,
        ],
      );
    }
    return result;
  }

  Future<TopicFeedImportResult> apply(
    TopicFeedBackupData data, {
    required List<BooruConfig> profiles,
    bool allowMissingProfiles = false,
    Map<String, CollectionImportAction>? feedActions,
    BackupProfileIdResolver? profileIdResolver,
  }) async {
    final unmatched = preview(
      data,
      profiles: profiles,
      profileIdResolver: profileIdResolver,
    ).unmatchedRecordIds;
    if (unmatched.isNotEmpty && !allowMissingProfiles) {
      throw UnmatchedTopicFeedProfilesException(unmatched);
    }
    if (feedActions != null) {
      return _applyActions(
        data,
        profiles: profiles,
        allowMissingProfiles: allowMissingProfiles,
        actions: feedActions,
        profileIdResolver: profileIdResolver,
      );
    }

    final mapped = [
      for (final (index, record) in data.feeds.indexed)
        (
          index: index,
          record: record,
          profileId: resolveBackupProfileId(
            record.profile,
            profiles,
            resolver: profileIdResolver,
          ),
        ),
    ];
    final localFeeds = await repository.getFeeds();
    final localById = {for (final feed in localFeeds) feed.id: feed};
    final conflicts = <String>{};
    for (final item in mapped) {
      final profileId = item.profileId;
      final local = localById[item.record.id];
      if (profileId != null && local != null && local.profileId != profileId) {
        conflicts.add(item.record.id);
      }
    }
    if (conflicts.isNotEmpty) throw FeedBackupIdConflictException(conflicts);

    final sourcesById = {
      for (final source in await repository.getAll()) source.id: source,
    };
    final accepted = mapped.where((item) => item.profileId != null).toList();
    final profileIds = {for (final item in accepted) item.profileId!};
    final finalOrder = <String, List<String>>{};
    for (final profileId in profileIds) {
      final rows =
          accepted.where((item) => item.profileId == profileId).toList()..sort((
            left,
            right,
          ) {
            final position = left.record.position.compareTo(
              right.record.position,
            );
            return position != 0 ? position : left.index.compareTo(right.index);
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
    for (final profileId in profileIds) {
      final previousFeeds = (await repository.getFeeds())
          .where((feed) => feed.profileId == profileId)
          .toList();
      final previousSources = (await repository.getAll())
          .where((source) => source.profileId == profileId)
          .toList();
      try {
        for (final item in accepted.where(
          (item) => item.profileId == profileId,
        )) {
          final record = item.record;
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
        await repository.setFeedOrder(profileId, finalOrder[profileId]!);
      } catch (error, stackTrace) {
        await repository.restoreForProfile(profileId, previousSources);
        await repository.restoreFeeds(profileId, previousFeeds);
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
    return TopicFeedImportResult(
      importedCount: imported,
      alreadyExistedCount: existing,
      skippedProfileCount: mapped.length - accepted.length,
    );
  }

  Future<TopicFeedImportResult> _applyActions(
    TopicFeedBackupData data, {
    required List<BooruConfig> profiles,
    required bool allowMissingProfiles,
    required Map<String, CollectionImportAction> actions,
    required BackupProfileIdResolver? profileIdResolver,
  }) async {
    final localFeeds = await repository.getFeeds();
    final localById = {for (final feed in localFeeds) feed.id: feed};
    final sourcesById = {
      for (final source in await repository.getAll()) source.id: source,
    };
    final resolved = <TopicFeedBackupRecord>[];
    var skippedProfiles = 0;
    for (final record in data.feeds) {
      final profileId = resolveBackupProfileId(
        record.profile,
        profiles,
        resolver: profileIdResolver,
      );
      if (profileId == null) {
        skippedProfiles++;
        continue;
      }
      final resolution = actions[record.id];
      if (resolution == null || resolution.action == ImportAction.skip) {
        continue;
      }
      final destinationId = switch (resolution.action) {
        ImportAction.mergeIntoTarget => resolution.targetId,
        ImportAction.copy =>
          resolution.destinationId ??
              (localById.containsKey(record.id) ? null : record.id),
        ImportAction.update ||
        ImportAction.merge ||
        ImportAction.replace => record.id,
        _ => null,
      };
      if (destinationId == null) {
        throw StateError('Feed target is unresolved.');
      }
      final local = localById[destinationId];
      if (switch (resolution.action) {
        ImportAction.update ||
        ImportAction.merge ||
        ImportAction.replace => local == null,
        ImportAction.mergeIntoTarget => local == null,
        ImportAction.copy => local != null,
        _ => true,
      }) {
        throw StateError('Feed action is not applicable.');
      }
      if (local != null && local.profileId != profileId) {
        throw FeedBackupIdConflictException({destinationId});
      }
      final localQueries = [
        for (final id in local?.sourceIds ?? const <String>[])
          if (sourcesById[id] case final source?) source.query,
      ];
      final merge = {
        ImportAction.merge,
        ImportAction.mergeIntoTarget,
      }.contains(resolution.action);
      resolved.add(
        TopicFeedBackupRecord(
          id: destinationId,
          name: merge ? local!.name : record.name,
          position: merge ? local!.position : record.position,
          queries: merge
              ? _orderedQueryUnion(localQueries, record.queries)
              : record.queries,
          profile: record.profile,
        ),
      );
    }
    final result = await apply(
      TopicFeedBackupData(feeds: resolved),
      profiles: profiles,
      allowMissingProfiles: allowMissingProfiles,
      profileIdResolver: profileIdResolver,
    );
    return TopicFeedImportResult(
      importedCount: result.importedCount,
      alreadyExistedCount: result.alreadyExistedCount,
      skippedProfileCount: result.skippedProfileCount + skippedProfiles,
    );
  }
}

bool _sameQueries(List<String> left, List<String> right) =>
    left.length == right.length &&
    [
      for (var i = 0; i < left.length; i++) left[i] == right[i],
    ].every((same) => same);

List<String> _orderedQueryUnion(
  Iterable<String> current,
  Iterable<String> imported,
) {
  final seen = <String>{};
  return [
    for (final query in [...current, ...imported])
      if (seen.add(normalizeSearchIdentity(query))) query,
  ];
}
