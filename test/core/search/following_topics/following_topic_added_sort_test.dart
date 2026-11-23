import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import 'following_topic_test_utils.dart';

void main() {
  test('folder switching applies the view sort without mutating either manual list', () async {
    FollowingTopic topic(String id, int day) => FollowingTopic.create(
      id: id,
      profileId: 'profile',
      query: id,
      name: id,
      position: 0,
      createdAt: DateTime.utc(2020, 1, day),
    );
    final first = [topic('old', 1), topic('new', 3)];
    final second = [topic('other', 2)];
    final harness = FollowingTopicHarness(
      overrides: [
        organizedFollowingTopicsProvider.overrideWith(
          (ref, id) => AsyncData(id == 'first' ? first : second),
        ),
      ],
    );
    addTearDown(harness.dispose);
    await harness.container
        .read(followingTopicSortProvider.notifier)
        .select(FollowingTopicSort.addedNewest);
    expect(
      harness.container
          .read(visibleFollowingTopicsProvider('first'))
          .asData!
          .value
          .map((t) => t.id),
      ['new', 'old'],
    );
    expect(
      harness.container
          .read(visibleFollowingTopicsProvider('second'))
          .asData!
          .value,
      second,
    );
    expect(first.map((t) => t.id), ['old', 'new']);
    await harness.container
        .read(followingTopicSortProvider.notifier)
        .select(FollowingTopicSort.manual);
    expect(
      harness.container
          .read(visibleFollowingTopicsProvider('first'))
          .asData!
          .value,
      first,
    );
  });

  for (final keyboardOpen in [false, true]) {
    testWidgets(
      'four sort choices work at 320px and 2x text with keyboard=$keyboardOpen',
      (tester) async {
        final harness = FollowingTopicHarness();
        addTearDown(harness.dispose);
        await harness.seed([topicFixture(id: 'one'), topicFixture(id: 'two')]);
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await harness.pump(tester, const FollowingTopicsPage());
        if (keyboardOpen) {
          await tester.tap(find.byTooltip('Search'));
          await tester.pumpAndSettle();
          await tester.showKeyboard(find.byType(TextField));
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
        }
        final original = harness.container
            .read(organizedFollowingTopicsProvider(null))
            .asData!
            .value;
        await tester.tap(find.byTooltip('Sort By'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<KurumiPopupMenuItem>(find.byType(KurumiPopupMenuItem))
              .map((item) => (item.title as Text).data),
          ['Manual', 'Name', 'Unread First', 'Recently Added'],
        );
        await tester.ensureVisible(find.text('Recently Added'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Recently Added'));
        await tester.pumpAndSettle();
        expect(
          harness.container.read(followingTopicSortProvider),
          FollowingTopicSort.addedNewest,
        );
        expect(
          harness.container
              .read(organizedFollowingTopicsProvider(null))
              .asData!
              .value,
          original,
        );
        expect(
          harness.container
              .read(visibleFollowingTopicsProvider('missing'))
              .asData!
              .value,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
