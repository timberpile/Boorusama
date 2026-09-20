import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/feed_follow_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pinned_search_test_utils.dart';

void main() {
  late PinnedSearchHarness harness;

  setUp(() => harness = PinnedSearchHarness());
  tearDown(() => harness.dispose());

  Future<void> openPicker(
    WidgetTester tester, {
    String query = 'artist_tag',
  }) async {
    await tester.runAsync(
      () => harness.container.read(searchSubscriptionsProvider.future),
    );
    await harness.pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFeedMembershipPicker(
              context,
              profileId: 12,
              query: query,
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
    'creating the first feed follows the source and closes both dialogs',
    (
      tester,
    ) async {
      await openPicker(tester);

      expect(find.byType(TextField), findsNothing);
      expect(find.text('No following feeds yet.'), findsOneWidget);
      await tester.tap(find.text('Create feed'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('artist_tag'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Characters');
      await tester.pump();
      await tester.tap(find.text('Create and follow'));
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (find.byType(AlertDialog).evaluate().isEmpty) break;
      }
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final feed = (await tester.runAsync(harness.repository.getFeeds))!.single;
      expect(feed.name, 'Characters');
      expect(feed.profileId, 12);
      expect(feed.sourceIds, hasLength(1));
      expect(
        (await tester.runAsync(
          () => harness.repository.getById(feed.sourceIds.single),
        ))!.query,
        'artist_tag',
      );
    },
  );

  testWidgets(
    'cancelling feed creation returns to the existing feed selector',
    (
      tester,
    ) async {
      await tester.runAsync(
        () => harness.repository.saveFeed(
          profileId: 12,
          name: 'Existing',
          queries: ['cat'],
        ),
      );
      await openPicker(tester);

      expect(find.text('Existing'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Create feed'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Existing'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(
        (await tester.runAsync(harness.repository.getFeeds))!.single.name,
        'Existing',
      );
    },
  );

  testWidgets('failed creation keeps the entered feed name visible', (
    tester,
  ) async {
    await openPicker(tester, query: 'artist_tag order:score');
    await tester.tap(find.text('Create feed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Characters');
    await tester.pump();
    await tester.tap(find.text('Create and follow'));
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find
          .text('Could not update the feed. Try again.')
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();

    expect(find.text('Could not update the feed. Try again.'), findsOneWidget);
    expect(find.text('Characters'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNWidgets(2));
    expect(await tester.runAsync(harness.repository.getFeeds), isEmpty);
  });
}
