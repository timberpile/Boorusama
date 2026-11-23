import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/explore/widgets.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/navigation_catalog.dart';
import 'package:boorusama/core/navigation/navigation_catalog_provider.dart';
import 'package:boorusama/core/navigation/destination_profile_scope.dart';
import 'package:boorusama/core/navigation/navigation_interaction_scopes.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/search/search/src/widgets/search_profile_session.dart';
import 'package:boorusama/boorus/pixiv/pixiv_builder.dart';
import 'package:boorusama/boorus/pixiv/works/search_page.dart';
import 'package:boorusama/boorus/pixiv/works/work_presentation.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/content/widgets/native_content_grid.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../../../core/search/following_topics/following_topic_test_utils.dart';
import 'work_test_fixtures.dart';

void main() {
  for (final query in [null, '', 'user:7', 'cat', 'explore', 'local-search']) {
    testWidgets(
      'route $query forwards navigation scroll exactly once',
      (tester) async {
        final access = workAccess();
        final config = access.config!;
        final client = _Client();
        final harness = FollowingTopicHarness(
          profiles: [config],
          overrides: [
            navigationCatalogProvider.overrideWithValue(
              NavigationCatalog(
                profileSections: [],
                globalEntries: [],
                eligibleFavoritesProfileIds: [],
              ),
            ),
            currentReadOnlyBooruConfigProvider.overrideWith((ref) => config),
            pixivClientProvider.overrideWith((ref, _) => client),
            booruGroupCapabilityProvider.overrideWith(
              (ref, _) => createPixivGroupCapability(ref),
            ),
          ],
        );
        addTearDown(harness.dispose);
        await harness.pump(
          tester,
          DestinationScope(
            id: DestinationId.browse(config.id),
            child: NavigationBarScrollScope(
              extent: 100,
              child: SearchProfileSession(
                local: query == 'local-search',
                snapshot: null,
                onSwitch: (_, _) {},
                child: query == null
                    ? Builder(builder: PixivBuilder().homeViewBuilder)
                    : query == 'explore'
                    ? const PixivExplorePage()
                    : PixivWorkSearchPage(
                        params: SearchParams(
                          query: query == 'local-search' ? 'cat' : query,
                        ),
                      ),
              ),
            ),
          ),
        );
        await drain(tester);
        final grid = find.byType(NativeContentGrid);
        if (query == 'local-search' && grid.evaluate().isEmpty) {
          expect(find.byType(PostGrid<Post>), findsOneWidget);
        } else {
          expect(grid, findsOneWidget);
          expect(find.byType(PostGrid<Post>), findsNothing);
        }
        final scrollContext = tester.element(
          find.byType(CustomScrollView).first,
        );
        const pixels = 200.0;
        final metrics = FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 1000,
          pixels: pixels,
          viewportDimension: 500,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1,
        );
        void update(double delta) => ScrollUpdateNotification(
          metrics: metrics,
          context: scrollContext,
          scrollDelta: delta,
          dragDetails: DragUpdateDetails(
            globalPosition: Offset.zero,
            delta: Offset(0, -delta),
          ),
        ).dispatch(scrollContext);
        update(30);
        expect(
          harness.container.read(navigationChromeProvider).barHiddenFraction,
          closeTo(.3, .000001),
          reason: 'one event must be forwarded exactly once',
        );
        update(-30);
        expect(
          harness.container.read(navigationChromeProvider).barHiddenFraction,
          closeTo(0, .000001),
        );
        if (query == 'local-search' && grid.evaluate().isEmpty) {
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          return;
        }
        final view = find.descendant(
          of: grid,
          matching: find.byType(CustomScrollView),
        );
        final controller = NativeContentGrid.controllerOf(tester.element(view));
        expect(controller.entries, hasLength(3));
        expect(controller.entries.whereType<GroupContentEntry>(), hasLength(2));
        expect(controller.entries.whereType<PostContentEntry>(), hasLength(1));
        expect(client.calls, [
          switch (query) {
            'user:7' => ('artist', '7', 1),
            'cat' || 'local-search' => ('search', 'cat', 1),
            'explore' => ('ranking', '', 1),
            _ => ('ranking', '', 1),
          },
        ]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

class _Client extends PixivClient {
  _Client() : super(accessToken: 'fixture');
  final calls = <(String, String, int)>[];
  PixivIllustListResult _result(String endpoint, String query, int page) {
    calls.add((endpoint, query, page));
    return PixivIllustListResult(
      illusts: [
        work(),
        work(id: 121),
        work(id: 122, type: 'ugoira'),
      ],
    );
  }

  @override
  Future<PixivIllustListResult> getRanking({
    PixivRankingMode mode = PixivRankingMode.day,
    DateTime? date,
    int page = 1,
  }) async => _result('ranking', '', page);

  @override
  Future<PixivIllustListResult> getUserIllusts({
    required int userId,
    int page = 1,
  }) async => _result('artist', '$userId', page);

  @override
  Future<PixivIllustListResult> searchIllust({
    required String word,
    DateTime? startDate,
    DateTime? endDate,
    PixivSearchSort sort = PixivSearchSort.dateDesc,
    PixivSearchTarget searchTarget = PixivSearchTarget.partialMatchForTags,
    int page = 1,
  }) async => _result('search', word, page);

  @override
  Future<PixivIllustDto?> getIllustDetail({required int illustId}) =>
      throw StateError('A card must not fetch artwork details');
}
