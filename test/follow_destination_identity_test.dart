import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/follow_topic_folder_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import 'core/search/following_topics/following_topic_test_utils.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'folder identity and pending selection survive navigation at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: scale == 2 ? 220 : 0);
        addTearDown(tester.view.reset);
        final harness = FollowingTopicHarness();
        addTearDown(harness.dispose);
        await harness.seed([]);
        final notifier = harness.container.read(
          followingTopicsProvider.notifier,
        );
        final parent = await notifier.createSharedFolder('Parent');
        final child = await notifier.createSharedFolder(
          'Child',
          parentId: parent.id,
        );
        FollowTopicPickerResult? result;
        await harness.pump(
          tester,
          MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 640),
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: scale == 2 ? 220 : 0),
            ),
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showFollowTopicFolderPickerDialog(
                      context,
                      query: 'cat',
                      selectedFolderIds: {null},
                      onCreateFolder: (_) async => null,
                    );
                  },
                  child: const Text('Open destinations'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open destinations'));
        await tester.pumpAndSettle();

        final homeCheckbox = tester.element(find.byType(Checkbox).first);
        expect(
          tester.widget<Checkbox>(find.byType(Checkbox).first).value,
          isTrue,
        );

        Future<void> enterParent() async {
          await tester.tap(
            find.descendant(
              of: find.widgetWithText(ListTile, 'Parent'),
              matching: find.byIcon(Icons.chevron_right),
            ),
          );
          // Inspect the first frame, before a reused checkbox could animate away
          // the incorrect selection inherited from the previous folder.
          await tester.pump();
        }

        await enterParent();
        final childCheckbox = tester.element(find.byType(Checkbox));
        expect(childCheckbox, isNot(same(homeCheckbox)));
        expect(
          tester.widget<Checkbox>(find.byType(Checkbox)).value,
          isFalse,
        );

        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        expect(tester.element(find.byType(Checkbox)), same(childCheckbox));
        expect(
          tester.widget<Checkbox>(find.byType(Checkbox)).value,
          isTrue,
        );

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pump();
        expect(
          tester.element(find.byType(Checkbox).first),
          isNot(same(childCheckbox)),
        );
        expect(
          tester.widget<Checkbox>(find.byType(Checkbox).first).value,
          isTrue,
        );

        await enterParent();
        expect(
          tester.widget<Checkbox>(find.byType(Checkbox)).value,
          isTrue,
        );
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(result, isA<FollowTopicDestinations>());
        expect((result! as FollowTopicDestinations).folders, {null, child.id});
        expect(tester.takeException(), isNull);
      },
    );
  }
}
