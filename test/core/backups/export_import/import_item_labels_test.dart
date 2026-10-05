import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/backups/export_import/import/import_item_labels.dart';
import 'package:boorusama/core/backups/export_import/sources/export_selection_ids.dart';
import 'package:boorusama/core/backups/sources/following_feed_backup_data.dart';
import 'package:boorusama/core/backups/sources/pinned_search_backup_data.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';

void main() {
  const profile = BackupProfileReference(
    id: '00000000-0000-4000-8000-000000000001',
    booruType: 'gelbooruV2',
    url: 'https://example.com',
    name: 'Example',
  );

  test('uses imported folder and search names in the review', () {
    const data = PinnedSearchBackupData(
      records: [
        PinnedSearchBackupRecord(
          id: 'search-id',
          name: 'Landscapes',
          query: 'landscape',
          position: 0,
          profile: profile,
        ),
        PinnedSearchBackupRecord(
          id: 'unnamed-id',
          name: null,
          query: 'blue sky',
          position: 1,
          profile: profile,
        ),
      ],
      folders: [
        PinnedSearchFolderBackupRecord(
          id: 'folder-id',
          name: 'References',
          position: 0,
          searchIds: ['search-id'],
        ),
      ],
      homeSearchIds: ['unnamed-id'],
    );

    final result = importItemPresentation('pinned_searches', data);

    expect(result.labels, {
      'folder:folder-id': 'References',
      'search:search-id': 'Landscapes',
      'search:unnamed-id': 'blue sky',
    });
    expect(result.descriptor.rootNodes.first.id, 'folder:folder-id');
    expect(
      result.descriptor.rootNodes.first.children.map((node) => node.id),
      ['search:search-id'],
    );
    expect(
      result.descriptor.rootNodes.last.id,
      ExportSelectionIds.pinnedSearchHome,
    );
    expect(
      result.presentation.items['search:search-id']?.trailingLabel,
      'Example',
    );
  });

  test('uses imported feed names in the review', () {
    final data = FollowingFeedBackupData(
      feeds: [
        FollowingFeedBackupRecord(
          id: 'feed-id',
          name: 'Daily art',
          position: 0,
          queries: const ['rating:safe'],
          profile: profile,
        ),
      ],
    );

    final result = importItemPresentation('following_feeds', data);

    expect(result.labels, {'feed:feed-id': 'Daily art'});
    expect(result.descriptor.childIds, {'feed:feed-id'});
    expect(
      result.presentation.items['feed:feed-id']?.trailingLabel,
      'Example',
    );
  });
}
