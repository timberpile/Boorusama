import '../../../profile_uuid_utils.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_planned_change_projector.dart';
import 'package:boorusama/core/backups/export_import/import/import_preflight.dart';
import 'package:boorusama/core/backups/export_import/import/profile_dependency_planner.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/following_feed_backup_data.dart';
import 'package:boorusama/core/backups/sources/pinned_search_backup_data.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projector = ImportPlannedChangeProjector();

  test('scalar projection distinguishes exact no-op update and skip', () {
    final unchanged = projector.scalar(
      local: const {
        'enabled': true,
        'nested': [1, 2],
      },
      incoming: const {
        'enabled': true,
        'nested': [1, 2],
      },
      resolution: _source('settings', ImportAction.replace),
    );
    final updated = projector.scalar(
      local: const {'enabled': true},
      incoming: const {'enabled': false},
      resolution: _source('settings', ImportAction.replace),
    );
    final skipped = projector.scalar(
      local: const {'enabled': true},
      incoming: const {'enabled': false},
      resolution: _source('settings', ImportAction.skip),
    );

    expect(unchanged, const PlannedChangeSummary(unchanged: 1));
    expect(updated, const PlannedChangeSummary(updated: 1));
    expect(skipped, const PlannedChangeSummary(preserved: 1));
  });

  test(
    'profile projection preserves credentials and counts added profiles',
    () {
      final local = _profile(id: 10, apiKey: 'secret');
      final imported = _profile(id: 1, name: 'Renamed');
      final additional = _profile(
        id: 20,
        name: 'Dependency',
        url: 'https://dependency.example',
      );

      final summary = projector.profiles(
        local: [local],
        imported: [imported],
        additionalProfiles: [additional],
        credentialsIncluded: false,
        resolution: ResolvedImportSource(
          id: 'profiles',
          action: ImportAction.configureItems,
          items: const [
            ResolvedImportItem(
              id: 'profile:00000000-0000-4000-8000-000000000001',
              action: ImportAction.update,
              targetId: 'profile:00000000-0000-4000-8000-00000000000a',
            ),
          ],
        ),
      );

      _expectTotals(
        summary,
        const PlannedChangeSummary(created: 1, updated: 1),
      );
    },
  );

  test(
    'profile projection reports credential-free identical updates as no-op',
    () {
      final local = _profile(id: 10, apiKey: 'secret');
      final imported = _profile(id: 1);

      final summary = projector.profiles(
        local: [local],
        imported: [imported],
        credentialsIncluded: false,
        resolution: ResolvedImportSource(
          id: 'profiles',
          action: ImportAction.configureItems,
          items: const [
            ResolvedImportItem(
              id: 'profile:00000000-0000-4000-8000-000000000001',
              action: ImportAction.update,
              targetId: 'profile:00000000-0000-4000-8000-00000000000a',
            ),
          ],
        ),
      );

      _expectTotals(summary, const PlannedChangeSummary(unchanged: 1));
    },
  );

  test(
    'bookmark projection counts group changes and orphan record deletion',
    () {
      final first = _bookmark(localId: 1, postId: 101);
      final orphan = _bookmark(localId: 2, postId: 102);
      final created = _bookmark(localId: 30, postId: 103);
      final incomingFirst = _bookmark(localId: 20, postId: 101);

      final summary = projector.bookmarks(
        local: BookmarkImportLocalSnapshot(
          bookmarks: [first, orphan],
          groups: [
            BookmarkGroup(
              id: 'group',
              name: 'Old',
              bookmarkIds: const {1, 2},
            ),
          ],
        ),
        incoming: BookmarkBackupData(
          bookmarks: [incomingFirst, created],
          groups: const [
            BookmarkGroupBackup(
              id: 'group',
              name: 'Updated',
              bookmarkIds: [20, 30],
            ),
          ],
        ),
        resolution: ResolvedImportSource(
          id: 'bookmarks',
          action: ImportAction.configureItems,
          items: const [
            ResolvedImportItem(
              id: 'group:group',
              action: ImportAction.update,
            ),
          ],
        ),
      );

      expect(
        _totals(summary),
        const PlannedChangeSummary(
          created: 1,
          updated: 1,
          deleted: 1,
          unchanged: 1,
        ),
      );
    },
  );

  for (final targetId in [null, 'group:missing']) {
    test('bookmark merge preview waits for a valid target: $targetId', () {
      expect(
        projector.bookmarks(
          local: BookmarkImportLocalSnapshot(
            bookmarks: const [],
            groups: const [],
          ),
          incoming: const BookmarkBackupData(
            bookmarks: [],
            groups: [
              BookmarkGroupBackup(
                id: 'incoming',
                name: 'AnimeBoxes',
                bookmarkIds: [],
              ),
            ],
          ),
          resolution: ResolvedImportSource(
            id: 'bookmarks',
            action: ImportAction.configureItems,
            items: [
              ResolvedImportItem(
                id: 'group:incoming',
                action: ImportAction.mergeIntoTarget,
                targetId: targetId,
              ),
            ],
          ),
        ),
        isNull,
      );
    });
  }

  test('bookmark projection counts every record inside a new group', () {
    final bookmarks = [
      for (var index = 0; index < 10; index++)
        _bookmark(localId: index, postId: 100 + index),
    ];
    final summary = projector.bookmarks(
      local: BookmarkImportLocalSnapshot(bookmarks: const [], groups: const []),
      incoming: BookmarkBackupData(
        bookmarks: bookmarks,
        groups: [
          BookmarkGroupBackup(
            id: 'group',
            name: 'Ten posts',
            bookmarkIds: [for (var index = 0; index < 10; index++) index],
          ),
        ],
      ),
      resolution: ResolvedImportSource(
        id: 'bookmarks',
        action: ImportAction.configureItems,
        items: const [
          ResolvedImportItem(id: 'group:group', action: ImportAction.copy),
        ],
      ),
    );

    _expectTotals(summary, const PlannedChangeSummary(created: 11));
    expect(summary!.entitySummaries['bookmark']?.created, 10);
    expect(summary.entitySummaries['bookmark-group']?.created, 1);
  });

  test(
    'pinned search projection reuses normalized query and profile identity',
    () {
      final localCat = _search(id: 'local-cat', query: 'cat   girl');
      const incoming = PinnedSearchBackupData(
        records: [
          PinnedSearchBackupRecord(
            id: 'remote-cat',
            name: 'Ignored because the row is reused',
            query: 'cat girl',
            position: 0,
            profile: _profileReference,
          ),
          PinnedSearchBackupRecord(
            id: 'dog',
            name: 'Dog',
            query: 'dog',
            position: 1,
            profile: _profileReference,
          ),
        ],
        folders: [
          PinnedSearchFolderBackupRecord(
            id: 'folder',
            name: 'Animals',
            position: 0,
            searchIds: ['remote-cat', 'dog'],
          ),
        ],
      );

      final summary = projector.pinnedSearches(
        local: PinnedSearchImportLocalSnapshot(
          searches: [localCat],
          organization: SearchOrganization(
            folders: [
              SharedSearchFolder(
                id: 'folder',
                name: 'Animals',
                searchIds: const ['local-cat'],
              ),
            ],
            homeSearchIds: const [],
          ),
          feeds: const [],
        ),
        incoming: incoming,
        profileMappings: {
          ProfileReferenceKey.fromReference(_profileReference):
              '00000000-0000-4000-8000-000000000001',
        },
        resolution: ResolvedImportSource(
          id: 'pinned_searches',
          action: ImportAction.configureItems,
          items: const [
            ResolvedImportItem(id: 'search:dog', action: ImportAction.copy),
            ResolvedImportItem(
              id: 'folder:folder',
              action: ImportAction.update,
            ),
          ],
        ),
      );

      expect(
        _totals(summary),
        const PlannedChangeSummary(
          created: 1,
          updated: 1,
          preserved: 1,
          unchanged: 1,
        ),
      );
    },
  );

  test('pinned search projection waits for unresolved profile mapping', () {
    final summary = projector.pinnedSearches(
      local: PinnedSearchImportLocalSnapshot(
        searches: const [],
        organization: SearchOrganization(
          folders: const [],
          homeSearchIds: const [],
        ),
        feeds: const [],
      ),
      incoming: const PinnedSearchBackupData(
        records: [
          PinnedSearchBackupRecord(
            id: 'remote-cat',
            name: null,
            query: 'cat',
            position: 0,
            profile: _profileReference,
          ),
        ],
      ),
      profileMappings: const {},
      resolution: ResolvedImportSource(
        id: 'pinned_searches',
        action: ImportAction.configureItems,
        items: const [
          ResolvedImportItem(
            id: 'search:remote-cat',
            action: ImportAction.copy,
          ),
        ],
      ),
    );

    expect(summary, isNull);
  });

  test(
    'pinned search projection treats a changed query with the same ID as new',
    () {
      final summary = projector.pinnedSearches(
        local: PinnedSearchImportLocalSnapshot(
          searches: [_search(id: 'same-id', query: 'local query')],
          organization: SearchOrganization(
            folders: const [],
            homeSearchIds: const ['same-id'],
          ),
          feeds: const [],
        ),
        incoming: const PinnedSearchBackupData(
          records: [
            PinnedSearchBackupRecord(
              id: 'same-id',
              name: null,
              query: 'remote query',
              position: 0,
              profile: _profileReference,
            ),
          ],
          homeSearchIds: ['same-id'],
        ),
        profileMappings: {
          ProfileReferenceKey.fromReference(_profileReference):
              '00000000-0000-4000-8000-000000000001',
        },
        resolution: ResolvedImportSource(
          id: 'pinned_searches',
          action: ImportAction.configureItems,
          items: const [
            ResolvedImportItem(id: 'search:same-id', action: ImportAction.copy),
          ],
        ),
      );

      expect(
        _totals(summary),
        const PlannedChangeSummary(created: 1, updated: 1, preserved: 1),
      );
    },
  );

  test(
    'pinned search projection reports Home membership and order changes',
    () {
      final first = _search(id: 'first', query: 'first');
      final second = _search(id: 'second', query: 'second');
      final summary = projector.pinnedSearches(
        local: PinnedSearchImportLocalSnapshot(
          searches: [first, second],
          organization: SearchOrganization(
            folders: const [],
            homeSearchIds: const ['first', 'second'],
          ),
          feeds: const [],
        ),
        incoming: const PinnedSearchBackupData(
          records: [
            PinnedSearchBackupRecord(
              id: 'first',
              name: null,
              query: 'first',
              position: 0,
              profile: _profileReference,
            ),
            PinnedSearchBackupRecord(
              id: 'second',
              name: null,
              query: 'second',
              position: 1,
              profile: _profileReference,
            ),
          ],
          homeSearchIds: ['second', 'first'],
        ),
        profileMappings: {
          ProfileReferenceKey.fromReference(_profileReference):
              '00000000-0000-4000-8000-000000000001',
        },
        resolution: ResolvedImportSource(
          id: 'pinned_searches',
          action: ImportAction.configureItems,
          items: const [
            ResolvedImportItem(id: 'search:first', action: ImportAction.copy),
            ResolvedImportItem(id: 'search:second', action: ImportAction.copy),
          ],
        ),
      );

      expect(summary?.hasMutations, isTrue);
      expect(summary?.updated, 1);
      expect(summary?.entitySummaries['pinned-home']?.updated, 1);
    },
  );

  test('ambiguous profile projection remains reviewable without a target', () {
    final summary = projector.profiles(
      local: [
        _profile(id: 4, url: 'https://same.example'),
        _profile(id: 5, url: 'https://same.example'),
      ],
      imported: [_profile(id: 99, url: 'https://same.example')],
      resolution: ResolvedImportSource(
        id: 'profiles',
        action: ImportAction.configureItems,
        items: const [
          ResolvedImportItem(
            id: 'profile:00000000-0000-4000-8000-000000000063',
            action: ImportAction.update,
          ),
        ],
      ),
      credentialsIncluded: false,
    );

    expect(summary, isNull);
  });

  test('pinned replace reuses semantic matches before deleting extras', () {
    final summary = projector.pinnedSearches(
      local: PinnedSearchImportLocalSnapshot(
        searches: [
          _search(id: 'local-cat', query: 'cat   girl'),
          _search(id: 'removed', query: 'removed'),
        ],
        organization: SearchOrganization(
          folders: [
            SharedSearchFolder(
              id: 'old-folder',
              name: 'Old',
              searchIds: const ['removed'],
            ),
          ],
          homeSearchIds: const ['local-cat'],
        ),
        feeds: const [],
      ),
      incoming: const PinnedSearchBackupData(
        records: [
          PinnedSearchBackupRecord(
            id: 'remote-cat',
            name: null,
            query: 'cat girl',
            position: 0,
            profile: _profileReference,
          ),
        ],
        folders: [
          PinnedSearchFolderBackupRecord(
            id: 'new-folder',
            name: 'New',
            position: 0,
            searchIds: ['remote-cat'],
          ),
        ],
      ),
      profileMappings: {
        ProfileReferenceKey.fromReference(_profileReference):
            '00000000-0000-4000-8000-000000000001',
      },
      resolution: _source('pinned_searches', ImportAction.replace),
    );

    expect(
      _totals(summary),
      const PlannedChangeSummary(
        created: 1,
        updated: 1,
        deleted: 2,
        unchanged: 1,
      ),
    );
  });

  test('folder projection counts all three new searches and the folder', () {
    const records = [
      PinnedSearchBackupRecord(
        id: 'one',
        name: null,
        query: 'one',
        position: 0,
        profile: _profileReference,
      ),
      PinnedSearchBackupRecord(
        id: 'two',
        name: null,
        query: 'two',
        position: 1,
        profile: _profileReference,
      ),
      PinnedSearchBackupRecord(
        id: 'three',
        name: null,
        query: 'three',
        position: 2,
        profile: _profileReference,
      ),
    ];
    final summary = projector.pinnedSearches(
      local: PinnedSearchImportLocalSnapshot(
        searches: const [],
        organization: SearchOrganization(
          folders: const [],
          homeSearchIds: const [],
        ),
        feeds: const [],
      ),
      incoming: const PinnedSearchBackupData(
        records: records,
        folders: [
          PinnedSearchFolderBackupRecord(
            id: 'folder',
            name: 'Three searches',
            position: 0,
            searchIds: ['one', 'two', 'three'],
          ),
        ],
      ),
      profileMappings: {
        ProfileReferenceKey.fromReference(_profileReference):
            '00000000-0000-4000-8000-000000000001',
      },
      resolution: ResolvedImportSource(
        id: 'pinned_searches',
        action: ImportAction.configureItems,
        items: const [
          ResolvedImportItem(id: 'search:one', action: ImportAction.copy),
          ResolvedImportItem(id: 'search:two', action: ImportAction.copy),
          ResolvedImportItem(id: 'search:three', action: ImportAction.copy),
          ResolvedImportItem(id: 'folder:folder', action: ImportAction.copy),
        ],
      ),
    );

    _expectTotals(
      summary,
      const PlannedChangeSummary(created: 4, preserved: 1),
    );
    expect(summary?.entitySummaries['pinned-search']?.created, 3);
    expect(summary?.entitySummaries['pinned-folder']?.created, 1);
  });

  test(
    'feed projection reuses internal searches and preserves shared rows',
    () {
      final cat = _search(
        id: 'cat-source',
        query: 'cat',
        profileId: '00000000-0000-4000-8000-00000000002a',
      );
      final first = SearchFollowingFeed(
        id: 'first',
        profileId: '00000000-0000-4000-8000-00000000002a',
        name: 'First',
        sourceIds: const ['cat-source'],
      );
      final second = SearchFollowingFeed(
        id: 'second',
        profileId: '00000000-0000-4000-8000-00000000002a',
        name: 'Second',
        sourceIds: const ['cat-source'],
        position: 1,
      );

      final summary = projector.followingFeeds(
        local: FollowingFeedImportLocalSnapshot(
          searches: [cat],
          feeds: [first, second],
        ),
        incoming: FollowingFeedBackupData(
          feeds: [
            FollowingFeedBackupRecord(
              id: 'first',
              name: 'First updated',
              position: 0,
              queries: const [' cat ', 'dog'],
              profile: _profileReference,
            ),
          ],
        ),
        profileMappings: {
          ProfileReferenceKey.fromReference(_profileReference):
              '00000000-0000-4000-8000-00000000002a',
        },
        resolution: ResolvedImportSource(
          id: 'following_feeds',
          action: ImportAction.configureItems,
          items: const [
            ResolvedImportItem(id: 'feed:first', action: ImportAction.update),
          ],
        ),
      );

      expect(
        _totals(summary),
        const PlannedChangeSummary(
          created: 1,
          updated: 1,
          preserved: 1,
          unchanged: 1,
        ),
      );
    },
  );

  test('feed projection waits for unresolved profile mapping', () {
    final summary = projector.followingFeeds(
      local: FollowingFeedImportLocalSnapshot(
        searches: [],
        feeds: [],
      ),
      incoming: FollowingFeedBackupData(
        feeds: [
          FollowingFeedBackupRecord(
            id: 'feed',
            name: 'Feed',
            position: 0,
            queries: const ['cat'],
            profile: _profileReference,
          ),
        ],
      ),
      profileMappings: const {},
      resolution: ResolvedImportSource(
        id: 'following_feeds',
        action: ImportAction.configureItems,
        items: const [
          ResolvedImportItem(id: 'feed:feed', action: ImportAction.copy),
        ],
      ),
    );

    expect(summary, isNull);
  });

  test('feed replace retains compatible feeds and removes absent orphans', () {
    final cat = _search(id: 'cat-source', query: 'cat');
    final dog = _search(id: 'dog-source', query: 'dog');
    final summary = projector.followingFeeds(
      local: FollowingFeedImportLocalSnapshot(
        searches: [cat, dog],
        feeds: [
          SearchFollowingFeed(
            id: 'kept',
            profileId: '00000000-0000-4000-8000-000000000001',
            name: 'Kept',
            sourceIds: const ['cat-source'],
          ),
          SearchFollowingFeed(
            id: 'removed',
            profileId: '00000000-0000-4000-8000-000000000001',
            name: 'Removed',
            sourceIds: const ['dog-source'],
            position: 1,
          ),
        ],
      ),
      incoming: FollowingFeedBackupData(
        feeds: [
          FollowingFeedBackupRecord(
            id: 'kept',
            name: 'Kept',
            position: 0,
            queries: const [' cat '],
            profile: _profileReference,
          ),
        ],
      ),
      profileMappings: {
        ProfileReferenceKey.fromReference(_profileReference):
            '00000000-0000-4000-8000-000000000001',
      },
      resolution: _source('following_feeds', ImportAction.replace),
    );

    expect(
      _totals(summary),
      const PlannedChangeSummary(deleted: 2, unchanged: 2),
    );
  });
}

void _expectTotals(
  PlannedChangeSummary? actual,
  PlannedChangeSummary expected,
) {
  expect(_totals(actual), expected);
}

PlannedChangeSummary _totals(PlannedChangeSummary? summary) =>
    PlannedChangeSummary(
      created: summary!.created,
      updated: summary.updated,
      deleted: summary.deleted,
      preserved: summary.preserved,
      unchanged: summary.unchanged,
    );

ResolvedImportSource _source(String id, ImportAction action) =>
    ResolvedImportSource(id: id, action: action, items: const []);

const _profileReference = BackupProfileReference(
  id: '00000000-0000-4000-8000-000000000001',
  booruType: 'gelbooruV2',
  url: 'https://example.com',
  name: 'Example',
);

BooruConfig _profile({
  required int id,
  String name = 'Example',
  String url = 'https://example.com',
  String? apiKey,
}) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': profileUuid(id),
  'booruId': 1,
  'booruIdHint': 1,
  'name': name,
  'url': url,
  'apiKey': apiKey,
});

Bookmark _bookmark({required int localId, required int postId}) => Bookmark(
  id: localId,
  booruId: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  thumbnailUrl: 'https://example.com/$postId-thumb.jpg',
  sampleUrl: 'https://example.com/$postId-sample.jpg',
  originalUrl: 'https://example.com/$postId.jpg',
  sourceUrl: 'https://example.com',
  width: 100,
  height: 100,
  md5: 'md5-$postId',
  tags: {'tag-$postId'},
  realSourceUrl: null,
  format: 'jpg',
  imageUrlResolver: const DefaultImageUrlResolver(),
  postId: postId,
  metadata: const {},
);

SearchSubscription _search({
  required String id,
  required String query,
  String profileId = '00000000-0000-4000-8000-000000000001',
}) => SearchSubscription.create(
  id: id,
  profileId: profileId,
  query: query,
  name: null,
  position: 0,
  createdAt: DateTime.utc(2026),
);
