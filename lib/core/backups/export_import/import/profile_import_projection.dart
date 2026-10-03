import '../../../configs/config/types.dart';
import '../../sources/search_backup_profile.dart';
import '../models/import_action.dart';
import 'import_plan.dart';
import 'profile_mapping.dart';

final class UnresolvedProfileImportException implements Exception {
  const UnresolvedProfileImportException(this.exportedProfileId);

  final int exportedProfileId;
}

final class ProfileImportProjection {
  ProfileImportProjection({
    required Iterable<BooruConfig> profiles,
    required Map<int, int> destinationIds,
  }) : profiles = List.unmodifiable(profiles),
       destinationIds = Map.unmodifiable(destinationIds);

  final List<BooruConfig> profiles;
  final Map<int, int> destinationIds;
}

final class ProfileImportProjector {
  const ProfileImportProjector();

  ProfileImportProjection project({
    required List<BooruConfig> imported,
    required List<BooruConfig> local,
    required ResolvedImportSource resolution,
    required bool credentialsIncluded,
  }) {
    if (resolution.action == ImportAction.skip) {
      return ProfileImportProjection(profiles: local, destinationIds: const {});
    }
    return switch (resolution.action) {
      ImportAction.replace => _replace(
        imported: imported,
        local: local,
        credentialsIncluded: credentialsIncluded,
      ),
      ImportAction.configureItems => _configure(
        imported: imported,
        local: local,
        resolution: resolution,
        credentialsIncluded: credentialsIncluded,
      ),
      _ => throw StateError('Unsupported profile import action'),
    };
  }

  ProfileImportProjection _replace({
    required List<BooruConfig> imported,
    required List<BooruConfig> local,
    required bool credentialsIncluded,
  }) {
    final result = <BooruConfig>[];
    final destinationIds = <int, int>{};
    final matches = <_ProfileMatch>[];
    final reservedMatches = <int, int>{};
    final reservedIds = <int>{};
    for (final (index, profile) in imported.indexed) {
      final match = _match(profile, local);
      if (match.isAmbiguous && !credentialsIncluded) {
        throw UnresolvedProfileImportException(profile.id);
      }
      matches.add(match);
      if (match.profile case final existing?) {
        if (reservedIds.add(existing.id)) {
          reservedMatches[index] = existing.id;
        }
      }
    }
    final usedIds = {...reservedIds};
    var nextId = _nextId([...local, ...imported]);
    for (final (index, profile) in imported.indexed) {
      final matchedId = reservedMatches[index];
      final destinationId = matchedId ??
          (usedIds.contains(profile.id) ? nextId++ : profile.id);
      usedIds.add(destinationId);
      destinationIds[profile.id] = destinationId;
      result.add(
        _withId(
          _credentialsForUpdate(
            imported: profile,
            existing: matchedId == null ? null : matches[index].profile,
            credentialsIncluded: credentialsIncluded,
          ),
          destinationId,
        ),
      );
    }
    return ProfileImportProjection(
      profiles: result,
      destinationIds: destinationIds,
    );
  }

  ProfileImportProjection _configure({
    required List<BooruConfig> imported,
    required List<BooruConfig> local,
    required ResolvedImportSource resolution,
    required bool credentialsIncluded,
  }) {
    final result = local.toList();
    final actions = {for (final item in resolution.items) item.id: item};
    final destinationIds = <int, int>{};
    var nextId = _nextId([...local, ...imported]);
    for (final profile in imported) {
      final item = actions['profile:${profile.id}'];
      if (item == null || item.action == ImportAction.skip) continue;
      switch (item.action) {
        case ImportAction.copy:
          final usedIds = result.map((profile) => profile.id).toSet();
          final destinationId = usedIds.contains(profile.id)
              ? nextId++
              : profile.id;
          result.add(_withId(profile, destinationId));
          destinationIds[profile.id] = destinationId;
        case ImportAction.update:
          final targetId = _targetId(item.targetId);
          final match = targetId == null
              ? _match(profile, result)
              : _matchTarget(profile, result, targetId);
          final existing = match.profile;
          if (existing == null) {
            throw UnresolvedProfileImportException(profile.id);
          }
          final index = result.indexWhere((value) => value.id == existing.id);
          result[index] = _withId(
            _credentialsForUpdate(
              imported: profile,
              existing: existing,
              credentialsIncluded: credentialsIncluded,
            ),
            existing.id,
          );
          destinationIds[profile.id] = existing.id;
        case ImportAction.replace ||
            ImportAction.configureItems ||
            ImportAction.merge ||
            ImportAction.mergeIntoTarget ||
            ImportAction.skip:
          throw StateError('Unsupported profile item action');
      }
    }
    return ProfileImportProjection(
      profiles: result,
      destinationIds: destinationIds,
    );
  }

  _ProfileMatch _match(BooruConfig imported, List<BooruConfig> local) {
    final candidates = portableProfileMatches(imported, local);
    final sameId = candidates.where((profile) => profile.id == imported.id);
    if (sameId.length == 1) return _ProfileMatch(sameId.single, false);
    if (candidates.length == 1) return _ProfileMatch(candidates.single, false);
    return _ProfileMatch(null, candidates.length > 1);
  }

  _ProfileMatch _matchTarget(
    BooruConfig imported,
    List<BooruConfig> local,
    int targetId,
  ) {
    final candidates = portableProfileMatches(imported, local);
    final target = candidates.where((profile) => profile.id == targetId);
    return _ProfileMatch(target.length == 1 ? target.single : null, false);
  }

  BooruConfig _credentialsForUpdate({
    required BooruConfig imported,
    required BooruConfig? existing,
    required bool credentialsIncluded,
  }) => existing == null
      ? imported
      : mergeImportedProfile(
          imported: imported,
          existing: existing,
          credentialsIncluded: credentialsIncluded,
        );

  BooruConfig _withId(BooruConfig profile, int id) =>
      BooruConfig.fromJson({...profile.toJson(), 'id': id});

  int _nextId(Iterable<BooruConfig> profiles) =>
      profiles.fold<int>(
        0,
        (value, profile) => profile.id > value ? profile.id : value,
      ) +
      1;

  int? _targetId(String? value) => switch (value) {
    final String value when value.startsWith('profile:') => int.tryParse(
      value.substring('profile:'.length),
    ),
    _ => null,
  };
}

List<BooruConfig> portableProfileMatches(
  BooruConfig imported,
  Iterable<BooruConfig> local,
) => [
  for (final profile in local)
    if (profile.auth.booruType == imported.auth.booruType &&
        normalizeBackupProfileUrl(profile.url) ==
            normalizeBackupProfileUrl(imported.url))
      profile,
];

final class _ProfileMatch {
  const _ProfileMatch(this.profile, this.isAmbiguous);

  final BooruConfig? profile;
  final bool isAmbiguous;
}
