import 'package:booru_clients/danbooru.dart';
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/posts/post/providers.dart';
import 'package:boorusama/boorus/danbooru/users/user/providers.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow_driver.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  for (final complete in [true, false]) {
    testWidgets('actual Search parent footer knows complete=$complete', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              requests.add(request);
              handler.resolve(
                Response<dynamic>(
                  requestOptions: request,
                  statusCode: 200,
                  data: request.path == '/posts.json'
                      ? [
                          for (var id = 101; id <= 103; id++)
                            {
                              'id': id,
                              'tag_string': 'cat',
                              'file_ext': 'jpg',
                              'image_width': 100,
                              'image_height': 100,
                            },
                        ]
                      : {
                          'counts': {'posts': complete ? 3 : 4},
                        },
                ),
              );
            },
          ),
        );
      final backend = FakeBooruBackend();
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        phone: TestPhone.portrait,
        additionalOverrides: [
          originAwarePostRepoProvider.overrideWith(
            (ref, config) => OriginAwarePostRepository(
              delegate: ref.watch(danbooruPostRepoProvider(config.search)),
              origin: postOriginFromConfig(config),
            ),
          ),
          postRepoProvider.overrideWith(
            (ref, config) => ref.watch(danbooruPostRepoProvider(config)),
          ),
          danbooruClientProvider.overrideWith(
            (ref, auth) => DanbooruClient(baseUrl: auth.url, dio: dio),
          ),
          danbooruCurrentUserProvider.overrideWith((ref, auth) async => null),
        ],
      );
      await harness.pumpUntilFound(tester, postTile(101));
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('parent:12480551', waitForRequest: false);
      await harness.pumpUntilFound(tester, postTile(101));
      await harness.settle(tester);
      expect(postController(tester).hasMore, !complete);
      expect(
        find.descendant(
          of: postGrid().first,
          matching: find.text(appStrings(tester).infinite_scroll.load_more),
        ),
        complete ? findsNothing : findsOneWidget,
      );
      final exact = requests
          .where(
            (request) =>
                request.path == '/counts/posts.json' &&
                request.queryParameters['skip_cache'] == true,
          )
          .toList();
      expect(exact, isNotEmpty);
      expect(exact.last.queryParameters['estimate_count'], false);
      expect(exact.last.queryParameters['tags'], contains('parent:12480551'));
      expect(tester.takeException(), isNull);
    });
  }
}
