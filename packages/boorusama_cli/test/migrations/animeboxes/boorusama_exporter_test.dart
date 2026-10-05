import 'dart:convert';
import 'dart:io';

import 'package:boorusama_cli/src/migrations/animeboxes/boorusama_exporter.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/csv_reader.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/errors.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/document_codec.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/normalizer.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/normalized_types.dart';
import 'package:test/test.dart';
import 'package:archive/archive.dart';

void main() {
  test(
    'preserves source folder labels and deterministic unnamed/duplicate names',
    () {
      final document = _document(
        fixture: File(
          'test/migrations/animeboxes/fixtures/folder_names.csv',
        ).readAsStringSync(),
      );
      expect(document.pinnedSearchFolders.map((folder) => folder.name), [
        'Folder, café',
        'Folder, café',
        '   ',
      ]);
      final artifacts = const BoorusamaMigrationExporter().export(document);
      final rows =
          (jsonDecode(artifacts.pinnedSearches) as Map)['data'] as List;
      final folders = rows.where((row) => row['kind'] == 'folder').toList();
      expect(folders.map((row) => row['id']), [
        for (var index = 0; index < 3; index++)
          'c0000000-0000-4000-8000-00000000000$index',
      ]);
      expect(folders.map((row) => row['position']), [0, 1, 2]);
      expect(folders.map((row) => row['searchIds']), [
        for (var index = 0; index < 3; index++)
          ['d0000000-0000-4000-8000-00000000000$index'],
      ]);
      expect(
        rows.where((row) => row['kind'] == 'folder').map((row) => row['name']),
        ['Folder, café', 'Folder, café (2)', 'Imported folder 3'],
      );
      expect(
        rows.where((row) => row['kind'] == 'search').map((row) => row['query']),
        [
          'synthetic_query_0 order:score',
          'synthetic_query_1 order:score',
          'synthetic_query_2 order:score',
        ],
      );
    },
  );

  test('exports canonical v4 bookmarks with stable group membership', () {
    final document = _document(fixture: _completeFixture());
    final artifacts = const BoorusamaMigrationExporter().export(document);
    final envelope = jsonDecode(artifacts.bookmarks) as Map<String, dynamic>;
    expect(envelope['version'], 4);
    final bookmark = (envelope['data'] as List).single as Map;
    expect(bookmark['identity'], {
      'site': 'danbooru.donmai.us',
      'postKey': 'id:42',
    });
    final group = (envelope['groups'] as List).single as Map;
    expect(group['id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(group['name'], 'AnimeBoxes');
    expect(group['bookmarkIds'], [1]);
    expect(
      const BoorusamaMigrationExporter().export(document).bookmarks,
      artifacts.bookmarks,
    );
  });

  test('Home searches are selected without an ignored Home action row', () {
    final document = _document(
      fixture: _completeFixture().replaceFirst(
        '4,11111111-1111-4111-8111-111111111111,22222222-',
        '4,,22222222-',
      ),
    );
    final artifacts = const BoorusamaMigrationExporter().export(document);
    final zip = ZipDecoder().decodeBytes(artifacts.packageBytes);
    final manifest =
        jsonDecode(utf8.decode(zip.findFile('manifest.json')!.content)) as Map;
    final pins =
        (manifest['sources'] as List).singleWhere(
              (source) => source['id'] == 'pinned_searches',
            )
            as Map;
    expect((pins['selection'] as Map)['childIds'], isNot(contains('home')));
  });

  test(
    'preserves an extras-only effective query and stable profile reference',
    () {
      const exporter = BoorusamaMigrationExporter();
      Map search(NormalizedAnimeBoxesDocument document) {
        final rows =
            (jsonDecode(exporter.export(document).pinnedSearches)
                    as Map)['data']
                as List;
        return rows.singleWhere((row) => row['kind'] == 'search') as Map;
      }

      final original = search(
        _pinnedDocument([('tag_one', <String, Object?>{})]),
      );
      final combined = search(
        _pinnedDocument([
          (
            '',
            {
              'extra_tags': 'is:sfw order:score',
              'danbooru2_is_has': 'is:sfw',
              'danbooru2_order': 'order:score',
            },
          ),
        ]),
      );
      expect(combined['query'], 'is:sfw order:score');
      expect(combined['profile'], original['profile']);
    },
  );

  test(
    'retains same-text searches with different effective filters in source order',
    () {
      final artifacts = const BoorusamaMigrationExporter().export(
        _pinnedDocument([
          (' tag_one ', {'extra_tags': ' rating:general '}),
          ('tag_one', {'extra_tags': 'rating:explicit'}),
        ]),
      );
      final rows =
          (jsonDecode(artifacts.pinnedSearches) as Map)['data'] as List;
      final searches = rows.where((row) => row['kind'] == 'search').toList();
      expect(searches.map((row) => row['query']), [
        'tag_one   rating:general',
        'tag_one rating:explicit',
      ]);
      expect(searches.map((row) => row['position']), [0, 1]);
      expect(searches.map((row) => row['id']).toSet(), hasLength(2));
      final report = jsonDecode(artifacts.report) as Map;
      expect(
        (report['diagnostics'] as List).where(
          (row) => row['code'] == 'pinned_search_settings_not_exported',
        ),
        isEmpty,
      );
    },
  );

  test(
    'reports repeated effective identities while retaining every definition',
    () {
      final artifacts = const BoorusamaMigrationExporter().export(
        _pinnedDocument([
          ('synthetic_private_query', {'extra_tags': 'order:score'}),
          (' synthetic_private_query ', {'extra_tags': ' order:score '}),
        ]),
      );
      final rows =
          (jsonDecode(artifacts.pinnedSearches) as Map)['data'] as List;
      expect(rows.where((row) => row['kind'] == 'search'), hasLength(2));
      final report = jsonDecode(artifacts.report) as Map;
      expect(
        (report['diagnostics'] as List).singleWhere(
          (row) => row['code'] == 'duplicate_pinned_query_identity',
        )['count'],
        1,
      );
      expect(artifacts.report, isNot(contains('synthetic_private_query')));
    },
  );

  test('reports unknown settings without dropping the effective query', () {
    final artifacts = const BoorusamaMigrationExporter().export(
      _pinnedDocument([
        ('tag_one', {'extra_tags': 'order:score', 'unknown_ui_setting': true}),
      ]),
    );
    final report = jsonDecode(artifacts.report) as Map;
    expect(
      (report['diagnostics'] as List).singleWhere(
        (row) => row['code'] == 'pinned_search_settings_not_exported',
      )['count'],
      1,
    );
    final rows = (jsonDecode(artifacts.pinnedSearches) as Map)['data'] as List;
    expect(
      rows.singleWhere((row) => row['kind'] == 'search')['query'],
      'tag_one order:score',
    );
  });

  for (final extra in [
    <String, Object?>{},
    {'extra_tags': ''},
    {'extra_tags': '   '},
  ]) {
    test(
      'rejects a genuinely empty effective query (${extra.isEmpty
          ? 'absent extras'
          : extra['extra_tags'] == ''
          ? 'empty extras'
          : 'whitespace extras'})',
      () {
        expect(
          () => const BoorusamaMigrationExporter().export(
            _pinnedDocument([
              ('   ', extra),
            ]),
          ),
          throwsA(
            isA<AnimeBoxesFormatException>().having(
              (error) => error.code,
              'code',
              'empty_pinned_search_query',
            ),
          ),
        );
      },
    );
  }

  for (final value in [
    null,
    42,
    ['order:score'],
    {'filter': 'rating:general'},
  ]) {
    test('rejects malformed extra tags of type ${value.runtimeType}', () {
      expect(
        () => const BoorusamaMigrationExporter().export(
          _pinnedDocument([
            ('tag_one', {'extra_tags': value}),
          ]),
        ),
        throwsA(
          isA<AnimeBoxesFormatException>().having(
            (error) => error.code,
            'code',
            'invalid_pinned_search_extra_tags',
          ),
        ),
      );
    });
  }

  test('retains distinct upstream posts sharing one media URL', () {
    final first = _document(fixture: _completeFixture());
    final second = _document(
      fixture: _completeFixture().replaceFirst(
        '2,42,https://danbooru.donmai.us/posts/42',
        '2,43,https://danbooru.donmai.us/posts/43',
      ),
    );
    final document = _withBookmarks(first, [
      ...first.bookmarks,
      ...second.bookmarks,
    ]);
    final envelope =
        jsonDecode(
              const BoorusamaMigrationExporter().export(document).bookmarks,
            )
            as Map<String, dynamic>;
    expect((envelope['data'] as List).map((row) => row['identity']), [
      {'site': 'danbooru.donmai.us', 'postKey': 'id:42'},
      {'site': 'danbooru.donmai.us', 'postKey': 'id:43'},
    ]);
    expect((envelope['groups'] as List).single['bookmarkIds'], [1, 2]);
  });

  test(
    'exports deterministic UUID references independent of account names',
    () {
      Map profile(String fixture) {
        final envelope =
            jsonDecode(
                  const BoorusamaMigrationExporter()
                      .export(_document(fixture: fixture))
                      .pinnedSearches,
                )
                as Map;
        return (envelope['data'] as List).singleWhere(
              (row) => row['kind'] == 'search',
            )['profile']
            as Map;
      }

      final first = profile(_completeFixture());
      expect(first['id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(
        first['id'],
        profile(
          _completeFixture().replaceAll('Donmai Fixture', 'Renamed'),
        )['id'],
      );
    },
  );

  test(
    'profile reference UUIDs use the current portable URL normalization',
    () {
      final document = _document(fixture: _completeFixture());
      Map reference(NormalizedAnimeBoxesDocument input) {
        final data =
            jsonDecode(
                  const BoorusamaMigrationExporter()
                      .export(input)
                      .pinnedSearches,
                )
                as Map;
        return (data['data'] as List).singleWhere(
              (row) => row['kind'] == 'search',
            )['profile']
            as Map;
      }

      final first = reference(document);
      final json =
          jsonDecode(const AnimeBoxesDocumentCodec().encode(document)) as Map;
      (json['profiles'] as List).single['url'] =
          'https://DANBOORU.DONMAI.US///';
      final second = reference(
        const AnimeBoxesDocumentCodec().decode(jsonEncode(json)),
      );
      expect(second['id'], first['id']);
      expect(second['url'], 'https://danbooru.donmai.us');
    },
  );

  for (final port in [':8443', ':443']) {
    test(
      'keeps the $port site namespace in bookmark identity and snapshot',
      () {
        final document = _document(
          fixture: _completeFixture().replaceAll(
            'https://danbooru.donmai.us',
            'http://danbooru.donmai.us$port',
          ),
        );
        final envelope =
            jsonDecode(
                  const BoorusamaMigrationExporter().export(document).bookmarks,
                )
                as Map;
        final row = (envelope['data'] as List).single as Map;
        expect(row['identity'], {
          'site': 'danbooru.donmai.us$port',
          'postKey': 'id:42',
        });
        expect(
          row['snapshot']['origin']['sourceHost'],
          'danbooru.donmai.us$port',
        );
      },
    );
  }

  test(
    'rejects normalized bookmark pages that conflict with their profile site',
    () {
      final document = _document(fixture: _completeFixture());
      final json =
          jsonDecode(const AnimeBoxesDocumentCodec().encode(document)) as Map;
      (json['bookmarks'] as List).single['postUrl'] =
          'https://danbooru.donmai.us:8443/posts/42';
      final input = const AnimeBoxesDocumentCodec().decode(jsonEncode(json));
      expect(
        () => const BoorusamaMigrationExporter().export(input),
        throwsA(
          isA<AnimeBoxesFormatException>().having(
            (error) => error.code,
            'code',
            'invalid_profile_reference',
          ),
        ),
      );
    },
  );

  test('rejects normalized pins that conflict with their profile site', () {
    final document = _document(fixture: _completeFixture());
    final json =
        jsonDecode(const AnimeBoxesDocumentCodec().encode(document)) as Map;
    (json['pinnedSearchFolders'] as List).single['searches'][0]['url'] =
        'https://danbooru.donmai.us:8443';
    final input = const AnimeBoxesDocumentCodec().decode(jsonEncode(json));
    expect(
      () => const BoorusamaMigrationExporter().export(input),
      throwsA(
        isA<AnimeBoxesFormatException>().having(
          (error) => error.code,
          'code',
          'invalid_profile_reference',
        ),
      ),
    );
  });

  test('reports only aggregate source, retained, and output counts', () {
    final source = const AnimeBoxesCsvReader().parse(
      File(
        'test/migrations/animeboxes/fixtures/complete.csv',
      ).readAsStringSync(),
    );
    final document = const AnimeBoxesNormalizer().normalize(source);

    final report =
        jsonDecode(
              const BoorusamaMigrationExporter().export(document).report,
            )
            as Map<String, dynamic>;

    expect(report['schema'], 'boorusama.animeboxes.conversion-report');
    expect(report['version'], 1);
    expect(report['sourceCounts'], {
      'profiles': 1,
      'history': 1,
      'bookmarks': 1,
      'blacklist': 1,
      'folders': 1,
      'searches': 1,
    });
    expect(report['retainedCounts'], {
      'profiles': 1,
      'history': 1,
      'bookmarks': 1,
      'blacklist': 1,
      'folders': 1,
      'searches': 1,
    });
    expect(report['outputCounts'], {
      'bookmarks': 1,
      'blacklistedTags': 1,
      'pinnedSearchFolders': 1,
      'pinnedSearches': 1,
    });
    expect(
      report.keys,
      unorderedEquals([
        'schema',
        'version',
        'sourceCounts',
        'retainedCounts',
        'outputCounts',
        'diagnostics',
      ]),
    );
    final diagnostics = (report['diagnostics'] as List)
        .cast<Map<String, dynamic>>();
    expect(
      diagnostics.singleWhere(
        (entry) => entry['code'] == 'pinned_search_settings_not_exported',
      )['count'],
      1,
    );
    expect(jsonEncode(report), isNot(contains('rating:general')));
    expect(jsonEncode(report), isNot(contains('blocked, tag')));
    expect(jsonEncode(report), isNot(contains('tag_one')));
    expect(jsonEncode(report), isNot(contains('danbooru.donmai.us')));
  });

  for (final c in [
    (format: 'jpg', isVideo: false),
    (format: 'gif', isVideo: false),
    (format: 'mp4', isVideo: true),
    (format: 'webm', isVideo: true),
  ]) {
    test('exports ${c.format} with video fields set to ${c.isVideo}', () {
      final document = _document(
        fixture: _completeFixture().replaceFirst(
          'original-42.webm',
          'original-42.${c.format}',
        ),
      );

      final common = _bookmarkCommon(
        const BoorusamaMigrationExporter().export(document).bookmarks,
      );

      expect(
        common['videoUrl'],
        c.isVideo ? 'https://cdn.example/original-42.${c.format}' : '',
      );
      expect(
        common['videoThumbnailUrl'],
        c.isVideo ? 'https://cdn.example/preview-42.jpg' : '',
      );
    });
  }

  for (final c in [
    (
      source: 'https://source.example/item/42',
      expected: {'kind': 'web', 'url': 'https://source.example/item/42'},
    ),
    (
      source: 'catalog reference 42',
      expected: {'kind': 'nonWeb', 'value': 'catalog reference 42'},
    ),
    (source: '', expected: {'kind': 'none'}),
  ]) {
    test('exports bookmark source as ${c.expected['kind']}', () {
      final document = _document(
        fixture: _completeFixture().replaceFirst(
          'https://source.example/item/42',
          c.source,
        ),
      );

      final common = _bookmarkCommon(
        const BoorusamaMigrationExporter().export(document).bookmarks,
      );

      expect(common['source'], c.expected);
    });
  }

  test('normalizes a blank folder name only in the production artifact', () {
    final document = _document(
      fixture: _completeFixture().replaceFirst('Folder, café', ''),
    );

    final artifacts = const BoorusamaMigrationExporter().export(document);
    final pinned = jsonDecode(artifacts.pinnedSearches) as Map<String, dynamic>;
    final folder = (pinned['data'] as List).first as Map<String, dynamic>;
    final report = jsonDecode(artifacts.report) as Map<String, dynamic>;

    expect(document.pinnedSearchFolders.single.name, '');
    expect(folder['name'], 'Imported folder 1');
    final diagnostic = (report['diagnostics'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere(
          (entry) => entry['code'] == 'folder_names_normalized_for_export',
        );
    expect(diagnostic['count'], 1);
  });

  test('rejects repeated canonical identities even when media differs', () {
    final first = _document(fixture: _completeFixture());
    final second = _document(
      fixture: _completeFixture().replaceAll(
        'original-42.webm',
        'other-media.webm',
      ),
    );
    expect(
      () => const BoorusamaMigrationExporter().export(
        _withBookmarks(first, [...first.bookmarks, ...second.bookmarks]),
      ),
      throwsA(
        isA<AnimeBoxesFormatException>().having(
          (error) => error.code,
          'code',
          'duplicate_bookmark_output_identity',
        ),
      ),
    );
  });
}

String _completeFixture() => File(
  'test/migrations/animeboxes/fixtures/complete.csv',
).readAsStringSync();

NormalizedAnimeBoxesDocument _document({required String fixture}) =>
    const AnimeBoxesNormalizer().normalize(
      const AnimeBoxesCsvReader().parse(fixture),
    );

Map<String, dynamic> _bookmarkCommon(String artifact) {
  final envelope = jsonDecode(artifact) as Map<String, dynamic>;
  final row = (envelope['data'] as List).single as Map<String, dynamic>;
  final snapshot = row['snapshot'] as Map<String, dynamic>;
  return snapshot['common'] as Map<String, dynamic>;
}

NormalizedAnimeBoxesDocument _withBookmarks(
  NormalizedAnimeBoxesDocument first,
  List<NormalizedAnimeBoxesBookmark> bookmarks,
) => NormalizedAnimeBoxesDocument(
  source: first.source,
  profiles: first.profiles,
  searchHistory: first.searchHistory,
  bookmarks: bookmarks,
  blacklist: first.blacklist,
  pinnedSearchFolders: first.pinnedSearchFolders,
  diagnostics: first.diagnostics,
);

NormalizedAnimeBoxesDocument _pinnedDocument(
  List<(String, Map<String, Object?>)> inputs,
) {
  const codec = AnimeBoxesDocumentCodec();
  final json =
      jsonDecode(codec.encode(_document(fixture: _completeFixture()))) as Map;
  final group = (json['pinnedSearchFolders'] as List).single as Map;
  final template = (group['searches'] as List).single as Map;
  group['searches'] = [
    for (final (index, input) in inputs.indexed)
      {
        ...template,
        'id':
            '22222222-2222-4222-8222-${(index + 1).toString().padLeft(12, '0')}',
        'query': input.$1,
        'extraParams': input.$2,
        'position': index,
        'disableAutoLoad': false,
        'includeBlacklisted': false,
        'initialPage': 0,
      },
  ];
  return codec.decode(jsonEncode(json));
}
