import 'package:equatable/equatable.dart';

import '../../sources/search_backup_profile.dart';
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';

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
    final sameSite = profiles
        .where(
          (profile) =>
              profile.auth.booruType.name == reference.booruType &&
              normalizePostSourceHost(reference.url).isNotEmpty &&
              normalizePostSourceHost(profile.url) ==
                  normalizePostSourceHost(reference.url),
        )
        .toList();
    final sameId = sameSite.where((profile) => profile.id == reference.id);
    if (sameId.length == 1) {
      return ProfileMapping(
        reference: reference,
        state: ProfileMappingState.automatic,
        candidateIds: {for (final profile in sameSite) profile.id},
        localProfileId: reference.id,
      );
    }
    if (sameSite.isNotEmpty) {
      return _unresolved(reference, sameSite, ProfileMappingState.ambiguous);
    }
    return _unresolved(reference, const [], ProfileMappingState.missing);
  }

  ProfileMapping _unresolved(
    BackupProfileReference reference,
    Iterable<BooruConfig> candidates,
    ProfileMappingState state,
  ) {
    final candidateIds = {for (final profile in candidates) profile.id};
    return ProfileMapping(
      reference: reference,
      state: candidateIds.length == 1 ? ProfileMappingState.automatic : state,
      candidateIds: candidateIds,
      localProfileId: candidateIds.length == 1 ? candidateIds.single : null,
    );
  }
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
