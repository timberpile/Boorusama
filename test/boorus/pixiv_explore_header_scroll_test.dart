import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/explore/feed.dart';
import 'package:boorusama/boorus/pixiv/explore/providers.dart';
import 'package:boorusama/boorus/pixiv/explore/widgets.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../core/search/following_topics/following_topic_test_utils.dart';
import '../support/fakes/test_post.dart';

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
        final origin = PostOrigin.fromSource(
          booruType: BooruType.pixiv,
          booruId: BooruType.pixiv.id,
          source: profile.url,
          profileIdHint: profile.id,
        );
        final repository = _ExploreRepository(
          PixivClient(accessToken: 'fixture', dio: dio),
          origin,
          [
            for (var id = 1; id <= 120; id++) TestPost(id: id, origin: origin),
          ],
        );
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
            pixivExploreRepoProvider.overrideWith((ref, config) => repository),
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
        final grid = find.byType(PostGrid<Post>);
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
          expect(tester.widget<PostGrid<Post>>(grid).controller.total, 120);
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

class _ExploreRepository extends PixivExploreRepository {
  _ExploreRepository(PixivClient client, PostOrigin origin, this.posts)
    : super(client: client, origin: origin);

  final List<Post> posts;

  @override
  PostsOrError<Post> getPosts({
    required PixivExploreFeed feed,
    required int page,
    DateTime? now,
  }) => TaskEither.of(
    PostResult(
      posts: page == 1 ? posts : [],
      total: posts.length,
      hasMore: false,
    ),
  );
}
