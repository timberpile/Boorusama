import 'package:booru_clients/danbooru.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  for (final scenario in [
    (
      names: ['alias_owner', 'kantoku'],
      deleted: <String>{},
      expected: 'kantoku',
    ),
    (names: ['alias_owner'], deleted: <String>{}, expected: 'alias_owner'),
    (
      names: ['kantoku', 'alias_owner'],
      deleted: {'kantoku'},
      expected: 'alias_owner',
    ),
    (names: ['kantoku'], deleted: {'kantoku'}, expected: null),
    (names: <String>[], deleted: <String>{}, expected: null),
  ]) {
    test(
      'prefers canonical artists while preserving active alias fallback ${scenario.names}/${scenario.deleted}',
      () async {
        var requests = 0;
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                requests++;
                expect(
                  options.queryParameters['search[any_name_matches]'],
                  'kantoku',
                );
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: [
                      for (final name in scenario.names)
                        {
                          'id': 1,
                          'created_at': '2020-01-01',
                          'updated_at': '2020-01-01',
                          'name': name,
                          'is_deleted': scenario.deleted.contains(name),
                          'group_name': '',
                          'is_banned': false,
                          'other_names': ['kantoku'],
                        },
                    ],
                  ),
                );
              },
            ),
          );
        addTearDown(() => dio.close(force: true));
        final artist = await DanbooruClient(
          baseUrl: 'https://example.test',
          dio: dio,
        ).getFirstMatchingArtist(name: 'kantoku');
        expect(artist?.name, scenario.expected);
        expect(requests, 1);
      },
    );
  }
}
