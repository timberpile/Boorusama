import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:boorusama/core/search/options/search_option.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = capabilitiesFor(BooruType.szurubooru, 'https://example.test');
  test('numeric comparisons become native ranges without rounding bounds', () {
    final option = catalog.byKey('score')!;
    expect(option.compose('>=20'), 'score:20..');
    expect(option.compose('<=20'), 'score:..20');
    expect(option.compose('>20'), '-score:..20');
    expect(option.compose('<20'), '-score:20..');
    expect(option.compose('>20', exclude: true), 'score:..20');
    expect(option.compose('-2..5', exclude: true), '-score:-2..5');
    expect(option.compose('5..2'), isNull);
    final ratio = catalog.byKey('image-aspect-ratio')!;
    expect(ratio.compose('>1.5'), '-image-aspect-ratio:..1.5');
    expect(ratio.compose('16:9'), 'image-aspect-ratio:16:9');
  });
  test('sort direction uses a comma and cannot be excluded', () {
    final sort = catalog.byKey('sort')!;
    expect(sort.compose('score,desc'), 'sort:score,desc');
    expect(sort.compose('score:desc'), isNull);
    expect(sort.compose('score,desc', exclude: true), isNull);
  });
  test(
    'canonical public fields have graphical editors and valid quick choices',
    () {
      expect(
        catalog.options.map((option) => option.key).toSet().length,
        catalog.options.length,
      );
      for (final key in [
        'rating',
        'uploader',
        'pool',
        'tag-count',
        'note-text',
        'flag',
        'special',
        'category',
        'file-size',
        'creation-date',
        'md5',
      ]) {
        expect(catalog.byKey(key), isNotNull, reason: key);
        expect(catalog.byKey(key)!.kind, isNot(SearchOptionKind.native));
      }
      for (final option in catalog.options) {
        for (final choice in option.choices) {
          expect(
            option.compose(choice.value),
            isNotNull,
            reason: '${option.key}:${choice.value}',
          );
        }
      }
      expect(catalog.byKey('pool')!.compose('42'), 'pool:42');
      expect(catalog.byKey('pool')!.compose('UnresolvedName'), isNull);
      expect(
        catalog.byKey('creation-date')!.compose('<2026-10-23'),
        '-creation-date:2026-10-23..',
      );
      expect(
        catalog.byKey('creation-date')!.compose('today'),
        'creation-date:today',
      );
    },
  );
}
