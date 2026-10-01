import 'dart:convert';

import 'package:boorusama_cli/src/migrations/animeboxes/document_codec.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/errors.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/normalized_types.dart';
import 'package:test/test.dart';

void main() {
  test('round-trips every normalized section without changing order', () {
    const codec = AnimeBoxesDocumentCodec();
    final document = _completeDocument();

    final encoded = codec.encode(document);
    final decoded = codec.decode(encoded);

    expect(
      encoded,
      startsWith(
        '{\n'
        '  "schema": "boorusama.animeboxes.normalized",\n'
        '  "version": 1,',
      ),
    );
    expect(codec.encode(decoded), encoded);
    expect(decoded.profiles.single.sourceId, 2);
    expect(decoded.searchHistory.single.query, 'quoted, café');
    expect(decoded.bookmarks.single.postId, 42);
    expect(decoded.blacklist.single.rule, 'blocked, tag');
    expect(
      decoded.pinnedSearchFolders.single.searches.single.query,
      'rating:general',
    );
    expect(decoded.diagnostics.single.sourcePositions, [0, 1]);
  });

  test('preserves source timestamp offsets verbatim', () {
    const codec = AnimeBoxesDocumentCodec();

    final encoded = codec.encode(_completeDocument());
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;

    expect(
      (decoded['source'] as Map<String, dynamic>)['exportedAt'],
      '2026-08-16T08:48:50+0200',
    );
    expect(
      ((decoded['bookmarks'] as List).single
          as Map<String, dynamic>)['dateAdded'],
      '2026-08-14T11:22:33+0200',
    );
  });

  for (final c in [
    (
      name: 'wrong schema',
      mutate: (Map<String, dynamic> json) => json['schema'] = 'other.schema',
    ),
    (
      name: 'wrong version',
      mutate: (Map<String, dynamic> json) => json['version'] = 2,
    ),
    (
      name: 'missing root key',
      mutate: (Map<String, dynamic> json) => json.remove('profiles'),
    ),
    (
      name: 'unknown root key',
      mutate: (Map<String, dynamic> json) => json['future'] = true,
    ),
    (
      name: 'unknown nested key',
      mutate: (Map<String, dynamic> json) =>
          _first(json, 'profiles')['future'] = true,
    ),
    (
      name: 'wrong primitive type',
      mutate: (Map<String, dynamic> json) =>
          _first(json, 'profiles')['sourceId'] = '2',
    ),
    (
      name: 'invalid timestamp',
      mutate: (Map<String, dynamic> json) =>
          (json['source'] as Map<String, dynamic>)['exportedAt'] = 'tomorrow',
    ),
    (
      name: 'invalid URL',
      mutate: (Map<String, dynamic> json) =>
          _first(json, 'profiles')['url'] = 'danbooru',
    ),
    (
      name: 'invalid UUID',
      mutate: (Map<String, dynamic> json) =>
          _first(json, 'pinnedSearchFolders')['id'] = 'folder-one',
    ),
    (
      name: 'unknown engine',
      mutate: (Map<String, dynamic> json) =>
          (_first(json, 'profiles')['engine'] as Map<String, dynamic>)['name'] =
              'futureBooru',
    ),
    (
      name: 'mismatched engine ID',
      mutate: (Map<String, dynamic> json) =>
          (_first(json, 'profiles')['engine']
                  as Map<String, dynamic>)['typeId'] =
              23,
    ),
    (
      name: 'host not matching URL',
      mutate: (Map<String, dynamic> json) =>
          _first(json, 'profiles')['host'] = 'example.com',
    ),
    (
      name: 'duplicate bookmark identity',
      mutate: (Map<String, dynamic> json) => (json['bookmarks'] as List).add(
        Map<String, dynamic>.from(_first(json, 'bookmarks')),
      ),
    ),
    (
      name: 'duplicate search membership',
      mutate: (Map<String, dynamic> json) {
        final group = Map<String, dynamic>.from(
          _first(json, 'pinnedSearchFolders'),
        );
        group['id'] = '33333333-3333-4333-8333-333333333333';
        group['name'] = 'Second folder';
        (json['pinnedSearchFolders'] as List).add(group);
      },
    ),
    (
      name: 'unknown rating',
      mutate: (Map<String, dynamic> json) =>
          _first(json, 'bookmarks')['rating'] = 'mature',
    ),
    (
      name: 'inconsistent parent relationship',
      mutate: (Map<String, dynamic> json) =>
          _first(json, 'bookmarks')['hasParentOrChildren'] = false,
    ),
  ]) {
    test('rejects ${c.name}', () {
      final json = _encodedMap();
      c.mutate(json);

      expect(
        () => const AnimeBoxesDocumentCodec().decode(jsonEncode(json)),
        throwsA(isA<AnimeBoxesFormatException>()),
      );
    });
  }

  for (final c in [
    (field: 'username', target: 'root'),
    (field: 'apiKey', target: 'profile'),
    (field: 'password', target: 'bookmark'),
    (field: 'cookie', target: 'search'),
    (field: 'authorization', target: 'diagnostic'),
  ]) {
    test('rejects sensitive-looking ${c.field} key at ${c.target}', () {
      const secret = 'fixture-sensitive-value-never-report';
      final json = _encodedMap();
      final target = switch (c.target) {
        'root' => json,
        'profile' => _first(json, 'profiles'),
        'bookmark' => _first(json, 'bookmarks'),
        'search' => _first(
          _first(json, 'pinnedSearchFolders'),
          'searches',
        ),
        'diagnostic' => _first(json, 'diagnostics'),
        _ => throw StateError('Unknown fixture target'),
      };
      target[c.field] = secret;

      try {
        const AnimeBoxesDocumentCodec().decode(jsonEncode(json));
        fail('Expected strict schema rejection');
      } on AnimeBoxesFormatException catch (error) {
        expect(error.toString(), isNot(contains(secret)));
        expect(error.source, isNull);
      }
    });
  }

  test('rejects normalized nested access token variants', () {
    const secret = 'fixture-sensitive-value-never-report';
    final json = _encodedMap();
    final search = _first(_first(json, 'pinnedSearchFolders'), 'searches');
    search['extraParams'] = {
      'nested': {'access_token': secret},
    };

    try {
      const AnimeBoxesDocumentCodec().decode(jsonEncode(json));
      fail('Expected sensitive query data to be rejected');
    } on AnimeBoxesFormatException catch (error) {
      expect(error.toString(), isNot(contains(secret)));
      expect(error.source, isNull);
    }
  });
}

Map<String, dynamic> _encodedMap() =>
    jsonDecode(
          const AnimeBoxesDocumentCodec().encode(_completeDocument()),
        )
        as Map<String, dynamic>;

Map<String, dynamic> _first(Map<String, dynamic> json, String field) =>
    (json[field] as List).first as Map<String, dynamic>;

NormalizedAnimeBoxesDocument _completeDocument() {
  const engine = AnimeBoxesEngine(name: 'danbooru', typeId: 20);
  return NormalizedAnimeBoxesDocument(
    source: NormalizedAnimeBoxesSource(
      formatVersion: '1.0',
      creatorName: 'Anime boxes (Android)',
      creatorVersion: '2.0.7',
      exportedAt: AnimeBoxesTimestamp.parse('2026-08-16T08:48:50+0200'),
    ),
    profiles: const [
      NormalizedAnimeBoxesProfile(
        sourceId: 2,
        name: 'Donmai Fixture',
        url: 'https://danbooru.donmai.us',
        host: 'danbooru.donmai.us',
        engine: engine,
        useNativeAutocomplete: false,
        ratingFilterEnabled: true,
        selected: false,
        isDefault: true,
        loginPresent: true,
        credentialsPresent: true,
        sourcePosition: 0,
      ),
    ],
    searchHistory: [
      NormalizedAnimeBoxesHistoryEntry(
        sourceId: 7,
        query: 'quoted, café',
        searchedAt: AnimeBoxesTimestamp.parse('2026-08-15T12:00:00+0200'),
        starred: true,
        sourcePosition: 0,
      ),
    ],
    bookmarks: [
      NormalizedAnimeBoxesBookmark(
        sourceProfileId: 2,
        host: 'danbooru.donmai.us',
        engine: engine,
        postId: 42,
        postUrl: 'https://danbooru.donmai.us/posts/42',
        preview: const AnimeBoxesMediaVariant(
          url: 'https://cdn.example/preview-42.jpg',
          width: 320,
          height: 240,
        ),
        sample: const AnimeBoxesMediaVariant(
          url: 'https://cdn.example/sample-42.jpg',
          width: 640,
          height: 480,
        ),
        original: const AnimeBoxesMediaVariant(
          url: 'https://cdn.example/original-42.webm',
          width: 1920,
          height: 1080,
        ),
        jpeg: const AnimeBoxesMediaVariant(
          url: 'https://cdn.example/jpeg-42.jpg',
          width: 1280,
          height: 720,
        ),
        format: 'webm',
        tags: const ['tag_one', 'tag_two'],
        generalTags: const ['general_one'],
        artistTags: const ['artist_one'],
        characterTags: const ['character_one'],
        copyrightTags: const ['copyright_one'],
        md5: '0123456789abcdef0123456789abcdef',
        source: 'https://source.example/item/42',
        parentId: 123,
        score: 17,
        rating: 'questionable',
        isTranslated: true,
        hasComment: true,
        hasChildren: false,
        hasParentOrChildren: true,
        dateAdded: AnimeBoxesTimestamp.parse('2026-08-14T11:22:33+0200'),
        sourcePosition: 0,
      ),
    ],
    blacklist: const [
      NormalizedAnimeBoxesBlacklistEntry(
        sourceId: 11,
        rule: 'blocked, tag',
        sourcePosition: 0,
      ),
    ],
    pinnedSearchFolders: [
      NormalizedAnimeBoxesPinnedGroup.folder(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Folder, café',
        sourcePosition: 0,
        searches: [
          NormalizedAnimeBoxesPinnedSearch(
            id: '22222222-2222-4222-8222-222222222222',
            sourceProfileId: 2,
            name: 'Quoted "title"',
            query: 'rating:general',
            position: 0,
            url: 'https://danbooru.donmai.us',
            host: 'danbooru.donmai.us',
            engine: engine,
            disableAutoLoad: true,
            includeBlacklisted: true,
            initialPage: 2,
            extraParams: {},
          ),
        ],
      ),
    ],
    diagnostics: [
      AnimeBoxesDiagnostic(
        code: 'duplicate_bookmark',
        count: 1,
        section: 'Favorites',
        sourcePositions: [0, 1],
      ),
    ],
  );
}
