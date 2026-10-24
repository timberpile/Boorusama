import 'package:booru_clients/philomena.dart';
import 'package:boorusama/boorus/philomena/philomena.dart';
import 'package:boorusama/boorus/philomena/tags/color.dart';
import 'package:boorusama/boorus/philomena/tags/parser.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/search/src/widgets/selected_tag_chip.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/search/suggestions/tag_suggestion_item.dart';
import 'package:boorusama/core/tags/categories/providers.dart';
import 'package:boorusama/core/tags/metatag/providers.dart';
import 'package:boorusama/core/tags/tag/colors.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/themes/configs/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scenario in [
      'normal',
      'legacy',
      'species',
      'unknown',
      'missing',
      'unavailable',
    ]) {
      testWidgets(
        'Philomena DTO and local category colors: $scenario/$brightness',
        (tester) async {
          final dto = TagDto.fromJson({
            'id': 42,
            'name': 'pony',
            'slug': 'pony',
            'name_in_namespace': 'pony',
            'category': scenario == 'species'
                ? 'species'
                : scenario == 'unknown'
                ? 'new-category'
                : null,
            'aliased_tag': null,
            'aliases': <String>[],
            'images': 123,
            'implied_by_tags': <String>[],
            'implied_tags': <String>[],
            'description': '',
            'short_description': '',
          });
          final suggestion = parsePhilomenaTagToAutocompleteData(dto);
          expect(suggestion.category, dto.category ?? 'general');
          final auth = BooruConfig.defaultConfig(
            booruType: BooruType.philomena,
            url: 'https://derpibooru.org/',
            customDownloadFileNameFormat: null,
          ).auth;
          final scheme = ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: brightness,
          );
          const generator = PhilomenaTagColorGenerator();
          final palette = generator.generateColors(
            TagColorsOptions(brightness: brightness),
          );
          final expected = switch (scenario) {
            'normal' || 'legacy' => palette.general,
            'species' => palette.get('species'),
            _ => null,
          };
          final cacheOnly = [
            'legacy',
            'missing',
            'unavailable',
          ].contains(scenario);
          var lookups = 0;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                booruEngineRegistryProvider.overrideWith((ref) {
                  final registry = BooruRegistry()
                    ..register(BooruType.philomena, createPhilomena());
                  final engine = registry.createEngine(
                    registry.parseFromConfig('philomena'),
                    ref,
                  );
                  return BooruEngineRegistry()
                    ..register(BooruType.philomena, engine);
                }),
                colorSchemeProvider.overrideWithValue(scheme),
                customColorsProvider.overrideWithValue(null),
                enableDynamicColoringProvider.overrideWithValue(false),
                metatagExtractorProvider.overrideWith((ref, _) => null),
                booruTagTypeProvider.overrideWith((ref, key) async {
                  expect(key, (auth, 'pony'));
                  lookups++;
                  if (scenario == 'unavailable')
                    throw StateError('local cache unavailable');
                  return scenario == 'legacy' ? '' : null;
                }),
              ],
              child: MaterialApp(
                theme: ThemeData(colorScheme: scheme),
                builder: (context, child) => MaterialUiCompatibilityBridge(
                  child: KurumiTheme(
                    data: KurumiThemeData.fromMaterial(Theme.of(context)),
                    child: child!,
                  ),
                ),
                home: Scaffold(
                  body: Column(
                    children: [
                      if (!cacheOnly)
                        DefaultTagSuggestionItem(
                          config: auth,
                          tag: suggestion,
                          onItemTap: (_) {},
                          currentQuery: 'pony',
                          dense: false,
                        ),
                      CategoryAwareSelectedTagChip(
                        auth: auth,
                        tagSearchItem: TagSearchItem.fromString(
                          suggestion.value,
                          category: cacheOnly ? null : suggestion.category,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<SelectedTagChip>(find.byType(SelectedTagChip))
                .tagColor,
            expected,
          );
          if (!cacheOnly) {
            expect(
              tester
                  .widget<TagSuggestionItem>(find.byType(TagSuggestionItem))
                  .textColor,
              expected,
            );
          }
          expect(lookups, cacheOnly ? 1 : 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
