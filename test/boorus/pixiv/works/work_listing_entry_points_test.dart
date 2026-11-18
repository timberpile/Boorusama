import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/pixiv_builder.dart';
import 'package:boorusama/boorus/pixiv/works/search_page.dart';
import 'package:boorusama/boorus/pixiv/works/work_presentation.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/content/widgets/native_content_grid.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:boorusama/core/search/search/src/widgets/search_profile_session.dart';
import 'package:boorusama/core/search/search/widgets.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../../../core/search/following_topics/following_topic_test_utils.dart';
import 'work_test_fixtures.dart';

void main() {
  test(
    'legacy position counts usable projected Pages instead of declared counts',
    () {
      final counts = pixivWorkLegacyPageCounts([
        work(
          id: 120,
          pageCount: 3,
          pages: [
            page(120, 0),
            {
              'image_urls': {'original': 'invalid'},
            },
            page(120, 2),
          ],
        ),
        work(id: 121, pageCount: null, pages: [page(121, 0), page(121, 1)]),
        work(id: 122, pageCount: 1),
      ]);
      expect(counts, [2, 2, 1]);
      expect(pixivWorkIndexForPagePosition(counts, 2), 1);
      expect(pixivWorkIndexForPagePosition(counts, 4), 2);
      expect(pixivWorkIndexForPagePosition(counts, -1), 0);
      expect(pixivWorkIndexForPagePosition(counts, 900), 2);
    },
  );
  for (final local in [false, true]) {
    for (final query in [null, '', 'user:7', 'cat']) {
      testWidgets(
        'native entry point $query local=$local keeps one card per Work without detail reads',
        (tester) async {
          final access = workAccess();
          final config = access.config!;
          final client = _Client();
          final harness = FollowingTopicHarness(
            profiles: [config],
            overrides: [
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
            SearchProfileSession(
              local: local,
              snapshot: null,
              onSwitch: (_, _) {},
              child: query == null
                  ? Builder(builder: PixivBuilder().homeViewBuilder)
                  : PixivWorkSearchPage(params: SearchParams(query: query)),
            ),
          );
          await drain(tester);
          final grid = find.byType(NativeContentGrid);
          expect(grid, findsOneWidget);
          expect(find.byType(PostGrid<Post>), findsNothing);
          final view = find.descendant(
            of: grid,
            matching: find.byType(CustomScrollView),
          );
          final controller = NativeContentGrid.controllerOf(
            tester.element(view),
          );
          expect(controller.entries, hasLength(3));
          expect(
            controller.entries.whereType<GroupContentEntry>(),
            hasLength(2),
          );
          expect(
            controller.entries.whereType<PostContentEntry>(),
            hasLength(1),
          );
          expect(client.calls, [
            switch (query) {
              'user:7' => ('artist', '7', 1),
              'cat' => ('search', 'cat', 1),
              _ => ('ranking', '', 1),
            },
          ]);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  for (final layout in [ImageListType.standard, ImageListType.masonry]) {
    testWidgets('route restores legacy Page position to one Work in $layout', (
      tester,
    ) async {
      final config = workAccess().config!;
      final client = _Client(count: 60);
      final harness = FollowingTopicHarness(
        profiles: [config],
        listingSettings: Settings.defaultSettings.listing.copyWith(
          pageMode: PageMode.infinite,
          imageListType: layout,
        ),
        overrides: [
          currentReadOnlyBooruConfigProvider.overrideWithValue(config),
          pixivClientProvider.overrideWith((ref, _) => client),
          booruGroupCapabilityProvider.overrideWith(
            (ref, _) => createPixivGroupCapability(ref),
          ),
        ],
      );
      addTearDown(harness.dispose);
      await harness.pump(
        tester,
        const PixivWorkSearchPage(
          params: SearchParams(query: 'cat', page: 4, scrollPosition: 91),
        ),
      );
      await tester.pumpAndSettle();
      final grid = find.byType(NativeContentGrid);
      final view = find.descendant(
        of: grid,
        matching: find.byType(CustomScrollView),
      );
      final controller = NativeContentGrid.controllerOf(tester.element(view));
      expect(controller.pageMode, PageMode.paginated);
      expect(controller.page, 4);
      expect(controller.entries, hasLength(60));
      final scroll = tester.widget<CustomScrollView>(view).controller!;
      expect(scroll.offset, greaterThan(0));
      // Legacy flat Page 91 belongs to Work index 30 (three Pages per Work).
      final target = find.text('Work 150');
      expect(target, findsOneWidget);
      expect(tester.getRect(view).overlaps(tester.getRect(target)), isTrue);
      scroll.jumpTo(0);
      await controller.refresh();
      await tester.pumpAndSettle();
      expect(scroll.offset, 0, reason: 'Restoration applies once per route');
      await controller.loadPage(3);
      await tester.pumpAndSettle();
      expect(controller.page, 3);
      await controller.loadPage(4);
      await tester.pumpAndSettle();
      expect(controller.page, 4);
      final raw = tester.widget<RawSearchPageScaffold<Post>>(
        find.byType(RawSearchPageScaffold<Post>),
      );
      raw.controller.skipToResultWithTag('dog');
      await tester.pumpAndSettle();
      final resetView = find.descendant(
        of: find.byType(NativeContentGrid),
        matching: find.byType(CustomScrollView),
      );
      final reset = NativeContentGrid.controllerOf(tester.element(resetView));
      expect(reset.page, 1);
      expect(reset.pageMode, PageMode.infinite);
      expect(tester.widget<CustomScrollView>(resetView).controller!.offset, 0);
      expect(client.calls.last, ('search', 'dog', 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'failed refresh retains the authorized seeded Work source offline',
    (tester) async {
      final config = workAccess().config!;
      final client = _Client();
      final harness = FollowingTopicHarness(
        profiles: [config],
        overrides: [
          currentReadOnlyBooruConfigProvider.overrideWithValue(config),
          pixivClientProvider.overrideWith((ref, _) => client),
          booruGroupCapabilityProvider.overrideWith(
            (ref, _) => createPixivGroupCapability(ref),
          ),
        ],
      );
      addTearDown(harness.dispose);
      await harness.pump(
        tester,
        const PixivWorkSearchPage(params: SearchParams(query: 'cat')),
      );
      await tester.pumpAndSettle();
      final access = harness.container.read(
        contentProfileAccessProvider(config.id),
      )!;
      final source = harness.container.read(
        contentGroupSourceProvider(access.key),
      );
      final view = find.descendant(
        of: find.byType(NativeContentGrid),
        matching: find.byType(CustomScrollView),
      );
      final controller = NativeContentGrid.controllerOf(tester.element(view));
      final reference = controller.entries.first.reference;
      expect((await source.loadSummary(reference).run()).isRight(), isTrue);
      client.pageCount = 2;
      await controller.refresh();
      await tester.pumpAndSettle();
      final refreshed = await source.loadSummary(reference).run();
      refreshed.fold(
        (error) => fail('$error'),
        (summary) => expect(summary.memberCount, 2),
      );
      client.offline = true;
      await controller.refresh();
      await tester.pumpAndSettle();
      expect(
        harness.container.read(contentGroupSourceProvider(access.key)),
        same(source),
      );
      expect((await source.loadSummary(reference).run()).isRight(), isTrue);
      expect(controller.errors.value, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'account switch recreates the authorized route and its anchor once',
    (tester) async {
      final first = workAccess().config!;
      final second = workAccess(id: '22222222-2222-4222-8222-222222222222')
          .config!;
      var active = first;
      final client = _Client(count: 60);
      final harness = FollowingTopicHarness(
        profiles: [first, second],
        overrides: [
          currentReadOnlyBooruConfigProvider.overrideWith((ref) => active),
          pixivClientProvider.overrideWith((ref, _) => client),
          booruGroupCapabilityProvider.overrideWith(
            (ref, _) => createPixivGroupCapability(ref),
          ),
        ],
      );
      addTearDown(harness.dispose);
      await harness.pump(
        tester,
        const PixivWorkSearchPage(
          params: SearchParams(query: 'cat', page: 4, scrollPosition: 91),
        ),
      );
      await tester.pumpAndSettle();
      Finder view() => find.descendant(
        of: find.byType(NativeContentGrid),
        matching: find.byType(CustomScrollView),
      );
      final old = NativeContentGrid.controllerOf(tester.element(view()));
      active = second;
      harness.container.invalidate(currentReadOnlyBooruConfigProvider);
      await tester.pumpAndSettle();
      final next = NativeContentGrid.controllerOf(tester.element(view()));
      expect(next, isNot(same(old)));
      expect(next.access.key.profileId, second.id);
      expect(next.page, 4);
      expect(next.pageMode, PageMode.paginated);
      expect(
        tester.widget<CustomScrollView>(view()).controller!.offset,
        greaterThan(0),
      );
      expect(
        tester.getRect(view()).overlaps(tester.getRect(find.text('Work 150'))),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('explicit Post-only session retains the compatibility page', (
    tester,
  ) async {
    final config = workAccess().config!;
    final harness = FollowingTopicHarness(
      profiles: [config],
      overrides: [currentReadOnlyBooruConfigProvider.overrideWithValue(config)],
    );
    addTearDown(harness.dispose);
    await harness.pump(
      tester,
      SearchProfileSession(
        local: true,
        postResultsOnly: true,
        snapshot: null,
        onSwitch: (_, _) {},
        child: const PixivWorkSearchPage(params: SearchParams()),
      ),
    );
    await drain(tester);
    expect(find.byType(DefaultSearchPage), findsOneWidget);
    expect(find.byType(NativeContentGrid), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Client extends PixivClient {
  _Client({this.count = 3}) : super(accessToken: 'fixture');
  final int count;
  var offline = false;
  var pageCount = 3;
  final calls = <(String, String, int)>[];
  PixivIllustListResult _result(String endpoint, String query, int page) {
    calls.add((endpoint, query, page));
    if (offline) throw StateError('offline');
    return PixivIllustListResult(
      illusts: count != 3
          ? [
              for (var i = 0; i < count; i++)
                work(id: 120 + i, height: i.isEven ? 800 : 2100),
            ]
          : [
              work(pageCount: pageCount),
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
