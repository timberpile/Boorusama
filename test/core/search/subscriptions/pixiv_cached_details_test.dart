import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/posts/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'pinned_search_test_utils.dart';

void main() {
  test(
    'a cached Pixiv page ID loads its native artwork before opening details',
    () async {
      final requests = <int>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options.queryParameters['illust_id'] as int);
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'illust': {
                      'id': 42,
                      'page_count': 2,
                      'user': {'id': 7},
                      'create_date': '2026-09-14T12:00:00Z',
                      'meta_pages': [
                        {
                          'image_urls': {
                            'original': 'https://example.com/first.jpg',
                          },
                        },
                        {
                          'image_urls': {
                            'original': 'https://example.com/second.jpg',
                          },
                        },
                      ],
                    },
                  },
                ),
              );
            },
          ),
        );
      final container = ProviderContainer(
        overrides: [
          pixivClientProvider.overrideWith(
            (ref, config) => PixivClient(accessToken: 'test', dio: dio),
          ),
        ],
      );
      addTearDown(container.dispose);
      final result = await container
          .read(pixivPostRepoProvider(testProfile.search))
          .getPost(const NumericPostId(42001))
          .run();
      expect(
        result.getOrElse((_) => null)?.originalImageUrl,
        'https://example.com/second.jpg',
      );
      expect(requests, [42]);
      final invalid = await container
          .read(pixivPostRepoProvider(testProfile.search))
          .getPost(const StringPostId('invalid'))
          .run();
      expect(invalid.getOrElse((_) => null), isNull);
      expect(requests, [42]);
    },
  );
}
