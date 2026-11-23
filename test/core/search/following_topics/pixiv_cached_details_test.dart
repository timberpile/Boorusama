import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/pixiv_repository.dart';
import 'package:boorusama/boorus/pixiv/posts/providers.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'following_topic_test_utils.dart';

void main() {
  for (final sparse in [false, true]) {
    test(
      'a cached Pixiv page ID loads its native artwork (sparse: $sparse)',
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
                        'page_count': sparse ? 3 : 2,
                        'user': {'id': 7, 'name': r'Artist\Alias:?'},
                        'create_date': '2026-09-14T12:00:00Z',
                        'meta_pages': [
                          {
                            'image_urls': {
                              'original': 'https://example.com/first.jpg',
                            },
                          },
                          if (sparse) null,
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
            .getPost(NumericPostId(sparse ? 42002 : 42001))
            .run();
        final post = result.getOrElse((_) => null)!;
        expect(
          post.originalImageUrl,
          'https://example.com/second.jpg',
        );
        expect(post.pageIndex, sparse ? 2 : 1);
        final filenames = container
            .read(
              Provider((ref) => PixivRepository(ref: ref)),
            )
            .downloadFilenameBuilder(testProfile.auth);
        const downloadConfig = BooruConfigDownload(
          fileNameFormat: null,
          bulkFileNameFormat: null,
          location: null,
        );
        for (final generate in [
          filenames.generate,
          filenames.generateForBulkDownload,
        ]) {
          expect(
            await generate(
              Settings.defaultSettings,
              downloadConfig,
              post,
              downloadUrl: post.originalImageUrl,
            ),
            sparse ? '42_p2.jpg' : '42_p1.jpg',
          );
          expect(
            await generate(
              Settings.defaultSettings,
              const BooruConfigDownload(
                fileNameFormat: '{user_name}_{illust_id}_p{page}.{extension}',
                bulkFileNameFormat:
                    '{user_name}_{illust_id}_p{page}.{extension}',
                location: null,
              ),
              post,
              downloadUrl: post.originalImageUrl,
            ),
            sparse ? 'Artist_Alias___42_p2.jpg' : 'Artist_Alias___42_p1.jpg',
          );
        }
        expect(requests, [42]);
        if (sparse) {
          final missing = await container
              .read(pixivPostRepoProvider(testProfile.search))
              .getPost(const NumericPostId(42001))
              .run();
          expect(missing.getOrElse((_) => null), isNull);
          expect(requests, [42, 42]);
        }
        final invalid = await container
            .read(pixivPostRepoProvider(testProfile.search))
            .getPost(const StringPostId('invalid'))
            .run();
        expect(invalid.getOrElse((_) => null), isNull);
        expect(requests, sparse ? [42, 42] : [42]);
      },
    );
  }
}
