import 'package:boorusama/core/bookmarks/src/data/bookmark_tag_color.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_tag_index.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/tags/tag/colors.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final index = BookmarkTagIndex.fromBookmarks([
    Bookmark.empty.copyWith(
      id: 1,
      tags: {'one_piece', 'blue_hair', 'smile'},
    ),
    Bookmark.empty.copyWith(id: 2, tags: {'ONE_PIECE', 'glasses'}),
  ]);

  test(
    'counts canonical tags once per bookmark with deterministic ordering',
    () {
      expect(index.byName['one_piece']!.count, 2);
      expect(index.entries.first.tag, 'one_piece');
      expect(index.entries.map((e) => e.tag), [
        'one_piece',
        'blue_hair',
        'glasses',
        'smile',
      ]);
    },
  );

  for (final draft in ['one piece', '-ONE PIECE', 'blue_hair -one pi']) {
    test('suggests the complete readable tag for $draft', () {
      expect(index.suggestions(draft).map((e) => e.tag), ['one_piece']);
    });
  }

  test('excludes selected tags without hiding their opposite operator', () {
    expect(index.suggestions('one pi', selectedTags: {'one_piece'}), isEmpty);
    expect(
      index.suggestions('-one pi', selectedTags: {'one_piece'}).single.tag,
      'one_piece',
    );
  });

  for (final draft in ['', ' \t ']) {
    test('lists every available tag by frequency for empty input "$draft"', () {
      final ranked = BookmarkTagIndex([
        for (final (tag, count) in [
          ('zeta', 1),
          ('beta', 3),
          ('gamma', 2),
          ('alpha', 3),
          ('delta', 1),
          ('epsilon', 1),
          ('eta', 1),
        ])
          BookmarkTagEntry(tag: tag, count: count, sources: const {}),
      ]);
      expect(
        ranked
            .suggestions(draft, selectedTags: {'alpha', '-beta'})
            .map((e) => e.tag),
        ['beta', 'gamma', 'delta', 'epsilon', 'eta', 'zeta'],
      );
    });
  }

  test('does not show matches for incomplete or unsupported operators', () {
    for (final draft in ['-', 'blue_hair -', '~one']) {
      expect(index.suggestions(draft), isEmpty);
    }
  });

  final colors = TagColors.fromBrightness(Brightness.light);
  const source = BookmarkTagSource(
    url: 'https://danbooru.donmai.us/',
    booruType: BooruType.danbooru,
  );
  const otherSource = BookmarkTagSource(
    url: 'https://gelbooru.com/',
    booruType: BooruType.gelbooruV2,
  );

  test(
    'uses stored snapshot categories without consulting the tag cache',
    () async {
      final entry = BookmarkTagEntry(
        tag: 'one_piece',
        count: 1,
        sources: {
          source: const {'copyright'},
        },
      );
      final color = await resolveBookmarkTagColor(
        entry,
        colors: colors,
        categoryLookup: (_, _) => throw StateError('must not read cache'),
        colorGenerator: (_) => null,
      );
      expect(color, colors.copyright);
    },
  );

  test(
    'reads category metadata from the bookmark source, not a browse profile',
    () async {
      final calls = <String>[];
      final entry = BookmarkTagEntry(
        tag: 'one_piece',
        count: 1,
        sources: {otherSource: const {}},
      );
      final color = await resolveBookmarkTagColor(
        entry,
        colors: colors,
        categoryLookup: (site, tag) async {
          calls.add('$site $tag');
          return '3';
        },
        colorGenerator: (type) {
          expect(type, BooruType.gelbooruV2);
          return const DefaultTagColorGenerator();
        },
      );
      expect(color, colors.copyright);
      expect(calls, ['https://gelbooru.com/ one_piece']);
    },
  );

  test('keeps unknown and conflicting categories neutral', () async {
    for (final sources in [
      {source: <String>{}},
      {
        source: {'artist'},
        otherSource: {'character'},
      },
    ]) {
      final color = await resolveBookmarkTagColor(
        BookmarkTagEntry(tag: 'ambiguous', count: 2, sources: sources),
        colors: colors,
        categoryLookup: (_, _) async => null,
        colorGenerator: (_) => const DefaultTagColorGenerator(),
      );
      expect(color, isNull);
    }
  });

  test(
    'does not borrow cached categories from a different installation path',
    () async {
      const nested = BookmarkTagSource(
        url: 'https://booru.example/nested/',
        booruType: BooruType.danbooru,
      );
      final calls = <String>[];
      final color = await resolveBookmarkTagColor(
        BookmarkTagEntry(
          tag: 'one_piece',
          count: 1,
          sources: {nested: const {}},
        ),
        colors: colors,
        categoryLookup: (site, _) async {
          calls.add(site);
          return site == 'https://booru.example/' ? '1' : null;
        },
        colorGenerator: (_) => const DefaultTagColorGenerator(),
      );
      expect(color, isNull);
      expect(calls, [
        'https://booru.example/nested/',
        'https://booru.example/nested',
      ]);
    },
  );

  test(
    'cache failure does not prevent local search or invent a category',
    () async {
      final color = await resolveBookmarkTagColor(
        BookmarkTagEntry(
          tag: 'one_piece',
          count: 1,
          sources: {source: const {}},
        ),
        colors: colors,
        categoryLookup: (_, _) async =>
            throw StateError('database unavailable'),
        colorGenerator: (_) => const DefaultTagColorGenerator(),
      );
      expect(color, isNull);
      expect(index.suggestions('one piece').single.tag, 'one_piece');
    },
  );
}
