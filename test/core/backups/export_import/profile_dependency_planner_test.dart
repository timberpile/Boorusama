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
