import 'package:boorusama/core/backups/export_import/import/profile_dependency_planner.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:flutter_test/flutter_test.dart';

const _reference = BackupProfileReference(
  id: '11111111-1111-4111-8111-111111111111',
  booruType: 'danbooru',
  url: 'https://example.org/first',
  name: 'First installation',
);

void main() {
  test(
    'Topics alone do not require a local profile or a fabricated mapping',
    () {
      final result = const ProfileDependencyPlanner().plan(
        references: [_reference],
        dependentSources: {
          ProfileReferenceKey.fromReference(_reference): {'pinned_searches'},
        },
        localProfiles: [],
      );
      expect(result.errors, isEmpty);
      expect(result.projectedProfiles, isEmpty);
      expect(result.mappings.single.isRequired, isFalse);
      expect(result.mappings.single.profileId, isNull);
    },
  );

  test('a shared legacy-feed dependency remains required', () {
    final result = const ProfileDependencyPlanner().plan(
      references: [_reference],
      dependentSources: {
        ProfileReferenceKey.fromReference(_reference): {
          'pinned_searches',
          'following_feeds',
        },
      },
      localProfiles: [],
    );
    expect(result.errors.single.code, 'unresolved_profile_dependency');
    expect(result.mappings.single.isRequired, isTrue);
  });

  test('different installations on one host cannot select each other', () {
    final other = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': '22222222-2222-4222-8222-222222222222',
      'booruId': BooruType.danbooru.id,
      'booruIdHint': BooruType.danbooru.id,
      'url': 'https://example.org/second',
    });
    final result = const ProfileDependencyPlanner().plan(
      references: [_reference],
      dependentSources: {
        ProfileReferenceKey.fromReference(_reference): {'pinned_searches'},
      },
      localProfiles: [other],
    );
    expect(result.errors, isEmpty);
    expect(result.mappings.single.candidateIds, isEmpty);
    expect(result.profileIdFor(_reference), isNull);
  });

  test(
    'portable reference keys preserve scheme, port and installation path',
    () {
      final keys = <ProfileReferenceKey>{};
      for (final url in [
        'https://example.org/first',
        'http://example.org/first',
        'https://example.org:8443/first',
        'https://example.org/second',
      ]) {
        keys.add(
          ProfileReferenceKey.fromReference(
            BackupProfileReference(
              id: _reference.id,
              booruType: _reference.booruType,
              url: url,
              name: _reference.name,
            ),
          ),
        );
      }
      expect(keys, hasLength(4));
    },
  );
}
