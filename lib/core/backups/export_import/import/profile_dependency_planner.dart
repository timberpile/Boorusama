import 'package:equatable/equatable.dart';

import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../../sources/search_backup_profile.dart';
import 'import_plan.dart';
import 'profile_import_projection.dart';

final class ProfileReferenceKey extends Equatable {
  const ProfileReferenceKey({
    required this.exportedId,
    required this.booruType,
    required this.url,
  });

  factory ProfileReferenceKey.fromReference(BackupProfileReference reference) =>
      ProfileReferenceKey(
        exportedId: reference.id,
        booruType: reference.booruType,
        url: normalizePostSourceHost(reference.url),
      );

  final String exportedId;
  final String booruType;
  final String url;

  @override
  List<Object> get props => [exportedId, booruType, url];
}

final class ProfileSiteKey extends Equatable {
  const ProfileSiteKey({required this.booruType, required this.site});

  factory ProfileSiteKey.fromReference(BackupProfileReference reference) {
    final site = normalizePostSourceHost(reference.url);
    return ProfileSiteKey(
      booruType: reference.booruType,
      site: site.isEmpty ? 'invalid:${reference.id}:${reference.url}' : site,
    );
  }

  final String booruType;
  final String site;

  @override
  List<Object> get props => [booruType, site];
}

final class ProfileDependencyMapping extends Equatable {
  ProfileDependencyMapping({
    required this.reference,
    Iterable<BackupProfileReference>? references,
    required Iterable<String> candidateIds,
    this.profileId,
    required this.providedByImport,
  }) : references = List.unmodifiable(references ?? [reference]),
       candidateIds = Set.unmodifiable(candidateIds);

  final BackupProfileReference reference;
  final List<BackupProfileReference> references;
  final Set<String> candidateIds;
  final String? profileId;
  final bool providedByImport;
  ProfileSiteKey get siteKey => ProfileSiteKey.fromReference(reference);
  bool get isResolved => profileId != null;

  @override
  List<Object?> get props => [
    references,
    candidateIds,
    profileId,
    providedByImport,
  ];
}

final class ProfileDependencyPlan extends Equatable {
  ProfileDependencyPlan({
    required Iterable<BooruConfig> projectedProfiles,
    required Iterable<ProfileDependencyMapping> mappings,
    required Iterable<ImportPlanIssue> errors,
  }) : projectedProfiles = List.unmodifiable(projectedProfiles),
       mappings = List.unmodifiable(mappings),
       errors = List.unmodifiable(errors);

  final List<BooruConfig> projectedProfiles;
  final List<ProfileDependencyMapping> mappings;
  final List<ImportPlanIssue> errors;

  String? profileIdFor(BackupProfileReference reference) {
    final key = ProfileSiteKey.fromReference(reference);
    for (final mapping in mappings) {
      if (mapping.siteKey == key) return mapping.profileId;
    }
    return null;
  }

  @override
  List<Object> get props => [projectedProfiles, mappings, errors];
}

final class ProfileDependencyPlanner {
  const ProfileDependencyPlanner();

  ProfileDependencyPlan plan({
    required Iterable<BackupProfileReference> references,
    required List<BooruConfig> localProfiles,
    Map<ProfileReferenceKey, Set<String>> dependentSources = const {},
    List<BooruConfig> importedProfiles = const [],
    ResolvedImportSource? profileResolution,
    bool credentialsIncluded = false,
    Map<String, String> copyIds = const {},
    Map<ProfileSiteKey, String> choices = const {},
  }) {
    var projected = localProfiles;
    var destinationIds = const <String, String>{};
    final errors = <ImportPlanIssue>[];
    if (profileResolution != null) {
      try {
        final projection = const ProfileImportProjector().project(
          imported: importedProfiles,
          local: localProfiles,
          resolution: profileResolution,
          credentialsIncluded: credentialsIncluded,
          copyIds: copyIds,
        );
        projected = projection.profiles;
        destinationIds = projection.destinationIds;
      } on ConflictingProfileIdentityException catch (error) {
        errors.add(
          ImportPlanIssue(
            code: 'profile_identity_conflict',
            sourceId: 'profiles',
            itemId: 'profile:${error.profileId}',
          ),
        );
      } on UnresolvedProfileImportException catch (error) {
        errors.add(
          ImportPlanIssue(
            code: 'unresolved_profile_import',
            sourceId: 'profiles',
            itemId: 'profile:${error.exportedProfileId}',
          ),
        );
      }
    }

    final grouped =
        <ProfileSiteKey, Map<ProfileReferenceKey, BackupProfileReference>>{};
    for (final reference in references) {
      grouped.putIfAbsent(
        ProfileSiteKey.fromReference(reference),
        () => {},
      )[ProfileReferenceKey.fromReference(reference)] = reference;
    }
    final mappings = <ProfileDependencyMapping>[];
    for (final entry in grouped.entries) {
      final siteKey = entry.key;
      final group = entry.value.values.toList();
      final reference = group.first;
      final validSite = normalizePostSourceHost(reference.url).isNotEmpty;
      bool matches(BooruConfig profile) =>
          validSite &&
          profile.auth.booruType.name == siteKey.booruType &&
          normalizePostSourceHost(profile.url) == siteKey.site;
      final candidates = projected.where(matches).toList();
      final candidateIds = {for (final profile in candidates) profile.id};
      final conflicts = <String>{};
      for (final reference in group) {
        for (final profile in [...localProfiles, ...projected]) {
          if (profile.id == reference.id && !matches(profile)) {
            conflicts.add(reference.id);
          }
        }
      }
      for (final id in conflicts) {
        errors.add(
          ImportPlanIssue(
            code: 'profile_identity_conflict',
            sourceId: 'profiles',
            itemId: 'profile:$id',
          ),
        );
      }
      final exactTargets = <String>{};
      for (final reference in group) {
        final destination = destinationIds[reference.id];
        if (destination != null && candidateIds.contains(destination)) {
          exactTargets.add(destination);
        } else if (candidateIds.contains(reference.id)) {
          exactTargets.add(reference.id);
        }
      }
      final choice = choices[siteKey];
      final chosen = conflicts.isNotEmpty
          ? null
          : choice != null
          ? (candidateIds.contains(choice) ? choice : null)
          : candidateIds.length == 1
          ? candidateIds.single
          : exactTargets.length == 1
          ? exactTargets.single
          : null;
      mappings.add(
        ProfileDependencyMapping(
          reference: reference,
          references: group,
          candidateIds: conflicts.isEmpty ? candidateIds : const {},
          profileId: chosen,
          providedByImport:
              chosen != null && destinationIds.values.contains(chosen),
        ),
      );
      if (chosen == null && conflicts.isEmpty) {
        final sourceIds = <String>{
          for (final reference in group)
            ...?dependentSources[ProfileReferenceKey.fromReference(reference)],
        };
        errors.add(
          ImportPlanIssue(
            code: 'unresolved_profile_dependency',
            sourceId: 'profiles',
            itemId: '${siteKey.booruType}:${siteKey.site}',
            profileDependency: ProfileDependencyIssueContext(
              reference: reference,
              label: validSite ? siteKey.site : reference.url,
              missingProfile: candidateIds.isEmpty,
              sourceIds: sourceIds.isEmpty
                  ? const {'pinned_searches', 'following_feeds'}
                  : sourceIds,
            ),
          ),
        );
      }
    }
    return ProfileDependencyPlan(
      projectedProfiles: projected,
      mappings: mappings,
      errors: errors,
    );
  }
}
