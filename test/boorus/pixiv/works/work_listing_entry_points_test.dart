import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
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
  for (final query in [null, '', 'user:7', 'cat']) {
    testWidgets(
      'native entry point $query keeps one card per Work without detail reads',
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
          query == null
              ? Builder(builder: PixivBuilder().homeViewBuilder)
              : PixivWorkSearchPage(params: SearchParams(query: query)),
        );
        await drain(tester);
        final grid = find.byType(NativeContentGrid);
        expect(grid, findsOneWidget);
        expect(find.byType(PostGrid<Post>), findsNothing);
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
