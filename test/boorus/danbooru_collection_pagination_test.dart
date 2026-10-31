import 'package:booru_clients/danbooru.dart';
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/users/user/providers.dart';
import 'package:boorusama/boorus/danbooru/posts/post/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scenario in [
    (name: 'complete', count: 3, ids: [1, 2, 3], more: false),
    (name: 'empty', count: 0, ids: <int>[], more: false),
    (name: 'filtered complete', count: 3, ids: [1, 2, 3], more: false),
    (name: 'filtered incomplete', count: 4, ids: [1, 2, 3], more: null),
    (name: 'count network error', count: null, ids: [1, 2, 3], more: null),
    (name: 'restricted members', count: 4, ids: [1, 2, 3], more: null),
    (name: 'duplicates', count: 3, ids: [1, 1, 2], more: null),
    (name: 'inconsistent count', count: 2, ids: [1, 2, 3], more: null),
    (name: 'count unavailable', count: null, ids: [1, 2, 3], more: null),
  ]) {
    test('actual parent Search producer preserves ${scenario.name}', () async {
      final paths = <String>[];
      final config = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': '00000000-0000-4000-8000-000000000113',
        'url': 'https://danbooru.donmai.us',
      }).search;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              paths.add(request.path);
              if (request.path == '/posts.json') {
                expect(
                  request.queryParameters['tags'],
                  contains('parent:12480551'),
                );
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: request,
                    data: [
                      for (final id in scenario.ids)
                        {
                          'id': id,
                          'tag_string': '',
                          'file_ext':
                              scenario.name.startsWith('filtered') && id == 3
                              ? 'swf'
                              : 'jpg',
                        },
                    ],
                    statusCode: 200,
                  ),
                );
              } else {
                expect(request.path, '/counts/posts.json');
                if (scenario.name == 'count network error') {
                  handler.reject(
                    DioException(
                      requestOptions: request,
                      type: DioExceptionType.connectionError,
                    ),
                  );
                  return;
                }
                expect(request.queryParameters['estimate_count'], false);
                expect(request.queryParameters['skip_cache'], true);
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: request,
                    data: {
                      'counts': {'posts': scenario.count},
                    },
                    statusCode: 200,
                  ),
                );
              }
            },
          ),
        );
      final container = ProviderContainer(
        overrides: [
          danbooruCurrentUserProvider.overrideWith((ref, auth) async => null),
          danbooruClientProvider.overrideWith(
            (ref, auth) => DanbooruClient(baseUrl: auth.url, dio: dio),
          ),
        ],
      );
      addTearDown(container.dispose);
      final result = await container
          .read(danbooruPostRepoProvider(config))
          .getPosts(
            'parent:12480551',
            1,
            limit: 20,
            options: scenario.name.startsWith('filtered')
                ? null
                : PostFetchOptions.raw,
          )
          .run();
      result.fold((error) => fail('Unexpected $error'), (value) {
        expect(
          value.posts.map((p) => p.id),
          scenario.name.startsWith('filtered')
              ? scenario.ids.take(2)
              : scenario.ids,
        );
        expect(value.hasMore, scenario.more);
        expect(
          value.total,
          scenario.name == 'inconsistent count' ? null : scenario.count,
        );
      });
      expect(paths, contains('/counts/posts.json'));
    });
  }
}
