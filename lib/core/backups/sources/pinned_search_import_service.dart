// Package imports:
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

// Project imports:
import '../../configs/config/types.dart';
import '../../search/subscriptions/types.dart';
import 'pinned_search_backup_data.dart';

class PinnedSearchImportResult extends Equatable {
  const PinnedSearchImportResult({
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

class PinnedSearchImportPreview extends Equatable {
  PinnedSearchImportPreview({required Set<String> unmatchedRecordIds})
    : unmatchedRecordIds = Set.unmodifiable(unmatchedRecordIds);

  final Set<String> unmatchedRecordIds;

  @override
  List<Object?> get props => [unmatchedRecordIds];
}

class UnmatchedPinnedSearchProfilesException implements Exception {
  const UnmatchedPinnedSearchProfilesException(this.recordIds);

  final Set<String> recordIds;
}

class PinnedSearchImportService {
  const PinnedSearchImportService({required this.repository});

  final SearchSubscriptionRepository repository;

  PinnedSearchImportPreview preview(
    PinnedSearchBackupData data, {
    required List<BooruConfig> profiles,
  }) => PinnedSearchImportPreview(
    unmatchedRecordIds: {
      for (final record in data.records)
        if (_resolveProfile(record.profile, profiles) == null) record.id,
      for (final feed in data.feeds)
        if (_resolveProfile(feed.profile, profiles) == null) feed.id,
    },
  );

  Future<PinnedSearchImportResult> apply(
    PinnedSearchBackupData data, {
    required List<BooruConfig> profiles,
    bool allowMissingProfiles = false,
  }) async {
    final unmatched = preview(data, profiles: profiles).unmatchedRecordIds;
    if (unmatched.isNotEmpty && !allowMissingProfiles) {
      throw UnmatchedPinnedSearchProfilesException(unmatched);
    }
    final previousOrganization = await repository.getOrganization();
    final internalIds = {
      for (final feed in await repository.getFeeds()) ...feed.sourceIds,
    };
    final createdIds = <String>[];
    final importedByBackupId = <String, String>{};
    final ordered = data.records.indexed.toList()
      ..sort((left, right) {
        final byPosition = left.$2.position.compareTo(right.$2.position);
        return byPosition != 0 ? byPosition : left.$1.compareTo(right.$1);
      });
    final mapped = [
      for (final (_, record) in ordered)
        (record: record, profile: _resolveProfile(record.profile, profiles)),
    ];
    var imported = 0;
    var existing = 0;
    var skipped = 0;
    for (final (:record, :profile) in mapped) {
      if (profile == null) {
        skipped++;
        continue;
      }
      final byId = await repository.getById(record.id);
      final byQuery = await repository.findByQuery(profile.id, record.query);
      final saved =
          byQuery ??
          switch (byId) {
            final pin?
                when pin.profileId == profile.id &&
                    !internalIds.contains(pin.id) =>
              pin,
            _ => null,
          };
      if (saved != null) {
        importedByBackupId[record.id] = saved.id;
        existing++;
        continue;
      }
      final created = await repository.create(
        profileId: profile.id,
        query: record.query,
        name: record.name,
        id: byId == null ? record.id : null,
      );
      importedByBackupId[record.id] = created.id;
      createdIds.add(created.id);
      imported++;
    }
    if (createdIds.isNotEmpty ||
        data.folders.isNotEmpty ||
        data.homeSearchIds.isNotEmpty) {
      final organization = SearchOrganization(
        folders: previousOrganization.folders,
        homeSearchIds: [...previousOrganization.homeSearchIds, ...createdIds],
      );
      final assigned = <String>{};
      List<String> mappedIds(Iterable<String> ids) => [
        for (final id in ids)
          if (importedByBackupId[id] case final savedId?)
            if (assigned.add(savedId)) savedId,
      ];
      final home = mappedIds(data.homeSearchIds);
      final orderedFolders = data.folders.toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      final importedFolders = <SharedSearchFolder>[];
      final matchedFolderIds = <String>{};
      for (final record in orderedFolders) {
        final existingFolder =
            organization.folders.firstWhereOrNull(
              (folder) => folder.id == record.id,
            ) ??
            organization.folders.firstWhereOrNull(
              (folder) =>
                  folder.name.toLowerCase() == record.name.toLowerCase(),
            );
        final folderId = existingFolder?.id ?? record.id;
        matchedFolderIds.add(folderId);
        final importedIndex = importedFolders.indexWhere(
          (folder) => folder.id == folderId,
        );
        final members = mappedIds(record.searchIds);
        final folder = SharedSearchFolder(
          id: folderId,
          name: existingFolder?.name ?? record.name,
          searchIds: [
            if (importedIndex >= 0) ...importedFolders[importedIndex].searchIds,
            ...members,
          ],
        );
        if (importedIndex >= 0) {
          importedFolders[importedIndex] = folder;
        } else {
          importedFolders.add(folder);
        }
      }
      await repository.replaceOrganization(
        SearchOrganization(
          folders: [
            for (final folder in importedFolders)
              SharedSearchFolder(
                id: folder.id,
                name: folder.name,
                searchIds: [
                  ...folder.searchIds,
                  ...?organization.folders
                      .firstWhereOrNull((local) => local.id == folder.id)
                      ?.searchIds
                      .where((id) => !assigned.contains(id)),
                ],
              ),
            for (final folder in organization.folders)
              if (!matchedFolderIds.contains(folder.id))
                SharedSearchFolder(
                  id: folder.id,
                  name: folder.name,
                  searchIds: folder.searchIds.where(
                    (id) => !assigned.contains(id),
                  ),
                ),
          ],
          homeSearchIds: [
            ...home,
            ...organization.homeSearchIds.where((id) => !assigned.contains(id)),
          ],
        ),
      );
    }
    final feeds = (await repository.getFeeds()).toList();
    for (final record in data.feeds) {
      final profile = _resolveProfile(record.profile, profiles);
      if (profile == null) {
        skipped++;
        continue;
      }
      final idOwner = feeds.firstWhereOrNull((f) => f.id == record.id);
      if (idOwner?.profileId == profile.id) {
        existing++;
        continue;
      }
      if (idOwner != null) {
        final byId = {
          for (final search in await repository.getAll()) search.id: search,
        };
        final recordQueries = record.queries
            .map(normalizeSearchIdentity)
            .toSet();
        final importedBefore = feeds.any(
          (feed) =>
              feed.profileId == profile.id &&
              feed.name.toLowerCase() == record.name.toLowerCase() &&
              const SetEquality<String>().equals(
                {
                  for (final id in feed.sourceIds)
                    if (byId[id] case final search?)
                      normalizeSearchIdentity(search.query),
                },
                recordQueries,
              ),
        );
        if (importedBefore) {
          existing++;
          continue;
        }
      }
      final feed = await repository.saveFeed(
        profileId: profile.id,
        name: record.name,
        queries: record.queries,
        id: idOwner == null ? record.id : null,
      );
      feeds.add(feed);
      imported++;
    }
    return PinnedSearchImportResult(
      importedCount: imported,
      alreadyExistedCount: existing,
      skippedProfileCount: skipped,
    );
  }
}

BooruConfig? _resolveProfile(
  PinnedSearchProfileReference reference,
  List<BooruConfig> profiles,
) {
  final normalizedUrl = normalizePinnedSearchProfileUrl(reference.url);
  final matches = profiles
      .where(
        (profile) =>
            profile.auth.booruType.name == reference.booruType &&
            normalizePinnedSearchProfileUrl(profile.url) == normalizedUrl,
      )
      .toList();
  return matches.firstWhereOrNull((profile) => profile.id == reference.id) ??
      switch (matches) {
        [final profile] => profile,
        _ => null,
      };
}
