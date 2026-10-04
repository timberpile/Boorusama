import 'package:equatable/equatable.dart';

import '../../sources/search_backup_profile.dart';
import '../../../configs/config/types.dart';

enum ProfileMappingState { automatic, resolved, missing, ambiguous }

final class ProfileMapping extends Equatable {
  ProfileMapping({
    required this.reference,
    required this.state,
    required Iterable<String> candidateIds,
    this.localProfileId,
  }) : candidateIds = Set.unmodifiable(candidateIds);

  final BackupProfileReference reference;
  final ProfileMappingState state;
  final Set<String> candidateIds;
  final String? localProfileId;

  bool get isResolved => localProfileId != null;

  ProfileMapping choose(String profileId) {
    if (!candidateIds.contains(profileId)) {
      throw ArgumentError.value(profileId, 'profileId');
    }
    return ProfileMapping(
      reference: reference,
      state: ProfileMappingState.resolved,
      candidateIds: candidateIds,
      localProfileId: profileId,
    );
  }

  @override
  List<Object?> get props => [
    reference,
    state,
    candidateIds,
    localProfileId,
  ];
}

final class ProfileMapper {
  const ProfileMapper();

  List<ProfileMapping> map(
    Iterable<BackupProfileReference> references,
    List<BooruConfig> localProfiles,
  ) => [
    for (final reference in references) _mapOne(reference, localProfiles),
  ];

  ProfileMapping _mapOne(
    BackupProfileReference reference,
    List<BooruConfig> profiles,
  ) {
    final sameId = profiles
        .where((profile) => profile.id == reference.id)
        .toList();
    if (sameId.length == 1 &&
        sameId.single.auth.booruType.name == reference.booruType &&
        normalizeBackupProfileUrl(sameId.single.url) ==
            normalizeBackupProfileUrl(reference.url)) {
      return ProfileMapping(
        reference: reference,
        state: ProfileMappingState.automatic,
        candidateIds: {reference.id},
        localProfileId: reference.id,
      );
    }
    final sameSite = profiles
        .where(
          (profile) =>
              profile.auth.booruType.name == reference.booruType &&
              normalizeBackupProfileUrl(profile.url) ==
                  normalizeBackupProfileUrl(reference.url),
        )
        .toList();
    if (sameSite.isNotEmpty) {
      return _unresolved(reference, sameSite, ProfileMappingState.ambiguous);
    }
    final compatible = profiles
        .where(
          (profile) => profile.auth.booruType.name == reference.booruType,
        )
        .toList();
    return _unresolved(
      reference,
      compatible,
      compatible.isEmpty
          ? ProfileMappingState.missing
          : ProfileMappingState.ambiguous,
    );
  }

  ProfileMapping _unresolved(
    BackupProfileReference reference,
    Iterable<BooruConfig> candidates,
    ProfileMappingState state,
  ) => ProfileMapping(
    reference: reference,
    state: state,
    candidateIds: {for (final profile in candidates) profile.id},
  );
}

BooruConfig mergeImportedProfile({
  required BooruConfig imported,
  required BooruConfig existing,
  required bool credentialsIncluded,
}) {
  if (credentialsIncluded) return imported;
  final json = imported.toJson()
    ..['apiKey'] = existing.apiKey
    ..['login'] = existing.login
    ..['passHash'] = existing.passHash;
  if ((json['proxySettings'], existing.proxySettings?.toJson()) case (
    final Map<String, dynamic> importedProxy,
    final Map<String, dynamic> existingProxy,
  )) {
    json['proxySettings'] = {
      ...importedProxy,
      'username': existingProxy['username'],
      'password': existingProxy['password'],
    };
  }
  return BooruConfig.fromJson(json);
}
