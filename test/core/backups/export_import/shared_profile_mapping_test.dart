import 'package:boorusama/core/backups/export_import/import/profile_dependency_planner.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:flutter_test/flutter_test.dart';

const firstId = '00000000-0000-4000-8000-000000000001';
const secondId = '00000000-0000-4000-8000-000000000002';
const remoteId = '00000000-0000-4000-8000-000000000003';

void main() {
  test(
    'one canonical site mapping resolves references across all categories',
    () {
      final references = [
        _reference(firstId, 'https://SITE.example:443/path/'),
        _reference(secondId, 'http://site.example:80/path'),
        _reference(remoteId, 'https://site.example/path'),
      ];
      final plan = const ProfileDependencyPlanner().plan(
        references: references,
        localProfiles: [_profile(remoteId, 'https://site.example/path/')],
        dependentSources: {
          for (final (index, reference) in references.indexed)
            ProfileReferenceKey.fromReference(reference): {
              ['bookmarks', 'pinned_searches', 'following_feeds'][index],
            },
        },
      );
      expect(plan.mappings, hasLength(1));
      expect(plan.errors, isEmpty);
      for (final reference in references) {
        expect(plan.profileIdFor(reference), remoteId);
      }
    },
  );

  test('another website using the same engine cannot satisfy dependencies', () {
    final plan = const ProfileDependencyPlanner().plan(
      references: [_reference(remoteId)],
      localProfiles: [_profile(firstId, 'https://other.example')],
    );
    expect(plan.mappings.single.candidateIds, isEmpty);
    expect(plan.profileIdFor(_reference(remoteId)), isNull);
    expect(plan.errors.single.code, 'unresolved_profile_dependency');
  });

  test(
    'different exact accounts on one site require one explicit shared choice',
    () {
      final references = [_reference(firstId), _reference(secondId)];
      final profiles = [_profile(firstId), _profile(secondId)];
      final initial = const ProfileDependencyPlanner().plan(
        references: references,
        localProfiles: profiles,
      );
      expect(initial.mappings, hasLength(1));
      expect(initial.mappings.single.profileId, isNull);
      final chosen = const ProfileDependencyPlanner().plan(
        references: references,
        localProfiles: profiles,
        choices: {ProfileSiteKey.fromReference(references.first): secondId},
      );
      expect(chosen.errors, isEmpty);
      for (final reference in references) {
        expect(chosen.profileIdFor(reference), secondId);
      }
    },
  );

  test(
    'one agreed exact account remains the default among several candidates',
    () {
      final plan = const ProfileDependencyPlanner().plan(
        references: [_reference(firstId), _reference(remoteId)],
        localProfiles: [_profile(firstId), _profile(secondId)],
      );
      expect(plan.mappings, hasLength(1));
      expect(plan.mappings.single.profileId, firstId);
      expect(plan.mappings.single.candidateIds, {firstId, secondId});
    },
  );

  test('invalid sites never group or select an unrelated unknown site', () {
    final references = [_reference(firstId, ''), _reference(secondId, '')];
    final plan = const ProfileDependencyPlanner().plan(
      references: references,
      localProfiles: [_profile(remoteId, '')],
    );
    expect(plan.mappings, hasLength(2));
    expect(
      plan.mappings.every((mapping) => mapping.candidateIds.isEmpty),
      isTrue,
    );
    expect(plan.errors, hasLength(2));
  });

  test('nondefault ports and distinct paths remain separate websites', () {
    final plan = const ProfileDependencyPlanner().plan(
      references: [
        _reference(firstId, 'https://site.example:8443/path'),
        _reference(secondId, 'https://site.example/other'),
      ],
      localProfiles: [_profile(remoteId, 'https://site.example/path')],
    );
    expect(plan.mappings, hasLength(2));
    expect(
      plan.mappings.every((mapping) => mapping.candidateIds.isEmpty),
      isTrue,
    );
  });

  test(
    'a reused UUID with another engine blocks a compatible shared choice',
    () {
      final reference = _reference(firstId);
      final wrongEngine = BooruConfig.fromJson({
        ..._profile(firstId).toJson(),
        'booruId': BooruType.gelbooru.id,
        'booruIdHint': BooruType.gelbooru.id,
      });
      final plan = const ProfileDependencyPlanner().plan(
        references: [reference],
        localProfiles: [wrongEngine, _profile(secondId)],
        choices: {ProfileSiteKey.fromReference(reference): secondId},
      );
      expect(
        plan.errors.map((issue) => issue.code),
        contains('profile_identity_conflict'),
      );
      expect(plan.profileIdFor(reference), isNull);
    },
  );

  test('a shared choice cannot bypass a conflicting bookmark UUID', () {
    final reference = _reference(firstId);
    final plan = const ProfileDependencyPlanner().plan(
      references: [reference],
      localProfiles: [
        _profile(firstId, 'https://other.example'),
        _profile(secondId),
      ],
      dependentSources: {
        ProfileReferenceKey.fromReference(reference): {'bookmarks'},
      },
      choices: {ProfileSiteKey.fromReference(reference): secondId},
    );
    expect(
      plan.errors.map((issue) => issue.code),
      contains('profile_identity_conflict'),
    );
    expect(plan.profileIdFor(reference), isNull);
  });
}

BackupProfileReference _reference(
  String id, [
  String url = 'https://site.example',
]) => BackupProfileReference(
  id: id,
  booruType: 'danbooru',
  url: url,
  name: 'Remote',
);
BooruConfig _profile(String id, [String url = 'https://site.example']) =>
    BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': id,
      'booruId': BooruType.danbooru.id,
      'booruIdHint': BooruType.danbooru.id,
      'url': url,
      'name': id == firstId ? 'First' : 'Second',
    });
