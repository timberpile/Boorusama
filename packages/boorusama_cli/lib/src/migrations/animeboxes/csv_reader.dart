import 'dart:convert';

import 'package:csv/csv.dart';

import 'errors.dart';
import 'source_types.dart';

const _sectionWidths = <String, int>{
  '#Meta': 10,
  '#Servers': 19,
  '#History': 10,
  '#Favorites': 39,
  '#Tag Blacklist': 8,
  '#Home Pins': 11,
};

final class AnimeBoxesCsvReader {
  const AnimeBoxesCsvReader();

  AnimeBoxesExport parse(String csvText) {
    final rows = _decode(csvText);
    final sections = _collectSections(rows);

    for (final section in _sectionWidths.keys) {
      if (!sections.containsKey(section)) {
        throw AnimeBoxesFormatException(
          'missing_section',
          'A required section is missing.',
          section: _displaySection(section),
        );
      }
    }

    for (final entry in sections.entries) {
      final expectedWidth = _sectionWidths[entry.key]!;
      for (final row in entry.value) {
        if (row.cells.length != expectedWidth) {
          throw AnimeBoxesFormatException(
            'invalid_row_width',
            'A row has an unexpected number of columns.',
            section: _displaySection(entry.key),
            row: row.sourceRow,
          );
        }
      }
    }

    final metadataRows = sections['#Meta']!;
    if (metadataRows.length != 1) {
      throw const AnimeBoxesFormatException(
        'invalid_metadata_count',
        'The Meta section must contain one row.',
        section: 'Meta',
      );
    }

    final metadata = _parseMetadata(metadataRows.single);
    final servers = <AnimeBoxesServer>[];
    for (final (position, row) in sections['#Servers']!.indexed) {
      servers.add(_parseServer(row, position));
    }
    final history = <AnimeBoxesHistoryEntry>[];
    for (final (position, row) in sections['#History']!.indexed) {
      history.add(_parseHistory(row, position));
    }
    final favorites = <AnimeBoxesFavorite>[];
    for (final (position, row) in sections['#Favorites']!.indexed) {
      favorites.add(_parseFavorite(row, position));
    }
    final blacklist = <AnimeBoxesBlacklistEntry>[];
    for (final (position, row) in sections['#Tag Blacklist']!.indexed) {
      blacklist.add(_parseBlacklist(row, position));
    }

    final folders = <AnimeBoxesPinFolder>[];
    final pinnedSearches = <AnimeBoxesPinnedSearch>[];
    for (final (position, row) in sections['#Home Pins']!.indexed) {
      _requireRowType(row, '4', 'Home Pins');
      final query = _parseSourceQuery(row);
      switch (_integer(row, 4, 'pin type', 'Home Pins')) {
        case 4:
          _requireEmpty(row, [1, 3], 'Home Pins');
          folders.add(
            AnimeBoxesPinFolder(
              id: _requiredString(row, 2, 'folder ID', 'Home Pins'),
              // Type-4 folder labels are stored in text, unlike search titles.
              name: query.text,
              query: query.text,
              disableAutoLoad: query.disableAutoLoad,
              includeBlacklisted: query.includeBlacklisted,
              initialPage: query.initialPage,
              extraParams: query.extraParams,
              sourceRow: row.sourceRow,
              sourcePosition: position,
            ),
          );
        case 3:
          pinnedSearches.add(
            AnimeBoxesPinnedSearch(
              folderId: _cell(row, 1),
              id: _requiredString(row, 2, 'search ID', 'Home Pins'),
              url: _url(row, 3, 'site URL', 'Home Pins'),
              name: query.title,
              query: query.text,
              disableAutoLoad: query.disableAutoLoad,
              includeBlacklisted: query.includeBlacklisted,
              initialPage: query.initialPage,
              extraParams: query.extraParams,
              sourceRow: row.sourceRow,
              sourcePosition: position,
            ),
          );
        default:
          throw AnimeBoxesFormatException(
            'invalid_pin_type',
            'The pin type is unsupported.',
            section: 'Home Pins',
            row: row.sourceRow,
          );
      }
      _requireEmpty(row, [6, 7, 8, 9, 10], 'Home Pins');
    }

    return AnimeBoxesExport(
      metadata: metadata,
      servers: List.unmodifiable(servers),
      history: List.unmodifiable(history),
      favorites: List.unmodifiable(favorites),
      blacklist: List.unmodifiable(blacklist),
      folders: List.unmodifiable(folders),
      pinnedSearches: List.unmodifiable(pinnedSearches),
    );
  }
}

List<List<dynamic>> _decode(String source) {
  if (source.isEmpty) {
    throw const AnimeBoxesFormatException(
      'empty_export',
      'The export contains no rows.',
    );
  }
  try {
    return Csv(autoDetect: false).decode(source);
  } catch (_) {
    throw const AnimeBoxesFormatException(
      'invalid_csv',
      'The source is not valid CSV.',
    );
  }
}

Map<String, List<_SourceRow>> _collectSections(List<List<dynamic>> rows) {
  final sections = <String, List<_SourceRow>>{};
  String? current;
  for (final (index, cells) in rows.indexed) {
    if (cells.isEmpty) continue;
    final first = _rawCell(cells.first);
    final marker = index == 0 && first.startsWith('\ufeff')
        ? first.substring(1)
        : first;
    if (marker.startsWith('#')) {
      if (cells.length != 1 || !_sectionWidths.containsKey(marker)) {
        throw AnimeBoxesFormatException(
          'unknown_section',
          'The export contains an unknown section.',
          row: index + 1,
        );
      }
      if (sections.containsKey(marker)) {
        throw AnimeBoxesFormatException(
          'repeated_section',
          'A section is repeated.',
          section: _displaySection(marker),
          row: index + 1,
        );
      }
      current = marker;
      sections[marker] = [];
      continue;
    }
    if (current == null) {
      throw AnimeBoxesFormatException(
        'row_before_section',
        'A data row appears before the first section.',
        row: index + 1,
      );
    }
    sections[current]!.add(_SourceRow(cells, index + 1));
  }
  return sections;
}

AnimeBoxesMetadata _parseMetadata(_SourceRow row) {
  _requireRowType(row, '5', 'Meta');
  final formatVersion = _requiredString(row, 1, 'format version', 'Meta');
  final creatorName = _requiredString(row, 2, 'creator', 'Meta');
  if (formatVersion != '1.0' || creatorName != 'Anime boxes (Android)') {
    throw AnimeBoxesFormatException(
      'unsupported_format',
      'Only AnimeBoxes Android export format 1.0 is supported.',
      section: 'Meta',
      row: row.sourceRow,
    );
  }
  _requireEmpty(row, [5, 6, 7, 8, 9], 'Meta');
  return AnimeBoxesMetadata(
    formatVersion: formatVersion,
    creatorName: creatorName,
    creatorVersion: _requiredString(row, 3, 'creator version', 'Meta'),
    exportedAt: _timestamp(row, 4, 'export timestamp', 'Meta'),
    sourceRow: row.sourceRow,
  );
}

AnimeBoxesServer _parseServer(_SourceRow row, int position) {
  _requireRowType(row, '0', 'Servers');
  final loginPresent = _cell(row, 9).isNotEmpty || _cell(row, 10).isNotEmpty;
  final credentialsPresent =
      loginPresent || _cell(row, 12).isNotEmpty || _cell(row, 13).isNotEmpty;
  _requireEmpty(row, [14, 15, 16, 17, 18], 'Servers');
  return AnimeBoxesServer(
    serverId: _integer(row, 1, 'server ID', 'Servers', minimum: 0),
    url: _url(row, 2, 'site URL', 'Servers'),
    name: _requiredString(row, 3, 'server name', 'Servers'),
    useNativeAutocomplete: _boolean(
      row,
      4,
      'native autocomplete',
      'Servers',
    ),
    ratingFilterEnabled: _boolean(row, 5, 'rating filter', 'Servers'),
    selected: _boolean(row, 6, 'selected flag', 'Servers'),
    isDefault: _boolean(row, 7, 'default flag', 'Servers'),
    type: _integer(row, 8, 'server type', 'Servers'),
    loginPresent: loginPresent,
    credentialsPresent: credentialsPresent,
    realUrl: _url(row, 11, 'real URL', 'Servers'),
    sourceRow: row.sourceRow,
    sourcePosition: position,
  );
}

AnimeBoxesHistoryEntry _parseHistory(_SourceRow row, int position) {
  _requireRowType(row, '1', 'History');
  _requireEmpty(row, [5, 6, 7, 8, 9], 'History');
  return AnimeBoxesHistoryEntry(
    itemId: _integer(row, 1, 'history ID', 'History', minimum: 0),
    query: _requiredString(row, 2, 'query', 'History'),
    searchedAt: _timestamp(row, 3, 'search timestamp', 'History'),
    starred: _boolean(row, 4, 'starred flag', 'History'),
    sourceRow: row.sourceRow,
    sourcePosition: position,
  );
}

AnimeBoxesFavorite _parseFavorite(_SourceRow row, int position) {
  _requireRowType(row, '2', 'Favorites');
  _requireEmpty(
    row,
    [29, 30, 31, 32, 33, 34, 35, 36, 37, 38],
    'Favorites',
  );
  final parent = _cell(row, 22);
  final parentId = parent.isEmpty || parent == '0'
      ? null
      : _integer(row, 22, 'parent ID', 'Favorites', minimum: 1);
  final rating = _requiredString(
    row,
    24,
    'rating',
    'Favorites',
  ).toLowerCase();
  if (!const {
    's',
    'safe',
    'sensitive',
    'e',
    'explicit',
    'g',
    'general',
    'q',
    'questionable',
  }.contains(rating)) {
    throw AnimeBoxesFormatException(
      'invalid_rating',
      'The rating is unsupported.',
      section: 'Favorites',
      row: row.sourceRow,
    );
  }
  final md5 = _requiredString(row, 20, 'MD5', 'Favorites');
  if (!RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(md5)) {
    throw AnimeBoxesFormatException(
      'invalid_md5',
      'The MD5 is invalid.',
      section: 'Favorites',
      row: row.sourceRow,
    );
  }
  return AnimeBoxesFavorite(
    postId: _integer(row, 1, 'post ID', 'Favorites', minimum: 1),
    postUrl: _url(row, 2, 'post URL', 'Favorites'),
    sampleWidth: _integer(row, 3, 'sample width', 'Favorites', minimum: 0),
    sampleHeight: _integer(row, 4, 'sample height', 'Favorites', minimum: 0),
    sampleUrl: _url(row, 5, 'sample URL', 'Favorites'),
    previewWidth: _integer(row, 6, 'preview width', 'Favorites', minimum: 0),
    previewHeight: _integer(row, 7, 'preview height', 'Favorites', minimum: 0),
    previewUrl: _url(row, 8, 'preview URL', 'Favorites'),
    width: _integer(row, 9, 'width', 'Favorites', minimum: 0),
    height: _integer(row, 10, 'height', 'Favorites', minimum: 0),
    fileUrl: _url(row, 11, 'file URL', 'Favorites'),
    jpegWidth: _integer(row, 12, 'JPEG width', 'Favorites', minimum: 0),
    jpegHeight: _integer(row, 13, 'JPEG height', 'Favorites', minimum: 0),
    jpegUrl: _optionalUrl(row, 14, 'JPEG URL', 'Favorites'),
    tags: _tags(row, 15),
    generalTags: _tags(row, 16),
    artistTags: _tags(row, 17),
    characterTags: _tags(row, 18),
    copyrightTags: _tags(row, 19),
    md5: md5.toLowerCase(),
    source: _optionalString(row, 21),
    parentId: parentId,
    score: _integer(row, 23, 'score', 'Favorites'),
    rating: rating,
    hasNotes: _boolean(row, 25, 'notes flag', 'Favorites'),
    hasComments: _boolean(row, 26, 'comments flag', 'Favorites'),
    hasChildren: _boolean(row, 27, 'children flag', 'Favorites'),
    dateAdded: _timestamp(row, 28, 'favorite-added timestamp', 'Favorites'),
    sourceRow: row.sourceRow,
    sourcePosition: position,
  );
}

AnimeBoxesBlacklistEntry _parseBlacklist(_SourceRow row, int position) {
  _requireRowType(row, '3', 'Tag Blacklist');
  _requireEmpty(row, [3, 4, 5, 6, 7], 'Tag Blacklist');
  return AnimeBoxesBlacklistEntry(
    rule: _requiredString(row, 1, 'rule', 'Tag Blacklist'),
    sourceId: _integer(row, 2, 'blacklist ID', 'Tag Blacklist', minimum: 0),
    sourceRow: row.sourceRow,
    sourcePosition: position,
  );
}

_SourceQuery _parseSourceQuery(_SourceRow row) {
  final Object? decoded;
  try {
    decoded = jsonDecode(_requiredString(row, 5, 'query data', 'Home Pins'));
  } catch (_) {
    throw AnimeBoxesFormatException(
      'invalid_query_data',
      'The pin query data is invalid.',
      section: 'Home Pins',
      row: row.sourceRow,
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw AnimeBoxesFormatException(
      'invalid_query_data',
      'The pin query data is invalid.',
      section: 'Home Pins',
      row: row.sourceRow,
    );
  }
  final disableAutoLoad = decoded['disableAutoLoad'];
  final includeBlacklisted = decoded['includeBlacklisted'];
  final initialPage = decoded['initialPage'];
  final text = decoded['text'];
  final title = decoded['title'];
  final extraParams = decoded['extraParams'];
  if (disableAutoLoad is! bool ||
      includeBlacklisted is! bool ||
      initialPage is! int ||
      text is! String ||
      title is! String ||
      extraParams is! Map) {
    throw AnimeBoxesFormatException(
      'invalid_query_data',
      'The pin query data is invalid.',
      section: 'Home Pins',
      row: row.sourceRow,
    );
  }
  return _SourceQuery(
    disableAutoLoad: disableAutoLoad,
    includeBlacklisted: includeBlacklisted,
    initialPage: initialPage,
    text: text,
    title: title,
    extraParams: Map<String, Object?>.unmodifiable(
      Map<String, Object?>.from(extraParams),
    ),
  );
}

void _requireRowType(_SourceRow row, String type, String section) {
  if (_cell(row, 0) != type) {
    throw AnimeBoxesFormatException(
      'invalid_row_type',
      'The row type does not match its section.',
      section: section,
      row: row.sourceRow,
    );
  }
}

String _cell(_SourceRow row, int index) => _rawCell(row.cells[index]);

String _rawCell(Object? cell) => switch (cell) {
  final String value => value,
  _ => '',
};

String _requiredString(
  _SourceRow row,
  int index,
  String field,
  String section,
) {
  final value = _cell(row, index);
  if (value.isEmpty) {
    throw AnimeBoxesFormatException(
      'missing_value',
      'A required $field is missing.',
      section: section,
      row: row.sourceRow,
    );
  }
  return value;
}

String? _optionalString(_SourceRow row, int index) =>
    switch (_cell(row, index)) {
      '' => null,
      final value => value,
    };

int _integer(
  _SourceRow row,
  int index,
  String field,
  String section, {
  int? minimum,
}) {
  final value = int.tryParse(_cell(row, index));
  if (value == null || (minimum != null && value < minimum)) {
    throw AnimeBoxesFormatException(
      'invalid_integer',
      'A required $field is invalid.',
      section: section,
      row: row.sourceRow,
    );
  }
  return value;
}

bool _boolean(_SourceRow row, int index, String field, String section) {
  return switch (_cell(row, index).toLowerCase()) {
    'true' || '1' => true,
    'false' || '0' => false,
    _ => throw AnimeBoxesFormatException(
      'invalid_boolean',
      'A required $field is invalid.',
      section: section,
      row: row.sourceRow,
    ),
  };
}

AnimeBoxesSourceTimestamp _timestamp(
  _SourceRow row,
  int index,
  String field,
  String section,
) {
  final raw = _cell(row, index);
  final instant = DateTime.tryParse(raw);
  if (raw.isEmpty || instant == null) {
    throw AnimeBoxesFormatException(
      'invalid_timestamp',
      'A required $field is invalid.',
      section: section,
      row: row.sourceRow,
    );
  }
  return AnimeBoxesSourceTimestamp(raw: raw, instant: instant);
}

String _url(_SourceRow row, int index, String field, String section) {
  final value = _requiredString(row, index, field, section);
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty) {
    throw AnimeBoxesFormatException(
      'invalid_url',
      'A required $field is invalid.',
      section: section,
      row: row.sourceRow,
    );
  }
  return value;
}

String? _optionalUrl(
  _SourceRow row,
  int index,
  String field,
  String section,
) => switch (_cell(row, index)) {
  '' => null,
  _ => _url(row, index, field, section),
};

List<String> _tags(_SourceRow row, int index) {
  final value = _cell(row, index).trim();
  if (value.isEmpty) return const [];
  return List.unmodifiable(value.split(RegExp(r'\s+')));
}

void _requireEmpty(_SourceRow row, Iterable<int> indexes, String section) {
  if (indexes.any((index) => _cell(row, index).isNotEmpty)) {
    throw AnimeBoxesFormatException(
      'unmapped_column',
      'A reserved column contains data.',
      section: section,
      row: row.sourceRow,
    );
  }
}

String _displaySection(String marker) => marker.substring(1);

final class _SourceRow {
  const _SourceRow(this.cells, this.sourceRow);

  final List<dynamic> cells;
  final int sourceRow;
}

final class _SourceQuery {
  const _SourceQuery({
    required this.disableAutoLoad,
    required this.includeBlacklisted,
    required this.initialPage,
    required this.text,
    required this.title,
    required this.extraParams,
  });

  final bool disableAutoLoad;
  final bool includeBlacklisted;
  final int initialPage;
  final String text;
  final String title;
  final Map<String, Object?> extraParams;
}
