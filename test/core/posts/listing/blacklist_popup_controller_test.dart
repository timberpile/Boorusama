import 'dart:async';

import 'package:boorusama/core/posts/listing/src/types/active_blacklist_count.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:foundation/widgets.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../support/fakes/test_post.dart';
import '../../search/following_topics/following_topic_test_utils.dart';

const _button = ValueKey('timeline-blacklist-button');

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'real popup toggles live normalized rules at $scale text with keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final page = _PopupHarness();
        await page.pump(tester, scale: scale, keyboard: 220);
        await page.controller.setBlacklistedTags({'CaT', 'dog'});
        await tester.pumpAndSettle();
        expect(page.controller.items, isEmpty);
        await tester.tap(find.byKey(_button));
        await tester.pumpAndSettle();
        expect(find.byType(BlacklistControls), findsOneWidget);
        await _tapAndPublish(tester, page.controller, find.text('cat'));
        expect(page.controller.activeFilters.value['cat'], isFalse);
        expect(page.controller.items, isEmpty);
        await _tapAndPublish(tester, page.controller, find.text('dog'));
        expect(page.controller.items, hasLength(1));
        expect(
          find.descendant(of: find.byKey(_button), matching: find.text('0')),
          findsOneWidget,
        );
        final strings = tester.element(find.byType(BlacklistControls)).t;
        await _tapAndPublish(
          tester,
          page.controller,
          find.text(strings.blacklisted_tags.reenable_all),
        );
        expect(page.controller.items, isEmpty);
        await _tapAndPublish(
          tester,
          page.controller,
          find.text(strings.blacklisted_tags.disable_all),
        );
        expect(page.controller.items, hasLength(1));
        expect(tester.takeException(), isNull);
        await page.close(tester);
      },
    );
  }

  testWidgets(
    'real popup clamps shrinking pages and resets for a different source',
    (tester) async {
      final page = _PopupHarness();
      await page.pump(tester);
      final rules = {for (var i = 0; i < 75; i++) 'rule_$i'};
      await page.controller.setBlacklistedTags(rules);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      // Use the real page selector callbacks; assertions inspect its actual chips.
      tester.widget<PageSelector>(find.byType(PageSelector)).onPageSelect!(3);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageSelector>(find.byType(PageSelector)).currentPage,
        3,
      );
      expect(find.text('rule 60'), findsOneWidget);
      await tester.runAsync(
        () => page.controller.setBlacklistedTags(rules.take(35).toSet()),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageSelector>(find.byType(PageSelector)).currentPage,
        2,
      );
      expect(find.text('rule 30'), findsOneWidget);
      expect(find.byType(KurumiMaterialChoiceChip), findsNWidgets(5));
      await page.replaceSource(tester);
      expect(find.byType(BlacklistControls), findsNothing);
      await tester.runAsync(
        () => page.controller.setBlacklistedTags(rules.take(35).toSet()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageSelector>(find.byType(PageSelector)).currentPage,
        1,
      );
      expect(find.text('rule 0'), findsOneWidget);
      expect(find.byType(KurumiMaterialChoiceChip), findsNWidgets(30));
      expect(tester.takeException(), isNull);
      await page.close(tester);
    },
  );
}

Future<void> _tapAndPublish(
  WidgetTester tester,
  PostGridController<Post> controller,
  Finder target,
) async {
  final completed = Completer<void>();
  void listener() {
    if (!completed.isCompleted) completed.complete();
  }

  controller.addListener(listener);
  try {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(completed.isCompleted, isTrue);
    await completed.future;
    await tester.pumpAndSettle();
  } finally {
    controller.removeListener(listener);
  }
}

class _PopupHarness {
  final harness = FollowingTopicHarness();
  late PostGridController<Post> controller;
  var otherSource = false;
  var mounted = true;

  void createController() {
    controller = PostGridController<Post>(
      fetcher: (_) => TaskEither.right(
        PostResult(
          posts: [
            TestPost(
              id: 1,
              tags: {'cat', 'dog', for (var i = 0; i < 75; i++) 'rule_$i'},
            ),
          ],
          total: 1,
        ),
      ),
      blacklistedTagsFetcher: () async => {},
      // Exercise real matching with a controlled computation scheduler. Native
      // isolate ordering is covered separately by controller tests.
      blacklistCounter: (posts, rules) async =>
          countPostBlacklistMatches(posts, rules),
      mountedChecker: () => mounted,
      duplicateTracker: PostDuplicateTracker<Post>(),
      onError: (_) {},
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    double scale = 1,
    double keyboard = 0,
  }) async {
    createController();
    await harness.pump(
      tester,
      MediaQuery(
        data: MediaQueryData(
          size: const Size(320, 640),
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => PostListConfigurationHeader(
                key: ValueKey((controller, otherSource)),
                postCount: controller.total,
                hasBlacklist: controller.hasBlacklist.value,
                hiddenCount: countActiveBlacklistPosts(
                  controller.tagCounts.value,
                  controller.activeFilters.value,
                ),
                blacklistChanges: controller,
                blacklistControls: ValueListenableBuilder(
                  valueListenable: controller.visibleHiddenTags,
                  builder: (_, tags, _) => BlacklistControls(
                    hiddenTags: tags,
                    axis: Axis.horizontal,
                    onEnableAll: controller.enableAllTags,
                    onDisableAll: controller.disableAllTags,
                    onChanged: (tag, hide) {
                      if (hide) {
                        controller.enableTag(tag);
                      } else {
                        controller.disableTag(tag);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await controller.refresh();
    await tester.pumpAndSettle();
  }

  Future<void> replaceSource(WidgetTester tester) async {
    final previous = controller;
    otherSource = true;
    await pump(tester);
    previous.dispose();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    mounted = false;
    controller.dispose();
    harness.dispose();
  }
}
