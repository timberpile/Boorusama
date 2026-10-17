// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../bookmarks/providers.dart';
import '../../configs/manage/providers.dart';
import '../../search/following_topics/providers.dart';
import '../export_import/models/export_selection.dart';
import '../export_import/sources/export_selection_ids.dart';
import '../export_import/sources/export_import_source.dart';
import '../export_import/sources/legacy_json_source_adapter.dart';
import '../export_import/sources/legacy_sqlite_source_adapter.dart';
import '../export_import/sources/profile_export_sanitizer.dart';
import '../types/backup_registry.dart';
import '../types/backup_data_source.dart';
import 'blacklisted_tags_source.dart';
import 'bookmark_backup_data.dart';
import '../export_import/import/import_item_labels.dart';
import 'bookmarks_source.dart';
import 'booru_configs_source.dart';
import 'downloads_source.dart';
import 'favorite_tags_source.dart';
import 'topic_feeds_source.dart';
import 'topic_feed_backup_data.dart';
import 'following_topics_source.dart';
import 'following_topic_backup_data.dart';
import 'search_history_source.dart';
import 'settings_source.dart';
import '../../search/following_topics/src/compatibility/topic_storage_contract.dart';

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

final followingTopicsBackupSourceProvider =
    NotifierProvider<
      FollowingTopicsBackupSourceNotifier,
      FollowingTopicsBackupSource
    >(
      FollowingTopicsBackupSourceNotifier.new,
    );

class FollowingTopicsBackupSourceNotifier
    extends Notifier<FollowingTopicsBackupSource> {
  @override
  FollowingTopicsBackupSource build() => FollowingTopicsBackupSource(ref);
}

final topicFeedsBackupSourceProvider =
    NotifierProvider<TopicFeedsBackupSourceNotifier, TopicFeedsBackupSource>(
      TopicFeedsBackupSourceNotifier.new,
    );

class TopicFeedsBackupSourceNotifier extends Notifier<TopicFeedsBackupSource> {
  @override
  TopicFeedsBackupSource build() => TopicFeedsBackupSource(ref);
}

final exportImportSourcesProvider = Provider<List<ExportImportSource>>((ref) {
  final profiles = ref.watch(booruConfigProvider);
  final bookmarks = ref.watch(bookmarkProvider).valueOrNull;
  final searches = ref.watch(followingTopicsProvider).valueOrNull;
  final folderIds =
      searches?.organization.folders.map((folder) => folder.id).toSet() ??
      <String>{};
  final internalSearchIds = <String>{
    for (final feed in searches?.feeds ?? const [])
      if (!folderIds.contains(feed.id)) ...feed.sourceIds,
  };
  final legacyFeeds = [
    for (final feed in searches?.feeds ?? const [])
      if (!folderIds.contains(feed.id)) feed,
  ];
  final selectableSearches = {
    for (final search in searches?.topics ?? const [])
      if (!internalSearchIds.contains(search.id)) search.id: search,
  };
  final followingTopicChildren = [
    ...buildFolderSelectionNodes(
      folders: searches?.organization.folders ?? [],
      folderPrefix: 'folder:',
      items: {
        for (final f in searches?.organization.folders ?? const [])
          f.id: [
            for (final id in f.searchIds)
              if (selectableSearches.containsKey(id))
                ExportSelectionNode(id: ExportSelectionIds.followingTopic(id)),
          ],
      },
    ),
    ExportSelectionNode(
      id: ExportSelectionIds.followingTopicHome,
      canHaveChildren: true,
      children: [
        for (final id in searches?.organization.homeSearchIds ?? const [])
          if (selectableSearches.containsKey(id))
            ExportSelectionNode(id: ExportSelectionIds.followingTopic(id)),
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
          selection.childIds
              .map(ExportSelectionIds.profileId)
              .whereType<String>(),
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
        children: bookmarkExportNodes(
          buildBookmarkBackupData(
            bookmarks: bookmarks?.items ?? [],
            groups: bookmarks?.groups ?? [],
            folders: bookmarks?.folders ?? [],
            scope: const BookmarkExportScope.all(),
          ),
        ),
      ),
      scopeBuilder: (selection) => switch (selection.kind) {
        ExportNodeSelectionKind.all => const BookmarkExportScope.all(),
        ExportNodeSelectionKind.explicit => BookmarkExportScope.selected(
          folderIds: selection.childIds
              .where((id) => id.startsWith('group-folder:'))
              .map((id) => id.substring(13)),
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
      source: ref.watch(followingTopicsBackupSourceProvider),
      descriptor: ExportSelectionDescriptor.collection(
        id: followingTopicsBackupSourceId,
        children: followingTopicChildren,
      ),
      scopeBuilder: (selection) => switch (selection.kind) {
        ExportNodeSelectionKind.all => const FollowingTopicExportScope.all(),
        ExportNodeSelectionKind.explicit => FollowingTopicExportScope.selected(
          searchIds: selection.childIds
              .map(ExportSelectionIds.followingTopicId)
              .whereType<String>(),
          folderIds: selection.childIds
              .map(ExportSelectionIds.followingTopicFolderId)
              .whereType<String>(),
          includeHome: selection.childIds.contains(
            ExportSelectionIds.followingTopicHome,
          ),
        ),
      },
    ),
    if (legacyFeeds.isNotEmpty)
      LegacyJsonSourceAdapter(
        source: ref.watch(topicFeedsBackupSourceProvider),
        descriptor: ExportSelectionDescriptor.collection(
          id: topicFeedsBackupSourceId,
          childIds: {
            for (final feed in legacyFeeds)
              ExportSelectionIds.topicFeed(feed.id),
          },
        ),
        scopeBuilder: (selection) => switch (selection.kind) {
          ExportNodeSelectionKind.all => const TopicFeedExportScope.all(),
          ExportNodeSelectionKind.explicit => TopicFeedExportScope.selected(
            selection.childIds
                .map(ExportSelectionIds.topicFeedId)
                .whereType<String>(),
          ),
        },
      ),
  ];
});

final backupPresentationSourcesProvider = Provider<List<BackupDataSource>>((
  ref,
) {
  final sources = ref.watch(backupRegistryProvider).getAllSources();
  final state = ref.watch(followingTopicsProvider).valueOrNull;
  if (state == null) return sources;
  final folderIds = state.organization.folders
      .map((folder) => folder.id)
      .toSet();
  final hasLegacyFeeds = state.feeds.any(
    (feed) => !folderIds.contains(feed.id),
  );
  return [
    for (final source in sources)
      if (source.id != topicFeedsBackupSourceId || hasLegacyFeeds) source,
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
    ..register(ref.watch(followingTopicsBackupSourceProvider))
    ..register(ref.watch(topicFeedsBackupSourceProvider));
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
    ..watch(followingTopicsBackupSourceProvider)
    ..watch(topicFeedsBackupSourceProvider);
});
