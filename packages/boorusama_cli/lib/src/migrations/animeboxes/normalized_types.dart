final class AnimeBoxesTimestamp {
  AnimeBoxesTimestamp.parse(this.raw) : instant = DateTime.parse(raw);

  final String raw;
  final DateTime instant;
}

final class AnimeBoxesEngine {
  const AnimeBoxesEngine({required this.name, required this.typeId});

  final String name;
  final int typeId;
}

final class NormalizedAnimeBoxesSource {
  const NormalizedAnimeBoxesSource({
    required this.formatVersion,
    required this.creatorName,
    required this.creatorVersion,
    required this.exportedAt,
  });

  final String formatVersion;
  final String creatorName;
  final String creatorVersion;
  final AnimeBoxesTimestamp exportedAt;
}

final class NormalizedAnimeBoxesProfile {
  const NormalizedAnimeBoxesProfile({
    required this.sourceId,
    required this.name,
    required this.url,
    required this.host,
    required this.engine,
    required this.useNativeAutocomplete,
    required this.ratingFilterEnabled,
    required this.selected,
    required this.isDefault,
    required this.loginPresent,
    required this.credentialsPresent,
    required this.sourcePosition,
  });

  final int sourceId;
  final String name;
  final String url;
  final String host;
  final AnimeBoxesEngine engine;
  final bool useNativeAutocomplete;
  final bool ratingFilterEnabled;
  final bool selected;
  final bool isDefault;
  final bool loginPresent;
  final bool credentialsPresent;
  final int sourcePosition;
}

final class NormalizedAnimeBoxesHistoryEntry {
  const NormalizedAnimeBoxesHistoryEntry({
    required this.sourceId,
    required this.query,
    required this.searchedAt,
    required this.starred,
    required this.sourcePosition,
  });

  final int sourceId;
  final String query;
  final AnimeBoxesTimestamp searchedAt;
  final bool starred;
  final int sourcePosition;
}

final class AnimeBoxesMediaVariant {
  const AnimeBoxesMediaVariant({
    required this.url,
    required this.width,
    required this.height,
  });

  final String url;
  final int width;
  final int height;
}

final class NormalizedAnimeBoxesBookmark {
  NormalizedAnimeBoxesBookmark({
    required this.sourceProfileId,
    required this.host,
    required this.engine,
    required this.postId,
    required this.postUrl,
    required this.preview,
    required this.sample,
    required this.original,
    required this.jpeg,
    required this.format,
    required List<String> tags,
    required List<String> generalTags,
    required List<String> artistTags,
    required List<String> characterTags,
    required List<String> copyrightTags,
    required this.md5,
    required this.source,
    required this.parentId,
    required this.score,
    required this.rating,
    required this.isTranslated,
    required this.hasComment,
    required this.hasChildren,
    required this.hasParentOrChildren,
    required this.dateAdded,
    required this.sourcePosition,
  }) : tags = List.unmodifiable(tags),
       generalTags = List.unmodifiable(generalTags),
       artistTags = List.unmodifiable(artistTags),
       characterTags = List.unmodifiable(characterTags),
       copyrightTags = List.unmodifiable(copyrightTags);

  final int sourceProfileId;
  final String host;
  final AnimeBoxesEngine engine;
  final int postId;
  final String postUrl;
  final AnimeBoxesMediaVariant preview;
  final AnimeBoxesMediaVariant sample;
  final AnimeBoxesMediaVariant original;
  final AnimeBoxesMediaVariant? jpeg;
  final String format;
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
  final bool isTranslated;
  final bool hasComment;
  final bool hasChildren;
  final bool hasParentOrChildren;
  final AnimeBoxesTimestamp dateAdded;
  final int sourcePosition;
}

final class NormalizedAnimeBoxesBlacklistEntry {
  const NormalizedAnimeBoxesBlacklistEntry({
    required this.sourceId,
    required this.rule,
    required this.sourcePosition,
  });

  final int sourceId;
  final String rule;
  final int sourcePosition;
}

final class NormalizedAnimeBoxesPinnedSearch {
  NormalizedAnimeBoxesPinnedSearch({
    required this.id,
    required this.sourceProfileId,
    required this.name,
    required this.query,
    required this.position,
    required this.url,
    required this.host,
    required this.engine,
    required this.disableAutoLoad,
    required this.includeBlacklisted,
    required this.initialPage,
    required Map<String, Object?> extraParams,
  }) : extraParams = Map.unmodifiable(extraParams);

  final String id;
  final int sourceProfileId;
  final String? name;
  final String query;
  final int position;
  final String url;
  final String host;
  final AnimeBoxesEngine engine;
  final bool disableAutoLoad;
  final bool includeBlacklisted;
  final int initialPage;
  final Map<String, Object?> extraParams;
}

final class NormalizedAnimeBoxesPinnedGroup {
  NormalizedAnimeBoxesPinnedGroup.folder({
    required String id,
    required String name,
    required this.sourcePosition,
    required List<NormalizedAnimeBoxesPinnedSearch> searches,
  }) : kind = 'folder',
       id = id,
       name = name,
       searches = List.unmodifiable(searches);

  NormalizedAnimeBoxesPinnedGroup.home({
    required this.sourcePosition,
    required List<NormalizedAnimeBoxesPinnedSearch> searches,
  }) : kind = 'home',
       id = null,
       name = null,
       searches = List.unmodifiable(searches);

  final String kind;
  final String? id;
  final String? name;
  final int sourcePosition;
  final List<NormalizedAnimeBoxesPinnedSearch> searches;
}

final class AnimeBoxesDiagnostic {
  AnimeBoxesDiagnostic({
    required this.code,
    required this.count,
    required this.section,
    this.row,
    required List<int> sourcePositions,
  }) : sourcePositions = List.unmodifiable(sourcePositions);

  final String code;
  final int count;
  final String? section;
  final int? row;
  final List<int> sourcePositions;
}

final class NormalizedAnimeBoxesDocument {
  NormalizedAnimeBoxesDocument({
    required this.source,
    required List<NormalizedAnimeBoxesProfile> profiles,
    required List<NormalizedAnimeBoxesHistoryEntry> searchHistory,
    required List<NormalizedAnimeBoxesBookmark> bookmarks,
    required List<NormalizedAnimeBoxesBlacklistEntry> blacklist,
    required List<NormalizedAnimeBoxesPinnedGroup> pinnedSearchFolders,
    required List<AnimeBoxesDiagnostic> diagnostics,
  }) : profiles = List.unmodifiable(profiles),
       searchHistory = List.unmodifiable(searchHistory),
       bookmarks = List.unmodifiable(bookmarks),
       blacklist = List.unmodifiable(blacklist),
       pinnedSearchFolders = List.unmodifiable(pinnedSearchFolders),
       diagnostics = List.unmodifiable(diagnostics);

  static const schema = 'boorusama.animeboxes.normalized';
  static const version = 1;

  final NormalizedAnimeBoxesSource source;
  final List<NormalizedAnimeBoxesProfile> profiles;
  final List<NormalizedAnimeBoxesHistoryEntry> searchHistory;
  final List<NormalizedAnimeBoxesBookmark> bookmarks;
  final List<NormalizedAnimeBoxesBlacklistEntry> blacklist;
  final List<NormalizedAnimeBoxesPinnedGroup> pinnedSearchFolders;
  final List<AnimeBoxesDiagnostic> diagnostics;
}
