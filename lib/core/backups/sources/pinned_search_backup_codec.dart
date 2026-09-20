// Package imports:
import 'package:uuid/uuid.dart';

// Project imports:
import '../types/types.dart';
import '../utils/json_handler.dart';
import 'pinned_search_backup_data.dart';

class PinnedSearchBackupCodec extends JsonHandler<PinnedSearchBackupData> {
  @override
  PinnedSearchBackupData parse(ExportDataPayload metadata) {
    final records = <PinnedSearchBackupRecord>[];
    final folders = <PinnedSearchFolderBackupRecord>[];
    final feeds = <PinnedSearchFeedBackupRecord>[];
    final ids = <String>{};
    List<String>? homeSearchIds;
    for (final (index, value) in metadata.data.indexed) {
      final row = 'data[$index]';
      final json = _object(value, row);
      if (json['kind'] == 'organization') {
        if (homeSearchIds != null) {
          throw InvalidBackupFormatException('$row organization is repeated');
        }
        homeSearchIds = _searchIds(json['homeSearchIds'], '$row.homeSearchIds');
        continue;
      }
      final id = switch (json['id']) {
        final String id when Uuid.isValidUUID(fromString: id) =>
          id.toLowerCase(),
        _ => throw InvalidBackupFormatException('$row.id is invalid'),
      };
      if (!ids.add(id)) {
        throw InvalidBackupFormatException('$row.id is repeated');
      }
      if (json['kind'] == 'feed') {
        final queries = switch (json['queries']) {
          final List values when values.isNotEmpty && values.length <= 1000 => [
            for (final value in values) _nonBlankString(value, '$row.queries'),
          ],
          _ => throw InvalidBackupFormatException('$row.queries is invalid'),
        };
        final profile = _object(json['profile'], '$row.profile');
        feeds.add(
          PinnedSearchFeedBackupRecord(
            id: id,
            name: _nonBlankString(json['name'], '$row.name').trim(),
            position: _nonNegativeInt(json['position'], '$row.position'),
            queries: List.unmodifiable(queries),
            profile: PinnedSearchProfileReference(
              id: _nonNegativeInt(profile['id'], '$row.profile.id'),
              booruType: _nonBlankString(
                profile['booruType'],
                '$row.profile.booruType',
              ),
              url: _profileUrl(profile['url'], '$row.profile.url'),
              name: _nonBlankString(profile['name'], '$row.profile.name'),
            ),
          ),
        );
        continue;
      }
      if (json['kind'] == 'folder') {
        final members = _searchIds(json['searchIds'], '$row.searchIds');
        folders.add(
          PinnedSearchFolderBackupRecord(
            id: id,
            name: _nonBlankString(json['name'], '$row.name').trim(),
            position: _nonNegativeInt(json['position'], '$row.position'),
            searchIds: List.unmodifiable(members),
          ),
        );
        continue;
      }
      if (json['kind'] != null && json['kind'] != 'search') {
        throw InvalidBackupFormatException('$row.kind is invalid');
      }
      final name = switch (json['name']) {
        null => null,
        final String name => name.trim().isEmpty ? null : name.trim(),
        _ => throw InvalidBackupFormatException('$row.name is invalid'),
      };
      final profile = _object(json['profile'], '$row.profile');
      records.add(
        PinnedSearchBackupRecord(
          id: id,
          name: name,
          query: _nonBlankString(json['query'], '$row.query'),
          position: _nonNegativeInt(json['position'], '$row.position'),
          profile: PinnedSearchProfileReference(
            id: _nonNegativeInt(profile['id'], '$row.profile.id'),
            booruType: _nonBlankString(
              profile['booruType'],
              '$row.profile.booruType',
            ),
            url: _profileUrl(profile['url'], '$row.profile.url'),
            name: _nonBlankString(profile['name'], '$row.profile.name'),
          ),
        ),
      );
    }
    final independentIds = records.map((record) => record.id).toSet();
    final folderNames = <String>{};
    for (final folder in folders) {
      if (!folderNames.add(folder.name.toLowerCase())) {
        throw const InvalidBackupFormatException('Repeated folder name');
      }
    }
    final assigned = <String>{};
    for (final id in [
      ...?homeSearchIds,
      for (final folder in folders) ...folder.searchIds,
    ]) {
      if (!assigned.add(id) || !independentIds.contains(id)) {
        throw const InvalidBackupFormatException(
          'Invalid organization search reference',
        );
      }
    }
    return PinnedSearchBackupData(
      records: List.unmodifiable(records),
      folders: List.unmodifiable(folders),
      feeds: List.unmodifiable(feeds),
      homeSearchIds: List.unmodifiable(homeSearchIds ?? const <String>[]),
    );
  }

  @override
  List<dynamic> encode(PinnedSearchBackupData data) => [
    for (final feed in data.feeds)
      {
        'kind': 'feed',
        'id': feed.id,
        'name': feed.name,
        'position': feed.position,
        'queries': feed.queries,
        'profile': {
          'id': feed.profile.id,
          'booruType': feed.profile.booruType,
          'url': normalizePinnedSearchProfileUrl(feed.profile.url),
          'name': feed.profile.name,
        },
      },
    for (final folder in data.folders)
      {
        'kind': 'folder',
        'id': folder.id,
        'name': folder.name,
        'position': folder.position,
        'searchIds': folder.searchIds,
      },
    for (final record in data.records)
      {
        'id': record.id,
        'name': record.name,
        'query': record.query,
        'position': record.position,
        'profile': {
          'id': record.profile.id,
          'booruType': record.profile.booruType,
          'url': normalizePinnedSearchProfileUrl(record.profile.url),
          'name': record.profile.name,
        },
      },
    {'kind': 'organization', 'homeSearchIds': data.homeSearchIds},
  ];
}

Map<String, dynamic> _object(Object? value, String field) => switch (value) {
  final Map<String, dynamic> value => value,
  _ => throw InvalidBackupFormatException('$field must be an object'),
};

String _nonBlankString(Object? value, String field) => switch (value) {
  final String value when value.trim().isNotEmpty => value,
  _ => throw InvalidBackupFormatException('$field is invalid'),
};

int _nonNegativeInt(Object? value, String field) => switch (value) {
  final int value when value >= 0 => value,
  _ => throw InvalidBackupFormatException('$field is invalid'),
};

String _profileUrl(Object? value, String field) {
  final url = _nonBlankString(value, field);
  final uri = Uri.tryParse(url);
  if (uri case Uri(
    scheme: 'http' || 'https',
    host: final host,
  ) when host.isNotEmpty) {
    return normalizePinnedSearchProfileUrl(url);
  }
  throw InvalidBackupFormatException('$field is invalid');
}

List<String> _searchIds(Object? value, String field) => switch (value) {
  final List values => [
    for (final value in values)
      switch (value) {
        final String id when Uuid.isValidUUID(fromString: id) =>
          id.toLowerCase(),
        _ => throw InvalidBackupFormatException('$field is invalid'),
      },
  ],
  _ => throw InvalidBackupFormatException('$field is invalid'),
};
