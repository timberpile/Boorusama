import 'dart:async';

import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/navigation/navigation_controller.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/search/following_topics/widgets.dart';
import 'package:boorusama/core/search/search/src/routes/route_utils.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/topic_follow_control.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/headless_app_harness.dart';

void main() {
  testWidgets(
    'modified Topic Follow action is retained from the first viewer return frame',
    (tester) async {
      final harness = await HeadlessAppHarness.mount(
        tester,
        viewportSize: kMobileViewport,
      );
      await harness.pumpUntilFound(tester, find.byType(PostGrid));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppNavigationShell)),
      );
      await harness.pumpUntilComplete(
        tester,
        container
            .read(navigationControllerProvider.notifier)
            .selectDestination(
              const DestinationId.app(AppDestination.following),
            ),
      );
      await harness.settle(tester);
      final ref = tester.element(find.byType(FollowingTopicsPage)) as WidgetRef;
      await harness.pumpUntilComplete(
        tester,
        container
            .read(followingTopicsProvider.notifier)
            .followLocally(
              profileId: harness.booruBackend.config.id,
              query: 'landscape',
              name: 'Viewer regression',
              queryStructure: SearchQueryStructure.typedTags(const [
                'landscape',
              ]),
            ),
      );
      unawaited(
        goToSearchPage(
          ref,
          config: harness.booruBackend.config,
          tags: SearchTagSet.fromList(const ['landscape']),
          queryType: QueryType.list,
          originatingTopicId: container
              .read(followingTopicsProvider)
              .requireValue
              .topics
              .single
              .id,
        ),
      );
      final update = find.byType(TopicFollowPill);
      await harness.pumpUntilFound(tester, update);
      final controller = InheritedSearchPageController.of(
        tester.element(update),
      );
      controller.tagsController.addTag(TagSearchItem.fromString('-dog'));
      await harness.settle(tester);
      expect(tester.widget<TopicFollowPill>(update).modified, isTrue);
      await harness.pumpUntilFound(
        tester,
        find.byType(SliverPostGridImageGridItem),
      );
      await harness.settle(tester);
      final editor = tester.state(find.byType(FollowTopicButton));
      final originalBottom = tester.getRect(update).bottom;
      final navigationTop = tester
          .getRect(find.byKey(const Key('nav-shortcut-browse')))
          .top;
      expect(originalBottom, lessThanOrEqualTo(navigationTop));

      await tester.tap(find.byType(SliverPostGridImageGridItem).first);
      await harness.pumpUntilFound(
        tester,
        find.byType(PostDetailsPageScaffold),
      );
      await harness.settle(tester);
      expect(container.read(navigationChromeProvider).viewerOpen, isTrue);
      await tester.binding.handlePopRoute();
      await harness.pumpUntil(
        tester,
        () => container.read(navigationChromeProvider).viewerClosing,
      );
      await tester.pump();

      // The viewer still owns the page's system insets while its reverse
      // transition reveals the timeline and navigation bar underneath it.
      expect(find.byType(PostDetailsPageScaffold), findsOneWidget);
      expect(container.read(navigationChromeProvider).viewerOpen, isTrue);
      expect(tester.state(find.byType(FollowTopicButton)), same(editor));
      expect(tester.widget<TopicFollowPill>(update).modified, isTrue);
      expect(tester.getRect(update).bottom, originalBottom);
      expect(tester.getRect(update).bottom, lessThanOrEqualTo(navigationTop));
      await harness.settle(tester);
      expect(tester.widget<TopicFollowPill>(update).modified, isTrue);
      expect(tester.getRect(update).bottom, originalBottom);
      expect(tester.takeException(), isNull);
    },
  );
}
