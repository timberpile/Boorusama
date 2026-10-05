final class AnimeBoxesExport {
  const AnimeBoxesExport({
    required this.metadata,
    required this.servers,
    required this.history,
    required this.favorites,
    required this.blacklist,
    required this.folders,
    required this.pinnedSearches,
  });

  final AnimeBoxesMetadata metadata;
  final List<AnimeBoxesServer> servers;
  final List<AnimeBoxesHistoryEntry> history;
  final List<AnimeBoxesFavorite> favorites;
  final List<AnimeBoxesBlacklistEntry> blacklist;
  final List<AnimeBoxesPinFolder> folders;
  final List<AnimeBoxesPinnedSearch> pinnedSearches;
}

final class AnimeBoxesSourceTimestamp {
  AnimeBoxesSourceTimestamp({required this.raw, required this.instant});

  final String raw;
  final DateTime instant;
}

final class AnimeBoxesMetadata {
  const AnimeBoxesMetadata({
    required this.formatVersion,
    required this.creatorName,
    required this.creatorVersion,
    required this.exportedAt,
    required this.sourceRow,
  });

  final String formatVersion;
  final String creatorName;
  final String creatorVersion;
  final AnimeBoxesSourceTimestamp exportedAt;
  final int sourceRow;
}

final class AnimeBoxesServer {
  const AnimeBoxesServer({
    required this.serverId,
    required this.url,
    required this.name,
    required this.useNativeAutocomplete,
    required this.ratingFilterEnabled,
    required this.selected,
    required this.isDefault,
    required this.type,
    required this.loginPresent,
    required this.credentialsPresent,
    required this.realUrl,
    required this.sourceRow,
    required this.sourcePosition,
  });

  final int serverId;
  final String url;
  final String name;
  final bool useNativeAutocomplete;
  final bool ratingFilterEnabled;
  final bool selected;
  final bool isDefault;
  final int type;
  final bool loginPresent;
  final bool credentialsPresent;
  final String realUrl;
  final int sourceRow;
  final int sourcePosition;
}

final class AnimeBoxesHistoryEntry {
  const AnimeBoxesHistoryEntry({
    required this.itemId,
    required this.query,
    required this.searchedAt,
    required this.starred,
    required this.sourceRow,
    required this.sourcePosition,
  });

  final int itemId;
  final String query;
  final AnimeBoxesSourceTimestamp searchedAt;
  final bool starred;
  final int sourceRow;
  final int sourcePosition;
}

final class AnimeBoxesFavorite {
  const AnimeBoxesFavorite({
    required this.postId,
    required this.postUrl,
    required this.sampleWidth,
    required this.sampleHeight,
    required this.sampleUrl,
    required this.previewWidth,
    required this.previewHeight,
    required this.previewUrl,
    required this.width,
    required this.height,
    required this.fileUrl,
    required this.jpegWidth,
    required this.jpegHeight,
    required this.jpegUrl,
    required this.tags,
    required this.generalTags,
    required this.artistTags,
    required this.characterTags,
    required this.copyrightTags,
    required this.md5,
    required this.source,
    required this.parentId,
    required this.score,
    required this.rating,
    required this.hasNotes,
    required this.hasComments,
    required this.hasChildren,
    required this.dateAdded,
    required this.sourceRow,
    required this.sourcePosition,
  });

  final int postId;
  final String postUrl;
  final int sampleWidth;
  final int sampleHeight;
  final String sampleUrl;
  final int previewWidth;
  final int previewHeight;
  final String previewUrl;
  final int width;
  final int height;
  final String fileUrl;
  final int jpegWidth;
  final int jpegHeight;
  final String? jpegUrl;
  final List<String> tags;
  final List<String> generalTags;
  final List<String> artistTags;
  final List<String> characterTags;
  final List<String> copyrightTags;
  final String md5;
  final String? source;
  final int? parentId;
  final int score;
  final String rating;
  final bool hasNotes;
  final bool hasComments;
  final bool hasChildren;
  final AnimeBoxesSourceTimestamp dateAdded;
  final int sourceRow;
  final int sourcePosition;
}

final class AnimeBoxesBlacklistEntry {
  const AnimeBoxesBlacklistEntry({
    required this.rule,
    required this.sourceId,
    required this.sourceRow,
    required this.sourcePosition,
  });

  final String rule;
  final int sourceId;
  final int sourceRow;
  final int sourcePosition;
}

final class AnimeBoxesPinFolder {
  const AnimeBoxesPinFolder({
    required this.id,
    required this.name,
    required this.query,
    required this.disableAutoLoad,
    required this.includeBlacklisted,
    required this.initialPage,
    required this.extraParams,
    required this.sourceRow,
    required this.sourcePosition,
  });

  final String id;
  final String name;
  final String query;
  final bool disableAutoLoad;
  final bool includeBlacklisted;
  final int initialPage;
  final Map<String, Object?> extraParams;
  final int sourceRow;
  final int sourcePosition;
}

final class AnimeBoxesPinnedSearch {
  const AnimeBoxesPinnedSearch({
    required this.folderId,
    required this.id,
    required this.url,
    required this.name,
    required this.query,
    required this.disableAutoLoad,
    required this.includeBlacklisted,
    required this.initialPage,
    required this.extraParams,
    required this.sourceRow,
    required this.sourcePosition,
  });

  final String folderId;
  final String id;
  final String url;
  final String name;
  final String query;
  final bool disableAutoLoad;
  final bool includeBlacklisted;
  final int initialPage;
  final Map<String, Object?> extraParams;
  final int sourceRow;
  final int sourcePosition;
}
