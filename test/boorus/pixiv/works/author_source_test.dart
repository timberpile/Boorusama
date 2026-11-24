import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/works/author_section.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'work_test_fixtures.dart';

void main() {
  test(
    'requests and filters the original profile author’s first batch',
    () async {
      final access = workAccess();
      final dio = Dio(BaseOptions(baseUrl: kPixivApiBaseUrl));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(request.uri.path, '/v1/user/illusts');
            expect(request.uri.queryParameters, {
              'user_id': '7',
              'type': 'illust',
              'offset': '0',
              'filter': 'for_ios',
            });
            expect(ApiRequestContext.current().cancelToken, isNotNull);
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'illusts': [
                    {
                      'id': 3,
                      'user': {'id': 7},
                      'tags': [],
                    },
                    {
                      'id': 2,
                      'user': {'id': 7},
                      'tags': [
                        {'name': 'blocked'},
                      ],
                    },
                    {
                      'id': 5,
                      'user': {'id': 19},
                      'tags': [],
                    },
                    {
                      'id': 3,
                      'user': {'id': 7},
                      'tags': [],
                    },
                    {
                      'id': 1,
                      'user': {'id': 7},
                      'tags': [],
                    },
                  ],
                  'next_url': '$kPixivApiBaseUrl/v1/user/illusts?offset=30',
                },
              ),
            );
          },
        ),
      );
      addTearDown(dio.close);
      final container = ProviderContainer(
        overrides: [
          contentAccessContextProvider.overrideWith((_, key) {
            expect(key, access.key);
            return access;
          }),
          contentEffectiveBlacklistProvider.overrideWith(
            (_, _) => const AsyncData({'blocked'}),
          ),
          pixivClientProvider.overrideWith(
            (_, _) => PixivClient(accessToken: 'fixture', dio: dio),
          ),
        ],
      );
      addTearDown(container.dispose);
      final provider = pixivAuthorWorksPreviewProvider((
        access: access.key,
        userId: 7,
      ));
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final result = await container.read(provider.future);
      expect(result.illusts.map((work) => work.id), [3, 1]);
      expect(result.hasMore, isTrue);
    },
  );
}
