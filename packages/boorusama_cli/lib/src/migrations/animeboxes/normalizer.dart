import 'errors.dart';
import 'normalized_types.dart';
import 'sensitive_data.dart';
import 'site_identity.dart';
import 'source_types.dart';

final class AnimeBoxesNormalizer {
  const AnimeBoxesNormalizer();

  NormalizedAnimeBoxesDocument normalize(AnimeBoxesExport source) {
    final profiles = source.servers.map(_normalizeProfile).toList();
    _requireUniqueProfileIds(profiles, source.servers);

    final profilesByHost = <String, NormalizedAnimeBoxesProfile>{};
    for (final profile in profiles) {
      final existing = profilesByHost[profile.host];
      if (existing != null &&
          migrationSiteNamespace(existing.url) !=
              migrationSiteNamespace(profile.url)) {
        throw const AnimeBoxesFormatException(
          'ambiguous_site_profiles',
          'Profiles on one host use different site URLs.',
          section: 'Servers',
        );
      }
      profilesByHost.putIfAbsent(profile.host, () => profile);
    }

    final normalizedBookmarks = <_BookmarkWithRow>[];
    for (final favorite in source.favorites) {
      final pageUrl = _normalizeAbsoluteUrl(
        favorite.postUrl,
        section: 'Favorites',
        row: favorite.sourceRow,
      );
      final host = Uri.parse(pageUrl).host;
      final profile = profilesByHost[host];
      if (profile == null ||
          migrationSiteNamespace(profile.url) !=
              migrationSiteNamespace(pageUrl, includePath: false)) {
        throw AnimeBoxesFormatException(
          'unmatched_profile',
          'A favorite does not match a configured profile.',
          section: 'Favorites',
          row: favorite.sourceRow,
        );
      }
      normalizedBookmarks.add(
        _BookmarkWithRow(
          bookmark: _normalizeBookmark(favorite, profile, pageUrl),
          sourceRow: favorite.sourceRow,
        ),
      );
    }
    final deduplicated = _deduplicateBookmarks(normalizedBookmarks);
    final groups = _normalizePinnedGroups(
      source.folders,
      source.pinnedSearches,
      profilesByHost,
    );

    final diagnostics = <AnimeBoxesDiagnostic>[
      if (profiles.any(
        (profile) => profile.loginPresent || profile.credentialsPresent,
      ))
        AnimeBoxesDiagnostic(
          code: 'sensitive_profile_fields_omitted',
          count: profiles
              .where(
                (profile) => profile.loginPresent || profile.credentialsPresent,
              )
              .length,
          section: 'Servers',
          sourcePositions: [
            for (final profile in profiles)
              if (profile.loginPresent || profile.credentialsPresent)
                profile.sourcePosition,
          ],
        ),
      if (source.history.isNotEmpty)
        AnimeBoxesDiagnostic(
          code: 'history_retained_without_target',
          count: source.history.length,
          section: 'History',
          sourcePositions: [
            for (final entry in source.history) entry.sourcePosition,
          ],
        ),
      ...deduplicated.diagnostics,
    ];

    return NormalizedAnimeBoxesDocument(
      source: NormalizedAnimeBoxesSource(
        formatVersion: source.metadata.formatVersion,
        creatorName: source.metadata.creatorName,
        creatorVersion: source.metadata.creatorVersion,
        exportedAt: _timestamp(source.metadata.exportedAt),
      ),
      profiles: profiles,
      searchHistory: [
        for (final entry in source.history)
          NormalizedAnimeBoxesHistoryEntry(
            sourceId: entry.itemId,
            query: entry.query,
            searchedAt: _timestamp(entry.searchedAt),
            starred: entry.starred,
            sourcePosition: entry.sourcePosition,
          ),
      ],
      bookmarks: deduplicated.bookmarks,
      blacklist: [
        for (final entry in source.blacklist)
          NormalizedAnimeBoxesBlacklistEntry(
            sourceId: entry.sourceId,
            rule: entry.rule,
            sourcePosition: entry.sourcePosition,
          ),
      ],
      pinnedSearchFolders: groups,
      diagnostics: diagnostics,
    );
  }
}

NormalizedAnimeBoxesProfile _normalizeProfile(AnimeBoxesServer server) {
  final url = _normalizeSiteUrl(
    server.realUrl,
    section: 'Servers',
    row: server.sourceRow,
  );
  final host = Uri.parse(url).host;
  final mapping = _mappingForHost(
    host,
    section: 'Servers',
    row: server.sourceRow,
  );
  if (server.type != mapping.animeBoxesType) {
    throw AnimeBoxesFormatException(
      'engine_mismatch',
      'A site does not match its AnimeBoxes engine type.',
      section: 'Servers',
      row: server.sourceRow,
    );
  }
  return NormalizedAnimeBoxesProfile(
    sourceId: server.serverId,
    name: server.name,
    url: url,
    host: host,
    engine: mapping.engine,
    useNativeAutocomplete: server.useNativeAutocomplete,
    ratingFilterEnabled: server.ratingFilterEnabled,
    selected: server.selected,
    isDefault: server.isDefault,
    loginPresent: server.loginPresent,
    credentialsPresent: server.credentialsPresent,
    sourcePosition: server.sourcePosition,
  );
}

void _requireUniqueProfileIds(
  List<NormalizedAnimeBoxesProfile> profiles,
  List<AnimeBoxesServer> servers,
) {
  final ids = <int>{};
  for (var index = 0; index < profiles.length; index++) {
    if (!ids.add(profiles[index].sourceId)) {
      throw AnimeBoxesFormatException(
        'duplicate_profile_id',
        'A profile ID is repeated.',
        section: 'Servers',
        row: servers[index].sourceRow,
      );
    }
  }
}

NormalizedAnimeBoxesBookmark _normalizeBookmark(
  AnimeBoxesFavorite favorite,
  NormalizedAnimeBoxesProfile profile,
  String postUrl,
) {
  final originalUrl = _normalizeAbsoluteUrl(
    favorite.fileUrl,
    section: 'Favorites',
    row: favorite.sourceRow,
  );
  return NormalizedAnimeBoxesBookmark(
    sourceProfileId: profile.sourceId,
    host: profile.host,
    engine: profile.engine,
    postId: favorite.postId,
    postUrl: postUrl,
    preview: AnimeBoxesMediaVariant(
      url: _normalizeAbsoluteUrl(
        favorite.previewUrl,
        section: 'Favorites',
        row: favorite.sourceRow,
      ),
      width: favorite.previewWidth,
      height: favorite.previewHeight,
    ),
    sample: AnimeBoxesMediaVariant(
      url: _normalizeAbsoluteUrl(
        favorite.sampleUrl,
        section: 'Favorites',
        row: favorite.sourceRow,
      ),
      width: favorite.sampleWidth,
      height: favorite.sampleHeight,
    ),
    original: AnimeBoxesMediaVariant(
      url: originalUrl,
      width: favorite.width,
      height: favorite.height,
    ),
    jpeg: switch (favorite.jpegUrl) {
      final url? => AnimeBoxesMediaVariant(
        url: _normalizeAbsoluteUrl(
          url,
          section: 'Favorites',
          row: favorite.sourceRow,
        ),
        width: favorite.jpegWidth,
        height: favorite.jpegHeight,
      ),
      null => null,
    },
    format: _fileExtension(originalUrl, favorite.sourceRow),
    tags: favorite.tags,
    generalTags: favorite.generalTags,
    artistTags: favorite.artistTags,
    characterTags: favorite.characterTags,
    copyrightTags: favorite.copyrightTags,
    md5: favorite.md5,
    source: favorite.source,
    parentId: favorite.parentId,
    score: favorite.score,
    rating: _normalizeRating(favorite.rating, favorite.sourceRow),
    isTranslated: favorite.hasNotes,
    hasComment: favorite.hasComments,
    hasChildren: favorite.hasChildren,
    hasParentOrChildren: favorite.hasChildren || favorite.parentId != null,
    dateAdded: _timestamp(favorite.dateAdded),
    sourcePosition: favorite.sourcePosition,
  );
}

_DeduplicatedBookmarks _deduplicateBookmarks(
  List<_BookmarkWithRow> bookmarks,
) {
  final groups = <(String, int), List<_BookmarkWithRow>>{};
  for (final bookmark in bookmarks) {
    groups
        .putIfAbsent(
          (bookmark.bookmark.host, bookmark.bookmark.postId),
          () => [],
        )
        .add(bookmark);
  }

  final winners = <NormalizedAnimeBoxesBookmark>[];
  final diagnostics = <AnimeBoxesDiagnostic>[];
  for (final group in groups.values) {
    final ranked = [...group]
      ..sort((left, right) {
        final dateOrder = right.bookmark.dateAdded.instant.compareTo(
          left.bookmark.dateAdded.instant,
        );
        if (dateOrder != 0) return dateOrder;
        return right.bookmark.sourcePosition.compareTo(
          left.bookmark.sourcePosition,
        );
      });
    final winner = ranked.first;
    winners.add(winner.bookmark);
    if (ranked.length > 1) {
      diagnostics.add(
        AnimeBoxesDiagnostic(
          code: 'duplicate_bookmark',
          count: ranked.length - 1,
          section: 'Favorites',
          row: winner.sourceRow,
          sourcePositions: [
            winner.bookmark.sourcePosition,
            for (final duplicate in ranked.skip(1))
              duplicate.bookmark.sourcePosition,
          ],
        ),
      );
    }
  }
  winners.sort(
    (left, right) => left.sourcePosition.compareTo(right.sourcePosition),
  );
  diagnostics.sort((left, right) {
    final leftPosition = left.sourcePositions.first;
    final rightPosition = right.sourcePositions.first;
    return leftPosition.compareTo(rightPosition);
  });
  return _DeduplicatedBookmarks(winners, diagnostics);
}

List<NormalizedAnimeBoxesPinnedGroup> _normalizePinnedGroups(
  List<AnimeBoxesPinFolder> folders,
  List<AnimeBoxesPinnedSearch> searches,
  Map<String, NormalizedAnimeBoxesProfile> profilesByHost,
) {
  final folderIds = <String>{};
  for (final folder in folders) {
    _requireUuid(folder.id, 'duplicate_folder_id', folder.sourceRow);
    if (!folderIds.add(folder.id)) {
      throw AnimeBoxesFormatException(
        'duplicate_folder_id',
        'A pinned-search folder ID is repeated.',
        section: 'Home Pins',
        row: folder.sourceRow,
      );
    }
  }
  final searchIds = <String>{};
  for (final search in searches) {
    _requireUuid(search.id, 'duplicate_search_id', search.sourceRow);
    if (!searchIds.add(search.id)) {
      throw AnimeBoxesFormatException(
        'duplicate_search_id',
        'A pinned-search ID is repeated.',
        section: 'Home Pins',
        row: search.sourceRow,
      );
    }
    if (search.folderId.isNotEmpty && !folderIds.contains(search.folderId)) {
      throw AnimeBoxesFormatException(
        'orphan_pinned_search',
        'A pinned search references a missing folder.',
        section: 'Home Pins',
        row: search.sourceRow,
      );
    }
  }
  final orderedSearches = [
    ...searches,
  ]..sort((left, right) => left.sourcePosition.compareTo(right.sourcePosition));
  final searchPositions = {
    for (final (position, search) in orderedSearches.indexed)
      search.id: position,
  };

  final groups = <NormalizedAnimeBoxesPinnedGroup>[];
  for (final folder in folders) {
    final children =
        searches.where((search) => search.folderId == folder.id).toList()..sort(
          (left, right) => left.sourcePosition.compareTo(right.sourcePosition),
        );
    groups.add(
      NormalizedAnimeBoxesPinnedGroup.folder(
        id: folder.id,
        name: folder.name,
        sourcePosition: folder.sourcePosition,
        searches: _normalizeSearches(
          children,
          profilesByHost,
          searchPositions,
        ),
      ),
    );
  }
  final homeSearches =
      searches.where((search) => search.folderId.isEmpty).toList()..sort(
        (left, right) => left.sourcePosition.compareTo(right.sourcePosition),
      );
  if (homeSearches.isNotEmpty) {
    groups.add(
      NormalizedAnimeBoxesPinnedGroup.home(
        sourcePosition: homeSearches.first.sourcePosition,
        searches: _normalizeSearches(
          homeSearches,
          profilesByHost,
          searchPositions,
        ),
      ),
    );
  }
  groups.sort(
    (left, right) => left.sourcePosition.compareTo(right.sourcePosition),
  );
  return groups;
}

List<NormalizedAnimeBoxesPinnedSearch> _normalizeSearches(
  List<AnimeBoxesPinnedSearch> searches,
  Map<String, NormalizedAnimeBoxesProfile> profilesByHost,
  Map<String, int> searchPositions,
) => [
  for (final search in searches)
    _normalizeSearch(search, searchPositions[search.id]!, profilesByHost),
];

NormalizedAnimeBoxesPinnedSearch _normalizeSearch(
  AnimeBoxesPinnedSearch search,
  int position,
  Map<String, NormalizedAnimeBoxesProfile> profilesByHost,
) {
  final url = _normalizeSiteUrl(
    search.url,
    section: 'Home Pins',
    row: search.sourceRow,
  );
  final host = Uri.parse(url).host;
  final mapping = _mappingForHost(
    host,
    section: 'Home Pins',
    row: search.sourceRow,
  );
  final profile = profilesByHost[host];
  if (profile == null ||
      profile.engine.name != mapping.engine.name ||
      profile.engine.typeId != mapping.engine.typeId ||
      migrationSiteNamespace(profile.url) != migrationSiteNamespace(url)) {
    throw AnimeBoxesFormatException(
      'unmatched_profile',
      'A pinned search does not match a configured profile.',
      section: 'Home Pins',
      row: search.sourceRow,
    );
  }
  _validateExtraParams(search.extraParams, search.sourceRow);
  return NormalizedAnimeBoxesPinnedSearch(
    id: search.id,
    sourceProfileId: profile.sourceId,
    name: search.name.isEmpty ? null : search.name,
    query: search.query,
    position: position,
    url: url,
    host: host,
    engine: mapping.engine,
    disableAutoLoad: search.disableAutoLoad,
    includeBlacklisted: search.includeBlacklisted,
    initialPage: search.initialPage,
    extraParams: search.extraParams,
  );
}

void _validateExtraParams(Object? value, int row) {
  switch (value) {
    case Map<String, Object?>():
      for (final entry in value.entries) {
        if (isSensitiveAnimeBoxesKey(entry.key)) {
          throw AnimeBoxesFormatException(
            'sensitive_query_data',
            'Pinned-search data contains a sensitive field.',
            section: 'Home Pins',
            row: row,
          );
        }
        _validateExtraParams(entry.value, row);
      }
    case List<Object?>():
      for (final item in value) {
        _validateExtraParams(item, row);
      }
    default:
      return;
  }
}

AnimeBoxesTimestamp _timestamp(AnimeBoxesSourceTimestamp source) =>
    AnimeBoxesTimestamp.parse(source.raw);

String _normalizeRating(String rating, int row) =>
    switch (rating.toLowerCase()) {
      'e' || 'explicit' => 'explicit',
      'q' || 'questionable' => 'questionable',
      's' || 'safe' || 'sensitive' => 'sensitive',
      'g' || 'general' => 'general',
      _ => throw AnimeBoxesFormatException(
        'invalid_rating',
        'A favorite rating is unsupported.',
        section: 'Favorites',
        row: row,
      ),
    };

String _fileExtension(String url, int row) {
  final segment = Uri.parse(url).pathSegments.lastOrNull ?? '';
  final separator = segment.lastIndexOf('.');
  if (separator < 0 || separator == segment.length - 1) {
    throw AnimeBoxesFormatException(
      'missing_media_format',
      'A favorite file URL has no media format.',
      section: 'Favorites',
      row: row,
    );
  }
  return segment.substring(separator + 1).toLowerCase();
}

String _normalizeSiteUrl(
  String raw, {
  required String section,
  required int row,
}) {
  final uri = _normalizedUri(raw, section: section, row: row);
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: _nonDefaultPort(uri),
  ).toString();
}

String _normalizeAbsoluteUrl(
  String raw, {
  required String section,
  required int row,
}) {
  final uri = _normalizedUri(raw, section: section, row: row);
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: _nonDefaultPort(uri),
    path: uri.path,
    query: uri.hasQuery ? uri.query : null,
    fragment: uri.hasFragment ? uri.fragment : null,
  ).toString();
}

Uri _normalizedUri(
  String raw, {
  required String section,
  required int row,
}) {
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !uri.isAbsolute ||
      !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw AnimeBoxesFormatException(
      'invalid_url',
      'A URL is invalid.',
      section: section,
      row: row,
    );
  }
  return uri.replace(
    scheme: uri.scheme.toLowerCase(),
    host: uri.host.toLowerCase(),
  );
}

int? _nonDefaultPort(Uri uri) {
  if (!uri.hasPort ||
      (uri.scheme == 'http' && uri.port == 80) ||
      (uri.scheme == 'https' && uri.port == 443)) {
    return null;
  }
  return uri.port;
}

_EngineMapping _mappingForHost(
  String host, {
  required String section,
  required int row,
}) {
  final normalized = host.startsWith('www.') ? host.substring(4) : host;
  final mapping = switch (normalized) {
    'donmai.us' || 'danbooru.donmai.us' || 'donmai.moe' => _danbooru,
    _ when normalized.endsWith('.donmai.us') => _danbooru,
    'gelbooru.com' => _gelbooru,
    'rule34.xxx' || 'realbooru.com' => _gelbooruV2,
    'konachan.com' || 'konachan.net' => _moebooru,
    _ => null,
  };
  if (mapping == null) {
    throw AnimeBoxesFormatException(
      'unsupported_engine',
      'A site uses an unsupported engine.',
      section: section,
      row: row,
    );
  }
  return mapping;
}

void _requireUuid(String value, String code, int row) {
  if (!_uuidPattern.hasMatch(value)) {
    throw AnimeBoxesFormatException(
      code,
      'A pinned-search UUID is invalid.',
      section: 'Home Pins',
      row: row,
    );
  }
}

final class _EngineMapping {
  const _EngineMapping({required this.engine, required this.animeBoxesType});

  final AnimeBoxesEngine engine;
  final int animeBoxesType;
}

final class _BookmarkWithRow {
  const _BookmarkWithRow({required this.bookmark, required this.sourceRow});

  final NormalizedAnimeBoxesBookmark bookmark;
  final int sourceRow;
}

final class _DeduplicatedBookmarks {
  const _DeduplicatedBookmarks(this.bookmarks, this.diagnostics);

  final List<NormalizedAnimeBoxesBookmark> bookmarks;
  final List<AnimeBoxesDiagnostic> diagnostics;
}

const _danbooru = _EngineMapping(
  engine: AnimeBoxesEngine(name: 'danbooru', typeId: 20),
  animeBoxesType: 3,
);
const _gelbooru = _EngineMapping(
  engine: AnimeBoxesEngine(name: 'gelbooru', typeId: 21),
  animeBoxesType: 1,
);
const _gelbooruV2 = _EngineMapping(
  engine: AnimeBoxesEngine(name: 'gelbooruV2', typeId: 23),
  animeBoxesType: 1,
);
const _moebooru = _EngineMapping(
  engine: AnimeBoxesEngine(name: 'moebooru', typeId: 24),
  animeBoxesType: 0,
);

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
