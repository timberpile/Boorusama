import 'package:boorusama/core/backups/sources/pinned_search_backup_codec.dart';
import 'package:boorusama/core/backups/sources/pinned_search_backup_data.dart';
import 'package:boorusama/core/backups/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final codec = PinnedSearchBackupCodec();

  test('round trips stable definitions while discarding runtime fields', () {
    final data = codec.parse(
      ExportDataPayload.legacy(
        data: [
          {
            ..._row(),
            'previews': ['https://private.example/image.jpg'],
            'recentPostIdentities': [42],
            'unreadCount': 12,
            'createdAt': '2026-09-01T12:00:00Z',
            'lastAttemptAt': '2026-09-14T12:00:00Z',
            'lastSuccessfulCheckAt': '2026-09-14T12:00:00Z',
            'lastErrorKind': 'network',
          },
        ],
      ),
    );

    expect(
      data,
      const PinnedSearchBackupData(
        records: [
          PinnedSearchBackupRecord(
            id: _id,
            name: 'Cats',
            query: 'cat  rating:safe',
            position: 0,
            profile: PinnedSearchProfileReference(
              id: 4,
              booruType: 'danbooru',
              url: 'https://example.test/Posts',
              name: 'Example',
            ),
          ),
        ],
      ),
    );
    final encoded = codec.encode(data);
    expect(encoded, [
      {
        ..._row(),
        'profile': {..._profile(), 'url': 'https://example.test/Posts'},
      },
    ]);
    expect(codec.parse(ExportDataPayload.legacy(data: encoded)), data);
  });

  test('canonicalizes UUIDs and optional names without changing the query', () {
    final data = codec.parse(
      ExportDataPayload.legacy(
        data: [
          {..._row(), 'id': _id.toUpperCase(), 'name': '   '},
        ],
      ),
    );

    expect(data.records.single.id, _id);
    expect(data.records.single.name, isNull);
    expect(data.records.single.query, 'cat  rating:safe');
    expect(codec.encode(data).single['name'], isNull);
  });

  test('accepts an omitted optional name', () {
    final data = codec.parse(
      ExportDataPayload.legacy(data: [_row()..remove('name')]),
    );
    expect(data.records.single.name, isNull);
  });

  final urlCases = [
    (input: 'https://EXAMPLE.test/', output: 'https://example.test'),
    (input: 'http://EXAMPLE.test/Path/', output: 'http://example.test/Path'),
    (
      input: 'https://EXAMPLE.test/Path/?x=A#B',
      output: 'https://example.test/Path?x=A#B',
    ),
  ];
  for (final c in urlCases) {
    test('normalizes ${c.input} without dropping scheme or path', () {
      final data = codec.parse(
        ExportDataPayload.legacy(
          data: [
            {
              ..._row(),
              'profile': {..._profile(), 'url': c.input},
            },
          ],
        ),
      );
      expect(data.records.single.profile.url, c.output);
    });
  }

  final cases = [
    (description: 'null rows', value: null, field: 'data[0]'),
    (description: 'list rows', value: <dynamic>[], field: 'data[0]'),
    (
      description: 'missing IDs',
      value: _row()..remove('id'),
      field: 'data[0].id',
    ),
    (
      description: 'malformed UUIDs',
      value: {..._row(), 'id': 'bad'},
      field: 'data[0].id',
    ),
    (
      description: 'blank queries',
      value: {..._row(), 'query': ' \n '},
      field: 'data[0].query',
    ),
    (
      description: 'null queries',
      value: {..._row(), 'query': null},
      field: 'data[0].query',
    ),
    (
      description: 'non-string names',
      value: {..._row(), 'name': 12},
      field: 'data[0].name',
    ),
    (
      description: 'missing positions',
      value: _row()..remove('position'),
      field: 'data[0].position',
    ),
    (
      description: 'negative positions',
      value: {..._row(), 'position': -1},
      field: 'data[0].position',
    ),
    (
      description: 'fractional positions',
      value: {..._row(), 'position': 1.5},
      field: 'data[0].position',
    ),
    (
      description: 'missing profiles',
      value: _row()..remove('profile'),
      field: 'data[0].profile',
    ),
    (
      description: 'non-object profiles',
      value: {..._row(), 'profile': 'Example'},
      field: 'data[0].profile',
    ),
    for (final field in ['id', 'booruType', 'url', 'name'])
      (
        description: 'missing profile $field',
        value: {..._row(), 'profile': _profile()..remove(field)},
        field: 'data[0].profile.$field',
      ),
    (
      description: 'negative profile IDs',
      value: {
        ..._row(),
        'profile': {..._profile(), 'id': -1},
      },
      field: 'data[0].profile.id',
    ),
    (
      description: 'string profile IDs',
      value: {
        ..._row(),
        'profile': {..._profile(), 'id': '4'},
      },
      field: 'data[0].profile.id',
    ),
    (
      description: 'blank profile types',
      value: {
        ..._row(),
        'profile': {..._profile(), 'booruType': ' '},
      },
      field: 'data[0].profile.booruType',
    ),
    (
      description: 'non-string profile types',
      value: {
        ..._row(),
        'profile': {..._profile(), 'booruType': 1},
      },
      field: 'data[0].profile.booruType',
    ),
    (
      description: 'blank profile names',
      value: {
        ..._row(),
        'profile': {..._profile(), 'name': ' '},
      },
      field: 'data[0].profile.name',
    ),
    (
      description: 'relative profile URLs',
      value: {
        ..._row(),
        'profile': {..._profile(), 'url': '/posts'},
      },
      field: 'data[0].profile.url',
    ),
    (
      description: 'malformed profile URLs',
      value: {
        ..._row(),
        'profile': {..._profile(), 'url': 'https://['},
      },
      field: 'data[0].profile.url',
    ),
    (
      description: 'non-web profile URLs',
      value: {
        ..._row(),
        'profile': {..._profile(), 'url': 'file:///posts'},
      },
      field: 'data[0].profile.url',
    ),
  ];
  for (final c in cases) {
    test('rejects ${c.description} with the offending field', () {
      expect(
        () => codec.parse(ExportDataPayload.legacy(data: [c.value])),
        throwsA(
          isA<InvalidBackupFormatException>().having(
            (e) => e.details,
            'details',
            contains(c.field),
          ),
        ),
      );
    });
  }

  test('rejects repeated UUIDs after canonicalization', () {
    expect(
      () => codec.parse(
        ExportDataPayload.legacy(
          data: [
            _row(),
            {..._row(), 'id': _id.toUpperCase()},
          ],
        ),
      ),
      throwsA(
        isA<InvalidBackupFormatException>().having(
          (e) => e.details,
          'details',
          contains('data[1].id'),
        ),
      ),
    );
  });
}

const _id = '550e8400-e29b-41d4-a716-446655440000';

Map<String, dynamic> _profile() => {
  'id': 4,
  'booruType': 'danbooru',
  'url': 'https://EXAMPLE.test/Posts/',
  'name': 'Example',
};

Map<String, dynamic> _row() => {
  'id': _id,
  'name': 'Cats',
  'query': 'cat  rating:safe',
  'position': 0,
  'profile': _profile(),
};
