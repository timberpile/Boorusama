import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'conversion_report.dart';
import 'errors.dart';
import 'migration_package.dart';
import 'normalized_types.dart';
import 'site_identity.dart';

final class BoorusamaMigrationArtifacts {
  const BoorusamaMigrationArtifacts({
    required this.bookmarks,
    required this.blacklistedTags,
    required this.pinnedSearches,
    required this.report,
  });

  final String bookmarks;
  final String blacklistedTags;
  final String pinnedSearches;
  final String report;

  List<int> get packageBytes => encodeMigrationPackage(
    bookmarks: bookmarks,
    blacklistedTags: blacklistedTags,
    pinnedSearches: pinnedSearches,
  );
}

final class BoorusamaMigrationExporter {
  const BoorusamaMigrationExporter();

  BoorusamaMigrationArtifacts export(NormalizedAnimeBoxesDocument document) {
    _validateBookmarkIdentities(document);
    final pinned = _encodePinnedSearches(document);
    final report = AnimeBoxesConversionReport.fromDocument(
      document,
      outputDiagnostics: pinned.diagnostics,
    );
    return BoorusamaMigrationArtifacts(
      bookmarks: _prettyJson(_bookmarkEnvelope(document)),
      blacklistedTags: _prettyJson(_blacklistEnvelope(document)),
      pinnedSearches: _prettyJson(pinned.envelope),
      report: _prettyJson(report.toJson()),
    );
  }
}

void _validateBookmarkIdentities(
  NormalizedAnimeBoxesDocument document,
) {
  final identities = <(String, int)>{};
  for (final bookmark in document.bookmarks) {
    if (!identities.add((_bookmarkSite(bookmark, document), bookmark.postId))) {
      throw const AnimeBoxesFormatException(
        'duplicate_bookmark_output_identity',
        'Bookmarks repeat a Boorusama output identity.',
        section: 'Favorites',
      );
    }
  }
}

String _bookmarkSite(
  NormalizedAnimeBoxesBookmark bookmark,
  NormalizedAnimeBoxesDocument document,
) {
  final profile = document.profiles
      .where(
        (profile) => profile.sourceId == bookmark.sourceProfileId,
      )
      .singleOrNull;
  if (profile == null ||
      profile.host != bookmark.host ||
      profile.engine.typeId != bookmark.engine.typeId ||
      migrationSiteNamespace(profile.url) !=
          migrationSiteNamespace(bookmark.postUrl, includePath: false)) {
    throw const AnimeBoxesFormatException(
      'invalid_profile_reference',
      'A bookmark has an invalid profile reference.',
      section: 'Favorites',
    );
  }
  return migrationSiteNamespace(profile.url);
}

Map<String, Object?> _bookmarkEnvelope(
  NormalizedAnimeBoxesDocument document,
) => {
  'groups': [
    {
      'id': const Uuid().v5(
        migrationUuidNamespace,
        jsonEncode([
          'bookmark-group',
          for (final bookmark in document.bookmarks)
            [_bookmarkSite(bookmark, document), bookmark.postId],
        ]),
      ),
      'name': 'AnimeBoxes',
      'bookmarkIds': [
        for (final (index, _) in document.bookmarks.indexed) index + 1,
      ],
    },
  ],
  'version': 4,
  'date': document.source.exportedAt.raw,
  'data': [
    for (final (index, bookmark) in document.bookmarks.indexed)
      {
        'localId': index + 1,
        'createdAt': bookmark.dateAdded.raw,
        'updatedAt': bookmark.dateAdded.raw,
        'snapshot': _bookmarkSnapshot(
          bookmark,
          _bookmarkSite(bookmark, document),
        ),
        'postId': bookmark.postId,
        'identity': {
          'site': _bookmarkSite(bookmark, document),
          'postKey': 'id:${bookmark.postId}',
        },
      },
  ],
};

Map<String, Object?> _bookmarkSnapshot(
  NormalizedAnimeBoxesBookmark bookmark,
  String site,
) {
  final isVideo = const {'mp4', 'webm', 'zip'}.contains(bookmark.format);
  return {
    'origin': {
      'booruTypeId': bookmark.engine.typeId,
      'booruId': bookmark.engine.typeId,
      'sourceHost': site,
    },
    'common': {
      'schemaVersion': 1,
      'id': bookmark.postId,
      'thumbnailImageUrl': bookmark.preview.url,
      'sampleImageUrl': bookmark.sample.url,
      'originalImageUrl': bookmark.original.url,
      'videoUrl': isVideo ? bookmark.original.url : '',
      'videoThumbnailUrl': isVideo ? bookmark.preview.url : '',
      'width': bookmark.original.width,
      'height': bookmark.original.height,
      'format': bookmark.format,
      'md5': bookmark.md5,
      'fileSize': 0,
      'duration': -1.0,
      'tags': bookmark.tags,
      if (bookmark.artistTags.isNotEmpty) 'artistTags': bookmark.artistTags,
      if (bookmark.characterTags.isNotEmpty)
        'characterTags': bookmark.characterTags,
      if (bookmark.copyrightTags.isNotEmpty)
        'copyrightTags': bookmark.copyrightTags,
      'rating': bookmark.rating,
      'hasComment': bookmark.hasComment,
      'isTranslated': bookmark.isTranslated,
      'hasParentOrChildren': bookmark.hasParentOrChildren,
      'parentId': ?bookmark.parentId,
      'source': _postSource(bookmark.source),
      'score': bookmark.score,
    },
    'custom': const {},
    'codecVersion': 1,
  };
}

Map<String, Object?> _postSource(String? source) {
  if (source == null || source.isEmpty) return const {'kind': 'none'};
  final uri = Uri.tryParse(source);
  if (uri != null &&
      uri.isAbsolute &&
      const {'http', 'https'}.contains(uri.scheme.toLowerCase()) &&
      uri.host.isNotEmpty) {
    return {'kind': 'web', 'url': source};
  }
  return {'kind': 'nonWeb', 'value': source};
}

Map<String, Object?> _blacklistEnvelope(
  NormalizedAnimeBoxesDocument document,
) => {
  'version': 1,
  'date': document.source.exportedAt.raw,
  'data': [
    for (final (index, entry) in document.blacklist.indexed)
      {
        'id': index + 1,
        'name': entry.rule,
        'isActive': true,
        'createdDate': document.source.exportedAt.raw,
        'updatedDate': document.source.exportedAt.raw,
      },
  ],
};

_PinnedExport _encodePinnedSearches(NormalizedAnimeBoxesDocument document) {
  final profiles = {
    for (final profile in document.profiles) profile.sourceId: profile,
  };
  final folders = document.pinnedSearchFolders
      .where((group) => group.kind == 'folder')
      .toList();
  final home = document.pinnedSearchFolders
      .where((group) => group.kind == 'home')
      .toList();
  final diagnostics = <AnimeBoxesDiagnostic>[];
  final folderNames = _exportFolderNames(folders);
  if (folderNames.changedCount > 0) {
    diagnostics.add(
      AnimeBoxesDiagnostic(
        code: 'folder_names_normalized_for_export',
        count: folderNames.changedCount,
        section: 'Home Pins',
        sourcePositions: [
          for (var index = 0; index < folders.length; index++)
            if (folders[index].name != folderNames.names[index])
              folders[index].sourcePosition,
        ],
      ),
    );
  }
  final allSearches = [
    for (final group in document.pinnedSearchFolders) ...group.searches,
  ]..sort((left, right) => left.position.compareTo(right.position));
  final effectiveQueries = {
    for (final search in allSearches)
      search.id: _effectivePinnedSearchQuery(search),
  };
  final identities = <(int, String)>{};
  final repeatedPositions = <int>[];
  for (final search in allSearches) {
    final query = effectiveQueries[search.id]!.split(RegExp(r'\s+')).join(' ');
    if (!identities.add((search.sourceProfileId, query))) {
      repeatedPositions.add(search.position);
    }
  }
  if (repeatedPositions.isNotEmpty) {
    diagnostics.add(
      AnimeBoxesDiagnostic(
        code: 'duplicate_pinned_query_identity',
        count: repeatedPositions.length,
        section: 'Home Pins',
        sourcePositions: repeatedPositions,
      ),
    );
  }
  final searchesWithUnsupportedSettings = allSearches
      .where(
        (search) =>
            search.disableAutoLoad ||
            search.includeBlacklisted ||
            search.initialPage != 0 ||
            search.extraParams.keys.any((key) => key != 'extra_tags'),
      )
      .toList();
  if (searchesWithUnsupportedSettings.isNotEmpty) {
    diagnostics.add(
      AnimeBoxesDiagnostic(
        code: 'pinned_search_settings_not_exported',
        count: searchesWithUnsupportedSettings.length,
        section: 'Home Pins',
        sourcePositions: [
          for (final search in searchesWithUnsupportedSettings) search.position,
        ],
      ),
    );
  }

  return _PinnedExport(
    envelope: {
      'source': 'pinned_searches',
      'version': 1,
      'date': document.source.exportedAt.raw,
      'data': [
        for (final (index, folder) in folders.indexed)
          {
            'kind': 'folder',
            'id': folder.id,
            'name': folderNames.names[index],
            'position': index,
            'searchIds': [for (final search in folder.searches) search.id],
          },
        for (final search in allSearches)
          {
            'kind': 'search',
            'id': search.id,
            'name': search.name,
            'query': effectiveQueries[search.id],
            'position': search.position,
            'profile': _profileReference(search, profiles),
          },
        {
          'kind': 'organization',
          'homeSearchIds': [
            for (final group in home)
              for (final search in group.searches) search.id,
          ],
        },
      ],
    },
    diagnostics: diagnostics,
  );
}

String _effectivePinnedSearchQuery(NormalizedAnimeBoxesPinnedSearch search) {
  final extraTags = search.extraParams['extra_tags'];
  if (search.extraParams.containsKey('extra_tags') && extraTags is! String) {
    throw const AnimeBoxesFormatException(
      'invalid_pinned_search_extra_tags',
      'Pinned-search extra tags must be text.',
      section: 'Home Pins',
    );
  }
  // AnimeBoxes appends this already-combined filter text, not its UI selectors.
  final query = switch (extraTags) {
    final String tags when tags.trim().isNotEmpty =>
      '${search.query} $tags'.trim(),
    _ => search.query.trim(),
  };
  if (query.isEmpty) {
    throw const AnimeBoxesFormatException(
      'empty_pinned_search_query',
      'A pinned search query cannot be exported.',
      section: 'Home Pins',
    );
  }
  return query;
}

Map<String, Object?> _profileReference(
  NormalizedAnimeBoxesPinnedSearch search,
  Map<int, NormalizedAnimeBoxesProfile> profiles,
) {
  final profile = profiles[search.sourceProfileId];
  if (profile == null ||
      profile.host != search.host ||
      profile.engine.name != search.engine.name ||
      profile.engine.typeId != search.engine.typeId ||
      migrationSiteNamespace(profile.url) !=
          migrationSiteNamespace(search.url)) {
    throw const AnimeBoxesFormatException(
      'invalid_profile_reference',
      'A pinned search has an invalid profile reference.',
      section: 'Home Pins',
    );
  }
  return {
    'id': const Uuid().v5(
      migrationUuidNamespace,
      jsonEncode([
        'profile',
        profile.sourceId,
        profile.engine.name,
        migrationProfileUrl(profile.url),
      ]),
    ),
    'booruType': profile.engine.name,
    'url': migrationProfileUrl(profile.url),
    'name': profile.name,
  };
}

_FolderNames _exportFolderNames(
  List<NormalizedAnimeBoxesPinnedGroup> folders,
) {
  final names = <String>[];
  final used = <String>{};
  var changedCount = 0;
  for (var index = 0; index < folders.length; index++) {
    final original = folders[index].name!;
    final base = original.trim().isEmpty
        ? 'Imported folder ${index + 1}'
        : original.trim();
    var name = base;
    var suffix = 2;
    while (!used.add(name.toLowerCase())) {
      name = '$base ($suffix)';
      suffix++;
    }
    if (name != original) changedCount++;
    names.add(name);
  }
  return _FolderNames(names, changedCount);
}

String _prettyJson(Object? value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

final class _PinnedExport {
  const _PinnedExport({required this.envelope, required this.diagnostics});

  final Map<String, Object?> envelope;
  final List<AnimeBoxesDiagnostic> diagnostics;
}

final class _FolderNames {
  const _FolderNames(this.names, this.changedCount);

  final List<String> names;
  final int changedCount;
}
