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

class PinnedSearchImportService {
  const PinnedSearchImportService({required this.repository});

  final SearchSubscriptionRepository repository;

  Future<PinnedSearchImportResult> apply(
    PinnedSearchBackupData data, {
    required List<BooruConfig> profiles,
  }) async {
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
      if (await repository.getById(record.id) != null ||
          await repository.findByQuery(profile.id, record.query) != null) {
        existing++;
        continue;
      }
      await repository.create(
        profileId: profile.id,
        query: record.query,
        name: record.name,
        id: record.id,
      );
      imported++;
    }
    final folders = (await repository.getFolders()).toList();
    final orderedFolders = data.folders.toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    for (final record in orderedFolders) {
      final profile = _resolveProfile(record.profile, profiles);
      if (profile == null) continue;
      if (folders.any((f) => f.id == record.id && f.profileId != profile.id)) {
        continue;
      }
      final owned = folders.where((f) => f.profileId == profile.id).toList();
      final existingFolder = owned.firstWhereOrNull(
        (f) =>
            f.id == record.id ||
            f.name.toLowerCase() == record.name.toLowerCase(),
      );
      final members = <String>{...existingFolder?.searchIds ?? {}};
      for (final id in record.searchIds) {
        final source = data.records.firstWhereOrNull((r) => r.id == id);
        if (source == null) continue;
        final search = await repository.findByQuery(profile.id, source.query);
        if (search != null &&
            !owned.any(
              (f) =>
                  f.id != existingFolder?.id && f.searchIds.contains(search.id),
            )) {
          members.add(search.id);
        }
      }
      final folder =
          existingFolder?.copyWith(searchIds: members) ??
          SearchFolder(
            id: record.id,
            profileId: profile.id,
            name: record.name,
            position: owned.length,
            searchIds: members,
          );
      owned.removeWhere((f) => f.id == folder.id);
      owned.add(folder);
      await repository.replaceFolders(profile.id, owned);
      folders.removeWhere((f) => f.profileId == profile.id);
      folders.addAll(owned);
    }
    final feeds = (await repository.getFeeds()).toList();
    for (final record in data.feeds) {
      final profile = _resolveProfile(record.profile, profiles);
      if (profile == null) {
        skipped++;
        continue;
      }
      if (feeds.any((f) => f.id == record.id && f.profileId != profile.id)) {
        existing++;
        continue;
      }
      if (feeds.any(
        (f) =>
            f.profileId == profile.id &&
            (f.id == record.id ||
                f.name.toLowerCase() == record.name.toLowerCase()),
      )) {
        existing++;
        continue;
      }
      final feed = await repository.saveFeed(
        profileId: profile.id,
        name: record.name,
        queries: record.queries,
        id: record.id,
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
