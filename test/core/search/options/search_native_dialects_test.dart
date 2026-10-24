import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/option_query_value.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/selected_tags/providers.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = capabilitiesFor(
    BooruType.shimmie2,
    'https://rule34.paheal.net',
  );
  test(
    'Paheal comparisons, media length and sort use its documented grammar',
    () {
      expect(catalog.byKey('width')!.compose('>=1920'), 'width>=1920');
      expect(catalog.byKey('ext')!.compose('png'), 'ext=png');
      expect(catalog.byKey('ext')!.compose('png', exclude: true), '-ext=png');
      expect(catalog.byKey('length')!.compose('>=10ms'), 'length>=10ms');
      expect(catalog.byKey('length')!.compose('10mo'), isNull);
      expect(catalog.byKey('order')!.compose('score_desc'), 'order=score_desc');
      expect(
        catalog.byKey('order')!.compose('score_desc', exclude: true),
        isNull,
      );
      expect(catalog.byKey('rating'), isNull);
      for (final option in catalog.options) {
        for (final choice in option.choices) {
          expect(
            option.compose(choice.value),
            isNotNull,
            reason: '${option.key}:${choice.value}',
          );
        }
      }
    },
  );
  test('known dialects reopen while unrelated tags remain untouched', () {
    expect(catalog.contextFor('-width>=1920')!.value, '>=1920');
    expect(catalog.contextFor('-width>=1920')!.exclude, isTrue);
    expect(optionQueryValue('score.gte:50', 'score'), '>=50');
    expect(optionQueryValue('scoreboard:50', 'score'), isNull);
    expect(catalog.contextFor('some_tag'), isNull);
  });
  testWidgets('native replacement preserves opaque syntax', (tester) async {
    final tags = SelectedTagController(metatagExtractor: null);
    final controller = SearchPageController(
      tagsController: tags,
      textMatchers: null,
      metatagExtractor: null,
      optionKeys: {'score', 'width'},
    );
    tags.addTags([
      TagSearchItem.fromString('score.gte:20'),
      const TagSearchItem.raw(tag: 'score.gte:100'),
      TagSearchItem.fromString('width>=640'),
    ]);
    controller.applyOption('score', 'score.gte:50');
    controller.applyOption('width', 'width>=1920');
    expect(tags.rawTags, ['score.gte:50', 'score.gte:100', 'width>=1920']);
    controller.submit('width>=');
    expect(tags.rawTags.length, 3);
    controller.dispose();
    tags.dispose();
  });
}
