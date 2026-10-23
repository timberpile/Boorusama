import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = capabilitiesFor(BooruType.e621, 'https://e621.net');

  test('e621 exact identifiers reject ranges and comparisons', () {
    for (final key in ['user_id', 'parent', 'randseed', 'limit']) {
      final option = catalog.byKey(key)!;
      expect(option.isComparable, isFalse, reason: key);
      expect(option.compose('42'), '$key:42');
      expect(option.compose('>=42'), isNull);
      expect(option.compose('42..100'), isNull);
      expect(option.compose('42abc'), isNull);
    }
    expect(
      catalog.byKey('parent')!.compose('none', exclude: true),
      '-parent:none',
    );
    expect(
      catalog.byKey('user_id')!.compose('42', exclude: true),
      '-user_id:42',
    );
    expect(catalog.byKey('randseed')!.compose('42', exclude: true), isNull);
    expect(catalog.byKey('limit')!.compose('0'), isNull);
  });

  test('e621 supports score equality and range negation natively', () {
    final score = catalog.byKey('score')!;
    expect(score.compose('20', exclude: true), '-score:20');
    expect(score.compose('-5..20', exclude: true), '-score:-5..20');
    expect(score.compose('20..-5'), isNull);
  });

  test('the same word can describe different fields on different engines', () {
    final szuru = capabilitiesFor(BooruType.szurubooru, 'https://example.test');
    expect(szuru.byKey('comment')!.labelKey, 'commenter');
    expect(szuru.byKey('comment')!.descriptionKey, 'user');
    expect(szuru.byKey('fav')!.labelKey, 'favorited_by');
  });
}
