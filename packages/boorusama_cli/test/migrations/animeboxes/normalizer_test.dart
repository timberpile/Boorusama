import 'dart:io';

import 'package:boorusama_cli/src/migrations/animeboxes/csv_reader.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/document_codec.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/errors.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/normalizer.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/source_types.dart';
import 'package:test/test.dart';

void main() {
  test('normalizes every parsed section without retaining credentials', () {
    final source = const AnimeBoxesCsvReader().parse(_completeFixture());

    final document = const AnimeBoxesNormalizer().normalize(source);

    expect(document.profiles.single.credentialsPresent, isTrue);
    expect(document.bookmarks.single.parentId, 123);
    expect(document.bookmarks.single.isTranslated, isTrue);
    expect(document.bookmarks.single.hasComment, isTrue);
    expect(document.bookmarks.single.hasParentOrChildren, isTrue);
    expect(
      document.bookmarks.single.dateAdded.raw,
      '2026-08-14T11:22:33+0200',
    );
    expect(document.searchHistory.single.query, 'quoted, café');
    expect(document.blacklist.single.rule, 'blocked, tag');
    expect(document.pinnedSearchFolders.single.searches, hasLength(1));

    final encoded = const AnimeBoxesDocumentCodec().encode(document);
    for (final secret in [
      'fixture-user-never-serialize',
      'fixture-password-never-serialize',
      'fixture-key-never-serialize',
      'fixture-api-key-never-serialize',
    ]) {
      expect(encoded, isNot(contains(secret)));
    }
  });

  for (final c in [
    (
      host: 'danbooru.donmai.us',
      sourceType: 3,
      engine: 'danbooru',
      typeId: 20,
    ),
    (host: 'donmai.moe', sourceType: 3, engine: 'danbooru', typeId: 20),
    (host: 'gelbooru.com', sourceType: 1, engine: 'gelbooru', typeId: 21),
    (host: 'rule34.xxx', sourceType: 1, engine: 'gelbooruV2', typeId: 23),
    (host: 'realbooru.com', sourceType: 1, engine: 'gelbooruV2', typeId: 23),
    (host: 'konachan.com', sourceType: 0, engine: 'moebooru', typeId: 24),
  ]) {
    test('maps ${c.host} to ${c.engine} type ${c.typeId}', () {
      final source = _sourceForSite(c.host, c.sourceType);

      final document = const AnimeBoxesNormalizer().normalize(source);

      expect(document.profiles.single.engine.name, c.engine);
      expect(document.profiles.single.engine.typeId, c.typeId);
      expect(document.bookmarks.single.engine.name, c.engine);
      expect(
        document.pinnedSearchFolders.single.searches.single.engine.name,
        c.engine,
      );
    });
  }

  for (final c in [
    (source: 's', normalized: 'sensitive'),
    (source: 'safe', normalized: 'sensitive'),
    (source: 'sensitive', normalized: 'sensitive'),
    (source: 'e', normalized: 'explicit'),
    (source: 'explicit', normalized: 'explicit'),
    (source: 'q', normalized: 'questionable'),
    (source: 'questionable', normalized: 'questionable'),
    (source: 'g', normalized: 'general'),
    (source: 'general', normalized: 'general'),
  ]) {
    test('normalizes ${c.source} rating to ${c.normalized}', () {
      final source = _parsedFixture();
      final favorite = _copyFavorite(source.favorites.single, rating: c.source);

      final document = const AnimeBoxesNormalizer().normalize(
        _copyExport(source, favorites: [favorite]),
      );

      expect(document.bookmarks.single.rating, c.normalized);
    });
  }

  for (final format in ['jpg', 'gif', 'mp4', 'webm']) {
    test('infers $format media from the original file URL', () {
      final source = _parsedFixture();
      final favorite = _copyFavorite(
        source.favorites.single,
        fileUrl: 'https://cdn.example/file.$format?download=1',
      );

      final document = const AnimeBoxesNormalizer().normalize(
        _copyExport(source, favorites: [favorite]),
      );

      expect(document.bookmarks.single.format, format);
    });
  }

  for (final c in [
    (name: 'parent only', parentId: 123, hasChildren: false, expected: true),
    (name: 'children only', parentId: null, hasChildren: true, expected: true),
    (name: 'neither', parentId: null, hasChildren: false, expected: false),
  ]) {
    test('derives the combined relationship flag for ${c.name}', () {
      final source = _parsedFixture();
      final favorite = _copyFavorite(
        source.favorites.single,
        parentId: c.parentId,
        replaceParentId: true,
        hasChildren: c.hasChildren,
      );

      final document = const AnimeBoxesNormalizer().normalize(
        _copyExport(source, favorites: [favorite]),
      );
      final bookmark = document.bookmarks.single;

      expect(bookmark.hasParentOrChildren, c.expected);
      expect(
        bookmark.hasParentOrChildren,
        bookmark.hasChildren || bookmark.parentId != null,
      );
      expect(bookmark.dateAdded.raw, favorite.dateAdded.raw);
    });
  }

  test('keeps empty optional bookmark data empty', () {
    final source = _parsedFixture();
    final favorite = _copyFavorite(
      source.favorites.single,
      replaceJpegUrl: true,
      tags: const [],
      generalTags: const [],
      artistTags: const [],
      characterTags: const [],
      copyrightTags: const [],
      replaceExternalSource: true,
    );

    final bookmark = const AnimeBoxesNormalizer()
        .normalize(_copyExport(source, favorites: [favorite]))
        .bookmarks
        .single;

    expect(bookmark.jpeg, isNull);
    expect(bookmark.tags, isEmpty);
    expect(bookmark.generalTags, isEmpty);
    expect(bookmark.artistTags, isEmpty);
    expect(bookmark.characterTags, isEmpty);
    expect(bookmark.copyrightTags, isEmpty);
    expect(bookmark.source, isNull);
  });

  test('round-trips source-supported zero dimensions and initial page', () {
    final source = _parsedFixture();
    final favorite = _copyFavorite(
      source.favorites.single,
      previewWidth: 0,
      previewHeight: 0,
      sampleWidth: 0,
      sampleHeight: 0,
      width: 0,
      height: 0,
    );
    final search = _copySearch(source.pinnedSearches.single, initialPage: 0);
    final document = const AnimeBoxesNormalizer().normalize(
      _copyExport(source, favorites: [favorite], pinnedSearches: [search]),
    );

    final decoded = const AnimeBoxesDocumentCodec().decode(
      const AnimeBoxesDocumentCodec().encode(document),
    );

    expect(decoded.bookmarks.single.preview.width, 0);
    expect(decoded.bookmarks.single.original.height, 0);
    expect(decoded.pinnedSearchFolders.single.searches.single.initialPage, 0);
  });

  test('round-trips a source-supported unnamed folder', () {
    final source = _parsedFixture();
    final folder = _copyFolder(source.folders.single, name: '');
    final document = const AnimeBoxesNormalizer().normalize(
      _copyExport(source, folders: [folder]),
    );

    final decoded = const AnimeBoxesDocumentCodec().decode(
      const AnimeBoxesDocumentCodec().encode(document),
    );

    expect(decoded.pinnedSearchFolders.single.name, '');
  });

  test('keeps the newest duplicate bookmark and records source positions', () {
    final source = _parsedFixture();
    final older = _copyFavorite(
      source.favorites.single,
      score: 1,
      sourcePosition: 0,
      dateAdded: _sourceTimestamp('2026-08-14T10:00:00+0200'),
    );
    final newer = _copyFavorite(
      source.favorites.single,
      score: 2,
      sourceRow: source.favorites.single.sourceRow + 1,
      sourcePosition: 1,
      dateAdded: _sourceTimestamp('2026-08-14T11:00:00+0200'),
    );

    final document = const AnimeBoxesNormalizer().normalize(
      _copyExport(source, favorites: [older, newer]),
    );

    expect(document.bookmarks.single.score, 2);
    final diagnostic = document.diagnostics.singleWhere(
      (entry) => entry.code == 'duplicate_bookmark',
    );
    expect(diagnostic.count, 1);
    expect(diagnostic.sourcePositions, [1, 0]);
  });

  test('breaks equal duplicate timestamps by greatest source position', () {
    final source = _parsedFixture();
    final timestamp = _sourceTimestamp('2026-08-14T11:00:00+0200');
    final first = _copyFavorite(
      source.favorites.single,
      score: 1,
      sourcePosition: 0,
      dateAdded: timestamp,
    );
    final second = _copyFavorite(
      source.favorites.single,
      score: 2,
      sourceRow: source.favorites.single.sourceRow + 1,
      sourcePosition: 1,
      dateAdded: timestamp,
    );

    final document = const AnimeBoxesNormalizer().normalize(
      _copyExport(source, favorites: [first, second]),
    );

    expect(document.bookmarks.single.score, 2);
    expect(
      document.diagnostics
          .singleWhere((entry) => entry.code == 'duplicate_bookmark')
          .sourcePositions,
      [1, 0],
    );
  });

  test('normalizes the same source to byte-identical JSON', () {
    final source = _parsedFixture();
    const normalizer = AnimeBoxesNormalizer();
    const codec = AnimeBoxesDocumentCodec();

    expect(
      codec.encode(normalizer.normalize(source)),
      codec.encode(normalizer.normalize(source)),
    );
  });

  test('normalizes an ungrouped source search into the Home group', () {
    final fixture = _completeFixture().replaceFirst(
      '4,11111111-1111-4111-8111-111111111111,22222222',
      '4,,22222222',
    );
    final source = const AnimeBoxesCsvReader().parse(fixture);

    final groups = const AnimeBoxesNormalizer()
        .normalize(source)
        .pinnedSearchFolders;

    expect(groups, hasLength(2));
    expect(groups.last.kind, 'home');
    expect(groups.last.id, isNull);
    expect(groups.last.searches.single.id, startsWith('22222222'));
  });

  test('preserves global source search order across different folders', () {
    final source = _parsedFixture();
    final firstFolder = _copyFolder(
      source.folders.single,
      name: 'First',
      sourcePosition: 0,
    );
    final secondFolder = _copyFolder(
      source.folders.single,
      id: '33333333-3333-4333-8333-333333333333',
      name: 'Second',
      sourcePosition: 1,
    );
    final secondFolderSearch = _copySearch(
      source.pinnedSearches.single,
      id: '44444444-4444-4444-8444-444444444444',
      folderId: secondFolder.id,
      sourcePosition: 2,
    );
    final firstFolderSearch = _copySearch(
      source.pinnedSearches.single,
      folderId: firstFolder.id,
      sourcePosition: 3,
    );

    final document = const AnimeBoxesNormalizer().normalize(
      _copyExport(
        source,
        folders: [firstFolder, secondFolder],
        pinnedSearches: [secondFolderSearch, firstFolderSearch],
      ),
    );
    final searches = {
      for (final group in document.pinnedSearchFolders)
        for (final search in group.searches) search.id: search,
    };

    expect(searches[secondFolderSearch.id]!.position, 0);
    expect(searches[firstFolderSearch.id]!.position, 1);
  });

  for (final sensitiveKey in ['password', 'api_key', 'access-token']) {
    test(
      'rejects sensitive query parameter $sensitiveKey without reporting its value',
      () {
        const secret = 'fixture-query-secret-never-report';
        final source = _parsedFixture();
        final search = _copySearch(
          source.pinnedSearches.single,
          extraParams: {
            'nested': {sensitiveKey: secret},
          },
        );

        try {
          const AnimeBoxesNormalizer().normalize(
            _copyExport(source, pinnedSearches: [search]),
          );
          fail('Expected sensitive query data to be rejected');
        } on AnimeBoxesFormatException catch (error) {
          expect(error.code, 'sensitive_query_data');
          expect(error.toString(), isNot(contains(secret)));
          expect(error.source, isNull);
        }
      },
    );
  }

  for (final c in [
    (
      name: 'orphan folder reference',
      mutate: (AnimeBoxesExport source) => _copyExport(
        source,
        pinnedSearches: [
          _copySearch(source.pinnedSearches.single, folderId: 'missing'),
        ],
      ),
      code: 'orphan_pinned_search',
    ),
    (
      name: 'duplicate folder UUID',
      mutate: (AnimeBoxesExport source) => _copyExport(
        source,
        folders: [source.folders.single, source.folders.single],
      ),
      code: 'duplicate_folder_id',
    ),
    (
      name: 'duplicate search UUID',
      mutate: (AnimeBoxesExport source) => _copyExport(
        source,
        pinnedSearches: [
          source.pinnedSearches.single,
          _copySearch(
            source.pinnedSearches.single,
            sourceRow: source.pinnedSearches.single.sourceRow + 1,
            sourcePosition: source.pinnedSearches.single.sourcePosition + 1,
          ),
        ],
      ),
      code: 'duplicate_search_id',
    ),
    (
      name: 'engine disagreement',
      mutate: (AnimeBoxesExport source) => _copyExport(
        source,
        servers: [_copyServer(source.servers.single, type: 1)],
      ),
      code: 'engine_mismatch',
    ),
    (
      name: 'unknown host',
      mutate: (AnimeBoxesExport source) => _copyExport(
        source,
        servers: [
          _copyServer(
            source.servers.single,
            url: 'https://example.com',
            realUrl: 'https://example.com',
          ),
        ],
      ),
      code: 'unsupported_engine',
    ),
  ]) {
    test('rejects ${c.name}', () {
      expect(
        () =>
            const AnimeBoxesNormalizer().normalize(c.mutate(_parsedFixture())),
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
}

String _completeFixture() => File(
  'test/migrations/animeboxes/fixtures/complete.csv',
).readAsStringSync();

AnimeBoxesExport _parsedFixture() =>
    const AnimeBoxesCsvReader().parse(_completeFixture());

AnimeBoxesExport _sourceForSite(String host, int sourceType) {
  final source = _parsedFixture();
  final root = 'https://$host';
  return _copyExport(
    source,
    servers: [
      _copyServer(
        source.servers.single,
        url: root,
        realUrl: root,
        type: sourceType,
      ),
    ],
    favorites: [
      _copyFavorite(source.favorites.single, postUrl: '$root/posts/42'),
    ],
    pinnedSearches: [_copySearch(source.pinnedSearches.single, url: root)],
  );
}

AnimeBoxesExport _copyExport(
  AnimeBoxesExport source, {
  List<AnimeBoxesServer>? servers,
  List<AnimeBoxesHistoryEntry>? history,
  List<AnimeBoxesFavorite>? favorites,
  List<AnimeBoxesBlacklistEntry>? blacklist,
  List<AnimeBoxesPinFolder>? folders,
  List<AnimeBoxesPinnedSearch>? pinnedSearches,
}) => AnimeBoxesExport(
  metadata: source.metadata,
  servers: servers ?? source.servers,
  history: history ?? source.history,
  favorites: favorites ?? source.favorites,
  blacklist: blacklist ?? source.blacklist,
  folders: folders ?? source.folders,
  pinnedSearches: pinnedSearches ?? source.pinnedSearches,
);

AnimeBoxesServer _copyServer(
  AnimeBoxesServer source, {
  String? url,
  String? realUrl,
  int? type,
}) => AnimeBoxesServer(
  serverId: source.serverId,
  url: url ?? source.url,
  name: source.name,
  useNativeAutocomplete: source.useNativeAutocomplete,
  ratingFilterEnabled: source.ratingFilterEnabled,
  selected: source.selected,
  isDefault: source.isDefault,
  type: type ?? source.type,
  loginPresent: source.loginPresent,
  credentialsPresent: source.credentialsPresent,
  realUrl: realUrl ?? source.realUrl,
  sourceRow: source.sourceRow,
  sourcePosition: source.sourcePosition,
);

AnimeBoxesFavorite _copyFavorite(
  AnimeBoxesFavorite source, {
  String? postUrl,
  String? fileUrl,
  int? sampleWidth,
  int? sampleHeight,
  int? previewWidth,
  int? previewHeight,
  int? width,
  int? height,
  String? jpegUrl,
  bool replaceJpegUrl = false,
  List<String>? tags,
  List<String>? generalTags,
  List<String>? artistTags,
  List<String>? characterTags,
  List<String>? copyrightTags,
  String? externalSource,
  bool replaceExternalSource = false,
  int? parentId,
  bool replaceParentId = false,
  int? score,
  String? rating,
  bool? hasChildren,
  AnimeBoxesSourceTimestamp? dateAdded,
  int? sourceRow,
  int? sourcePosition,
}) => AnimeBoxesFavorite(
  postId: source.postId,
  postUrl: postUrl ?? source.postUrl,
  sampleWidth: sampleWidth ?? source.sampleWidth,
  sampleHeight: sampleHeight ?? source.sampleHeight,
  sampleUrl: source.sampleUrl,
  previewWidth: previewWidth ?? source.previewWidth,
  previewHeight: previewHeight ?? source.previewHeight,
  previewUrl: source.previewUrl,
  width: width ?? source.width,
  height: height ?? source.height,
  fileUrl: fileUrl ?? source.fileUrl,
  jpegWidth: source.jpegWidth,
  jpegHeight: source.jpegHeight,
  jpegUrl: replaceJpegUrl ? jpegUrl : jpegUrl ?? source.jpegUrl,
  tags: tags ?? source.tags,
  generalTags: generalTags ?? source.generalTags,
  artistTags: artistTags ?? source.artistTags,
  characterTags: characterTags ?? source.characterTags,
  copyrightTags: copyrightTags ?? source.copyrightTags,
  md5: source.md5,
  source: replaceExternalSource
      ? externalSource
      : externalSource ?? source.source,
  parentId: replaceParentId ? parentId : parentId ?? source.parentId,
  score: score ?? source.score,
  rating: rating ?? source.rating,
  hasNotes: source.hasNotes,
  hasComments: source.hasComments,
  hasChildren: hasChildren ?? source.hasChildren,
  dateAdded: dateAdded ?? source.dateAdded,
  sourceRow: sourceRow ?? source.sourceRow,
  sourcePosition: sourcePosition ?? source.sourcePosition,
);

AnimeBoxesPinnedSearch _copySearch(
  AnimeBoxesPinnedSearch source, {
  String? folderId,
  String? id,
  String? url,
  int? initialPage,
  Map<String, Object?>? extraParams,
  int? sourceRow,
  int? sourcePosition,
}) => AnimeBoxesPinnedSearch(
  folderId: folderId ?? source.folderId,
  id: id ?? source.id,
  url: url ?? source.url,
  name: source.name,
  query: source.query,
  disableAutoLoad: source.disableAutoLoad,
  includeBlacklisted: source.includeBlacklisted,
  initialPage: initialPage ?? source.initialPage,
  extraParams: extraParams ?? source.extraParams,
  sourceRow: sourceRow ?? source.sourceRow,
  sourcePosition: sourcePosition ?? source.sourcePosition,
);

AnimeBoxesPinFolder _copyFolder(
  AnimeBoxesPinFolder source, {
  String? id,
  required String name,
  int? sourcePosition,
}) => AnimeBoxesPinFolder(
  id: id ?? source.id,
  name: name,
  query: source.query,
  disableAutoLoad: source.disableAutoLoad,
  includeBlacklisted: source.includeBlacklisted,
  initialPage: source.initialPage,
  extraParams: source.extraParams,
  sourceRow: source.sourceRow,
  sourcePosition: sourcePosition ?? source.sourcePosition,
);

AnimeBoxesSourceTimestamp _sourceTimestamp(String raw) =>
    AnimeBoxesSourceTimestamp(raw: raw, instant: DateTime.parse(raw));
