import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/entity_endpoint.dart';
import 'package:boorusama/core/search/options/entity_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'user suggestions use the selected engine endpoint and bounded queries',
    () {
      final e621 = searchEntityEndpoint(BooruType.e621, 'user', 'test')!;
      expect(e621.path, '/users.json');
      expect(e621.parameters['search[name_matches]'], 'test*');
      expect(e621.parameters['limit'], 8);
      final moe = searchEntityEndpoint(BooruType.moebooru, 'user', 'test')!;
      expect(moe.path, '/user/autocomplete_name.json');
      expect(moe.parameters, {'term': 'test'});
      expect(searchEntityEndpoint(BooruType.e621, 'user', ''), isNull);
      expect(searchEntityEndpoint(BooruType.e621, 'user', 'x'), isNull);
      expect(searchEntityEndpoint(BooruType.gelbooru, 'user', 'test'), isNull);
      expect(searchEntityPrefix(BooruType.e621, 'fav'), 'user');
      expect(searchEntityPrefix(BooruType.moebooru, 'user'), 'user');
      expect(searchEntityPrefix(BooruType.szurubooru, 'comment'), 'user');
    },
  );

  test('nullable or malformed user responses do not invent names', () {
    final items = parseSearchEntityResponse([
      null,
      {},
      {'name': null},
      {'name': 'good_user'},
      {'name': 'good_user'},
      {'name': 'another_user'},
      {'name': 'bad user'},
      'direct_user',
    ], 'user');
    expect(items.map((item) => item.value), [
      'good_user',
      'another_user',
      'direct_user',
    ]);
    expect(items.every((item) => item.type == 'user'), isTrue);
    expect(parseSearchEntityResponse('<html>error</html>', 'user'), isEmpty);
    expect(parseSearchEntityResponse(null, 'user'), isEmpty);
  });

  test(
    'pool selection keeps the numeric ID instead of inserting its display name',
    () {
      final endpoint = searchEntityEndpoint(
        BooruType.szurubooru,
        'pool',
        'series',
      )!;
      expect(endpoint.poolIds, isTrue);
      final values = parseSearchEntityResponse(
        {
          'results': [
            {
              'id': 42,
              'names': ['A series'],
            },
            {
              'names': ['Missing ID'],
            },
          ],
        },
        'pool',
        poolIds: true,
      );
      expect(values.single.label, 'A series');
      expect(values.single.value, '42');
      expect(searchEntityValue(values.single, 'pool'), '42');
    },
  );
}
