import 'package:boorusama/boorus/philomena/tags/color.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_tag_color.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_tag_index.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/selected_tags/tag_search_item.dart';
import 'package:boorusama/core/tags/tag/colors.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const generator = DefaultTagColorGenerator();
  for (final brightness in Brightness.values) {
    final colors = generator.generateColors(
      TagColorsOptions(brightness: brightness),
    );
    test('uses known category semantics in $brightness', () {
      final expected = {
        '0': colors.general,
        'general': colors.general,
        '1': colors.artist,
        'artist': colors.artist,
        'creator': colors.artist,
        '3': colors.copyright,
        'copyright': colors.copyright,
        'series': colors.copyright,
        '4': colors.character,
        'character': colors.character,
        '5': colors.meta,
        'meta': colors.meta,
        'metadata': colors.meta,
        ' ARTIST ': colors.artist,
      };
      for (final entry in expected.entries) {
        expect(
          generator.generateColor(
            TagColorOptions(
              tagType: entry.key,
              colors: colors,
            ),
          ),
          entry.value,
          reason: entry.key,
        );
      }
      for (final category in [null, '', 'unknown', '9999', 'not_a_category']) {
        expect(
          generator.generateColor(
            TagColorOptions(
              tagType: category,
              colors: colors,
            ),
          ),
          isNull,
          reason: '$category',
        );
      }
    });
  }

  test(
    'Philomena legacy empty bookmark category uses its origin General palette',
    () async {
      const generator = PhilomenaTagColorGenerator();
      final colors = generator.generateColors(
        const TagColorsOptions(brightness: Brightness.dark),
      );
      final result = await resolveBookmarkTagColor(
        BookmarkTagEntry(
          tag: 'pony',
          count: 1,
          sources: {
            const BookmarkTagSource(
              url: 'https://derpibooru.org/',
              booruType: BooruType.philomena,
            ): const <String>{},
          },
        ),
        colors: colors,
        categoryLookup: (url, name) async => url.endsWith('/') ? '' : null,
        colorGenerator: (_) => generator,
      );
      expect(result, colors.general);
    },
  );

  test('editing a different tag invalidates only its category metadata', () {
    final artist = TagSearchItem.fromString('artist_name', category: 'artist');
    expect(artist.withQuery('-artist_name').category, 'artist');
    final renamed = artist.withQuery('-character_name');
    expect(renamed.category, isNull);
    expect(renamed.toString(), '-character_name');
    expect(artist.toString(), 'artist_name');
    expect(artist.category, 'artist');
    const raw = TagSearchItem.raw(tag: 'custom syntax');
    expect(raw.withQuery('other syntax').isRaw, isTrue);
  });

  const source = BookmarkTagSource(
    url: 'https://example.test/nested/',
    booruType: BooruType.danbooru,
  );
  test(
    'stored categories use their origin palette without cache requests',
    () async {
      final fallback = TagColors.fromBrightness(Brightness.light);
      final origin = TagColors.fromBrightness(Brightness.dark);
      final color = await resolveBookmarkTagColor(
        BookmarkTagEntry(
          tag: 'artist_name',
          count: 1,
          sources: {
            source: const {'artist'},
          },
        ),
        colors: fallback,
        colorsForType: (type) {
          expect(type, source.booruType);
          return origin;
        },
        categoryLookup: (_, _) => throw StateError('must not read cache'),
        colorGenerator: (_) => generator,
      );
      expect(color, origin.artist);
    },
  );

  test(
    'cached codes use the same source palette and color transform',
    () async {
      final colors = TagColors.fromBrightness(Brightness.light);
      final origin = TagColors.fromBrightness(Brightness.dark);
      var transformed = 0;
      final color = await resolveBookmarkTagColor(
        BookmarkTagEntry(
          tag: 'character_name',
          count: 1,
          sources: {
            source: const <String>{},
          },
        ),
        colors: colors,
        colorsForType: (_) => origin,
        categoryLookup: (url, _) async {
          expect(url, source.url);
          return '4';
        },
        colorGenerator: (_) => generator,
        transformColor: (value) {
          expect(value, origin.character);
          transformed++;
          return value;
        },
      );
      expect(color, origin.character);
      expect(transformed, 1);
    },
  );
}
