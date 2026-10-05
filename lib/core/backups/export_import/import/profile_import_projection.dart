import '../../../configs/config/types.dart';
import '../../sources/search_backup_profile.dart';
import '../models/import_action.dart';
import 'import_plan.dart';
import 'profile_mapping.dart';

final class UnresolvedProfileImportException implements Exception {
  const UnresolvedProfileImportException(this.exportedProfileId);

  final String exportedProfileId;
}

final class ConflictingProfileIdentityException implements Exception {
  const ConflictingProfileIdentityException(this.profileId);

  final String profileId;
}

final class ProfileImportProjection {
  ProfileImportProjection({
    required Iterable<BooruConfig> profiles,
    required Map<String, String> destinationIds,
  }) : profiles = List.unmodifiable(profiles),
       destinationIds = Map.unmodifiable(destinationIds);

  final List<BooruConfig> profiles;
  final Map<String, String> destinationIds;
}

final class ProfileImportProjector {
  const ProfileImportProjector();

  ProfileImportProjection project({
    required List<BooruConfig> imported,
    required List<BooruConfig> local,
    required ResolvedImportSource resolution,
    required bool credentialsIncluded,
    Map<String, String> copyIds = const {},
  }) {
    if (resolution.action == ImportAction.skip) {
      return ProfileImportProjection(profiles: local, destinationIds: const {});
    }
    final seen = <String>{};
    for (final profile in imported) {
      if (!seen.add(profile.id)) {
        throw ConflictingProfileIdentityException(profile.id);
      }
      _existingById(profile, local);
    }
    return switch (resolution.action) {
      ImportAction.replace => _replace(imported, local, credentialsIncluded),
      ImportAction.configureItems => _configure(
        imported,
        local,
        resolution,
        credentialsIncluded,
        copyIds,
      ),
      _ => throw StateError('Unsupported profile import action'),
    };
  }

  ProfileImportProjection _replace(
    List<BooruConfig> imported,
    List<BooruConfig> local,
    bool credentialsIncluded,
  ) {
    final profiles = [
      for (final profile in imported)
        _credentialsForUpdate(
          imported: profile,
          existing: _existingById(profile, local),
          credentialsIncluded: credentialsIncluded,
        ),
    ];
    return ProfileImportProjection(
      profiles: profiles,
      destinationIds: {for (final profile in imported) profile.id: profile.id},
    );
  }

  ProfileImportProjection _configure(
    List<BooruConfig> imported,
    List<BooruConfig> local,
    ResolvedImportSource resolution,
    bool credentialsIncluded,
    Map<String, String> copyIds,
  ) {
    final result = local.toList();
    final actions = {for (final item in resolution.items) item.id: item};
    final destinationIds = <String, String>{};
    for (final profile in imported) {
      final item = actions['profile:${profile.id}'];
      if (item == null || item.action == ImportAction.skip) continue;
      switch (item.action) {
        case ImportAction.copy:
          final copyId = copyIds[profile.id] ?? createProfileId();
          if (!isCanonicalProfileId(copyId) ||
              result.any((value) => value.id == copyId)) {
            throw ConflictingProfileIdentityException(copyId);
          }
          result.add(_withId(profile, copyId));
          destinationIds[profile.id] = copyId;
        case ImportAction.update:
          final targetId = _targetId(item.targetId) ?? profile.id;
          final existing = result
              .where((value) => value.id == targetId)
              .firstOrNull;
          if (existing == null) {
            throw UnresolvedProfileImportException(profile.id);
          }
          if (!_compatible(profile, existing)) {
            throw ConflictingProfileIdentityException(profile.id);
          }
          final index = result.indexWhere((value) => value.id == targetId);
          result[index] = _withId(
            _credentialsForUpdate(
              imported: profile,
              existing: existing,
              credentialsIncluded: credentialsIncluded,
            ),
            targetId,
          );
          destinationIds[profile.id] = targetId;
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

  BooruConfig? _existingById(BooruConfig imported, List<BooruConfig> local) {
    for (final profile in local) {
      if (profile.id != imported.id) continue;
      if (!_compatible(imported, profile)) {
        throw ConflictingProfileIdentityException(imported.id);
      }
      return profile;
    }
    return null;
  }

  bool _compatible(BooruConfig imported, BooruConfig local) =>
      imported.auth.booruType == local.auth.booruType &&
      normalizeBackupProfileUrl(imported.url) ==
          normalizeBackupProfileUrl(local.url);

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

  BooruConfig _withId(BooruConfig profile, String id) =>
      BooruConfig.fromJson({...profile.toJson(), 'id': id});

  String? _targetId(String? value) => switch (value) {
    final String value
        when value.startsWith('profile:') &&
            isCanonicalProfileId(value.substring('profile:'.length)) =>
      value.substring('profile:'.length),
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
