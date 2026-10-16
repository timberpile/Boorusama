import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/topic_follow_control.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'following_topic_test_utils.dart';

void main() {
  late FollowingTopicHarness harness;
  setUp(() => harness = FollowingTopicHarness());
  tearDown(() => harness.dispose());

  Future<void> openPicker(WidgetTester tester) async {
    await tester.runAsync(
      () => harness.container.read(followingTopicsProvider.future),
    );
    await harness.pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTopicFolderFollowDialog(
              context,
              profileId: testProfile.id,
              query: 'artist_tag',
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Follow creates an ordinary visible Topic without a parallel feed',
    (tester) async {
      await openPicker(tester);
      expect(find.text('Follow Topic'), findsOneWidget);
      expect(find.text('Create feed'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Artist');
      await tester.tap(find.widgetWithText(FilledButton, 'Follow'));
      await drain(tester);
      await tester.pumpAndSettle();
      final topics = (await tester.runAsync(harness.repository.getAll))!;
      expect(topics.single.query, 'artist_tag');
      expect(topics.single.name, 'Artist');
      expect(
        (await tester.runAsync(
          harness.repository.getOrganization,
        ))!.homeSearchIds,
        [topics.single.id],
      );
      expect(await tester.runAsync(harness.repository.getFeeds), isEmpty);
    },
  );

  testWidgets('cancelling Follow leaves existing topics unchanged', (
    tester,
  ) async {
    await tester.runAsync(() => harness.seed([topicFixture()]));
    await openPicker(tester);
    await tester.enterText(find.byType(TextField), 'Unsaved');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(harness.repository.getAll))!.single.id,
      'cats',
    );
    expect(await tester.runAsync(harness.repository.getFeeds), isEmpty);
  });
}
