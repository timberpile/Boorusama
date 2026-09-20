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
    final ids = <String>{};
    for (final (index, value) in metadata.data.indexed) {
      final row = 'data[$index]';
      final json = _object(value, row);
      final id = switch (json['id']) {
        final String id when Uuid.isValidUUID(fromString: id) =>
          id.toLowerCase(),
        _ => throw InvalidBackupFormatException('$row.id is invalid'),
      };
      if (!ids.add(id)) {
        throw InvalidBackupFormatException('$row.id is repeated');
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
    return PinnedSearchBackupData(records: List.unmodifiable(records));
  }

  @override
  List<dynamic> encode(PinnedSearchBackupData data) => [
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
