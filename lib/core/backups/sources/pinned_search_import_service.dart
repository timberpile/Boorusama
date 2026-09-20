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
