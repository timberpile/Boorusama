import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/entity_suggestions.dart';
import 'package:boorusama/core/tags/autocompletes/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('user roles and ordered pools use their real entity endpoints', () {
    for (final key in ['user', 'approver', 'fav', 'noter', 'commenter']) {
      expect(searchEntityPrefix(BooruType.danbooru, key), 'user');
    }
    expect(searchEntityPrefix(BooruType.danbooru, 'ordpool'), 'pool');
    expect(searchEntityPrefix(BooruType.danbooru, 'source'), isNull);
    expect(searchEntityPrefix(BooruType.gelbooru, 'user'), isNull);
  });

  test(
    'only a matching entity is accepted and its wire prefix is stripped',
    () {
      expect(
        searchEntityValue(
          const AutocompleteData(
            type: 'user',
            label: 'Some User',
            value: 'user:some_user',
          ),
          'user',
        ),
        'some_user',
      );
      expect(
        searchEntityValue(
          const AutocompleteData(
            type: 'user',
            label: 'Some User',
            value: 'some_user',
          ),
          'user',
        ),
        'some_user',
      );
      expect(
        searchEntityValue(
          const AutocompleteData(
            type: 'tag',
            label: 'Some User',
            value: 'some_user',
          ),
          'user',
        ),
        isNull,
      );
      expect(
        searchEntityValue(
          const AutocompleteData(
            type: 'user',
            label: 'Invalid',
            value: 'user:',
          ),
          'user',
        ),
        isNull,
      );
    },
  );
}
