import 'dart:io';

import 'package:boorusama_cli/src/migrations/animeboxes/csv_reader.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/errors.dart';
import 'package:test/test.dart';

void main() {
  test('parses every Android 1.0 section into typed source records', () {
    final source = const AnimeBoxesCsvReader().parse(_completeFixture());

    expect(source.metadata.formatVersion, '1.0');
    expect(source.servers, hasLength(1));
    expect(source.history, hasLength(1));
    expect(source.favorites, hasLength(1));
    expect(source.blacklist, hasLength(1));
    expect(source.folders, hasLength(1));
    expect(source.pinnedSearches, hasLength(1));
  });

  test('names every supported source field without retaining secrets', () {
    final source = const AnimeBoxesCsvReader().parse(_completeFixture());

    expect(source.metadata.creatorName, 'Anime boxes (Android)');
    expect(source.metadata.creatorVersion, '2.0.7');
    expect(source.metadata.exportedAt.raw, '2026-08-16T08:48:50+0200');

    final server = source.servers.single;
    expect(server.serverId, 2);
    expect(server.url, 'https://danbooru.donmai.us');
    expect(server.name, 'Donmai Fixture');
    expect(server.useNativeAutocomplete, isFalse);
    expect(server.ratingFilterEnabled, isTrue);
    expect(server.selected, isFalse);
    expect(server.isDefault, isTrue);
    expect(server.type, 3);
    expect(server.loginPresent, isTrue);
    expect(server.credentialsPresent, isTrue);
    expect(server.realUrl, 'https://danbooru.donmai.us');

    final history = source.history.single;
    expect(history.itemId, 7);
    expect(history.query, 'quoted, café');
    expect(history.searchedAt.raw, '2026-08-15T12:00:00+0200');
    expect(history.starred, isTrue);

    final blacklist = source.blacklist.single;
    expect(blacklist.rule, 'blocked, tag');
    expect(blacklist.sourceId, 11);

    for (final secret in [
      'fixture-user-never-serialize',
      'fixture-password-never-serialize',
      'fixture-key-never-serialize',
      'fixture-api-key-never-serialize',
    ]) {
      expect(source.toString(), isNot(contains(secret)));
      expect(server.toString(), isNot(contains(secret)));
    }
  });

  test('maps all favorite columns to their exact source meaning', () {
    final favorite = const AnimeBoxesCsvReader()
        .parse(_completeFixture())
        .favorites
        .single;

    expect(favorite.postId, 42);
    expect(favorite.postUrl, 'https://danbooru.donmai.us/posts/42');
    expect((favorite.sampleWidth, favorite.sampleHeight), (640, 480));
    expect(favorite.sampleUrl, 'https://cdn.example/sample-42.jpg');
    expect((favorite.previewWidth, favorite.previewHeight), (320, 240));
    expect(favorite.previewUrl, 'https://cdn.example/preview-42.jpg');
    expect((favorite.width, favorite.height), (1920, 1080));
    expect(favorite.fileUrl, 'https://cdn.example/original-42.webm');
    expect((favorite.jpegWidth, favorite.jpegHeight), (1280, 720));
    expect(favorite.jpegUrl, 'https://cdn.example/jpeg-42.jpg');
    expect(favorite.tags, ['tag_one', 'tag_two']);
    expect(favorite.generalTags, ['general_one']);
    expect(favorite.artistTags, ['artist_one']);
    expect(favorite.characterTags, ['character_one']);
    expect(favorite.copyrightTags, ['copyright_one']);
    expect(favorite.md5, '0123456789abcdef0123456789abcdef');
    expect(favorite.source, 'https://source.example/item/42');
    expect(favorite.parentId, 123);
    expect(favorite.score, 17);
    expect(favorite.rating, 'questionable');
    expect(favorite.hasNotes, isTrue);
    expect(favorite.hasComments, isTrue);
    expect(favorite.hasChildren, isFalse);
    expect(favorite.dateAdded.raw, '2026-08-14T11:22:33+0200');
    expect(favorite.sourcePosition, 0);
  });

  test('parses folder and search query settings with exact membership', () {
    final source = const AnimeBoxesCsvReader().parse(_completeFixture());

    final folder = source.folders.single;
    expect(folder.id, '11111111-1111-4111-8111-111111111111');
    expect(folder.name, 'Folder, café');
    expect(folder.query, 'Folder, café');

    final search = source.pinnedSearches.single;
    expect(search.folderId, folder.id);
    expect(search.id, '22222222-2222-4222-8222-222222222222');
    expect(search.url, 'https://danbooru.donmai.us');
    expect(search.query, 'rating:general');
    expect(search.name, 'Quoted "title"');
    expect(search.disableAutoLoad, isTrue);
    expect(search.includeBlacklisted, isTrue);
    expect(search.initialPage, 2);
  });

  test('reads folder labels from text without changing search titles', () {
    final fixture = _completeFixture().replaceFirst(
      '""text"":""Folder, café"",""title"":""""',
      '""text"":""Folder text"",""title"":""""',
    );
    final source = const AnimeBoxesCsvReader().parse(fixture);
    expect(source.folders.single.name, 'Folder text');
    expect(source.pinnedSearches.single.name, 'Quoted "title"');
    expect(source.pinnedSearches.single.query, 'rating:general');
  });

  for (final marker in [
    '#Meta',
    '#Servers',
    '#History',
    '#Favorites',
    '#Tag Blacklist',
    '#Home Pins',
  ]) {
    test('rejects a missing $marker section', () {
      expect(
        () => const AnimeBoxesCsvReader().parse(
          _removeSection(_completeFixture(), marker),
        ),
        throwsA(
          isA<AnimeBoxesFormatException>().having(
            (error) => error.code,
            'code',
            'missing_section',
          ),
        ),
      );
    });

    test('rejects a repeated $marker section', () {
      final repeated = '${_completeFixture()}\r\n$marker\r\n';
      expect(
        () => const AnimeBoxesCsvReader().parse(repeated),
        throwsA(
          isA<AnimeBoxesFormatException>().having(
            (error) => error.code,
            'code',
            'repeated_section',
          ),
        ),
      );
    });

    test('rejects an incorrect row width in $marker', () {
      expect(
        () => const AnimeBoxesCsvReader().parse(
          _mutateFirstRow(
            _completeFixture(),
            marker,
            (row) => '$row,unexpected',
          ),
        ),
        throwsA(
          isA<AnimeBoxesFormatException>().having(
            (error) => error.code,
            'code',
            'invalid_row_width',
          ),
        ),
      );
    });
  }

  for (final c in [
    (
      name: 'format version',
      input: _completeFixture().replaceFirst(',1.0,', ',2.0,'),
    ),
    (
      name: 'creator',
      input: _completeFixture().replaceFirst(
        'Anime boxes (Android)',
        'Anime boxes (Desktop)',
      ),
    ),
  ]) {
    test('rejects an unsupported ${c.name}', () {
      expect(
        () => const AnimeBoxesCsvReader().parse(c.input),
        throwsA(
          isA<AnimeBoxesFormatException>().having(
            (error) => error.code,
            'code',
            'unsupported_format',
          ),
        ),
      );
    });
  }

  for (final c in [
    (
      name: 'integer',
      input: _completeFixture().replaceFirst(
        ',42,https://',
        ',forty-two,https://',
      ),
      code: 'invalid_integer',
    ),
    (
      name: 'boolean',
      input: _completeFixture().replaceFirst(
        ',1,1,0,2026-',
        ',1,maybe,0,2026-',
      ),
      code: 'invalid_boolean',
    ),
    (
      name: 'URL',
      input: _completeFixture().replaceFirst(
        'https://cdn.example/sample-42.jpg',
        'not-a-url',
      ),
      code: 'invalid_url',
    ),
    (
      name: 'rating',
      input: _completeFixture().replaceFirst(',questionable,', ',mature,'),
      code: 'invalid_rating',
    ),
    (
      name: 'timestamp',
      input: _completeFixture().replaceFirst(
        '2026-08-14T11:22:33+0200',
        'not-a-date',
      ),
      code: 'invalid_timestamp',
    ),
  ]) {
    test('rejects an invalid required ${c.name}', () {
      expect(
        () => const AnimeBoxesCsvReader().parse(c.input),
        throwsA(
          isA<AnimeBoxesFormatException>().having(
            (error) => error.code,
            'code',
            c.code,
          ),
        ),
      );
    });
  }

  test('treats blank and zero parent IDs as absent', () {
    final blank = _completeFixture().replaceFirst(
      ',123,17,questionable,',
      ',,17,questionable,',
    );
    final zero = _completeFixture().replaceFirst(
      ',123,17,questionable,',
      ',0,17,questionable,',
    );

    expect(
      const AnimeBoxesCsvReader().parse(blank).favorites.single.parentId,
      isNull,
    );
    expect(
      const AnimeBoxesCsvReader().parse(zero).favorites.single.parentId,
      isNull,
    );
  });

  test('rejects nonempty reserved columns instead of discarding data', () {
    final input = _completeFixture().replaceFirst(
      '2026-08-14T11:22:33+0200,,,,,,,,,,',
      '2026-08-14T11:22:33+0200,future-value,,,,,,,,,',
    );

    expect(
      () => const AnimeBoxesCsvReader().parse(input),
      throwsA(
        isA<AnimeBoxesFormatException>().having(
          (error) => error.code,
          'code',
          'unmapped_column',
        ),
      ),
    );
  });

  test('accepts a UTF-8 BOM and CRLF source with quoted Unicode fields', () {
    final input = '\ufeff${_completeFixture()}';

    final source = const AnimeBoxesCsvReader().parse(input);

    expect(source.history.single.query, 'quoted, café');
    expect(source.folders.single.name, 'Folder, café');
  });

  test('rejects an unknown home pin type', () {
    final input = _completeFixture().replaceFirst(
      ',3,"{""disable',
      ',9,"{""disable',
    );

    expect(
      () => const AnimeBoxesCsvReader().parse(input),
      throwsA(
        isA<AnimeBoxesFormatException>().having(
          (error) => error.code,
          'code',
          'invalid_pin_type',
        ),
      ),
    );
  });

  test('never includes a rejected cell value in an exception', () {
    const secret = 'fixture-invalid-secret-never-report';
    final input = _completeFixture().replaceFirst(
      'https://cdn.example/sample-42.jpg',
      secret,
    );

    try {
      const AnimeBoxesCsvReader().parse(input);
      fail('Expected invalid URL');
    } on AnimeBoxesFormatException catch (error) {
      expect(error.toString(), isNot(contains(secret)));
      expect(error.source, isNull);
    }
  });
}

String _completeFixture() => File(
  'test/migrations/animeboxes/fixtures/complete.csv',
).readAsStringSync();

String _removeSection(String source, String marker) {
  final lines = source.split('\r\n');
  final markerIndex = lines.indexOf(marker);
  lines.removeRange(markerIndex, markerIndex + 2);
  return lines.join('\r\n');
}

String _mutateFirstRow(
  String source,
  String marker,
  String Function(String row) mutate,
) {
  final lines = source.split('\r\n');
  final markerIndex = lines.indexOf(marker);
  lines[markerIndex + 1] = mutate(lines[markerIndex + 1]);
  return lines.join('\r\n');
}
