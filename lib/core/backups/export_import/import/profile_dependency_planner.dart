import 'package:equatable/equatable.dart';

import '../../../boorus/booru/types.dart';
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

  final String exportedId;
  final String booruType;
  final String url;

  @override
  List<Object> get props => [exportedId, booruType, url];
}

final class ProfileDependencyMapping extends Equatable {
  ProfileDependencyMapping({
    required this.reference,
    required Iterable<String> candidateIds,
    this.profileId,
    required this.providedByImport,
    this.createdFromReference = false,
  }) : candidateIds = Set.unmodifiable(candidateIds);

  final BackupProfileReference reference;
  final Set<String> candidateIds;
  final String? profileId;
  final bool providedByImport;
  final bool createdFromReference;

  bool get isResolved => profileId != null;

  @override
  List<Object?> get props => [
    reference,
    candidateIds,
    profileId,
    providedByImport,
    createdFromReference,
  ];
}

final class ProfileDependencyPlan extends Equatable {
  ProfileDependencyPlan({
    required Iterable<BooruConfig> projectedProfiles,
    required Iterable<ProfileDependencyMapping> mappings,
    required Iterable<ImportPlanIssue> errors,
    Iterable<BooruConfig> createdProfiles = const [],
  }) : projectedProfiles = List.unmodifiable(projectedProfiles),
       mappings = List.unmodifiable(mappings),
       errors = List.unmodifiable(errors),
       createdProfiles = List.unmodifiable(createdProfiles);

  final List<BooruConfig> projectedProfiles;
  final List<ProfileDependencyMapping> mappings;
  final List<ImportPlanIssue> errors;
  final List<BooruConfig> createdProfiles;

  String? profileIdFor(BackupProfileReference reference) {
    final key = ProfileReferenceKey.fromReference(reference);
    for (final mapping in mappings) {
      if (ProfileReferenceKey.fromReference(mapping.reference) == key) {
        return mapping.profileId;
      }
    }
    return null;
  }

  @override
  List<Object> get props => [
    projectedProfiles,
    mappings,
    errors,
    createdProfiles,
  ];
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
    Map<ProfileReferenceKey, String> choices = const {},
    Set<ProfileReferenceKey> createFromReferences = const {},
  }) {
    var projected = localProfiles;
    var destinationIds = const <String, String>{};
    final errors = <ImportPlanIssue>[];
    if (importedProfiles.isNotEmpty && profileResolution != null) {
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

    final uniqueReferences = <ProfileReferenceKey, BackupProfileReference>{};
    for (final reference in references) {
      uniqueReferences[ProfileReferenceKey.fromReference(reference)] =
          reference;
    }
    final importedById = {
      for (final profile in importedProfiles) profile.id: profile,
    };
    final mappings = <ProfileDependencyMapping>[];
    final createdProfiles = <BooruConfig>[];
    for (final entry in uniqueReferences.entries) {
      final matchingId = projected
          .where(
            (profile) => profile.id == entry.key.exportedId,
          )
          .firstOrNull;
      if (matchingId != null &&
          (matchingId.auth.booruType.name != entry.key.booruType ||
              normalizeBackupProfileUrl(matchingId.url) != entry.key.url)) {
        errors.add(
          ImportPlanIssue(
            code: 'profile_identity_conflict',
            sourceId: 'profiles',
            itemId: 'profile:${entry.key.exportedId}',
          ),
        );
        mappings.add(
          ProfileDependencyMapping(
            reference: entry.value,
            candidateIds: const {},
            providedByImport: false,
          ),
        );
        continue;
      }
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

      if (createFromReferences.contains(entry.key) && matchingId == null) {
        final created = _createProfile(entry.value, entry.value.id);
        if (created == null) {
          mappings.add(
            ProfileDependencyMapping(
              reference: entry.value,
              candidateIds: const {},
              providedByImport: false,
            ),
          );
          errors.add(
            ImportPlanIssue(
              code: 'unsupported_profile_type',
              sourceId: 'profiles',
              itemId: entry.key.exportedId,
            ),
          );
          continue;
        }
        projected = [...projected, created];
        createdProfiles.add(created);
        mappings.add(
          ProfileDependencyMapping(
            reference: entry.value,
            candidateIds: {created.id},
            profileId: created.id,
            providedByImport: false,
            createdFromReference: true,
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
            itemId: entry.key.exportedId,
            profileDependency: ProfileDependencyIssueContext(
              reference: entry.value,
              label: _referenceLabel(entry.value, uniqueReferences.values),
              sourceIds:
                  dependentSources[entry.key] ??
                  const {'pinned_searches', 'following_feeds'},
            ),
          ),
        );
      }
    }
    return ProfileDependencyPlan(
      projectedProfiles: projected,
      mappings: mappings,
      errors: errors,
      createdProfiles: createdProfiles,
    );
  }

  String _referenceLabel(
    BackupProfileReference reference,
    Iterable<BackupProfileReference> references,
  ) {
    final sameName = references
        .where((other) => other.name == reference.name)
        .toList();
    final name = reference.name.trim().isEmpty ? reference.url : reference.name;
    if (sameName.length < 2) return name;
    final site = normalizeBackupProfileUrl(reference.url);
    final sameSite = sameName.where(
      (other) => normalizeBackupProfileUrl(other.url) == site,
    );
    return sameSite.length > 1
        ? '$name ($site; ${reference.id})'
        : '$name ($site)';
  }

  BooruConfig? _createProfile(BackupProfileReference reference, String id) {
    final type = BooruYamlConfigs.values
        .map((config) => config.type)
        .firstWhere(
          (type) => type.name == reference.booruType,
          orElse: () => BooruType.unknown,
        );
    if (type == BooruType.unknown) return null;
    return BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': id,
      'booruId': type.id,
      'booruIdHint': type.id,
      'url': reference.url,
      'name': reference.name,
      'apiKey': null,
      'login': null,
      'passHash': null,
      'proxySettings': null,
    });
  }
}
