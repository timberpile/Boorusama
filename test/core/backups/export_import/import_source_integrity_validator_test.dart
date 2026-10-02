import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/backups/export_import/import/import_source_integrity_validator.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/pinned_search_backup_data.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';

void main() {
  const validator = ImportSourceIntegrityValidator();

  test('rejects a source schema newer than the app understands', () {
    final issues = validator.validate(
      sourceId: 'settings',
      packageSchemaVersion: 3,
      supportedSchemaVersion: 2,
      selection: const ExportNodeSelection.leaf('settings'),
      itemRecommendations: const {},
      data: Object(),
    );

    expect(issues.single.code, 'unsupported_source_version');
  });

  test('rejects selected and recommended items absent from the payload', () {
    const data = BookmarkBackupData(bookmarks: [], groups: []);
    final issues = validator.validate(
      sourceId: 'bookmarks',
      packageSchemaVersion: 3,
      supportedSchemaVersion: 3,
      selection: const ExportNodeSelection.explicit('bookmarks', {
        'group:missing',
      }),
      itemRecommendations: const {
        'group:also-missing': ImportAction.update,
      },
      data: data,
    );

    expect(issues.map((issue) => issue.code).toSet(), {
      'unknown_selected_item',
      'unknown_recommended_item',
    });
  });

  test('rejects bookmark groups referencing an absent bookmark', () {
    const data = BookmarkBackupData(
      bookmarks: [],
      groups: [
        BookmarkGroupBackup(
          id: 'group-id',
          name: 'References',
          bookmarkIds: [42],
        ),
      ],
    );
    final issues = validator.validate(
      sourceId: 'bookmarks',
      packageSchemaVersion: 3,
      supportedSchemaVersion: 3,
      selection: const ExportNodeSelection.all('bookmarks'),
      itemRecommendations: const {},
      data: data,
    );

    expect(issues.single.code, 'missing_bookmark_reference');
    expect(issues.single.itemId, 'group:group-id');
  });

  test('rejects payload items hidden outside an explicit selection', () {
    const data = PinnedSearchBackupData(
      records: [
        PinnedSearchBackupRecord(
          id: 'shown',
          name: null,
          query: 'one',
          position: 0,
          profile: BackupProfileReference(
            id: 1,
            booruType: 'danbooru',
            url: 'https://example.com',
            name: 'Example',
          ),
        ),
        PinnedSearchBackupRecord(
          id: 'hidden',
          name: null,
          query: 'two',
          position: 1,
          profile: BackupProfileReference(
            id: 1,
            booruType: 'danbooru',
            url: 'https://example.com',
            name: 'Example',
          ),
        ),
      ],
    );
    final issues = validator.validate(
      sourceId: 'pinned_searches',
      packageSchemaVersion: 1,
      supportedSchemaVersion: 1,
      selection: const ExportNodeSelection.explicit('pinned_searches', {
        'search:shown',
      }),
      itemRecommendations: const {},
      data: data,
    );

    expect(issues.single.code, 'unselected_payload_item');
    expect(issues.single.itemId, 'search:hidden');
  });

  test('allows searches required by an explicitly selected folder', () {
    const data = PinnedSearchBackupData(
      records: [
        PinnedSearchBackupRecord(
          id: 'member',
          name: null,
          query: 'one',
          position: 0,
          profile: BackupProfileReference(
            id: 1,
            booruType: 'danbooru',
            url: 'https://example.com',
            name: 'Example',
          ),
        ),
      ],
      folders: [
        PinnedSearchFolderBackupRecord(
          id: 'folder',
          name: 'Folder',
          position: 0,
          searchIds: ['member'],
        ),
      ],
    );
    final issues = validator.validate(
      sourceId: 'pinned_searches',
      packageSchemaVersion: 1,
      supportedSchemaVersion: 1,
      selection: const ExportNodeSelection.explicit('pinned_searches', {
        'folder:folder',
      }),
      itemRecommendations: const {},
      data: data,
    );

    expect(issues, isEmpty);
  });

  test('allows structural folders for selected searches and Home payloads', () {
    const data = PinnedSearchBackupData(
      records: [
        PinnedSearchBackupRecord(
          id: 'folder-member',
          name: null,
          query: 'one',
          position: 0,
          profile: BackupProfileReference(
            id: 1,
            booruType: 'danbooru',
            url: 'https://example.com',
            name: 'Example',
          ),
        ),
        PinnedSearchBackupRecord(
          id: 'home-member',
          name: null,
          query: 'two',
          position: 1,
          profile: BackupProfileReference(
            id: 1,
            booruType: 'danbooru',
            url: 'https://example.com',
            name: 'Example',
          ),
        ),
      ],
      folders: [
        PinnedSearchFolderBackupRecord(
          id: 'folder',
          name: 'Folder',
          position: 0,
          searchIds: ['folder-member'],
        ),
      ],
      homeSearchIds: ['home-member'],
    );

    final selectedSearchIssues = validator.validate(
      sourceId: 'pinned_searches',
      packageSchemaVersion: 1,
      supportedSchemaVersion: 1,
      selection: const ExportNodeSelection.explicit('pinned_searches', {
        'search:folder-member',
      }),
      itemRecommendations: const {},
      data: const PinnedSearchBackupData(
        records: [
          PinnedSearchBackupRecord(
            id: 'folder-member',
            name: null,
            query: 'one',
            position: 0,
            profile: BackupProfileReference(
              id: 1,
              booruType: 'danbooru',
              url: 'https://example.com',
              name: 'Example',
            ),
          ),
        ],
        folders: [
          PinnedSearchFolderBackupRecord(
            id: 'folder',
            name: 'Folder',
            position: 0,
            searchIds: ['folder-member'],
          ),
        ],
      ),
    );
    final selectedHomeIssues = validator.validate(
      sourceId: 'pinned_searches',
      packageSchemaVersion: 1,
      supportedSchemaVersion: 1,
      selection: const ExportNodeSelection.explicit('pinned_searches', {
        'home',
      }),
      itemRecommendations: const {},
      data: PinnedSearchBackupData(
        records: [data.records.last],
        homeSearchIds: const ['home-member'],
      ),
    );

    expect(selectedSearchIssues, isEmpty);
    expect(selectedHomeIssues, isEmpty);
  });

  test('Home selection still rejects records outside Home', () {
    const profile = BackupProfileReference(
      id: 1,
      booruType: 'danbooru',
      url: 'https://example.com',
      name: 'Example',
    );
    final issues = validator.validate(
      sourceId: 'pinned_searches',
      packageSchemaVersion: 1,
      supportedSchemaVersion: 1,
      selection: const ExportNodeSelection.explicit('pinned_searches', {
        'home',
      }),
      itemRecommendations: const {},
      data: const PinnedSearchBackupData(
        records: [
          PinnedSearchBackupRecord(
            id: 'home-member',
            name: null,
            query: 'one',
            position: 0,
            profile: profile,
          ),
          PinnedSearchBackupRecord(
            id: 'unrelated',
            name: null,
            query: 'two',
            position: 1,
            profile: profile,
          ),
        ],
        homeSearchIds: ['home-member'],
      ),
    );

    expect(issues.single.code, 'unselected_payload_item');
    expect(issues.single.itemId, 'search:unrelated');
  });

  test('allows an explicitly selected empty ungrouped boundary', () {
    final issues = validator.validate(
      sourceId: 'bookmarks',
      packageSchemaVersion: 1,
      supportedSchemaVersion: 1,
      selection: const ExportNodeSelection.explicit('bookmarks', {
        'ungrouped',
      }),
      itemRecommendations: const {},
      data: const BookmarkBackupData(bookmarks: [], groups: []),
    );

    expect(issues, isEmpty);
  });
}
