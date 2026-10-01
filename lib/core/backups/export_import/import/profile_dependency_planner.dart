import 'package:equatable/equatable.dart';

import '../../../configs/config/types.dart';
import '../../sources/search_backup_profile.dart';
import 'import_plan.dart';
import 'profile_import_projection.dart';
import 'profile_mapping.dart';

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
        url: normalizeBackupProfileUrl(reference.url),
      );

  final int exportedId;
  final String booruType;
  final String url;

  @override
  List<Object> get props => [exportedId, booruType, url];
}

final class ProfileDependencyMapping extends Equatable {
  ProfileDependencyMapping({
    required this.reference,
    required Iterable<int> candidateIds,
    this.profileId,
    required this.providedByImport,
  }) : candidateIds = Set.unmodifiable(candidateIds);

  final BackupProfileReference reference;
  final Set<int> candidateIds;
  final int? profileId;
  final bool providedByImport;

  bool get isResolved => profileId != null;

  @override
  List<Object?> get props => [
    reference,
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

  int? profileIdFor(BackupProfileReference reference) {
    final key = ProfileReferenceKey.fromReference(reference);
    for (final mapping in mappings) {
      if (ProfileReferenceKey.fromReference(mapping.reference) == key) {
        return mapping.profileId;
      }
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
    List<BooruConfig> importedProfiles = const [],
    ResolvedImportSource? profileResolution,
    bool credentialsIncluded = false,
    Map<ProfileReferenceKey, int> choices = const {},
  }) {
    var projected = localProfiles;
    var destinationIds = const <int, int>{};
    final errors = <ImportPlanIssue>[];
    if (importedProfiles.isNotEmpty && profileResolution != null) {
      try {
        final projection = const ProfileImportProjector().project(
          imported: importedProfiles,
          local: localProfiles,
          resolution: profileResolution,
          credentialsIncluded: credentialsIncluded,
        );
        projected = projection.profiles;
        destinationIds = projection.destinationIds;
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

    final uniqueReferences = <ProfileReferenceKey, BackupProfileReference>{};
    for (final reference in references) {
      uniqueReferences[ProfileReferenceKey.fromReference(reference)] =
          reference;
    }
    final importedById = {
      for (final profile in importedProfiles) profile.id: profile,
    };
    final mappings = <ProfileDependencyMapping>[];
    for (final entry in uniqueReferences.entries) {
      final imported = importedById[entry.key.exportedId];
      final importedDestination = destinationIds[entry.key.exportedId];
      final suppliedByImport =
          imported != null &&
          importedDestination != null &&
          imported.auth.booruType.name == entry.key.booruType &&
          normalizeBackupProfileUrl(imported.url) == entry.key.url;
      if (suppliedByImport) {
        mappings.add(
          ProfileDependencyMapping(
            reference: entry.value,
            candidateIds: {importedDestination},
            profileId: importedDestination,
            providedByImport: true,
          ),
        );
        continue;
      }

      final mapped = const ProfileMapper().map([
        entry.value,
      ], projected).single;
      final choice = choices[entry.key];
      final chosen = choice != null && mapped.candidateIds.contains(choice)
          ? choice
          : mapped.localProfileId;
      mappings.add(
        ProfileDependencyMapping(
          reference: entry.value,
          candidateIds: mapped.candidateIds,
          profileId: chosen,
          providedByImport: false,
        ),
      );
      if (chosen == null) {
        errors.add(
          ImportPlanIssue(
            code: 'unresolved_profile_dependency',
            sourceId: 'profiles',
            itemId: entry.key.exportedId.toString(),
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
