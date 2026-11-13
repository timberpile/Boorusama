import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/explore/feed.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/works/work_presentation.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/widgets/native_content_grid.dart';

import 'pixiv/works/work_test_fixtures.dart' as works;

import 'package:boorusama/boorus/pixiv/explore/widgets.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../core/search/following_topics/following_topic_test_utils.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'only the Explore timeline returns on reverse scroll at $scale',
      (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final profile = BooruConfig.fromJson({
          ...BooruConfig.defaultConfig(
            booruType: BooruType.pixiv,
            url: 'https://pixiv.net/',
            customDownloadFileNameFormat: null,
          ).toJson(),
          'id': testProfile.id,
        });
        final dio = Dio();
        addTearDown(() => dio.close(force: true));
        const settings = Settings.defaultSettings;
        final harness = FollowingTopicHarness(
          profiles: [profile],
          settings: settings.copyWith(
            listing: settings.listing.copyWith(
              keepTimelineToolbarVisible: false,
            ),
          ),
          overrides: [
            currentReadOnlyBooruConfigProvider.overrideWith((ref) => profile),
            pixivClientProvider.overrideWith((ref, _) => _Client()),
            booruGroupCapabilityProvider.overrideWith(
              (ref, _) => createPixivGroupCapability(ref),
            ),
          ],
        );
        addTearDown(harness.dispose);
        await harness.pump(
          tester,
          MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 844),
              padding: const EdgeInsets.only(top: 24),
              textScaler: TextScaler.linear(scale),
            ),
            child: const PixivExplorePage(),
          ),
        );
        await drain(tester);
        final grid = find.byType(NativeContentGrid);
        final selector = find.byType(
          KurumiSegmentedButton<PixivExploreFeedKind>,
        );
        final toolbar = find.byType(PostListConfigurationHeader);
        final title = find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText() == 'Explore',
        );
        final vertical = find
            .descendant(
              of: grid,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              ),
            )
            .first;
        for (final feed in ['Ranking', 'Following', 'Recommended']) {
          if (feed != 'Ranking') {
            await tester.tap(find.text(feed));
            await tester.pumpAndSettle();
          }
          expect(
            NativeContentGrid.controllerOf(tester.element(vertical)).entries,
            hasLength(120),
          );
          expect(selector.hitTestable(), findsOneWidget);
          expect(title.hitTestable(), findsOneWidget);
          final position = tester.state<ScrollableState>(vertical).position;
          for (var scroll = 0; scroll < 3; scroll++) {
            await tester.drag(vertical, const Offset(0, -600));
            await tester.pumpAndSettle();
          }
          expect(selector.hitTestable(), findsNothing);
          final gesture = await tester.startGesture(tester.getCenter(vertical));
          try {
            await gesture.moveBy(const Offset(0, 420));
            // Floating SliverAppBars read the direction during layout. Keep the
            // pointer down until that frame has painted, as on a real device.
            await tester.pumpAndSettle();
            expect(position.pixels, greaterThan(1000));
            expect(title.hitTestable(), findsNothing);
            expect(selector.hitTestable(), findsNothing);
          } finally {
            await gesture.up();
          }
          await tester.pumpAndSettle();
          expect(toolbar.hitTestable(), findsOneWidget);
          expect(tester.getTopLeft(toolbar).dy, greaterThanOrEqualTo(24));
          expect(title.hitTestable(), findsNothing);
          expect(selector.hitTestable(), findsNothing);
          position.jumpTo(0);
          await tester.pumpAndSettle();
          expect(selector.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}

class _Client extends PixivClient {
  _Client() : super(accessToken: 'fixture');
  PixivIllustListResult _page(int page) => PixivIllustListResult(
    illusts: page == 1
        ? [for (var id = 1; id <= 120; id++) works.work(id: id)]
        : [],
    hasMore: false,
  );
  @override
  Future<PixivIllustListResult> getRanking({
    PixivRankingMode mode = PixivRankingMode.day,
    DateTime? date,
    int page = 1,
  }) async => _page(page);
  @override
  Future<PixivIllustListResult> getFollowedIllusts({
    PixivFollowRestrict restrict = PixivFollowRestrict.all,
    int page = 1,
  }) async => _page(page);
  @override
  Future<PixivIllustListResult> getRecommendedIllusts({int page = 1}) async =>
      _page(page);
}
