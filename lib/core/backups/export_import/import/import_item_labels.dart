import '../../../configs/config/types.dart';
import '../../sources/bookmark_backup_data.dart';
import '../../sources/following_feed_backup_data.dart';
import '../../sources/pinned_search_backup_data.dart';

Map<String, String> importItemLabels(Object? data) => switch (data) {
  final List<BooruConfig> profiles => {
    for (final profile in profiles) 'profile:${profile.id}': profile.name,
  },
  final BookmarkBackupData bookmarks => {
    for (final group in bookmarks.groups)
      if (group.id case final id?) 'group:$id': group.name,
  },
  final PinnedSearchBackupData searches => {
    for (final folder in searches.folders) 'folder:${folder.id}': folder.name,
    for (final search in searches.records)
      'search:${search.id}': switch (search.name?.trim()) {
        final name? when name.isNotEmpty => name,
        _ => search.query,
      },
  },
  final FollowingFeedBackupData feeds => {
    for (final feed in feeds.feeds) 'feed:${feed.id}': feed.name,
  },
  _ => const {},
};
