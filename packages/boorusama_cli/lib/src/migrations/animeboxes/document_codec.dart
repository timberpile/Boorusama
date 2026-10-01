import 'dart:convert';

import 'errors.dart';
import 'normalized_types.dart';
import 'sensitive_data.dart';

final class AnimeBoxesDocumentCodec {
  const AnimeBoxesDocumentCodec();

  String encode(NormalizedAnimeBoxesDocument document) =>
      '${const JsonEncoder.withIndent('  ').convert(_encodeDocument(document))}\n';

  NormalizedAnimeBoxesDocument decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      throw const AnimeBoxesFormatException(
        'invalid_normalized_json',
        'The normalized document is not valid JSON.',
      );
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['schema'] != NormalizedAnimeBoxesDocument.schema ||
        decoded['version'] != NormalizedAnimeBoxesDocument.version) {
      throw const AnimeBoxesFormatException(
        'unsupported_normalized_schema',
        'The normalized document schema or version is unsupported.',
      );
    }
    try {
      return _decodeDocument(decoded);
    } on AnimeBoxesFormatException {
      rethrow;
    } catch (_) {
      throw const AnimeBoxesFormatException(
        'invalid_normalized_document',
        'The normalized document is invalid.',
      );
    }
  }
}

Map<String, Object?> _encodeDocument(NormalizedAnimeBoxesDocument document) => {
  'schema': NormalizedAnimeBoxesDocument.schema,
  'version': NormalizedAnimeBoxesDocument.version,
  'source': _encodeSource(document.source),
  'profiles': document.profiles.map(_encodeProfile).toList(),
  'searchHistory': document.searchHistory.map(_encodeHistory).toList(),
  'bookmarks': document.bookmarks.map(_encodeBookmark).toList(),
  'blacklist': document.blacklist.map(_encodeBlacklist).toList(),
  'pinnedSearchFolders': document.pinnedSearchFolders
      .map(_encodePinnedGroup)
      .toList(),
  'diagnostics': document.diagnostics.map(_encodeDiagnostic).toList(),
};

Map<String, Object?> _encodeSource(NormalizedAnimeBoxesSource source) => {
  'formatVersion': source.formatVersion,
  'creatorName': source.creatorName,
  'creatorVersion': source.creatorVersion,
  'exportedAt': source.exportedAt.raw,
};

Map<String, Object?> _encodeProfile(NormalizedAnimeBoxesProfile profile) => {
  'sourceId': profile.sourceId,
  'name': profile.name,
  'url': profile.url,
  'host': profile.host,
  'engine': _encodeEngine(profile.engine),
  'useNativeAutocomplete': profile.useNativeAutocomplete,
  'ratingFilterEnabled': profile.ratingFilterEnabled,
  'selected': profile.selected,
  'isDefault': profile.isDefault,
  'loginPresent': profile.loginPresent,
  'credentialsPresent': profile.credentialsPresent,
  'sourcePosition': profile.sourcePosition,
};

Map<String, Object?> _encodeEngine(AnimeBoxesEngine engine) => {
  'name': engine.name,
  'typeId': engine.typeId,
};

Map<String, Object?> _encodeHistory(
  NormalizedAnimeBoxesHistoryEntry history,
) => {
  'sourceId': history.sourceId,
  'query': history.query,
  'searchedAt': history.searchedAt.raw,
  'starred': history.starred,
  'sourcePosition': history.sourcePosition,
};

Map<String, Object?> _encodeBookmark(NormalizedAnimeBoxesBookmark bookmark) => {
  'sourceProfileId': bookmark.sourceProfileId,
  'host': bookmark.host,
  'engine': _encodeEngine(bookmark.engine),
  'postId': bookmark.postId,
  'postUrl': bookmark.postUrl,
  'media': {
    'preview': _encodeMedia(bookmark.preview),
    'sample': _encodeMedia(bookmark.sample),
    'original': _encodeMedia(bookmark.original),
    'jpeg': bookmark.jpeg == null ? null : _encodeMedia(bookmark.jpeg!),
  },
  'format': bookmark.format,
  'tags': bookmark.tags,
  'generalTags': bookmark.generalTags,
  'artistTags': bookmark.artistTags,
  'characterTags': bookmark.characterTags,
  'copyrightTags': bookmark.copyrightTags,
  'md5': bookmark.md5,
  'source': bookmark.source,
  'parentId': bookmark.parentId,
  'score': bookmark.score,
  'rating': bookmark.rating,
  'isTranslated': bookmark.isTranslated,
  'hasComment': bookmark.hasComment,
  'hasChildren': bookmark.hasChildren,
  'hasParentOrChildren': bookmark.hasParentOrChildren,
  'dateAdded': bookmark.dateAdded.raw,
  'sourcePosition': bookmark.sourcePosition,
};

Map<String, Object?> _encodeMedia(AnimeBoxesMediaVariant media) => {
  'url': media.url,
  'width': media.width,
  'height': media.height,
};

Map<String, Object?> _encodeBlacklist(
  NormalizedAnimeBoxesBlacklistEntry entry,
) => {
  'sourceId': entry.sourceId,
  'rule': entry.rule,
  'sourcePosition': entry.sourcePosition,
};

Map<String, Object?> _encodePinnedGroup(
  NormalizedAnimeBoxesPinnedGroup group,
) => {
  'kind': group.kind,
  'id': group.id,
  'name': group.name,
  'sourcePosition': group.sourcePosition,
  'searches': group.searches.map(_encodePinnedSearch).toList(),
};

Map<String, Object?> _encodePinnedSearch(
  NormalizedAnimeBoxesPinnedSearch search,
) => {
  'id': search.id,
  'sourceProfileId': search.sourceProfileId,
  'name': search.name,
  'query': search.query,
  'position': search.position,
  'url': search.url,
  'host': search.host,
  'engine': _encodeEngine(search.engine),
  'disableAutoLoad': search.disableAutoLoad,
  'includeBlacklisted': search.includeBlacklisted,
  'initialPage': search.initialPage,
  'extraParams': search.extraParams,
};

Map<String, Object?> _encodeDiagnostic(AnimeBoxesDiagnostic diagnostic) => {
  'code': diagnostic.code,
  'count': diagnostic.count,
  'section': diagnostic.section,
  'row': diagnostic.row,
  'sourcePositions': diagnostic.sourcePositions,
};

NormalizedAnimeBoxesDocument _decodeDocument(
  Map<String, dynamic> json,
) {
  const rootKeys = {
    'schema',
    'version',
    'source',
    'profiles',
    'searchHistory',
    'bookmarks',
    'blacklist',
    'pinnedSearchFolders',
    'diagnostics',
  };
  _requireExactKeys(json, rootKeys, r'$');

  final source = _decodeSource(
    _object(json['source'], r'$.source'),
    r'$.source',
  );
  final profiles = _decodeList(
    json['profiles'],
    r'$.profiles',
    _decodeProfile,
  );
  final history = _decodeList(
    json['searchHistory'],
    r'$.searchHistory',
    _decodeHistory,
  );
  final bookmarks = _decodeList(
    json['bookmarks'],
    r'$.bookmarks',
    _decodeBookmark,
  );
  final blacklist = _decodeList(
    json['blacklist'],
    r'$.blacklist',
    _decodeBlacklist,
  );
  final groups = _decodeList(
    json['pinnedSearchFolders'],
    r'$.pinnedSearchFolders',
    _decodePinnedGroup,
  );
  final diagnostics = _decodeList(
    json['diagnostics'],
    r'$.diagnostics',
    _decodeDiagnostic,
  );

  _validateRelationships(profiles, bookmarks, groups);
  return NormalizedAnimeBoxesDocument(
    source: source,
    profiles: profiles,
    searchHistory: history,
    bookmarks: bookmarks,
    blacklist: blacklist,
    pinnedSearchFolders: groups,
    diagnostics: diagnostics,
  );
}

NormalizedAnimeBoxesSource _decodeSource(
  Map<String, dynamic> json,
  String path,
) {
  _requireExactKeys(json, const {
    'formatVersion',
    'creatorName',
    'creatorVersion',
    'exportedAt',
  }, path);
  return NormalizedAnimeBoxesSource(
    formatVersion: _nonEmptyString(
      json['formatVersion'],
      '$path.formatVersion',
    ),
    creatorName: _nonEmptyString(json['creatorName'], '$path.creatorName'),
    creatorVersion: _nonEmptyString(
      json['creatorVersion'],
      '$path.creatorVersion',
    ),
    exportedAt: _timestamp(json['exportedAt'], '$path.exportedAt'),
  );
}

NormalizedAnimeBoxesProfile _decodeProfile(
  Map<String, dynamic> json,
  String path,
) {
  _requireExactKeys(json, const {
    'sourceId',
    'name',
    'url',
    'host',
    'engine',
    'useNativeAutocomplete',
    'ratingFilterEnabled',
    'selected',
    'isDefault',
    'loginPresent',
    'credentialsPresent',
    'sourcePosition',
  }, path);
  final url = _url(json['url'], '$path.url');
  final host = _host(json['host'], '$path.host');
  if (Uri.parse(url).host != host) _invalid('$path.host');
  return NormalizedAnimeBoxesProfile(
    sourceId: _nonNegativeInteger(json['sourceId'], '$path.sourceId'),
    name: _nonEmptyString(json['name'], '$path.name'),
    url: url,
    host: host,
    engine: _decodeEngine(
      _object(json['engine'], '$path.engine'),
      '$path.engine',
    ),
    useNativeAutocomplete: _boolean(
      json['useNativeAutocomplete'],
      '$path.useNativeAutocomplete',
    ),
    ratingFilterEnabled: _boolean(
      json['ratingFilterEnabled'],
      '$path.ratingFilterEnabled',
    ),
    selected: _boolean(json['selected'], '$path.selected'),
    isDefault: _boolean(json['isDefault'], '$path.isDefault'),
    loginPresent: _boolean(json['loginPresent'], '$path.loginPresent'),
    credentialsPresent: _boolean(
      json['credentialsPresent'],
      '$path.credentialsPresent',
    ),
    sourcePosition: _nonNegativeInteger(
      json['sourcePosition'],
      '$path.sourcePosition',
    ),
  );
}

AnimeBoxesEngine _decodeEngine(Map<String, dynamic> json, String path) {
  _requireExactKeys(json, const {'name', 'typeId'}, path);
  final name = _nonEmptyString(json['name'], '$path.name');
  final typeId = _nonNegativeInteger(json['typeId'], '$path.typeId');
  if (_engineTypeIds[name] != typeId) _invalid(path);
  return AnimeBoxesEngine(name: name, typeId: typeId);
}

NormalizedAnimeBoxesHistoryEntry _decodeHistory(
  Map<String, dynamic> json,
  String path,
) {
  _requireExactKeys(json, const {
    'sourceId',
    'query',
    'searchedAt',
    'starred',
    'sourcePosition',
  }, path);
  return NormalizedAnimeBoxesHistoryEntry(
    sourceId: _nonNegativeInteger(json['sourceId'], '$path.sourceId'),
    query: _string(json['query'], '$path.query'),
    searchedAt: _timestamp(json['searchedAt'], '$path.searchedAt'),
    starred: _boolean(json['starred'], '$path.starred'),
    sourcePosition: _nonNegativeInteger(
      json['sourcePosition'],
      '$path.sourcePosition',
    ),
  );
}

NormalizedAnimeBoxesBookmark _decodeBookmark(
  Map<String, dynamic> json,
  String path,
) {
  _requireExactKeys(json, const {
    'sourceProfileId',
    'host',
    'engine',
    'postId',
    'postUrl',
    'media',
    'format',
    'tags',
    'generalTags',
    'artistTags',
    'characterTags',
    'copyrightTags',
    'md5',
    'source',
    'parentId',
    'score',
    'rating',
    'isTranslated',
    'hasComment',
    'hasChildren',
    'hasParentOrChildren',
    'dateAdded',
    'sourcePosition',
  }, path);
  final media = _object(json['media'], '$path.media');
  _requireExactKeys(media, const {
    'preview',
    'sample',
    'original',
    'jpeg',
  }, '$path.media');
  final host = _host(json['host'], '$path.host');
  final postUrl = _url(json['postUrl'], '$path.postUrl');
  if (Uri.parse(postUrl).host != host) _invalid('$path.host');
  final parentId = _optionalPositiveInteger(json['parentId'], '$path.parentId');
  final hasChildren = _boolean(json['hasChildren'], '$path.hasChildren');
  final hasParentOrChildren = _boolean(
    json['hasParentOrChildren'],
    '$path.hasParentOrChildren',
  );
  if (hasParentOrChildren != (hasChildren || parentId != null)) {
    _invalid('$path.hasParentOrChildren');
  }
  final format = _nonEmptyString(json['format'], '$path.format');
  if (!RegExp(r'^[a-z0-9]+$').hasMatch(format)) _invalid('$path.format');
  final md5 = _nonEmptyString(json['md5'], '$path.md5');
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(md5)) _invalid('$path.md5');
  final rating = _nonEmptyString(json['rating'], '$path.rating');
  if (!_ratings.contains(rating)) _invalid('$path.rating');

  return NormalizedAnimeBoxesBookmark(
    sourceProfileId: _nonNegativeInteger(
      json['sourceProfileId'],
      '$path.sourceProfileId',
    ),
    host: host,
    engine: _decodeEngine(
      _object(json['engine'], '$path.engine'),
      '$path.engine',
    ),
    postId: _positiveInteger(json['postId'], '$path.postId'),
    postUrl: postUrl,
    preview: _decodeMedia(
      _object(media['preview'], '$path.media.preview'),
      '$path.media.preview',
    ),
    sample: _decodeMedia(
      _object(media['sample'], '$path.media.sample'),
      '$path.media.sample',
    ),
    original: _decodeMedia(
      _object(media['original'], '$path.media.original'),
      '$path.media.original',
    ),
    jpeg: media['jpeg'] == null
        ? null
        : _decodeMedia(
            _object(media['jpeg'], '$path.media.jpeg'),
            '$path.media.jpeg',
          ),
    format: format,
    tags: _strings(json['tags'], '$path.tags'),
    generalTags: _strings(json['generalTags'], '$path.generalTags'),
    artistTags: _strings(json['artistTags'], '$path.artistTags'),
    characterTags: _strings(json['characterTags'], '$path.characterTags'),
    copyrightTags: _strings(json['copyrightTags'], '$path.copyrightTags'),
    md5: md5,
    source: _optionalString(json['source'], '$path.source'),
    parentId: parentId,
    score: _integer(json['score'], '$path.score'),
    rating: rating,
    isTranslated: _boolean(json['isTranslated'], '$path.isTranslated'),
    hasComment: _boolean(json['hasComment'], '$path.hasComment'),
    hasChildren: hasChildren,
    hasParentOrChildren: hasParentOrChildren,
    dateAdded: _timestamp(json['dateAdded'], '$path.dateAdded'),
    sourcePosition: _nonNegativeInteger(
      json['sourcePosition'],
      '$path.sourcePosition',
    ),
  );
}

AnimeBoxesMediaVariant _decodeMedia(
  Map<String, dynamic> json,
  String path,
) {
  _requireExactKeys(json, const {'url', 'width', 'height'}, path);
  return AnimeBoxesMediaVariant(
    url: _url(json['url'], '$path.url'),
    width: _nonNegativeInteger(json['width'], '$path.width'),
    height: _nonNegativeInteger(json['height'], '$path.height'),
  );
}

NormalizedAnimeBoxesBlacklistEntry _decodeBlacklist(
  Map<String, dynamic> json,
  String path,
) {
  _requireExactKeys(json, const {'sourceId', 'rule', 'sourcePosition'}, path);
  return NormalizedAnimeBoxesBlacklistEntry(
    sourceId: _nonNegativeInteger(json['sourceId'], '$path.sourceId'),
    rule: _nonEmptyString(json['rule'], '$path.rule'),
    sourcePosition: _nonNegativeInteger(
      json['sourcePosition'],
      '$path.sourcePosition',
    ),
  );
}

NormalizedAnimeBoxesPinnedGroup _decodePinnedGroup(
  Map<String, dynamic> json,
  String path,
) {
  _requireExactKeys(json, const {
    'kind',
    'id',
    'name',
    'sourcePosition',
    'searches',
  }, path);
  final kind = _nonEmptyString(json['kind'], '$path.kind');
  final searches = _decodeList(
    json['searches'],
    '$path.searches',
    _decodePinnedSearch,
  );
  final sourcePosition = _nonNegativeInteger(
    json['sourcePosition'],
    '$path.sourcePosition',
  );
  return switch (kind) {
    'folder' => NormalizedAnimeBoxesPinnedGroup.folder(
      id: _uuid(json['id'], '$path.id'),
      name: _string(json['name'], '$path.name'),
      sourcePosition: sourcePosition,
      searches: searches,
    ),
    'home' when json['id'] == null && json['name'] == null =>
      NormalizedAnimeBoxesPinnedGroup.home(
        sourcePosition: sourcePosition,
        searches: searches,
      ),
    _ => _invalid(path),
  };
}

NormalizedAnimeBoxesPinnedSearch _decodePinnedSearch(
  Map<String, dynamic> json,
  String path,
) {
  _requireExactKeys(json, const {
    'id',
    'sourceProfileId',
    'name',
    'query',
    'position',
    'url',
    'host',
    'engine',
    'disableAutoLoad',
    'includeBlacklisted',
    'initialPage',
    'extraParams',
  }, path);
  final url = _url(json['url'], '$path.url');
  final host = _host(json['host'], '$path.host');
  if (Uri.parse(url).host != host) _invalid('$path.host');
  final extraParams = _object(json['extraParams'], '$path.extraParams');
  _validateJsonTree(extraParams, '$path.extraParams');
  final name = _optionalString(json['name'], '$path.name');
  if (name != null && name.isEmpty) _invalid('$path.name');
  return NormalizedAnimeBoxesPinnedSearch(
    id: _uuid(json['id'], '$path.id'),
    sourceProfileId: _nonNegativeInteger(
      json['sourceProfileId'],
      '$path.sourceProfileId',
    ),
    name: name,
    query: _string(json['query'], '$path.query'),
    position: _nonNegativeInteger(json['position'], '$path.position'),
    url: url,
    host: host,
    engine: _decodeEngine(
      _object(json['engine'], '$path.engine'),
      '$path.engine',
    ),
    disableAutoLoad: _boolean(
      json['disableAutoLoad'],
      '$path.disableAutoLoad',
    ),
    includeBlacklisted: _boolean(
      json['includeBlacklisted'],
      '$path.includeBlacklisted',
    ),
    initialPage: _nonNegativeInteger(json['initialPage'], '$path.initialPage'),
    extraParams: Map<String, Object?>.from(extraParams),
  );
}

AnimeBoxesDiagnostic _decodeDiagnostic(
  Map<String, dynamic> json,
  String path,
) {
  _requireExactKeys(json, const {
    'code',
    'count',
    'section',
    'row',
    'sourcePositions',
  }, path);
  final code = _nonEmptyString(json['code'], '$path.code');
  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(code)) _invalid('$path.code');
  final row = _optionalPositiveInteger(json['row'], '$path.row');
  final sourcePositions = _integers(
    json['sourcePositions'],
    '$path.sourcePositions',
    minimum: 0,
  );
  return AnimeBoxesDiagnostic(
    code: code,
    count: _nonNegativeInteger(json['count'], '$path.count'),
    section: _optionalString(json['section'], '$path.section'),
    row: row,
    sourcePositions: sourcePositions,
  );
}

void _validateRelationships(
  List<NormalizedAnimeBoxesProfile> profiles,
  List<NormalizedAnimeBoxesBookmark> bookmarks,
  List<NormalizedAnimeBoxesPinnedGroup> groups,
) {
  final profilesById = <int, NormalizedAnimeBoxesProfile>{};
  for (var index = 0; index < profiles.length; index++) {
    final profile = profiles[index];
    if (profilesById.putIfAbsent(profile.sourceId, () => profile) != profile) {
      _invalid(r'$.profiles');
    }
  }

  final bookmarkIdentities = <(String, int)>{};
  for (var index = 0; index < bookmarks.length; index++) {
    final bookmark = bookmarks[index];
    final path = '\$.bookmarks[$index]';
    final profile = profilesById[bookmark.sourceProfileId];
    if (profile == null ||
        profile.host != bookmark.host ||
        !_sameEngine(profile.engine, bookmark.engine)) {
      _invalid('$path.sourceProfileId');
    }
    if (!bookmarkIdentities.add((bookmark.host, bookmark.postId))) {
      _invalid(path);
    }
  }

  final folderIds = <String>{};
  final searchIds = <String>{};
  var homeCount = 0;
  for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
    final group = groups[groupIndex];
    final groupPath = '\$.pinnedSearchFolders[$groupIndex]';
    if (group.kind == 'home') {
      homeCount++;
      if (homeCount > 1) _invalid(groupPath);
    } else if (!folderIds.add(group.id!)) {
      _invalid('$groupPath.id');
    }
    for (
      var searchIndex = 0;
      searchIndex < group.searches.length;
      searchIndex++
    ) {
      final search = group.searches[searchIndex];
      final path = '$groupPath.searches[$searchIndex]';
      if (!searchIds.add(search.id)) _invalid('$path.id');
      final profile = profilesById[search.sourceProfileId];
      if (profile == null ||
          profile.host != search.host ||
          !_sameEngine(profile.engine, search.engine)) {
        _invalid('$path.sourceProfileId');
      }
    }
  }
}

bool _sameEngine(AnimeBoxesEngine left, AnimeBoxesEngine right) =>
    left.name == right.name && left.typeId == right.typeId;

List<T> _decodeList<T>(
  Object? value,
  String path,
  T Function(Map<String, dynamic>, String) decode,
) {
  final list = _list(value, path);
  return [
    for (var index = 0; index < list.length; index++)
      decode(_object(list[index], '$path[$index]'), '$path[$index]'),
  ];
}

Map<String, dynamic> _object(Object? value, String path) {
  if (value is! Map<String, dynamic>) _invalid(path);
  return value;
}

List<dynamic> _list(Object? value, String path) {
  if (value is! List<dynamic>) _invalid(path);
  return value;
}

void _requireExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
  String path,
) {
  if (json.length != expected.length || !json.keys.every(expected.contains)) {
    _invalid(path);
  }
}

String _string(Object? value, String path) {
  if (value is! String) _invalid(path);
  return value;
}

String _nonEmptyString(Object? value, String path) {
  final result = _string(value, path);
  if (result.isEmpty) _invalid(path);
  return result;
}

String? _optionalString(Object? value, String path) => switch (value) {
  null => null,
  String() => value,
  _ => _invalid(path),
};

int _integer(Object? value, String path) {
  if (value is! int) _invalid(path);
  return value;
}

int _nonNegativeInteger(Object? value, String path) {
  final result = _integer(value, path);
  if (result < 0) _invalid(path);
  return result;
}

int _positiveInteger(Object? value, String path) {
  final result = _integer(value, path);
  if (result < 1) _invalid(path);
  return result;
}

int? _optionalPositiveInteger(Object? value, String path) => switch (value) {
  null => null,
  int() when value > 0 => value,
  _ => _invalid(path),
};

bool _boolean(Object? value, String path) {
  if (value is! bool) _invalid(path);
  return value;
}

AnimeBoxesTimestamp _timestamp(Object? value, String path) {
  final raw = _string(value, path);
  if (!_timestampPattern.hasMatch(raw)) _invalid(path);
  try {
    return AnimeBoxesTimestamp.parse(raw);
  } on FormatException {
    _invalid(path);
  }
}

String _url(Object? value, String path) {
  final raw = _nonEmptyString(value, path);
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !uri.isAbsolute ||
      !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    _invalid(path);
  }
  return raw;
}

String _host(Object? value, String path) {
  final host = _nonEmptyString(value, path);
  if (host != host.trim().toLowerCase() ||
      !RegExp(r'^[a-z0-9.-]+$').hasMatch(host) ||
      host.startsWith('.') ||
      host.endsWith('.')) {
    _invalid(path);
  }
  return host;
}

String _uuid(Object? value, String path) {
  final result = _nonEmptyString(value, path);
  if (!_uuidPattern.hasMatch(result)) _invalid(path);
  return result;
}

List<String> _strings(Object? value, String path) {
  final list = _list(value, path);
  return [
    for (var index = 0; index < list.length; index++)
      _string(list[index], '$path[$index]'),
  ];
}

List<int> _integers(Object? value, String path, {required int minimum}) {
  final list = _list(value, path);
  return [
    for (var index = 0; index < list.length; index++)
      _boundedInteger(list[index], '$path[$index]', minimum),
  ];
}

int _boundedInteger(Object? value, String path, int minimum) {
  final result = _integer(value, path);
  if (result < minimum) _invalid(path);
  return result;
}

void _validateJsonTree(Object? value, String path) {
  switch (value) {
    case null || bool() || num() || String():
      return;
    case List<dynamic>():
      for (var index = 0; index < value.length; index++) {
        _validateJsonTree(value[index], '$path[$index]');
      }
    case Map<String, dynamic>():
      for (final entry in value.entries) {
        if (isSensitiveAnimeBoxesKey(entry.key)) {
          _invalid(path);
        }
        _validateJsonTree(entry.value, '$path.${entry.key}');
      }
    default:
      _invalid(path);
  }
}

Never _invalid(String path) => throw AnimeBoxesFormatException(
  'invalid_normalized_document',
  'The normalized document is invalid.',
  section: path,
);

const _engineTypeIds = {
  'danbooru': 20,
  'gelbooru': 21,
  'gelbooruV2': 23,
  'moebooru': 24,
};

const _ratings = {
  'unknown',
  'explicit',
  'questionable',
  'sensitive',
  'general',
};

final _timestampPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:?\d{2})$',
);
final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
