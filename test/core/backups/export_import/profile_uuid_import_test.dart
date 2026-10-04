import 'package:boorusama/core/backups/export_import/import/import_planned_change_projector.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/profile_dependency_planner.dart';
import 'package:boorusama/core/backups/export_import/import/profile_import_projection.dart';
import 'package:boorusama/core/backups/export_import/import/profile_mapping.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:flutter_test/flutter_test.dart';

const sourceId = '4d5b640c-cf50-4291-83f6-d6ff359e6389';
const localId = 'f6b8db8b-fb20-4f3b-b7b0-47780786ab43';

void main() {
  test(
    'profile copy gives the copy a new UUID and remaps its dependencies',
    () {
      final source = _profile(sourceId, 'https://same.example');
      final local = _profile(localId, 'https://same.example');
      const reference = BackupProfileReference(
        id: sourceId,
        booruType: 'danbooru',
        url: 'https://same.example',
        name: 'Source',
      );
      final result = const ProfileDependencyPlanner().plan(
        references: [reference],
        localProfiles: [local],
        importedProfiles: [source],
        profileResolution: ResolvedImportSource(
          id: 'profiles',
          action: ImportAction.configureItems,
          items: [
            ResolvedImportItem(
              id: 'profile:$sourceId',
              action: ImportAction.copy,
            ),
          ],
        ),
      );
      final copyId = result.profileIdFor(reference);
      expect(result.errors, isEmpty);
      expect(copyId, isNot(sourceId));
      expect(copyId, isNot(localId));
      expect(isCanonicalProfileId(copyId), isTrue);
      expect(
        result.projectedProfiles.map((profile) => profile.id),
        containsAll([localId, copyId]),
      );
    },
  );

  test('one approved copy ID is reused by preflight and apply projection', () {
    final source = _profile(sourceId, 'https://same.example');
    final local = _profile(localId, 'https://same.example');
    const copyId = 'cc8dfaa8-9d8c-4fb1-876a-c06d5a99edec';
    final resolution = ResolvedImportSource(
      id: 'profiles',
      action: ImportAction.configureItems,
      items: const [
        ResolvedImportItem(
          id: 'profile:$sourceId',
          action: ImportAction.copy,
        ),
      ],
    );
    final planned = const ProfileDependencyPlanner().plan(
      references: const [
        BackupProfileReference(
          id: sourceId,
          booruType: 'danbooru',
          url: 'https://same.example',
          name: 'Source',
        ),
      ],
      localProfiles: [local],
      importedProfiles: [source],
      profileResolution: resolution,
      copyIds: const {sourceId: copyId},
    );
    final applied = const ProfileImportProjector().project(
      imported: [source],
      local: [local],
      resolution: resolution,
      credentialsIncluded: false,
      copyIds: const {sourceId: copyId},
    );
    expect(planned.errors, isEmpty);
    expect(planned.mappings.single.profileId, copyId);
    expect(applied.destinationIds[sourceId], copyId);
    expect(applied.profiles.map((profile) => profile.id), contains(copyId));
  });

  test('a separate copy request can use a fresh UUID', () {
    final source = _profile(sourceId, 'https://same.example');
    final local = _profile(localId, 'https://same.example');
    final resolution = ResolvedImportSource(
      id: 'profiles',
      action: ImportAction.configureItems,
      items: const [
        ResolvedImportItem(
          id: 'profile:$sourceId',
          action: ImportAction.copy,
        ),
      ],
    );
    const firstCopyId = 'cc8dfaa8-9d8c-4fb1-876a-c06d5a99edec';
    const nextCopyId = 'd9324d44-49a7-4ca0-b624-819ea7cd3c47';
    final second = const ProfileImportProjector().project(
      imported: [source],
      local: [
        local,
        _profile(firstCopyId, 'https://same.example'),
      ],
      resolution: resolution,
      credentialsIncluded: false,
      copyIds: const {sourceId: nextCopyId},
    );
    expect(second.destinationIds[sourceId], nextCopyId);
    expect(
      second.profiles.map((profile) => profile.id),
      containsAll([firstCopyId, nextCopyId]),
    );
  });

  test('identity conflict stays in preflight instead of aborting review', () {
    final imported = _profile(sourceId, 'https://other.example');
    final local = _profile(sourceId, 'https://same.example');
    final resolution = ResolvedImportSource(
      id: 'profiles',
      action: ImportAction.replace,
      items: const [],
    );
    final dependencies = const ProfileDependencyPlanner().plan(
      references: const [],
      localProfiles: [local],
      importedProfiles: [imported],
      profileResolution: resolution,
    );
    final summary = const ImportPlannedChangeProjector().profiles(
      local: [local],
      imported: [imported],
      resolution: resolution,
      credentialsIncluded: false,
    );

    expect(
      dependencies.errors.map((issue) => issue.code),
      contains('profile_identity_conflict'),
    );
    expect(summary, isNull);
  });

  test('same UUID on a different site fails profile preflight', () {
    expect(
      () => const ProfileImportProjector().project(
        imported: [_profile(sourceId, 'https://other.example')],
        local: [_profile(sourceId, 'https://same.example')],
        resolution: ResolvedImportSource(
          id: 'profiles',
          action: ImportAction.replace,
          items: const [],
        ),
        credentialsIncluded: true,
      ),
      throwsA(isA<ConflictingProfileIdentityException>()),
    );
  });

  test('matching site with a different UUID requires an explicit mapping', () {
    final mappings = const ProfileMapper().map(
      const [
        BackupProfileReference(
          id: sourceId,
          booruType: 'danbooru',
          url: 'https://same.example',
          name: 'Source',
        ),
      ],
      [_profile(localId, 'https://same.example')],
    );
    expect(mappings.single.localProfileId, isNull);
    expect(mappings.single.candidateIds, {localId});
  });

  test('integer profile references fail format validation', () {
    expect(
      () => parseBackupProfile({
        'id': 4,
        'booruType': 'danbooru',
        'url': 'https://same.example',
        'name': 'Source',
      }, 'profile'),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });
}

BooruConfig _profile(String id, String url) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'booruId': BooruType.danbooru.id,
  'booruIdHint': BooruType.danbooru.id,
  'url': url,
  'name': 'Source',
});
