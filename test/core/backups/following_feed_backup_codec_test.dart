import 'package:boorusama/core/backups/sources/following_feed_backup_codec.dart';
import 'package:boorusama/core/backups/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final codec = FollowingFeedBackupCodec();

  test('preserves feed definition and query order without runtime state', () {
    final parsed = codec.parse(
      _payload(
        data: [
          _feedRow(queries: [' cat ', 'dog', 'cat']),
        ],
      ),
    );
    expect(parsed.feeds.single.queries, ['cat', 'dog']);
    expect(parsed.feeds.single.name, 'Animals');
    final encoded = codec.encode(parsed);
    expect(encoded, hasLength(1));
    final row = encoded.single as Map<String, dynamic>;
    expect(row['kind'], 'feed');
    expect(row['queries'], ['cat', 'dog']);
    expect(row.keys, isNot(contains('sourceIds')));
    expect(row.keys, isNot(contains('posts')));
    expect(row.keys, isNot(contains('new')));
    expect(codec.parse(_payload(data: encoded)), parsed);
  });

  test('round-trips an empty feed collection', () {
    final parsed = codec.parse(_payload(data: const []));
    expect(parsed.feeds, isEmpty);
    expect(codec.encode(parsed), isEmpty);
  });

  for (final c in [
    (
      name: 'another source',
      source: 'pinned_searches',
      version: 1,
    ),
    (name: 'missing source', source: null, version: 1),
    (name: 'unsupported version', source: 'following_feeds', version: 2),
  ]) {
    test('rejects ${c.name}', () {
      expect(
        () => codec.parse(
          _payload(
            data: [_feedRow()],
            source: c.source,
            version: c.version,
          ),
        ),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });
  }

  for (final c in [
    (name: 'a search row', row: {..._feedRow(), 'kind': 'search'}),
    (name: 'a duplicate ID', row: _feedRow()),
    (name: 'an invalid UUID', row: {..._feedRow(), 'id': 'invalid'}),
    (name: 'a blank name', row: {..._feedRow(), 'name': ' '}),
    (name: 'a negative position', row: {..._feedRow(), 'position': -1}),
    (name: 'a missing profile', row: _feedRow()..remove('profile')),
    (name: 'an empty query list', row: _feedRow(queries: [])),
    (name: 'a non-string query', row: _feedRow(queries: [1])),
    (
      name: 'more than 1000 queries',
      row: _feedRow(queries: List.filled(1001, 'cat')),
    ),
  ]) {
    test('rejects ${c.name}', () {
      expect(
        () => codec.parse(
          _payload(
            data: c.name == 'a duplicate ID' ? [_feedRow(), c.row] : [c.row],
          ),
        ),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });
  }
}

ExportDataPayload _payload({
  required List<dynamic> data,
  String? source = 'following_feeds',
  int version = 1,
}) => ExportDataPayload(
  version: version,
  exportDate: null,
  exportVersion: null,
  data: data,
  extraFields: {'source': ?source},
);

Map<String, dynamic> _feedRow({List<dynamic> queries = const ['cat', 'dog']}) =>
    {
      'kind': 'feed',
      'id': '550e8400-e29b-41d4-a716-446655440000',
      'name': 'Animals',
      'position': 0,
      'queries': queries,
      'profile': {
        'id': 4,
        'booruType': 'danbooru',
        'url': 'https://example.test/Posts',
        'name': 'Example',
      },
    };
