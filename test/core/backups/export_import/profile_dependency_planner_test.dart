import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/profile_dependency_planner.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';

void main() {
  const remote = BackupProfileReference(
    id: 12,
    booruType: 'danbooru',
    url: 'https://remote.example',
    name: 'Remote',
  );

  test('an imported profile satisfies dependencies on a fresh device', () {
    final result = const ProfileDependencyPlanner().plan(
      references: [remote],
      localProfiles: const [],
      importedProfiles: [_profile(12, 'https://remote.example')],
      profileResolution: _profileResolution(12, ImportAction.copy),
    );

    expect(result.errors, isEmpty);
    expect(result.profileIdFor(remote), 12);
    expect(result.projectedProfiles.single.id, 12);
  });

  test('replacement remaps dependent references when exported IDs collide', () {
    const rule34 = BackupProfileReference(
      id: 0,
      booruType: 'danbooru',
      url: 'https://rule34.xxx',
      name: 'Rule34',
    );
    const safebooru = BackupProfileReference(
      id: 5,
      booruType: 'danbooru',
      url: 'https://safebooru.donmai.us',
      name: 'Safebooru',
    );
    final result = const ProfileDependencyPlanner().plan(
      references: const [rule34, safebooru],
      localProfiles: [_profile(0, 'https://safebooru.donmai.us')],
      importedProfiles: [
        _profile(0, 'https://rule34.xxx'),
        _profile(5, 'https://safebooru.donmai.us'),
      ],
      profileResolution: ResolvedImportSource(
        id: 'profiles',
        action: ImportAction.replace,
        items: const [],
      ),
    );

    expect(result.errors, isEmpty);
    expect(result.projectedProfiles, hasLength(2));
    expect(
      result.projectedProfiles.map((profile) => profile.id).toSet(),
      hasLength(2),
    );
    expect(result.profileIdFor(rule34), isNot(0));
    expect(result.profileIdFor(safebooru), 0);
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
      choices: {ProfileReferenceKey.fromReference(remote): 5},
    );

    expect(unresolved.errors.single.code, 'unresolved_profile_dependency');
    expect(unresolved.mappings.single.candidateIds, {4, 5});
    expect(resolved.errors, isEmpty);
    expect(resolved.profileIdFor(remote), 5);
  });

  test('one compatible local profile is selected automatically', () {
    final result = const ProfileDependencyPlanner().plan(
      references: [remote],
      localProfiles: [_profile(4, 'https://different.example')],
    );

    expect(result.errors, isEmpty);
    expect(result.profileIdFor(remote), 4);
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
    expect(result.profileIdFor(remote), 41);
    expect(result.createdProfiles.single.id, 41);
    expect(result.createdProfiles.single.name, 'Remote');
    expect(result.createdProfiles.single.url, 'https://remote.example');
    expect(result.createdProfiles.single.apiKey, isNull);
    expect(result.createdProfiles.single.login, isNull);
    expect(result.createdProfiles.single.passHash, isNull);
  });

  test('an unsupported profile type is rejected during preflight', () {
    const unsupported = BackupProfileReference(
      id: 13,
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
      items: [ResolvedImportItem(id: 'profile:$id', action: action)],
    );

BooruConfig _profile(int id, String url) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'booruIdHint': BooruType.danbooru.id,
  'url': url,
  'name': 'Remote',
});
