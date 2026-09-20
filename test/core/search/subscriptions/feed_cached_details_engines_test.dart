import 'package:booru_clients/eshuushuu.dart';
import 'package:booru_clients/shimmie2.dart';
import 'package:boorusama/boorus/eshuushuu/client_provider.dart';
import 'package:boorusama/boorus/eshuushuu/posts/providers.dart';
import 'package:boorusama/boorus/eshuushuu/posts/types.dart';
import 'package:boorusama/boorus/shimmie2/clients/providers.dart';
import 'package:boorusama/boorus/shimmie2/posts/providers.dart';
import 'package:boorusama/boorus/shimmie2/posts/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pinned_search_test_utils.dart';

void main() {
  test('a cached Shimmie2 post ID opens native details by ID', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://shimmie.example'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                data:
                    '<posts count="1"><tag id="42" '
                    'file_url="/images/42.jpg" '
                    'preview_url="/thumbs/42.jpg" tags="artist" '
                    'date="2026-09-14T12:00:00Z" /></posts>',
              ),
            );
          },
        ),
      );
    final container = ProviderContainer(
      overrides: [
        useGraphQLClientProvider.overrideWith(
          (ref, auth) => Future.value(false),
        ),
        shimmie2ClientProvider.overrideWith(
          (ref, config) => Shimmie2Client(
            dio: dio,
            baseUrl: config.url,
            apiKey: config.apiKey,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(shimmie2PostRepoProvider(testProfile.search))
        .getPost(const NumericPostId(42))
        .run();
    final post = result.getOrElse((_) => null);

    expect(post, isA<Shimmie2Post>());
    expect(post?.id, 42);
    expect(post?.originalImageUrl, 'https://shimmie.example/images/42.jpg');
    expect(requests.single.path, '/api/danbooru/find_posts');
    expect(requests.single.queryParameters['id'], 42);
  });

  for (final returnedId in [42, 43]) {
    test(
      'Shimmie2 GraphQL ${returnedId == 42 ? 'opens the requested post' : 'rejects a different post'}',
      () async {
        final requests = <RequestOptions>[];
        final dio = Dio(BaseOptions(baseUrl: 'https://shimmie.example'))
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                requests.add(options);
                final query =
                    (options.data as Map<String, dynamic>)['query'] as String;
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: {
                      'data': query.contains('GetPost')
                          ? {
                              'post': {
                                'post_id': returnedId,
                                'image_link': '/images/$returnedId.jpg',
                                'thumb_link': '/thumbs/$returnedId.jpg',
                              },
                            }
                          : {'posts': <Object>[]},
                    },
                  ),
                );
              },
            ),
          );
        final container = ProviderContainer(
          overrides: [
            useGraphQLClientProvider.overrideWith(
              (ref, auth) => Future.value(true),
            ),
            shimmie2ClientProvider.overrideWith(
              (ref, config) => Shimmie2Client(
                dio: dio,
                baseUrl: config.url,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container
            .read(shimmie2PostRepoProvider(testProfile.search))
            .getPost(const NumericPostId(42))
            .run();
        final post = result.getOrElse((_) => null);

        expect(post, returnedId == 42 ? isA<Shimmie2Post>() : isNull);
        expect(requests, hasLength(2));
        expect(requests.every((request) => request.path == '/graphql'), isTrue);
      },
    );
  }

  test('a cached E-shuushuu image ID opens native details by ID', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://e-shuushuu.example'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'image_id': 42,
                  'url': 'https://cdn.example/42.jpg',
                  'thumbnail_url': 'https://cdn.example/42-thumb.jpg',
                  'date_added': '2026-09-14T12:00:00Z',
                  'tags': <Map<String, Object>>[],
                },
              ),
            );
          },
        ),
      );
    final container = ProviderContainer(
      overrides: [
        eshuushuuClientProvider.overrideWith(
          (ref, config) => EShuushuuClient(dio: dio),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(eshuushuuPostRepoProvider(testProfile.search))
        .getPost(const NumericPostId(42))
        .run();
    final post = result.getOrElse((_) => null);

    expect(post, isA<EshuushuuPost>());
    expect(post?.id, 42);
    expect(post?.originalImageUrl, 'https://cdn.example/42.jpg');
    expect(requests.single.path, '/api/v1/images/42');
  });

  test('an unavailable Shimmie2 post does not open details', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://shimmie.example'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response(
              requestOptions: options,
              data: '<posts count="0"></posts>',
            ),
          ),
        ),
      );
    final container = ProviderContainer(
      overrides: [
        useGraphQLClientProvider.overrideWith(
          (ref, auth) => Future.value(false),
        ),
        shimmie2ClientProvider.overrideWith(
          (ref, config) => Shimmie2Client(
            dio: dio,
            baseUrl: config.url,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(shimmie2PostRepoProvider(testProfile.search))
        .getPost(const NumericPostId(42))
        .run();

    expect(result.getOrElse((_) => null), isNull);
  });

  test('an unavailable E-shuushuu image does not open details', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://e-shuushuu.example'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 500),
            ),
          ),
        ),
      );
    final container = ProviderContainer(
      overrides: [
        eshuushuuClientProvider.overrideWith(
          (ref, config) => EShuushuuClient(dio: dio),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(eshuushuuPostRepoProvider(testProfile.search))
        .getPost(const NumericPostId(42))
        .run();

    expect(result.getOrElse((_) => null), isNull);
  });
}
