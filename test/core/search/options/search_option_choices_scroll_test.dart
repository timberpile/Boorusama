import 'package:boorusama/core/search/options/search_option_choices.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../following_topics/following_topic_test_utils.dart';

void main() {
  testWidgets(
    'new quick-choice rows start left without inheriting another row offset',
    (tester) async {
      final harness = FollowingTopicHarness();
      addTearDown(harness.dispose);
      final bucket = PageStorageBucket();
      final row = ValueNotifier(0);
      addTearDown(row.dispose);
      await harness.pump(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              child: PageStorage(
                bucket: bucket,
                child: SizedBox(
                  key: const PageStorageKey('shared-options'),
                  child: ValueListenableBuilder(
                    valueListenable: row,
                    builder: (_, value, _) => SearchOptionChoices(
                      key: ValueKey(value),
                      children: [
                        for (var i = 0; i < 10; i++)
                          ActionChip(
                            label: Text('Choice $value-$i'),
                            onPressed: () {},
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      final scroller = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroller.position.pixels, greaterThan(0));
      row.value = 1;
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        0,
      );
      expect(find.text('Choice 1-0').hitTestable(), findsOneWidget);
    },
  );
}
