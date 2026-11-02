import 'package:booru_clients/danbooru.dart';
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/pools/bookmarks.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/bookmarks/pool_bookmark_test_utils.dart';

void main() {
  final config = BooruConfig.fromJson({
    ...BooruConfig.empty.toJson(),
    'id': poolProfile,
    'url': 'https://danbooru.donmai.us',
    'booruIdHint': poolOrigin().booruType.id,
  });
  final capabilityProvider = Provider((ref) => DanbooruPoolBookmarks(ref));

  for (final saturated in [false, true]) {
    test(
      saturated
          ? 'a saturated Pool response fails instead of caching partial membership'
          : 'one metadata request covers 200 IDs and more than 100 Pools',
      () async {
        var requests = 0;
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                requests++;
                expect(options.path, '/pools.json');
                expect(options.queryParameters['limit'], 1000);
                expect(
                  options.queryParameters['search[post_ids_include_any]'],
                  List.generate(200, (i) => i + 1).join(' '),
                );
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: [
                      for (var i = 0; i < (saturated ? 1000 : 150); i++)
                        {
                          'id': i + 1,
                          'name': 'Series $i',
                          'category': i == 0 ? 'collection' : 'series',
                          'post_count': 500,
                          'post_ids': [1, 200, 999],
                        },
                    ],
                  ),
                );
              },
            ),
          );
        addTearDown(() => dio.close(force: true));
        final container = ProviderContainer(
          overrides: [
            danbooruClientProvider(config.auth).overrideWithValue(
              DanbooruClient(baseUrl: config.url, dio: dio),
            ),
          ],
        );
        addTearDown(container.dispose);
        final pending = container.read(capabilityProvider).getBookmarkSeries(
          config,
          [
            for (var id = 1; id <= 240; id++)
              testPoolPost(id).post
                  .copyWith(origin: postOriginFromConfig(config)),
          ],
        );
        if (saturated) {
          await expectLater(pending, throwsStateError);
        } else {
          final result = await pending;
          expect(result.keys, unorderedEquals([1, 200]));
          expect(result[200], hasLength(149));
          expect(result[200]!.last.total, 500);
          expect(result[200]!.last.id, 150);
        }
        expect(requests, 1);
      },
    );
  }
}
