import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:boorusama/core/search/options/search_id_parameters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'account IDs become selected engine parameters instead of tag lookups',
    () {
      final request = splitSearchIdParameters(
        ['landscape', 'user_id:42', 'favorited_by_user_id:7'],
        {'user_id', 'favorited_by_user_id'},
      );
      expect(request.terms, ['landscape']);
      expect(request.ids, {'user_id': 42, 'favorited_by_user_id': 7});
      expect(
        splitSearchIdParameters(['stars_by:7'], {'stars_by'}).terms,
        isEmpty,
      );
      expect(splitSearchIdParameters(['stars_by:7'], {'user_id'}).terms, [
        'stars_by:7',
      ]);
    },
  );
  test('flattened history and Topic queries retain account parameters', () {
    final request = splitSearchIdParameters(
      ['landscape user_id:42 favorited_by_user_id:7'],
      {'user_id', 'favorited_by_user_id'},
    );
    expect(request.terms, ['landscape']);
    expect(request.ids, {'user_id': 42, 'favorited_by_user_id': 7});
    expect(
      splitSearchIdParameters(['stars_by:7'], {'stars_by'}).ids,
      {'stars_by': 7},
    );
  });
  test('unknown, negated, malformed and grouped directives stay verbatim', () {
    final terms = [
      'user_id:0',
      '-user_id:7',
      '(user_id:7 OR cat)',
      'user_id:>=7',
      'user_id:name',
    ];
    expect(splitSearchIdParameters(terms, {'user_id'}).terms, terms);
    expect(
      splitSearchIdParameters(['user_id:7', 'user_id:8'], {'user_id'}).ids,
      {'user_id': 8},
    );
  });
  test('the graphical controls use exact positive IDs, not invented username suggestions', () {
    final e = capabilitiesFor(BooruType.eshuushuu, 'https://e-shuushuu.net');
    final a = capabilitiesFor(
      BooruType.animePictures,
      'https://anime-pictures.net',
    );
    for (final option in [...e.options, ...a.options]) {
      expect(option.isComparable, isFalse);
      expect(option.compose('7'), '${option.key}:7');
      expect(option.compose('0'), isNull);
      expect(option.compose('>=7'), isNull);
      expect(option.compose('name'), isNull);
      expect(option.compose('7', exclude: true), isNull);
    }
  });
}
