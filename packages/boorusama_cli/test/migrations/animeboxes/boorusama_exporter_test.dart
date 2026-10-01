import 'dart:convert';
import 'dart:io';

import 'package:boorusama_cli/src/migrations/animeboxes/boorusama_exporter.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/csv_reader.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/errors.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/normalizer.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/normalized_types.dart';
import 'package:test/test.dart';

void main() {
  test('exports deterministic production backup envelopes', () {
    final source = const AnimeBoxesCsvReader().parse(
      File(
        'test/migrations/animeboxes/fixtures/complete.csv',
      ).readAsStringSync(),
    );
    final document = const AnimeBoxesNormalizer().normalize(source);

    final artifacts = const BoorusamaMigrationExporter().export(document);

    expect(
      artifacts.bookmarks,
      _golden('boorusama_bookmarks.json'),
    );
    expect(
      artifacts.blacklistedTags,
      _golden('boorusama_blacklisted_tags.json'),
    );
    expect(
      artifacts.pinnedSearches,
      _golden('boorusama_pinned_searches.json'),
    );
  });

  test('exports all bookmarks in a fresh AnimeBoxes group', () {
    final first = _document(fixture: _completeFixture());
    final second = _document(
      fixture: _completeFixture().replaceAll('42', '43'),
    );
    final document = NormalizedAnimeBoxesDocument(
      source: first.source,
      profiles: first.profiles,
      searchHistory: first.searchHistory,
      bookmarks: [...first.bookmarks, ...second.bookmarks],
      blacklist: first.blacklist,
      pinnedSearchFolders: first.pinnedSearchFolders,
      diagnostics: first.diagnostics,
    );

    final envelope =
        jsonDecode(
              const BoorusamaMigrationExporter().export(document).bookmarks,
            )
            as Map<String, dynamic>;

    expect(envelope['groups'], [
      {
        'name': 'AnimeBoxes',
        'bookmarkIds': [1, 2],
      },
    ]);
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

  test(
    'rejects bookmark identities that the production codec would repeat',
    () {
      final first = _document(fixture: _completeFixture());
      final second = _document(
        fixture: _completeFixture().replaceAll(
          'danbooru.donmai.us',
          'donmai.moe',
        ),
      );
      final document = NormalizedAnimeBoxesDocument(
        source: first.source,
        profiles: first.profiles,
        searchHistory: first.searchHistory,
        bookmarks: [...first.bookmarks, ...second.bookmarks],
        blacklist: first.blacklist,
        pinnedSearchFolders: first.pinnedSearchFolders,
        diagnostics: first.diagnostics,
      );

      expect(
        () => const BoorusamaMigrationExporter().export(document),
        throwsA(
          isA<AnimeBoxesFormatException>().having(
            (error) => error.code,
            'code',
            'duplicate_bookmark_output_identity',
          ),
        ),
      );
    },
  );
}

String _golden(String name) => File(
  'test/migrations/animeboxes/fixtures/$name',
).readAsStringSync();

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
