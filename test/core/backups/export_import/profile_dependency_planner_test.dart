import '../../../profile_uuid_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/profile_dependency_planner.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';

void main() {
  const remote = BackupProfileReference(
    id: '00000000-0000-4000-8000-00000000000c',
    booruType: 'danbooru',
    url: 'https://remote.example',
    name: 'Remote',
  );

  test(
    'unresolved issues retain distinct references and selected dependent kinds',
    () {
      const other = BackupProfileReference(
        id: '00000000-0000-4000-8000-000000000020',
        booruType: 'danbooru',
        url: 'https://other.example',
        name: 'Remote',
      );
      const third = BackupProfileReference(
        id: '00000000-0000-4000-8000-000000000021',
        booruType: 'danbooru',
        url: 'https://remote.example',
        name: 'Remote',
      );
      final result = const ProfileDependencyPlanner().plan(
        references: [remote, remote, other, third],
        localProfiles: const [],
        dependentSources: {
          ProfileReferenceKey.fromReference(remote): {'pinned_searches'},
          ProfileReferenceKey.fromReference(other): {'following_feeds'},
          ProfileReferenceKey.fromReference(third): {
            'pinned_searches',
            'following_feeds',
          },
        },
      );
      expect(result.errors, hasLength(3));
      expect(
        result.errors.map((e) => e.profileDependency!.label).toSet(),
        hasLength(3),
      );
      expect(result.errors.first.profileDependency!.sourceIds, {
        'pinned_searches',
      });
      final resolved = const ProfileDependencyPlanner().plan(
        references: [remote, other, third],
        localProfiles: [
          _profile(1, 'https://local-one.example'),
          _profile(2, 'https://local-two.example'),
        ],
        choices: {
          ProfileReferenceKey.fromReference(other): _profile(
            1,
            'https://local-one.example',
          ).id,
        },
      );
      expect(resolved.errors.map((e) => e.profileDependency!.reference.id), [
        remote.id,
        third.id,
      ]);
    },
  );

  test('an imported profile satisfies dependencies on a fresh device', () {
    final result = const ProfileDependencyPlanner().plan(
      references: [remote],
      localProfiles: const [],
      importedProfiles: [_profile(12, 'https://remote.example')],
      profileResolution: _profileResolution(12, ImportAction.copy),
    );

    expect(result.errors, isEmpty);
    final copiedId = result.profileIdFor(remote);
    expect(isCanonicalProfileId(copiedId), isTrue);
    expect(copiedId, isNot(remote.id));
    expect(result.projectedProfiles.single.id, copiedId);
  });

  test('replacement rejects a UUID used by a different site', () {
    const rule34 = BackupProfileReference(
      id: '00000000-0000-4000-8000-000000000000',
      booruType: 'danbooru',
      url: 'https://rule34.xxx',
      name: 'Rule34',
    );
    final result = const ProfileDependencyPlanner().plan(
      references: const [rule34],
      localProfiles: [_profile(0, 'https://safebooru.donmai.us')],
      importedProfiles: [_profile(0, 'https://rule34.xxx')],
      profileResolution: ResolvedImportSource(
        id: 'profiles',
        action: ImportAction.replace,
        items: const [],
      ),
    );

    expect(
      result.errors.map((issue) => issue.code),
      contains('profile_identity_conflict'),
    );
  });

  test('an ambiguous dependency requires a local profile choice', () {
    final profiles = [
      _profile(4, 'https://one.example'),
      _profile(5, 'https://two.example'),
    ];

    final unresolved = const ProfileDependencyPlanner().plan(
      references: [remote],
      localProfiles: profiles,
    );
    final resolved = const ProfileDependencyPlanner().plan(
      references: [remote],
      localProfiles: profiles,
      choices: {
        ProfileReferenceKey.fromReference(remote):
            '00000000-0000-4000-8000-000000000005',
      },
    );

    expect(unresolved.errors.single.code, 'unresolved_profile_dependency');
    expect(unresolved.mappings.single.candidateIds, {
      profileUuid(4),
      profileUuid(5),
    });
    expect(resolved.errors, isEmpty);
    expect(resolved.profileIdFor(remote), profileUuid(5));
  });

  test('one compatible local profile requires an explicit choice', () {
    final result = const ProfileDependencyPlanner().plan(
      references: [remote],
      localProfiles: [_profile(4, 'https://different.example')],
    );

    expect(result.errors.single.code, 'unresolved_profile_dependency');
    expect(result.profileIdFor(remote), isNull);
    expect(result.mappings.single.candidateIds, {profileUuid(4)});
  });

  test('a skipped imported profile does not satisfy dependencies', () {
    final result = const ProfileDependencyPlanner().plan(
      references: [remote],
      localProfiles: const [],
      importedProfiles: [_profile(12, 'https://remote.example')],
      profileResolution: _profileResolution(12, ImportAction.skip),
    );

    expect(result.errors.single.code, 'unresolved_profile_dependency');
    expect(result.profileIdFor(remote), isNull);
  });

  test('a missing dependency can create an unauthenticated local profile', () {
    final key = ProfileReferenceKey.fromReference(remote);
    final result = const ProfileDependencyPlanner().plan(
      references: [remote],
      localProfiles: [_profile(40, 'https://other.example')],
      createFromReferences: {key},
    );

    expect(result.errors, isEmpty);
    expect(result.mappings.single.createdFromReference, isTrue);
    expect(result.profileIdFor(remote), remote.id);
    expect(result.createdProfiles.single.id, remote.id);
    expect(result.createdProfiles.single.name, 'Remote');
    expect(result.createdProfiles.single.url, 'https://remote.example');
    expect(result.createdProfiles.single.apiKey, isNull);
    expect(result.createdProfiles.single.login, isNull);
    expect(result.createdProfiles.single.passHash, isNull);
  });

  test('an unsupported profile type is rejected during preflight', () {
    const unsupported = BackupProfileReference(
      id: '00000000-0000-4000-8000-00000000000d',
      booruType: 'future_engine',
      url: 'https://future.example',
      name: 'Future',
    );
    final result = const ProfileDependencyPlanner().plan(
      references: const [unsupported],
      localProfiles: const [],
      createFromReferences: {
        ProfileReferenceKey.fromReference(unsupported),
      },
    );

    expect(result.errors.single.code, 'unsupported_profile_type');
    expect(result.profileIdFor(unsupported), isNull);
    expect(result.createdProfiles, isEmpty);
  });
}

ResolvedImportSource _profileResolution(int id, ImportAction action) =>
    ResolvedImportSource(
      id: 'profiles',
      action: ImportAction.configureItems,
      items: [
        ResolvedImportItem(id: 'profile:${profileUuid(id)}', action: action),
      ],
    );

BooruConfig _profile(int id, String url) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': profileUuid(id),
  'booruIdHint': BooruType.danbooru.id,
  'url': url,
  'name': 'Remote',
});
