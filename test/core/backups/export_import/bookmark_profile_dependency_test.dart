import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/backups/export_import/import/bookmark_profile_dependency.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/profile_dependency_planner.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';

const first = '00000000-0000-4000-8000-000000000001';
const second = '00000000-0000-4000-8000-000000000002';
const groupId = '00000000-0000-4000-8000-000000000003';

void main() {
  final bookmark = _bookmark();
  final reference = bookmarkProfileReference(bookmark);
  final key = ProfileReferenceKey.fromReference(reference);
  final siteKey = ProfileSiteKey.fromReference(reference);
  ProfileDependencyPlan plan({
    List<BooruConfig> local = const [],
    List<BooruConfig> imported = const [],
    ResolvedImportSource? resolution,
    Map<ProfileSiteKey, String> choices = const {},
  }) => const ProfileDependencyPlanner().plan(
    references: [reference],
    dependentSources: {
      key: {'bookmarks'},
    },
    localProfiles: local,
    importedProfiles: imported,
    profileResolution: resolution,
    choices: choices,
  );

  for (final c in [
    (name: 'missing profiles', profiles: <BooruConfig>[]),
    (
      name: 'the same engine on another website',
      profiles: [_profile(first, 'https://other.example/install')],
    ),
    (
      name: 'another installation on the same host',
      profiles: [_profile(first, 'https://site.example/other')],
    ),
    (
      name: 'another engine on the same website',
      profiles: [_profile(first, reference.url, BooruType.danbooru)],
    ),
  ]) {
    test('${c.name} leaves the bookmark dependency unresolved', () {
      final result = plan(local: c.profiles);
      expect(result.mappings.single.candidateIds, isEmpty);
      expect(result.errors.single.profileDependency!.sourceIds, {'bookmarks'});
      expect(result.profileIdFor(reference), isNull);
    });
  }
  test('a sole canonical website and engine match automatically resolves', () {
    final result = plan(
      local: [_profile(first, 'http://SITE.example/install/')],
    );
    expect(result.errors, isEmpty);
    expect(result.profileIdFor(reference), first);
  });
  test('multiple accounts require a choice and reject wrong-site choices', () {
    final profiles = [
      _profile(first, reference.url),
      _profile(second, reference.url),
      _profile(groupId, 'https://other.example'),
    ];
    expect(plan(local: profiles).errors, isNotEmpty);
    expect(
      plan(local: profiles, choices: {siteKey: groupId}).errors,
      isNotEmpty,
    );
    expect(
      plan(local: profiles, choices: {siteKey: second}).profileIdFor(reference),
      second,
    );
  });
  test(
    'a compatible stored origin hint preserves an account among several',
    () {
      final hinted = bookmarkWithProfileHint(bookmark, second);
      final ref = bookmarkProfileReference(hinted);
      final result = const ProfileDependencyPlanner().plan(
        references: [ref],
        dependentSources: {
          ProfileReferenceKey.fromReference(ref): {'bookmarks'},
        },
        localProfiles: [
          _profile(first, reference.url),
          _profile(second, reference.url),
        ],
      );
      expect(result.profileIdFor(ref), second);
      expect(hinted.identity, bookmark.identity);
      expect(hinted.id, bookmark.id);
    },
  );
  test(
    'newly imported profile satisfies website dependencies without matching exported hints',
    () {
      final result = plan(
        imported: [_profile(first, reference.url)],
        resolution: ResolvedImportSource(
          id: 'profiles',
          action: ImportAction.replace,
          items: const [],
        ),
      );
      expect(result.errors, isEmpty);
      expect(result.profileIdFor(reference), first);
    },
  );
  test('an empty profile replacement removes otherwise matching profiles', () {
    final result = plan(
      local: [_profile(first, reference.url)],
      resolution: ResolvedImportSource(
        id: 'profiles',
        action: ImportAction.replace,
        items: const [],
      ),
    );
    expect(result.projectedProfiles, isEmpty);
    expect(result.profileIdFor(reference), isNull);
    expect(result.errors, isNotEmpty);
  });
  test(
    'a stale origin UUID for another website cannot be remapped silently',
    () {
      final hinted = bookmarkWithProfileHint(bookmark, first);
      final ref = bookmarkProfileReference(hinted);
      final result = const ProfileDependencyPlanner().plan(
        references: [ref],
        dependentSources: {
          ProfileReferenceKey.fromReference(ref): {'bookmarks'},
        },
        localProfiles: [
          _profile(first, 'https://other.example'),
          _profile(second, reference.url),
        ],
        choices: {ProfileSiteKey.fromReference(ref): second},
      );
      expect(
        result.errors.map((e) => e.code),
        contains('profile_identity_conflict'),
      );
      expect(result.mappings.single.isResolved, isFalse);
    },
  );
  test(
    'only selected group and ungrouped bookmarks contribute dependencies',
    () {
      final ungrouped = _bookmark(2);
      final data = BookmarkBackupData(
        bookmarks: [bookmark, ungrouped],
        groups: [
          BookmarkGroupBackup(
            id: groupId,
            name: 'Group',
            bookmarkIds: [bookmark.id],
          ),
        ],
      );
      expect(
        selectedProfileBookmarks(
          data,
          ResolvedImportSource(
            id: 'bookmarks',
            action: ImportAction.skip,
            items: const [],
          ),
        ),
        isEmpty,
      );
      expect(
        selectedProfileBookmarks(
          data,
          ResolvedImportSource(
            id: 'bookmarks',
            action: ImportAction.replace,
            items: const [],
          ),
        ),
        data.bookmarks,
      );
      expect(
        selectedProfileBookmarks(
          data,
          ResolvedImportSource(
            id: 'bookmarks',
            action: ImportAction.configureItems,
            items: const [
              ResolvedImportItem(id: 'ungrouped', action: ImportAction.update),
              ResolvedImportItem(
                id: 'group:$groupId',
                action: ImportAction.skip,
              ),
            ],
          ),
        ),
        [ungrouped],
      );
    },
  );
}

Bookmark _bookmark([int id = 1]) => Bookmark(
  id: id,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  thumbnailUrl: 'https://media.example/$id.jpg',
  sampleUrl: 'https://media.example/$id.jpg',
  originalUrl: 'https://media.example/$id.jpg',
  sourceUrl: 'https://site.example/install',
  booruId: BooruType.gelbooruV2.id,
  width: 100,
  height: 100,
  md5: '',
  tags: const {},
  realSourceUrl: null,
  format: 'jpg',
  imageUrlResolver: const DefaultImageUrlResolver(),
  postId: id,
  metadata: const {},
);
BooruConfig _profile(
  String id,
  String url, [
  BooruType type = BooruType.gelbooruV2,
]) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'url': url,
  'name': 'Profile',
  'booruId': type.id,
  'booruIdHint': type.id,
});
