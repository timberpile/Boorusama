import '../../../profile_uuid_utils.dart';
import 'package:boorusama/core/backups/export_import/import/bookmark_profile_dependency.dart';
import 'package:boorusama/core/backups/export_import/import/import_change_preview.dart';
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

  test('preview counts memberships without an extra changed group', () {
    final a = _bookmark(localId: 1, postId: 101);
    final b = _bookmark(localId: 2, postId: 102);
    final c = _bookmark(localId: 3, postId: 103);
    final summary = projector.bookmarks(
      local: BookmarkImportLocalSnapshot(
        bookmarks: [a, b],
        groups: [
          BookmarkGroup(id: 'g', name: 'Local', bookmarkIds: const {1, 2}),
        ],
      ),
      incoming: BookmarkBackupData(
        bookmarks: [a, c],
        groups: const [
          BookmarkGroupBackup(id: 'g', name: 'Imported', bookmarkIds: [1, 3]),
        ],
      ),
      resolution: ResolvedImportSource(
        id: 'bookmarks',
        action: ImportAction.configureItems,
        items: const [
          ResolvedImportItem(id: 'group:g', action: ImportAction.update),
        ],
      ),
    )!;
    expect(summary.previewRows.single.label, 'Local');
    expect(summary.previewRows.single.counts.added, 1);
    expect(summary.previewRows.single.counts.removed, 1);
    expect(summary.previewRows.single.counts.changed, 0);
  });
  test('settings preview exposes changed keys and masks nested secrets', () {
    final summary = projector.jsonPreview(
      sourceId: 'settings',
      local: {
        'themeMode': 'light',
        'proxy': {'password': 'old-secret'},
        'url': 'https://user:pass@site.example/?token=old',
        'proxyServer': 'socks5://proxy-user:proxy-secret@site.example',
      },
      incoming: {
        'themeMode': 'dark',
        'proxy': {'password': 'new-secret'},
        'url': 'https://user:newpass@site.example/?token=new',
        'proxyServer': 'socks5://new-user:new-proxy-secret@site.example',
      },
      resolution: _source('settings', ImportAction.replace),
    );
    expect(summary.previewRows.map((r) => r.label), contains('themeMode'));
    final values = summary.previewRows
        .expand((r) => r.details)
        .map((d) => '${d.before} ${d.after}')
        .join(' ');
    expect(values, contains('light dark'));
    for (final secret in [
      'old-secret',
      'new-secret',
      'pass@',
      'newpass',
      'proxy-secret',
      'proxy-user',
      'token=old',
      'token=new',
    ]) {
      expect(values, isNot(contains(secret)));
    }
  });
  test(
    'replace preview counts group additions removals and true renames with memberships',
    () {
      final a = _bookmark(localId: 1, postId: 101),
          b = _bookmark(localId: 2, postId: 102),
          c = _bookmark(localId: 3, postId: 103);
      final rows = projector
          .bookmarks(
            local: BookmarkImportLocalSnapshot(
              bookmarks: [a, b],
              groups: [
                BookmarkGroup(
                  id: 'rename',
                  name: 'Old',
                  bookmarkIds: const {1},
                ),
                BookmarkGroup(
                  id: 'removed',
                  name: 'Removed',
                  bookmarkIds: const {2},
                ),
              ],
            ),
            incoming: BookmarkBackupData(
              bookmarks: [a, c],
              groups: const [
                BookmarkGroupBackup(
                  id: 'rename',
                  name: 'New',
                  bookmarkIds: [1, 3],
                ),
                BookmarkGroupBackup(
                  id: 'added',
                  name: 'Added',
                  bookmarkIds: [],
                ),
              ],
            ),
            resolution: _source('bookmarks', ImportAction.replace),
          )!
          .previewRows;
      final total = rows.fold(
        const ImportChangeCounts(),
        (sum, row) => sum + row.counts,
      );
      expect(total, const ImportChangeCounts(added: 2, removed: 2, changed: 1));
      expect(
        rows.singleWhere((row) => row.id == 'rename').previousLabel,
        'Old',
      );
    },
  );
  test(
    'shared memberships and ungrouped metadata remain compact without record duplication',
    () {
      final a = _bookmark(localId: 1, postId: 101),
          b = _bookmark(localId: 2, postId: 102);
      final updated = b.copyWith(metadata: {'search': 'updated'});
      final rows = projector
          .bookmarks(
            local: BookmarkImportLocalSnapshot(
              bookmarks: [a, b],
              groups: [
                BookmarkGroup(id: 'one', name: 'One', bookmarkIds: const {1}),
                BookmarkGroup(id: 'two', name: 'Two', bookmarkIds: const {1}),
              ],
            ),
            incoming: BookmarkBackupData(
              bookmarks: [a, updated],
              groups: const [
                BookmarkGroupBackup(id: 'one', name: 'One', bookmarkIds: []),
                BookmarkGroupBackup(id: 'two', name: 'Two', bookmarkIds: [1]),
              ],
            ),
            resolution: _source('bookmarks', ImportAction.replace),
          )!
          .previewRows;
      expect(
        rows.where((row) => row.category == 'bookmarks').single.counts,
        const ImportChangeCounts(removed: 1),
      );
      final metadata = rows.singleWhere(
        (row) => row.category == 'bookmark_metadata',
      );
      expect(metadata.counts, const ImportChangeCounts(changed: 1));
      expect(metadata.limit, ImportPreviewLimit.bookmarkMetadata);
      expect(rows.any((row) => row.label.contains('102')), isFalse);
      final ungrouped = projector
          .bookmarks(
            local: BookmarkImportLocalSnapshot(
              bookmarks: [a, b],
              groups: const [],
            ),
            incoming: BookmarkBackupData(bookmarks: [a], groups: const []),
            resolution: _source('bookmarks', ImportAction.replace),
          )!
          .previewRows
          .single;
      expect(ungrouped.id, 'ungrouped');
      expect(ungrouped.counts, const ImportChangeCounts(removed: 1));
    },
  );
  test(
    'global blacklist replacement shows missing local deletion and masks sensitive URLs',
    () {
      final summary = projector.jsonPreview(
        sourceId: 'blacklisted_tags',
        local: [
          {'id': 1, 'name': 'old'},
          {'id': 2, 'name': 'rating:e'},
        ],
        incoming: [
          {'id': 2, 'name': 'rating:e -scenery'},
          {
            'id': 3,
            'name':
                'https://user:private@site.example/?auth=hidden&access_key=hidden&pwd=hidden&signature=hidden',
          },
        ],
        resolution: _source('blacklisted_tags', ImportAction.replace),
      );
      expect(
        summary.previewRows.fold(
          const ImportChangeCounts(),
          (sum, row) => sum + row.counts,
        ),
        const ImportChangeCounts(added: 1, removed: 1, changed: 1),
      );
      expect(
        summary.previewRows.singleWhere((row) => row.id == '2').previousLabel,
        'rating:e',
      );
      expect(
        summary.previewRows.singleWhere((row) => row.id == '3').label,
        isNot(contains('hidden')),
      );
      expect(
        summary.previewRows.singleWhere((row) => row.id == '3').label,
        isNot(contains('private')),
      );
    },
  );
  test(
    'profile scoped rule details show additions removals and masked credentials once',
    () {
      final old = BooruConfig.fromJson({
        ..._profile(id: 1, apiKey: 'old-secret').toJson(),
        'blacklistedTags': {
          'combinationMode': 'merge',
          'enable': true,
          'blacklistedTags': 'old\nkeep',
        },
      });
      final next = BooruConfig.fromJson({
        ..._profile(id: 1, apiKey: 'new-secret').toJson(),
        'blacklistedTags': {
          'combinationMode': 'merge',
          'enable': true,
          'blacklistedTags': 'new\nkeep',
        },
      });
      final row = projector
          .profiles(
            local: [old],
            imported: [next],
            credentialsIncluded: true,
            resolution: _source('profiles', ImportAction.replace),
          )!
          .previewRows
          .single;
      expect(row.counts, const ImportChangeCounts(changed: 1));
      expect(row.profileId, old.id);
      expect(
        row.details.where((d) => d.key == 'id' || d.key == 'name'),
        isEmpty,
      );
      expect(
        row.details.where((d) => d.key == 'blacklistedTags').map((d) => d.kind),
        containsAll([ImportChangeKind.added, ImportChangeKind.removed]),
      );
      expect(
        row.details.map((d) => d.before + ' ' + d.after).join(),
        isNot(contains('secret')),
      );
    },
  );
  for (final action in [ImportAction.skip, ImportAction.replace]) {
    test(
      '${action.name} identical JSON has no display rows',
      () => expect(
        projector
            .jsonPreview(
              sourceId: 'settings',
              local: {'themeMode': 'dark'},
              incoming: {'themeMode': 'dark'},
              resolution: _source('settings', action),
            )
            .previewRows,
        isEmpty,
      ),
    );
  }
  test(
    'SQLite preview states database replacement without invented individual row counts',
    () {
      final row = projector
          .jsonPreview(
            sourceId: 'search_histories',
            local: 'digest-old',
            incoming: 'digest-next',
            resolution: _source('search_histories', ImportAction.replace),
          )
          .previewRows
          .single;
      expect(row.limit, ImportPreviewLimit.database);
      expect(row.counts, const ImportChangeCounts(changed: 1));
      expect(row.details, isEmpty);
    },
  );
  for (final destination in [1, 2]) {
    test(
      'bookmark mapping to profile $destination projects existing hint changes before writes',
      () {
        final bookmark = bookmarkWithProfileHint(
          _bookmark(localId: 1, postId: 101),
          profileUuid(1),
        );
        final summary = projector.bookmarks(
          local: BookmarkImportLocalSnapshot(
            bookmarks: [bookmark],
            groups: [
              BookmarkGroup(id: 'g', name: 'Group', bookmarkIds: const {1}),
            ],
          ),
          incoming: BookmarkBackupData(
            bookmarks: [bookmark],
            groups: const [
              BookmarkGroupBackup(id: 'g', name: 'Group', bookmarkIds: [1]),
            ],
          ),
          resolution: ResolvedImportSource(
            id: 'bookmarks',
            action: ImportAction.configureItems,
            items: const [
              ResolvedImportItem(id: 'group:g', action: ImportAction.update),
            ],
          ),
          profileMappings: {
            ProfileReferenceKey.fromReference(
              bookmarkProfileReference(bookmark),
            ): profileUuid(
              destination,
            ),
          },
        )!;
        expect(summary.hasMutations, destination == 2);
        if (destination == 1) {
          expect(summary.previewRows, isEmpty);
        } else {
          expect(summary.previewRows.single.category, 'bookmark_metadata');
          expect(
            summary.previewRows.single.counts,
            const ImportChangeCounts(changed: 1),
          );
        }
      },
    );
  }
  test(
    'favorite tags replace uses tag names as identities and retains every affected tag',
    () {
      final rows = projector
          .jsonPreview(
            sourceId: 'favorite_tags',
            local: [
              {'name': 'removed'},
              {
                'name': 'kept',
                'labels': ['old'],
              },
            ],
            incoming: [
              {'name': 'added'},
              {
                'name': 'kept',
                'labels': ['new'],
              },
            ],
            resolution: _source('favorite_tags', ImportAction.replace),
          )
          .previewRows;
      expect(
        rows.map((row) => row.label),
        containsAll(['removed', 'added', 'kept']),
      );
      expect(
        rows.fold(const ImportChangeCounts(), (sum, row) => sum + row.counts),
        const ImportChangeCounts(added: 1, removed: 1, changed: 1),
      );
    },
  );
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
      expect(summary!.previewRows, isEmpty);
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

  for (final action in [ImportAction.update, ImportAction.replace]) {
    test(
      '${action.name} preview distinguishes a local name from imported content',
      () {
        final local = _bookmark(localId: 1, postId: 101);
        final incoming = _bookmark(localId: 20, postId: 101);
        final summary = projector.bookmarks(
          local: BookmarkImportLocalSnapshot(
            bookmarks: [local],
            groups: [
              BookmarkGroup(
                id: 'group',
                name: 'Cookie//Artists',
                bookmarkIds: const {1},
              ),
            ],
          ),
          incoming: BookmarkBackupData(
            bookmarks: [incoming],
            groups: const [
              BookmarkGroupBackup(
                id: 'group',
                name: 'Artists',
                bookmarkIds: [20],
              ),
            ],
          ),
          resolution: action == ImportAction.replace
              ? _source('bookmarks', ImportAction.replace)
              : ResolvedImportSource(
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
        _expectTotals(
          summary,
          action == ImportAction.replace
              ? const PlannedChangeSummary(updated: 1, unchanged: 1)
              : const PlannedChangeSummary(unchanged: 2),
        );
        expect(
          summary!.entitySummaries['bookmark-group']?.updated,
          action == ImportAction.replace ? 1 : 0,
        );
      },
    );
  }

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

    _expectTotals(summary, const PlannedChangeSummary(created: 12));
    expect(summary!.entitySummaries['bookmark']?.created, 10);
    expect(summary.entitySummaries['bookmark-group']?.created, 1);
    expect(
      summary.previewRows
          .singleWhere((row) => row.label != 'Imported Groups')
          .counts,
      const ImportChangeCounts(added: 11),
    );
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

      expect(summary?.hasMutations, isFalse);
      expect(summary?.updated, 0);
      expect(summary?.entitySummaries['pinned-home']?.updated ?? 0, 0);
      expect(summary!.previewRows.every((row) => !row.entityChanged), isTrue);
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
    expect(summary!.previewRows.every((row) => row.isContainer), isTrue);
    final newFolder = summary.previewRows.singleWhere(
      (row) => row.label == 'New',
    );
    final oldFolder = summary.previewRows.singleWhere(
      (row) => row.label == 'Old',
    );
    final home = summary.previewRows.singleWhere(
      (row) => row.label == '__home',
    );
    expect(newFolder.children.single.label, 'cat girl');
    expect(newFolder.children.single.kind, ImportChangeKind.added);
    expect(oldFolder.children.single.label, 'removed');
    expect(oldFolder.children.single.kind, ImportChangeKind.removed);
    expect(home.children.single.label, 'cat girl');
    expect(home.children.single.kind, ImportChangeKind.removed);
    expect(
      summary.previewRows.fold(
        const ImportChangeCounts(),
        (sum, row) => sum + row.counts,
      ),
      const ImportChangeCounts(added: 2, removed: 3),
    );
  });

  test('adding a search to Home counts only the search', () {
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
            id: 'pin',
            name: null,
            query: 'cat',
            position: 0,
            profile: _profileReference,
          ),
        ],
        homeSearchIds: ['pin'],
      ),
      profileMappings: {
        ProfileReferenceKey.fromReference(_profileReference):
            '00000000-0000-4000-8000-000000000001',
      },
      resolution: _source('pinned_searches', ImportAction.replace),
    )!;
    final home = summary.previewRows.single;
    expect(home.label, '__home');
    expect(home.entityChanged, isFalse);
    expect(home.children.single.kind, ImportChangeKind.added);
    expect(home.counts, const ImportChangeCounts(added: 1));
  });

  for (final rename in [false, true]) {
    test(
      rename
          ? 'renaming a folder counts the folder itself'
          : 'adding to an existing folder counts only the added search',
      () {
        final summary = projector.pinnedSearches(
          local: PinnedSearchImportLocalSnapshot(
            searches: [_search(id: 'cat', query: 'cat')],
            organization: SearchOrganization(
              folders: [
                SharedSearchFolder(
                  id: 'folder',
                  name: 'Animals',
                  searchIds: const ['cat'],
                ),
              ],
              homeSearchIds: const [],
            ),
            feeds: const [],
          ),
          incoming: PinnedSearchBackupData(
            records: [
              const PinnedSearchBackupRecord(
                id: 'cat',
                name: null,
                query: 'cat',
                position: 0,
                profile: _profileReference,
              ),
              if (!rename)
                const PinnedSearchBackupRecord(
                  id: 'dog',
                  name: null,
                  query: 'dog',
                  position: 1,
                  profile: _profileReference,
                ),
            ],
            folders: [
              PinnedSearchFolderBackupRecord(
                id: 'folder',
                name: rename ? 'Renamed' : 'Animals',
                position: 0,
                searchIds: ['cat', if (!rename) 'dog'],
              ),
            ],
          ),
          profileMappings: {
            ProfileReferenceKey.fromReference(_profileReference):
                '00000000-0000-4000-8000-000000000001',
          },
          resolution: _source('pinned_searches', ImportAction.replace),
        )!;
        final folder = summary.previewRows.single;
        expect(folder.entityChanged, rename);
        expect(
          folder.counts,
          rename
              ? const ImportChangeCounts(changed: 1)
              : const ImportChangeCounts(added: 1),
        );
        expect(folder.children.length, rename ? 0 : 1);
      },
    );
  }

  test('legacy pins without organization entries are shown under Home', () {
    final summary = projector.pinnedSearches(
      local: PinnedSearchImportLocalSnapshot(
        searches: [_search(id: 'orphan', query: 'cat')],
        organization: SearchOrganization(folders: [], homeSearchIds: []),
        feeds: [],
      ),
      incoming: const PinnedSearchBackupData(records: [], folders: []),
      profileMappings: {},
      resolution: _source('pinned_searches', ImportAction.replace),
    )!;
    expect(summary.previewRows.single.label, '__home');
    expect(summary.previewRows.single.children.single.label, 'cat');
    expect(
      summary.previewRows.single.children.single.kind,
      ImportChangeKind.removed,
    );
    expect(
      summary.previewRows.single.counts,
      const ImportChangeCounts(removed: 1),
    );
  });

  test(
    'matching query text from different profiles remains separate inside its folder',
    () {
      final summary = projector.pinnedSearches(
        local: PinnedSearchImportLocalSnapshot(
          searches: [_search(id: 'old', query: 'cat')],
          organization: SearchOrganization(
            folders: [
              SharedSearchFolder(
                id: 'folder',
                name: 'Cats',
                searchIds: ['old'],
              ),
            ],
            homeSearchIds: [],
          ),
          feeds: [],
        ),
        incoming: const PinnedSearchBackupData(
          records: [
            PinnedSearchBackupRecord(
              id: 'new',
              name: 'Cats at work',
              query: 'cat',
              position: 0,
              profile: _profileReference,
            ),
          ],
          folders: [
            PinnedSearchFolderBackupRecord(
              id: 'folder',
              name: 'Cats',
              position: 0,
              searchIds: ['new'],
            ),
          ],
        ),
        profileMappings: {
          ProfileReferenceKey.fromReference(_profileReference):
              '00000000-0000-4000-8000-000000000002',
        },
        resolution: _source('pinned_searches', ImportAction.replace),
      )!;
      final folder = summary.previewRows.single;
      expect(folder.children.map((row) => row.kind), [
        ImportChangeKind.added,
        ImportChangeKind.removed,
      ]);
      expect(folder.children.map((row) => row.profileId), [
        '00000000-0000-4000-8000-000000000002',
        '00000000-0000-4000-8000-000000000001',
      ]);
      expect(folder.children.first.label, 'Cats at work');
      expect(folder.children.first.details.single.after, 'cat');
      expect(
        folder.counts,
        const ImportChangeCounts(added: 1, removed: 1),
      );
    },
  );

  test(
    'folder reorder remains visible without fabricating search additions or removals',
    () {
      final summary = projector.pinnedSearches(
        local: PinnedSearchImportLocalSnapshot(
          searches: [
            _search(id: 'cat', query: 'cat'),
            _search(id: 'dog', query: 'dog'),
          ],
          organization: SearchOrganization(
            folders: [
              SharedSearchFolder(
                id: 'folder',
                name: 'Animals',
                searchIds: ['cat', 'dog'],
              ),
            ],
            homeSearchIds: [],
          ),
          feeds: [],
        ),
        incoming: const PinnedSearchBackupData(
          records: [
            PinnedSearchBackupRecord(
              id: 'cat',
              name: null,
              query: 'cat',
              position: 0,
              profile: _profileReference,
            ),
            PinnedSearchBackupRecord(
              id: 'dog',
              name: null,
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
              searchIds: ['dog', 'cat'],
            ),
          ],
        ),
        profileMappings: {
          ProfileReferenceKey.fromReference(_profileReference):
              '00000000-0000-4000-8000-000000000001',
        },
        resolution: _source('pinned_searches', ImportAction.replace),
      )!;
      final folder = summary.previewRows.single;
      expect(folder.children, hasLength(2));
      expect(folder.entityChanged, isFalse);
      expect(
        folder.details.single.presentation,
        ImportDetailPresentation.queryOrder,
      );
      expect(folder.details.single.before, 'cat\ndog');
      expect(folder.details.single.after, 'dog\ncat');
      expect(folder.counts, const ImportChangeCounts(changed: 2));
    },
  );

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
      const PlannedChangeSummary(created: 5, preserved: 1),
    );
    expect(summary?.entitySummaries['pinned-search']?.created, 3);
    expect(summary?.entitySummaries['pinned-folder']?.created, 2);
    final folder = summary!.previewRows.singleWhere(
      (row) => row.label == 'Three searches',
    );
    expect(folder.isContainer, isTrue);
    expect(folder.label, 'Three searches');
    expect(folder.children.map((row) => row.label), ['one', 'two', 'three']);
    expect(
      folder.children.every(
        (row) => row.profileId == '00000000-0000-4000-8000-000000000001',
      ),
      isTrue,
    );
    expect(folder.counts, const ImportChangeCounts(added: 4));
    expect(folder.details, isEmpty);
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

      final row = summary!.previewRows.single;
      expect(row.previousLabel, 'First');
      expect(row.label, 'First updated');
      expect(row.isContainer, isTrue);
      expect(row.details, isEmpty);
      expect(row.children.single.label, 'dog');
      expect(row.children.single.kind, ImportChangeKind.added);
      expect(row.children.single.profileId, cat.profileId);
      expect(row.counts, const ImportChangeCounts(added: 1, changed: 1));

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

  test('empty library counts each new feed and each of its search entries', () {
    final summary = projector.followingFeeds(
      local: FollowingFeedImportLocalSnapshot(
        searches: const [],
        feeds: const [],
      ),
      incoming: FollowingFeedBackupData(
        feeds: [
          FollowingFeedBackupRecord(
            id: 'one',
            name: 'One entry',
            position: 0,
            queries: ['cat'],
            profile: _profileReference,
          ),
          FollowingFeedBackupRecord(
            id: 'two',
            name: 'Two entries',
            position: 1,
            queries: ['cat', 'dog'],
            profile: _profileReference,
          ),
        ],
      ),
      profileMappings: {
        ProfileReferenceKey.fromReference(_profileReference):
            '00000000-0000-4000-8000-000000000001',
      },
      resolution: _source('following_feeds', ImportAction.replace),
    )!;
    expect(summary.previewRows.map((row) => row.counts), [
      const ImportChangeCounts(added: 2),
      const ImportChangeCounts(added: 3),
    ]);
    expect(
      summary.previewRows.fold(
        const ImportChangeCounts(),
        (sum, row) => sum + row.counts,
      ),
      const ImportChangeCounts(added: 5),
    );
  });

  for (final scenario in [
    (
      label: 'rename',
      before: ['cat'],
      after: ['cat'],
      profile: '00000000-0000-4000-8000-000000000001',
      counts: const ImportChangeCounts(changed: 1),
    ),
    (
      label: 'reordering',
      before: ['cat', 'dog'],
      after: ['dog', 'cat'],
      profile: '00000000-0000-4000-8000-000000000001',
      counts: const ImportChangeCounts(changed: 2),
    ),
    (
      label: 'insertion without artificial position changes',
      before: ['cat', 'dog'],
      after: ['bird', 'cat', 'dog'],
      profile: '00000000-0000-4000-8000-000000000001',
      counts: const ImportChangeCounts(added: 1),
    ),
    (
      label: 'replacement',
      before: ['cat'],
      after: ['dog'],
      profile: '00000000-0000-4000-8000-000000000001',
      counts: const ImportChangeCounts(added: 1, removed: 1),
    ),
    (
      label: 'profile change',
      before: ['cat'],
      after: ['cat'],
      profile: '00000000-0000-4000-8000-000000000002',
      counts: const ImportChangeCounts(changed: 2),
    ),
  ]) {
    test(
      'feed entry counts include individual changes for ${scenario.label}',
      () {
        final summary = projector.followingFeeds(
          local: FollowingFeedImportLocalSnapshot(
            searches: [
              for (final (index, query) in scenario.before.indexed)
                _search(id: 'source-$index', query: query),
            ],
            feeds: [
              SearchFollowingFeed(
                id: 'feed',
                name: 'Feed',
                profileId: '00000000-0000-4000-8000-000000000001',
                sourceIds: [
                  for (final (index, _) in scenario.before.indexed)
                    'source-$index',
                ],
              ),
            ],
          ),
          incoming: FollowingFeedBackupData(
            feeds: [
              FollowingFeedBackupRecord(
                id: 'feed',
                name: scenario.label == 'rename' ? 'Renamed' : 'Feed',
                position: 0,
                queries: scenario.after,
                profile: _profileReference,
              ),
            ],
          ),
          profileMappings: {
            ProfileReferenceKey.fromReference(_profileReference):
                scenario.profile,
          },
          resolution: _source('following_feeds', ImportAction.replace),
        )!;
        final feed = summary.previewRows.single;
        expect(feed.counts, scenario.counts);
        if (scenario.label == 'reordering') {
          expect(feed.children.map((row) => row.kind), [
            ImportChangeKind.changed,
            ImportChangeKind.changed,
          ]);
          expect(feed.children.first.details.single.before, '1');
          expect(feed.children.first.details.single.after, '0');
        }
        if (scenario.label == 'insertion without artificial position changes') {
          expect(feed.children.single.label, 'bird');
        }
      },
    );
  }

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
    expect(summary!.previewRows.single.category, 'following_feeds');
    expect(summary.previewRows.single.isContainer, isTrue);
    expect(summary.previewRows.single.children.single.label, 'dog');
    expect(
      summary.previewRows.single.children.single.kind,
      ImportChangeKind.removed,
    );
    expect(
      summary.previewRows.single.children.single.profileId,
      '00000000-0000-4000-8000-000000000001',
    );

    expect(
      summary.previewRows.single.counts,
      const ImportChangeCounts(removed: 2),
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
