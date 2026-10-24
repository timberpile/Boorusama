import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:boorusama/core/search/options/search_option.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final danbooru = capabilitiesFor(
    BooruType.danbooru,
    'https://danbooru.donmai.us',
  );
  final gelbooru = capabilitiesFor(BooruType.gelbooru, 'https://gelbooru.com');
  final rule34 = capabilitiesFor(BooruType.gelbooruV2, 'https://rule34.xxx');

  test('sorts use site syntax and cannot be negated', () {
    expect(danbooru.byKey('order')!.choices.first.value, 'id_desc');
    expect(danbooru.byKey('order')!.compose('score', exclude: true), isNull);
    expect(gelbooru.byKey('sort')!.compose('score:desc'), 'sort:score:desc');
    expect(rule34.byKey('sort')!.compose('score:desc'), 'sort:score:desc');
    expect(rule34.byKey('sort')!.compose('random'), 'sort:random');
    expect(gelbooru.byKey('sort')!.compose('random'), 'sort:random');
  });
  for (final c in [
    ('<7d', '>=7d'),
    ('<=7d', '>7d'),
    ('>7d', '<=7d'),
    ('>=7d', '<7d'),
  ]) {
    test('duration exclusion preserves the boundary of ${c.$1}', () {
      expect(
        danbooru.byKey('age')!.compose(c.$1, exclude: true),
        'age:${c.$2}',
      );
    });
  }
  test(
    'documented metadata has guided editors instead of raw placeholders',
    () {
      for (final key in [
        'width',
        'height',
        'date',
        'ratio',
        'filesize',
        'filetype',
        'favcount',
        'pool',
        'commenter',
        'parent',
        'status',
        'has',
      ]) {
        final option = danbooru.byKey(key)!;
        expect(option.kind, isNot(SearchOptionKind.native), reason: key);
      }
      expect(danbooru.byKey('newpool'), isNull);
      expect(danbooru.byKey('locked'), isNull);
    },
  );
  test('legacy hosts gain their declared filters, not Danbooru-only age', () {
    for (final key in [
      'rating',
      'sort',
      'score',
      'user',
      'width',
      'height',
      'parent',
      'md5',
      'id',
    ]) {
      expect(rule34.byKey(key), isNotNull, reason: key);
    }
    expect(rule34.byKey('age'), isNull);
    expect(
      capabilitiesFor(BooruType.gelbooruV2, 'https://custom.example').options,
      isEmpty,
    );
    expect(rule34.byKey('rating')!.compose('safe'), 'rating:safe');
    expect(gelbooru.byKey('rating')!.compose('q'), isNull);
    expect(danbooru.byKey('rating')!.compose('q', exclude: true), '-rating:q');
  });
  test('incomplete and compound graphical values remain rejected', () {
    for (final value in [
      '',
      '<0d',
      '<-7d',
      '<7',
      '<7d rating:q',
      '<7d\n',
      '>2months',
    ]) {
      expect(danbooru.byKey('age')!.compose(value), isNull, reason: value);
    }
    expect(danbooru.byKey('score')!.compose('>=-5'), 'score:>=-5');
    expect(danbooru.byKey('score')!.compose('50', exclude: true), '-score:50');
    expect(danbooru.byKey('user')!.compose('name other_tag'), isNull);
  });
  test('catalog keys are unique and every quick choice can be serialized', () {
    for (final capabilities in [danbooru, gelbooru, rule34]) {
      expect(
        capabilities.options.map((o) => o.key).toSet().length,
        capabilities.options.length,
      );
      for (final option in capabilities.options) {
        for (final choice in option.choices) {
          expect(
            option.compose(choice.value),
            isNotNull,
            reason: '${option.key}:${choice.value}',
          );
        }
      }
    }
  });
  test('FREE is not inferred from the engine and context retains colons', () {
    expect(danbooru.options.every((option) => !option.isFree), isTrue);
    expect(danbooru.contextFor('-rating:q')!.exclude, isTrue);
    expect(gelbooru.contextFor('sort:score:desc')!.value, 'score:desc');
    expect(danbooru.contextFor('~rating:q'), isNull);
  });
}
