import 'dart:async';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/pixiv.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart' show PixivPostDataX;
import 'package:boorusama/boorus/pixiv/works/related_page.dart';
import 'package:boorusama/boorus/pixiv/works/related_section.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/boorus/pixiv/works/work_source.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/widgets/native_content_grid.dart';
import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/navigation/navigation_controller.dart';
import 'package:boorusama/core/posts/details/routes.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_prefetch.dart';
import 'package:boorusama/core/posts/pools/pool_grid_item.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../boorus/pixiv/works/work_test_fixtures.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/fake_image_dio.dart';
import 'support/headless_app_harness.dart';

void main() {
  for (final reduceMotion in [false, true]) {
    testWidgets(
      'Pixiv Work opens related timeline and returns, reduced=$reduceMotion',
      (
        tester,
      ) async {
        final backend = FakeBooruBackend(
          additionalBoorus: {BooruType.pixiv: createPixiv().parser.parse()},
        )..registry.register(BooruType.pixiv, createPixiv());
        final pixiv = workAccess().config!.copyWith(apiKey: 'fixture');
        final anchor = work(id: 42);
        final relatedRequests = <Map<String, String>>[];
        final dio = Dio(BaseOptions(baseUrl: kPixivApiBaseUrl));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              final related = request.path == '/v2/illust/related';
              final next = request.queryParameters.containsKey('viewed[0]');
              if (related) relatedRequests.add(request.uri.queryParameters);
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: {
                    'illusts': [
                      if (related)
                        for (final id
                            in next
                                ? [100, 200]
                                : List.generate(8, (i) => 100 + i))
                          {
                            'id': id,
                            'title': 'Recommendation $id',
                            'page_count': 1,
                            'user': {'id': 7},
                            'width': 1200,
                            'height': 1800,
                            'meta_single_page': {
                              'original_image_url':
                                  'https://i.pximg.net/original/${id}_p0.jpg',
                            },
                            'tags': [],
                            'x_restrict': 0,
                          },
                    ],
                    'next_url': related && !next
                        ? '$kPixivApiBaseUrl/v2/illust/related'
                              '?illust_id=42&filter=for_ios&viewed[0]=100'
                        : null,
                  },
                ),
              );
            },
          ),
        );
        final harness = await HeadlessAppHarness.mount(
          tester,
          booruBackend: backend,
          viewportSize: const Size(320, 844),
          runtime: backend.createRuntime(
            configs: [backend.config, pixiv],
            settings: Settings.defaultSettings.copyWith(
              reduceAnimations: reduceMotion,
            ),
          ),
          additionalOverrides: [
            deterministicImageDioOverride(),
            deterministicFaviconDioOverride(),
            pixivClientProvider.overrideWith(
              (_, _) => PixivClient(accessToken: 'fixture', dio: dio),
            ),
            contentGroupSourceProvider.overrideWith((ref, key) {
              final source = PixivWorkSource(
                access: ref.watch(contentAccessContextProvider(key))!,
                fetchWork: (id) async =>
                    id == anchor.id ? anchor : work(id: id, pageCount: 1),
              );
              ref.onDispose(source.dispose);
              return source;
            }),
          ],
        );
        await harness.pumpUntilFound(tester, postTile(101));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(AppNavigationShell)),
          listen: false,
        );
        final binding = container
            .read(navigationControllerProvider.notifier)
            .binding!;
        final router = container.read(routerProvider);
        unawaited(
          router.push<void>(
            '${binding.currentDestination!.location}/details',
            extra: DetailsRouteContext<Post>(
              initialIndex: 0,
              posts: const [],
              scrollController: null,
              isDesktop: false,
              hero: false,
              initialThumbnailUrl: null,
              config: pixiv,
              useMixedViewer: true,
              entries: [
                GroupViewerEntry(
                  summary: pixivWorkSummary(anchor, workAccess()),
                  occurrenceId: Object(),
                  source: ViewerSourceBinding(pixiv),
                ),
              ],
            ),
          ),
        );
        await harness.pumpUntilFound(tester, find.byType(PostDetailsPageView));
        expect(relatedRequests, isEmpty);
        final original = binding.currentRoute;
        final pager = tester
            .widget<PostDetailsPageView>(find.byType(PostDetailsPageView))
            .controller!;
        await harness.pumpUntilComplete(tester, pager.expandToSnapPoint());
        final section = find.byType(PixivRelatedWorksSection);
        await harness.pumpUntilFound(tester, section);
        await tester.ensureVisible(section);
        final header = find.text('Related Works');
        await harness.pumpUntilFound(tester, header);
        final scrollable = find.descendant(
          of: find.byType(PostDetailsPageView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        );
        await tester.scrollUntilVisible(
          header.hitTestable(),
          140,
          scrollable: scrollable,
          maxScrolls: 6,
        );
        await harness.settle(tester);
        expect(header.hitTestable(), findsOneWidget);
        expect(relatedRequests, hasLength(1));
        expect(relatedRequests.single['illust_id'], '42');

        await tester.tap(header);
        await harness.pumpUntilFound(
          tester,
          find.byType(PixivRelatedTimelinePage),
        );
        await harness.pumpUntil(tester, () => relatedRequests.length == 2);
        expect(relatedRequests.last['viewed[0]'], '100');
        final timeline = find.byType(PixivRelatedTimelinePage);
        final controller =
            tester
                    .widget<PostGridPrefetch>(
                      find.descendant(
                        of: timeline,
                        matching: find.byType(PostGridPrefetch),
                      ),
                    )
                    .controller
                as NativeContentController;
        await harness.pumpUntil(tester, () => !controller.loadingMore);
        expect(controller.errors.value, isNull);
        expect(
          controller.entries.map((entry) => entry.reference.sourceKey),
          [for (var id = 100; id < 108; id++) 'work:$id', 'work:200'],
        );

        binding.currentNavigator!.pop();
        await harness.settle(tester);
        expect(binding.currentRoute, same(original));
        expect(header.hitTestable(), findsOneWidget);
        expect(relatedRequests, hasLength(2));

        final previewTile = find
            .descendant(
              of: section,
              matching: find.byType(PoolGridItem),
            )
            .first;
        await tester.scrollUntilVisible(
          previewTile.hitTestable(),
          90,
          scrollable: scrollable,
          maxScrolls: 6,
        );
        await harness.settle(tester);
        await tester.tap(previewTile);
        await harness.pumpUntil(tester, () => binding.currentRoute != original);
        await harness.settle(tester);
        final previewViewer = find.byType(PostDetailsPageView).last;
        final previewPager = tester
            .widget<PostDetailsPageView>(previewViewer)
            .controller!;
        expect(previewPager.totalPage, 8);
        expect(previewPager.page, 0);
        int? previewArtworkId() => tester
            .widget<PostDetailsPageScaffold>(postDetailsScaffold().last)
            .controller
            ?.currentPost
            .value
            .pixivData
            ?.illustId;
        await harness.pumpUntil(tester, () => previewArtworkId() == 100);
        await tester.dragFrom(const Offset(270, 350), const Offset(-235, 0));
        await harness.pumpUntil(tester, () => previewPager.page == 1);
        await harness.pumpUntil(tester, () => previewArtworkId() == 101);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
