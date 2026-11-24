import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/works/author_section.dart';
import 'package:boorusama/boorus/pixiv/works/related_page.dart';
import 'package:boorusama/boorus/pixiv/works/related_section.dart';
import 'package:boorusama/boorus/pixiv/works/related_source.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/details/routes.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/pools/pool_grid_item.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'work_test_fixtures.dart';

void main() {
  for (final author in [false, true]) {
    testWidgets(
      'loads a visible Work preview once with swiping, author=$author',
      (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 840);
        tester.view.devicePixelRatio = 1;
        final base = workAccess();
        final access = ContentAccessContext.profile(
          config: base.config!.copyWith(apiKey: 'fixture'),
          authEpoch: 1,
          policyEpoch: 1,
        );
        final pages = pixivWorkPagePosts(
          work(id: 42, artist: 'Artist_Name'),
          access,
        );
        final selected = ValueNotifier(0);
        final scroll = ScrollController();
        final liveAccess = StateProvider<ContentAccessContext?>((_) => access);
        final queries = <Object>[];
        final title = author ? 'Artist' : 'Related Works';
        final firstPage = PixivRelatedPage([
          for (var id = 100; id < 114; id++)
            PixivIllustDto.fromJson({
              'id': id,
              'page_count': 1,
              'type': 'illust',
              'user': {'id': 7},
            }),
        ]);
        PixivRelatedPageArgs? timeline;
        DetailsRouteContext<dynamic>? opened;
        SearchRouteContext? search;
        String? authorFilter;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: ValueListenableBuilder(
                  valueListenable: selected,
                  builder: (_, index, _) => InheritedPost(
                    presentationContext: PostPresentationContext.generic(
                      pages[index],
                    ),
                    child: CustomScrollView(
                      controller: scroll,
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 1100)),
                        if (author)
                          const PixivAuthorWorksSection()
                        else
                          const PixivRelatedWorksSection(),
                        const SliverToBoxAdapter(child: SizedBox(height: 640)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/pixiv/related',
              builder: (_, state) {
                timeline = state.extra! as PixivRelatedPageArgs;
                return const Scaffold(body: Text('Timeline destination'));
              },
            ),
            GoRoute(
              path: '/search',
              builder: (_, state) {
                search = state.extra! as SearchRouteContext;
                authorFilter = SearchParams.fromUri(state.uri).query;
                return const Scaffold(body: Text('Timeline destination'));
              },
            ),
            GoRoute(
              path: '/details',
              builder: (_, state) {
                opened = state.extra! as DetailsRouteContext<dynamic>;
                return const Scaffold(body: Text('Artwork destination'));
              },
            ),
          ],
        );
        final container = ProviderContainer(
          overrides: [
            routerProvider.overrideWithValue(router),
            currentContentAccessKeyProvider.overrideWithValue(access.key),
            contentAccessContextProvider.overrideWith(
              (ref, key) => ref.watch(liveAccess),
            ),
            pixivAuthorWorksPreviewProvider.overrideWith((ref, query) {
              queries.add(query);
              return Future.value(
                PixivIllustListResult(illusts: firstPage.illusts),
              );
            }),
            pixivRelatedFirstPageProvider.overrideWith((ref, query) {
              queries.add(query);
              return Future.value(firstPage);
            }),
          ],
        );
        final visibility = VisibilityDetectorController.instance;
        final interval = visibility.updateInterval;
        visibility.updateInterval = Duration.zero;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          visibility.updateInterval = interval;
          container.dispose();
          router.dispose();
          selected.dispose();
          scroll.dispose();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: BooruLocalization(
              child: MaterialApp.router(
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(queries, isEmpty);

        scroll.jumpTo(1100);
        await tester.pumpAndSettle();
        expect(queries, [
          if (author)
            (access: access.key, userId: 7)
          else
            (access: access.key, illustId: 42),
        ]);
        expect(find.byType(PoolGridItem), findsNWidgets(6));
        if (author) expect(find.text('Artist_Name'), findsOneWidget);

        selected.value = 2;
        await tester.pumpAndSettle();
        expect(queries, hasLength(1));

        await tester.tap(find.text('Show 6 more'));
        await tester.pumpAndSettle();
        expect(find.byType(PoolGridItem), findsNWidgets(12));
        expect(queries, hasLength(1));

        final offset = scroll.offset;
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(find.text('Timeline destination'), findsOneWidget);
        if (author) {
          expect(authorFilter, 'user:7');
          expect(search?.config, access.config);
        } else {
          expect(timeline?.query, (access: access.key, illustId: 42));
          expect(timeline?.firstPage, same(firstPage));
        }

        router.pop();
        await tester.pumpAndSettle();
        expect(scroll.offset, offset);
        expect(find.byType(PoolGridItem), findsNWidgets(12));
        expect(selected.value, 2);

        tester.widget<PoolGridItem>(find.byType(PoolGridItem).at(3)).onTap();
        await tester.pumpAndSettle();
        expect(opened!.initialIndex, 3);
        expect(
          opened!.entries!.map((entry) => entry.contentReference!.sourceKey),
          [for (var id = 100; id < 114; id++) 'work:$id'],
        );
        expect(
          opened!.entries!.every(
            (entry) => entry.source!.config == access.config,
          ),
          isTrue,
        );

        router.pop();
        await tester.pumpAndSettle();
        final oldTap = tester
            .widget<PoolGridItem>(find.byType(PoolGridItem).first)
            .onTap;
        container.read(liveAccess.notifier).state = null;
        oldTap();
        await tester.pumpAndSettle();
        expect(find.text(title), findsNothing);
        expect(find.text('Artwork destination'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
