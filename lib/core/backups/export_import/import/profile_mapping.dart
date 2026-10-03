import 'package:equatable/equatable.dart';

import '../../sources/search_backup_profile.dart';
import '../../../configs/config/types.dart';

enum ProfileMappingState { automatic, resolved, missing, ambiguous }

final class ProfileMapping extends Equatable {
  ProfileMapping({
    required this.reference,
    required this.state,
    required Iterable<int> candidateIds,
    this.localProfileId,
  }) : candidateIds = Set.unmodifiable(candidateIds);

  final BackupProfileReference reference;
  final ProfileMappingState state;
  final Set<int> candidateIds;
  final int? localProfileId;

  bool get isResolved => localProfileId != null;

  ProfileMapping choose(int profileId) {
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
    final normalizedUrl = normalizeBackupProfileUrl(reference.url);
    final exact = profiles
        .where(
          (profile) =>
              profile.auth.booruType.name == reference.booruType &&
              normalizeBackupProfileUrl(profile.url) == normalizedUrl,
        )
        .toList();
    final sameId = exact
        .where((profile) => profile.id == reference.id)
        .toList();
    if (sameId.length == 1) return _automatic(reference, sameId.single.id);
    if (exact.length == 1) return _automatic(reference, exact.single.id);
    if (exact.length > 1) {
      return _unresolved(reference, exact, ProfileMappingState.ambiguous);
    }

    final compatible = profiles
        .where((profile) => profile.auth.booruType.name == reference.booruType)
        .toList();
    if (compatible.length == 1) {
      return _automatic(reference, compatible.single.id);
    }
    return _unresolved(
      reference,
      compatible,
      compatible.isEmpty
          ? ProfileMappingState.missing
          : ProfileMappingState.ambiguous,
    );
  }

  ProfileMapping _automatic(BackupProfileReference reference, int id) =>
      ProfileMapping(
        reference: reference,
        state: ProfileMappingState.automatic,
        candidateIds: {id},
        localProfileId: id,
      );

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
