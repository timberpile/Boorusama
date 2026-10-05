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
    'unresolved issues group canonical sites and retain selected dependent kinds',
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
      expect(result.errors, hasLength(2));
      expect(
        result.errors.map((e) => e.profileDependency!.label).toSet(),
        hasLength(2),
      );
      expect(result.errors.first.profileDependency!.sourceIds, {
        'pinned_searches',
        'following_feeds',
      });
      final resolved = const ProfileDependencyPlanner().plan(
        references: [remote, other, third],
        localProfiles: [
          _profile(1, other.url),
          _profile(2, 'https://local-two.example'),
        ],
        choices: {
          ProfileSiteKey.fromReference(other): _profile(
            1,
            'https://local-one.example',
          ).id,
        },
      );
      expect(resolved.errors.map((e) => e.profileDependency!.reference.id), [
        remote.id,
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
      _profile(4, remote.url),
      _profile(5, remote.url),
    ];

    final unresolved = const ProfileDependencyPlanner().plan(
      references: [remote],
      localProfiles: profiles,
    );
    final resolved = const ProfileDependencyPlanner().plan(
      references: [remote],
      localProfiles: profiles,
      choices: {
        ProfileSiteKey.fromReference(remote):
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

  test('one compatible local profile is selected automatically', () {
    final result = const ProfileDependencyPlanner().plan(
      references: [remote],
      localProfiles: [_profile(4, remote.url)],
    );

    expect(result.errors, isEmpty);
    expect(result.profileIdFor(remote), profileUuid(4));
    expect(result.mappings.single.candidateIds, {profileUuid(4)});
  });

  test(
    'exact identity defaults remain editable to another valid candidate',
    () {
      final profiles = [
        _profile(12, remote.url),
        _profile(4, remote.url),
        _profile(5, 'https://different.example'),
      ];
      final initial = const ProfileDependencyPlanner().plan(
        references: [remote],
        localProfiles: profiles,
      );
      expect(initial.profileIdFor(remote), remote.id);
      expect(initial.mappings.single.candidateIds, {remote.id, profileUuid(4)});
      final changed = const ProfileDependencyPlanner().plan(
        references: [remote],
        localProfiles: profiles,
        choices: {ProfileSiteKey.fromReference(remote): profileUuid(4)},
      );
      expect(changed.profileIdFor(remote), profileUuid(4));
      expect(changed.errors, isEmpty);
    },
  );

  test('a UUID conflict cannot be bypassed by one compatible candidate', () {
    final result = const ProfileDependencyPlanner().plan(
      references: [remote],
      localProfiles: [
        _profile(12, 'https://conflict.example'),
        _profile(4, remote.url),
      ],
      choices: {ProfileSiteKey.fromReference(remote): profileUuid(4)},
    );
    expect(result.errors.single.code, 'profile_identity_conflict');
    expect(result.profileIdFor(remote), isNull);
    expect(result.mappings.single.candidateIds, isEmpty);
  });

  test('one same-site candidate wins without broadening to other sites', () {
    final result = const ProfileDependencyPlanner().plan(
      references: [remote],
      localProfiles: [
        _profile(4, remote.url),
        _profile(5, 'https://different.example'),
      ],
    );
    expect(result.profileIdFor(remote), profileUuid(4));
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

  test('a missing dependency remains unresolved without creating profiles', () {
    final profiles = [_profile(40, 'https://other.example')];
    final result = const ProfileDependencyPlanner().plan(
      references: [remote],
      localProfiles: profiles,
    );
    expect(result.errors.single.code, 'unresolved_profile_dependency');
    expect(result.profileIdFor(remote), isNull);
    expect(result.projectedProfiles, profiles);
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
    );

    expect(result.errors.single.code, 'unresolved_profile_dependency');
    expect(result.profileIdFor(unsupported), isNull);
    expect(result.projectedProfiles, isEmpty);
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
