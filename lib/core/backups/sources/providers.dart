// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../bookmarks/providers.dart';
import '../../configs/manage/providers.dart';
import '../../search/subscriptions/providers.dart';
import '../export_import/models/export_selection.dart';
import '../export_import/sources/export_selection_ids.dart';
import '../export_import/sources/export_import_source.dart';
import '../export_import/sources/legacy_json_source_adapter.dart';
import '../export_import/sources/legacy_sqlite_source_adapter.dart';
import '../export_import/sources/profile_export_sanitizer.dart';
import '../types/backup_registry.dart';
import 'blacklisted_tags_source.dart';
import 'bookmark_backup_data.dart';
import 'bookmarks_source.dart';
import 'booru_configs_source.dart';
import 'downloads_source.dart';
import 'favorite_tags_source.dart';
import 'following_feeds_source.dart';
import 'following_feed_backup_data.dart';
import 'pinned_searches_source.dart';
import 'pinned_search_backup_data.dart';
import 'search_history_source.dart';
import 'settings_source.dart';

final booruConfigsBackupSourceProvider = Provider<BooruConfigsBackupSource>((
  ref,
) {
  return BooruConfigsBackupSource(ref);
});

final settingsBackupSourceProvider = Provider<SettingsBackupSource>((ref) {
  return SettingsBackupSource(ref);
});

final favoriteTagsBackupSourceProvider = Provider<FavoriteTagsBackupSource>((
  ref,
) {
  return FavoriteTagsBackupSource(ref);
});

final blacklistedTagsBackupSourceProvider =
    Provider<BlacklistedTagsBackupSource>((ref) {
      return BlacklistedTagsBackupSource(ref);
    });

final searchHistoryBackupSourceProvider = Provider<SearchHistoryBackupSource>((
  ref,
) {
  return SearchHistoryBackupSource(ref);
});

final downloadsBackupSourceProvider = Provider<DownloadsBackupSource>((ref) {
  return DownloadsBackupSource(ref);
});

final bookmarksBackupSourceProvider = Provider<BookmarksBackupSource>((ref) {
  return BookmarksBackupSource(ref);
});

final pinnedSearchesBackupSourceProvider =
    NotifierProvider<
      PinnedSearchesBackupSourceNotifier,
      PinnedSearchesBackupSource
    >(
      PinnedSearchesBackupSourceNotifier.new,
    );

class PinnedSearchesBackupSourceNotifier
    extends Notifier<PinnedSearchesBackupSource> {
  @override
  PinnedSearchesBackupSource build() => PinnedSearchesBackupSource(ref);
}

final followingFeedsBackupSourceProvider =
    NotifierProvider<
      FollowingFeedsBackupSourceNotifier,
      FollowingFeedsBackupSource
    >(
      FollowingFeedsBackupSourceNotifier.new,
    );

class FollowingFeedsBackupSourceNotifier
    extends Notifier<FollowingFeedsBackupSource> {
  @override
  FollowingFeedsBackupSource build() => FollowingFeedsBackupSource(ref);
}

final exportImportSourcesProvider = Provider<List<ExportImportSource>>((ref) {
  final profiles = ref.watch(booruConfigProvider);
  final bookmarks = ref.watch(bookmarkProvider).valueOrNull;
  final searches = ref.watch(searchSubscriptionsProvider).valueOrNull;
  final internalSearchIds = <String>{
    for (final feed in searches?.feeds ?? const []) ...feed.sourceIds,
  };
  final selectableSearches = {
    for (final search in searches?.subscriptions ?? const [])
      if (!internalSearchIds.contains(search.id)) search.id: search,
  };
  final pinnedSearchChildren = <ExportSelectionNode>[
    for (final folder in searches?.organization.folders ?? const [])
      ExportSelectionNode(
        id: ExportSelectionIds.pinnedSearchFolder(folder.id),
        children: [
          for (final id in folder.searchIds)
            if (selectableSearches.containsKey(id))
              ExportSelectionNode(id: ExportSelectionIds.pinnedSearch(id)),
        ],
      ),
    if ((searches?.organization.homeSearchIds ?? const []).any(
      selectableSearches.containsKey,
    ))
      ExportSelectionNode(
        id: ExportSelectionIds.pinnedSearchHome,
        children: [
          for (final id in searches?.organization.homeSearchIds ?? const [])
            if (selectableSearches.containsKey(id))
              ExportSelectionNode(id: ExportSelectionIds.pinnedSearch(id)),
        ],
      ),
  ];

  return [
    LegacyJsonSourceAdapter(
      source: ref.watch(booruConfigsBackupSourceProvider),
      descriptor: ExportSelectionDescriptor.collection(
        id: 'profiles',
        childIds: {
          for (final profile in profiles)
            ExportSelectionIds.profile(profile.id),
        },
      ),
      scopeBuilder: (selection) => switch (selection.kind) {
        ExportNodeSelectionKind.all => const ProfileExportScope.all(),
        ExportNodeSelectionKind.explicit => ProfileExportScope.selected(
          selection.childIds.map(ExportSelectionIds.profileId).whereType<int>(),
        ),
      },
      transformer: const ProfileExportSanitizer().sanitizeExportJson,
    ),
    LegacyJsonSourceAdapter(source: ref.watch(settingsBackupSourceProvider)),
    LegacyJsonSourceAdapter(
      source: ref.watch(favoriteTagsBackupSourceProvider),
    ),
    LegacySqliteSourceAdapter(ref.watch(searchHistoryBackupSourceProvider)),
    LegacySqliteSourceAdapter(ref.watch(downloadsBackupSourceProvider)),
    LegacyJsonSourceAdapter(
      source: ref.watch(blacklistedTagsBackupSourceProvider),
    ),
    LegacyJsonSourceAdapter(
      source: ref.watch(bookmarksBackupSourceProvider),
      descriptor: ExportSelectionDescriptor.collection(
        id: 'bookmarks',
        childIds: {
          ExportSelectionIds.ungroupedBookmarks,
          for (final group in bookmarks?.groups ?? const [])
            ExportSelectionIds.bookmarkGroup(group.id),
        },
      ),
      scopeBuilder: (selection) => switch (selection.kind) {
        ExportNodeSelectionKind.all => const BookmarkExportScope.all(),
        ExportNodeSelectionKind.explicit => BookmarkExportScope.selected(
          groupIds: selection.childIds
              .map(ExportSelectionIds.bookmarkGroupId)
              .whereType<String>(),
          includeUngrouped: selection.childIds.contains(
            ExportSelectionIds.ungroupedBookmarks,
          ),
        ),
      },
    ),
    LegacyJsonSourceAdapter(
      source: ref.watch(pinnedSearchesBackupSourceProvider),
      descriptor: ExportSelectionDescriptor.collection(
        id: 'pinned_searches',
        children: pinnedSearchChildren,
      ),
      scopeBuilder: (selection) => switch (selection.kind) {
        ExportNodeSelectionKind.all => const PinnedSearchExportScope.all(),
        ExportNodeSelectionKind.explicit => PinnedSearchExportScope.selected(
          searchIds: selection.childIds
              .map(ExportSelectionIds.pinnedSearchId)
              .whereType<String>(),
          folderIds: selection.childIds
              .map(ExportSelectionIds.pinnedSearchFolderId)
              .whereType<String>(),
          includeHome: selection.childIds.contains(
            ExportSelectionIds.pinnedSearchHome,
          ),
        ),
      },
    ),
    LegacyJsonSourceAdapter(
      source: ref.watch(followingFeedsBackupSourceProvider),
      descriptor: ExportSelectionDescriptor.collection(
        id: 'following_feeds',
        childIds: {
          for (final feed in searches?.feeds ?? const [])
            ExportSelectionIds.followingFeed(feed.id),
        },
      ),
      scopeBuilder: (selection) => switch (selection.kind) {
        ExportNodeSelectionKind.all => const FollowingFeedExportScope.all(),
        ExportNodeSelectionKind.explicit => FollowingFeedExportScope.selected(
          selection.childIds
              .map(ExportSelectionIds.followingFeedId)
              .whereType<String>(),
        ),
      },
    ),
  ];
});

final backupRegistryProvider = Provider<BackupRegistry>((ref) {
  final registry = BackupRegistry()
    ..register(ref.read(booruConfigsBackupSourceProvider))
    ..register(ref.read(settingsBackupSourceProvider))
    ..register(ref.read(favoriteTagsBackupSourceProvider))
    ..register(ref.read(searchHistoryBackupSourceProvider))
    ..register(ref.read(downloadsBackupSourceProvider))
    ..register(ref.read(blacklistedTagsBackupSourceProvider))
    ..register(ref.read(bookmarksBackupSourceProvider))
    ..register(ref.watch(pinnedSearchesBackupSourceProvider))
    ..register(ref.watch(followingFeedsBackupSourceProvider));
  return registry;
});

final allBackupSourcesProvider = Provider<void>((ref) {
  ref
    ..watch(booruConfigsBackupSourceProvider)
    ..watch(settingsBackupSourceProvider)
    ..watch(favoriteTagsBackupSourceProvider)
    ..watch(searchHistoryBackupSourceProvider)
    ..watch(downloadsBackupSourceProvider)
    ..watch(blacklistedTagsBackupSourceProvider)
    ..watch(bookmarksBackupSourceProvider)
    ..watch(pinnedSearchesBackupSourceProvider)
    ..watch(followingFeedsBackupSourceProvider);
});
