import 'dart:async';

// Package imports:
import 'package:flutter/widgets.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

// Project imports:
import 'package:boorusama/core/home/types.dart';
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/users/user/providers.dart';
import 'package:boorusama/boorus/danbooru/users/user/src/types/user.dart';
import 'package:boorusama/boorus/danbooru/users/user/src/types/user_level.dart';
import 'package:boorusama/boorus/registry.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/settings/types.dart';

import 'support/fake_booru_backend.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_image_dio.dart';
import 'support/headless_app_harness.dart';
import 'support/app_flow_driver.dart';
import '../support/boorusama_test_runtime.dart';

void main() {
  testWidgets(
    'first authenticated Danbooru switch renders the live engine grid',
    (
      tester,
    ) async {
      final backend = FakeBooruBackend();
      final profile = BooruConfig.fromJson({
        ...backend.configB.toJson(),
        'login': 'fixture-user',
        'apiKey': 'fixture-key',
      });
      final response = Completer<UserSelf?>();
      final userRequested = Completer<void>();
      final runtime = createTestBoorusamaRuntime(
        initialState: backend
            .createRuntime(
              configs: [backend.config, profile],
              settings: Settings.defaultSettings.copyWith(
                booruConfigSelectorPosition: BooruConfigSelectorPosition.bottom,
              ),
            )
            .initialState,
        booruDb: backend.booruDb,
        booruRegistry: createBooruRegistry(),
      );
      final harness = await HeadlessAppHarness.mount(
        tester,
        runtime: runtime,
        booruBackend: backend,
        additionalOverrides: [
          deterministicImageDioOverride(),
          deterministicFaviconDioOverride(),
          danbooruCurrentUserProvider.overrideWith((ref, auth) {
            if (auth.url != profile.url) return null;
            if (!userRequested.isCompleted) userRequested.complete();
            return response.future;
          }),
          danbooruDioProvider.overrideWith((ref, auth) {
            final dio = Dio(BaseOptions(baseUrl: auth.url));
            dio.interceptors.add(
              InterceptorsWrapper(
                onRequest: (request, handler) {
                  final id = auth.url == profile.url ? 201 : 101;
                  handler.resolve(
                    Response<dynamic>(
                      requestOptions: request,
                      statusCode: 200,
                      data: request.path == '/posts.json'
                          ? [
                              {
                                'id': id,
                                'file_url': '${auth.url}/original/$id.jpg',
                                'large_file_url': '${auth.url}/sample/$id.jpg',
                                'preview_file_url': '${auth.url}/thumb/$id.jpg',
                                'tag_string': 'landscape',
                                'image_width': 100,
                                'image_height': 100,
                                'rating': 'g',
                              },
                            ]
                          : const <Object>[],
                    ),
                  );
                },
              ),
            );
            ref.onDispose(dio.close);
            return dio;
          }),
        ],
      );
      addTearDown(() {
        if (!response.isCompleted) response.complete(null);
      });

      await harness.pumpUntilFound(tester, postTile(101));
      await harness.settle(tester);
      final shortcut = find.byKey(const Key('nav-shortcut-browse'));
      await tester.tap(
        shortcut.evaluate().isNotEmpty
            ? shortcut
            : find.text(appStrings(tester).navigation.browse).first,
      );
      await harness.settle(tester);
      final picker = find.byTooltip(
        appStrings(tester).navigation.choose_profile,
      );
      if (picker.evaluate().isNotEmpty) {
        await tester.tap(picker);
        await harness.settle(tester);
      }
      await tester.tap(find.text(profile.name).last);
      await harness.pumpUntil(tester, () => userRequested.isCompleted);
      response.complete(
        const UserSelf(
          id: 1,
          level: UserLevel.gold,
          name: 'fixture-user',
          blacklistedTags: {'server_rule'},
        ),
      );

      await harness.pumpUntilFound(tester, postTile(201));
      await harness.settle(tester);
      expect(postTile(201), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switches the active booru and reloads posts from the new config',
    (tester) async {
      final backend = FakeBooruBackend();
      final harness = HeadlessAppHarness(
        booruBackend: backend,
        runtime: backend.createRuntime(
          configs: [backend.config, backend.configB],
          settings: Settings.defaultSettings.copyWith(
            booruConfigSelectorPosition: BooruConfigSelectorPosition.bottom,
          ),
        ),
      );
      addTearDown(() => harness.teardown(tester));

      await harness.pump(tester);
      await harness.pumpUntilFound(
        tester,
        find.byType(SliverPostGridImageGridItem),
      );
      expect(find.byType(SliverPostGridImageGridItem), findsNWidgets(2));
      expect(
        backend.requests.whereType<FakeBooruPostRequest>().last.siteUrl,
        backend.config.url,
      );

      await AppFlowDriver(
        tester: tester,
        harness: harness,
      ).selectProfile(backend.configB);
      await harness.pumpUntil(
        tester,
        () => backend.requests.whereType<FakeBooruPostRequest>().any(
          (request) => request.siteUrl == backend.configB.url,
        ),
      );
      await harness.settle(tester);

      expect(find.byType(SliverPostGridImageGridItem), findsNWidgets(2));
      expect(
        backend.requests.whereType<FakeBooruPostRequest>().last.siteUrl,
        backend.configB.url,
      );
      expect(
        backend.requests.whereType<FakeBooruPostRequest>().last.resultIds,
        [201, 202],
      );
    },
  );
}
