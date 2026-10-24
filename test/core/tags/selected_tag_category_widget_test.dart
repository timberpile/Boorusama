import 'package:boorusama/boorus/e621/tags/color.dart';
import 'package:boorusama/boorus/philomena/tags/color.dart';
import 'package:boorusama/boorus/zerochan/tags/color.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/search/src/widgets/selected_tag_chip.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/tags/categories/providers.dart';
import 'package:boorusama/core/tags/metatag/types.dart';
import 'package:boorusama/core/tags/tag/colors.dart';
import 'package:boorusama/core/tags/tag/providers.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/themes/colors/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final harmonize in [false, true]) {
      testWidgets(
        'selected chips use the normal category palette in $brightness/$harmonize',
        (
          tester,
        ) async {
          final scheme = ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: brightness,
          );
          final palette = BooruChipColors.colorScheme(
            scheme,
            harmonizeWithPrimary: harmonize,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [booruChipColorsProvider.overrideWithValue(palette)],
              child: MaterialApp(
                theme: ThemeData(colorScheme: scheme),
                builder: (context, child) => MaterialUiCompatibilityBridge(
                  child: KurumiTheme(
                    data: KurumiThemeData.fromMaterial(Theme.of(context)),
                    child: child!,
                  ),
                ),
                home: Scaffold(
                  body: SizedBox(
                    width: 240,
                    child: SelectedTagChip(
                      tagSearchItem: TagSearchItem.fromString('-artist_name'),
                      tagColor: Colors.red,
                      textScaler: const TextScaler.linear(2),
                    ),
                  ),
                ),
              ),
            ),
          );
          final expected = palette.fromColor(Colors.red)!;
          final chip = tester.widget<KurumiMaterialChip>(
            find.byType(KurumiMaterialChip),
          );
          expect(chip.backgroundColor, expected.backgroundColor);
          expect(chip.side!.color, expected.borderColor);
          expect((chip.deleteIcon! as Icon).color, expected.foregroundColor);
          final label = chip.label as RichText;
          final spans = (label.text as TextSpan).children!.cast<TextSpan>();
          expect(
            spans.firstWhere((span) => span.text == 'artist name').style!.color,
            expected.foregroundColor,
          );
          expect(
            spans.first.style!.color,
            TagColors.fromBrightness(brightness).copyright,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final generator in <TagColorGenerator>[
    const ZerochanTagColorGenerator(),
    const PhilomenaTagColorGenerator(),
    const E621TagColorGenerator(),
  ]) {
    test('${generator.runtimeType} keeps missing categories neutral', () {
      final colors = generator.generateColors(
        const TagColorsOptions(brightness: Brightness.dark),
      );
      for (final category in [null, '', 'unknown', '9999', 'not_a_category']) {
        expect(
          generator.generateColor(
            TagColorOptions(tagType: category, colors: colors),
          ),
          category == '' && generator is PhilomenaTagColorGenerator
              ? colors.general
              : isNull,
        );
      }
      expect(
        generator.generateColor(
          TagColorOptions(tagType: 'character', colors: colors),
        ),
        colors.character,
      );
      expect(
        generator.generateColor(
          TagColorOptions(tagType: 'general', colors: colors),
        ),
        colors.general,
      );
    });
  }
  test('site-specific categories retain their palettes', () {
    const zero = ZerochanTagColorGenerator();
    const philo = PhilomenaTagColorGenerator();
    const e621 = E621TagColorGenerator();
    final colors = TagColors.fromBrightness(Brightness.light);
    expect(
      zero.generateColor(
        TagColorOptions(tagType: 'visual_novel', colors: colors),
      ),
      colors.copyright,
    );
    expect(
      zero.generateColor(
        TagColorOptions(tagType: 'mangaka_primary', colors: colors),
      ),
      colors.artist,
    );
    final philoColors = philo.generateColors(
      const TagColorsOptions(brightness: Brightness.light),
    );
    expect(
      philo.generateColor(
        TagColorOptions(tagType: 'species', colors: philoColors),
      ),
      philoColors.get('species'),
    );
    final e621Colors = e621.generateColors(
      const TagColorsOptions(brightness: Brightness.light),
    );
    expect(
      e621.generateColor(
        TagColorOptions(tagType: 'invalid', colors: e621Colors),
      ),
      e621Colors.get('invalid'),
    );
  });

  testWidgets(
    'rendered chip uses its own profile, cache, and unchanged callbacks',
    (tester) async {
      final first = BooruConfig.empty.auth;
      final second = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': '00000000-0000-4000-8000-000000000048',
        'url': 'https://other.example/',
      }).auth;
      final lookups = <(BooruConfigAuth, String)>[];
      final container = ProviderContainer(
        overrides: [
          booruTagTypeProvider.overrideWith((ref, key) async {
            lookups.add(key);
            return 'artist';
          }),
          tagColorProvider.overrideWith(
            (ref, key) => key.$1 == first ? Colors.red : Colors.blue,
          ),
          booruChipColorsProvider.overrideWithValue(
            BooruChipColors.colorScheme(
              ColorScheme.fromSeed(seedColor: Colors.blue),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      var deleted = 0;
      var tapped = 0;
      Future<void> pump(BooruConfigAuth auth, TagSearchItem item) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              builder: (context, child) => MaterialUiCompatibilityBridge(
                child: KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: child!,
                ),
              ),
              home: Scaffold(
                body: SizedBox(
                  width: 240,
                  child: CategoryAwareSelectedTagChip(
                    auth: auth,
                    tagSearchItem: item,
                    textScaler: const TextScaler.linear(2),
                    onDeleted: () => deleted++,
                    onTap: () => tapped++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      final item = TagSearchItem.fromString('-artist_name');
      await pump(first, item);
      expect(
        tester.widget<SelectedTagChip>(find.byType(SelectedTagChip)).tagColor,
        Colors.red,
      );
      await tester.tap(find.byType(CategoryAwareSelectedTagChip));
      tester.widget<SelectedTagChip>(find.byType(SelectedTagChip)).onDeleted!();
      expect((tapped, deleted), (1, 1));
      await pump(second, item);
      expect(
        tester.widget<SelectedTagChip>(find.byType(SelectedTagChip)).tagColor,
        Colors.blue,
      );
      expect(
        lookups,
        containsAll([(first, 'artist_name'), (second, 'artist_name')]),
      );
      final count = lookups.length;
      await pump(first, const TagSearchItem.raw(tag: 'raw custom_syntax'));
      await pump(
        first,
        TagSearchItem.fromString('rating:safe', extractor: _Extractor()),
      );
      expect(lookups.length, count);
      expect(
        tester.widget<SelectedTagChip>(find.byType(SelectedTagChip)).tagColor,
        isNull,
      );
      final theme = Kurumi.themeOf(
        tester.element(find.byType(SelectedTagChip)),
      );
      expect(
        tester
            .widget<KurumiMaterialChip>(find.byType(KurumiMaterialChip))
            .backgroundColor,
        theme.colorScheme.surfaceContainerHighest,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final fail in [false, true]) {
    testWidgets('missing/failing cache stays neutral ($fail)', (tester) async {
      final container = ProviderContainer(
        overrides: [
          booruTagTypeProvider.overrideWith((ref, _) async {
            if (fail) throw StateError('cache unavailable');
            return null;
          }),
          tagColorProvider.overrideWith(
            (ref, _) => throw StateError('no category to color'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MaterialUiCompatibilityBridge(
              child: KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: CategoryAwareSelectedTagChip(
                auth: BooruConfig.empty.auth,
                tagSearchItem: TagSearchItem.fromString('uncached_tag'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SelectedTagChip>(find.byType(SelectedTagChip)).tagColor,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

class _Extractor implements MetatagExtractor {
  @override
  String? fromString(String value) =>
      value.startsWith('rating:') ? 'rating' : null;
  @override
  bool hasMetatag(String query) => fromString(query) != null;
}
