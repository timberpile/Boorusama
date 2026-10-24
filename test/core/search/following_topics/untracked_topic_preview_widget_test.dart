import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_query_text.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/search/following_topics/src/providers/untracked_topic_preview_provider.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'following_topic_test_utils.dart';

void main() {
  testWidgets('feed preview remains cache-only for an unsupported source', (
    tester,
  ) async {
    final harness = FollowingTopicHarness(
      supported: false,
      overrides: [
        untrackedTopicPreviewProvider.overrideWith(
          (ref, _) => throw StateError('feed must not fetch previews'),
        ),
      ],
    );
    addTearDown(harness.dispose);
    await harness.pump(
      tester,
      Scaffold(
        body: FollowingTopicCard(
          topic: topicFixture(error: SearchRefreshErrorKind.unsupported),
          config: testProfile.auth,
          refreshing: false,
          onOpen: () {},
          onAction: (_) {},
          preview: const Text('cached feed preview'),
        ),
      ),
    );
    expect(find.text('cached feed preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final name in <String?>[null, 'Named Topic']) {
    for (final fail in [false, true]) {
      testWidgets(
        'formatted card retains independent preview and status: $name/$fail',
        (tester) async {
          final topic = topicFixture(
            name: name,
            query: 'artist_name rating:safe',
            error: SearchRefreshErrorKind.unsupported,
          );
          final harness = FollowingTopicHarness(
            supported: false,
            overrides: [
              untrackedTopicPreviewProvider.overrideWith((ref, _) async {
                if (fail) throw StateError('independent preview failed');
                return [
                  for (var i = 0; i < 4; i++) 'https://images.example/$i.jpg',
                ];
              }),
            ],
          );
          addTearDown(harness.dispose);
          await harness.seed([topic]);
          final mutations = harness.box.mutationCount;
          var opened = false;
          await harness.pump(
            tester,
            Scaffold(
              body: SizedBox(
                width: 280,
                child: FollowingTopicCard(
                  topic: topic,
                  config: testProfile.auth,
                  refreshing: false,
                  onOpen: () => opened = true,
                  onAction: (_) {},
                ),
              ),
            ),
          );
          expect(find.byType(FollowingTopicQueryText), findsOneWidget);
          if (name != null) expect(find.text(name), findsOneWidget);
          expect(
            find.text('New-post tracking is unsupported for this search.'),
            findsOneWidget,
          );
          expect(
            find.byType(BooruImage),
            fail ? findsNothing : findsNWidgets(4),
          );
          expect(
            find.text('Could not load previews. Try refreshing this topic.'),
            fail ? findsOneWidget : findsNothing,
          );
          await tester.tap(find.byType(FollowingTopicQueryText));
          expect(opened, isTrue);
          expect(await harness.repository.getAll(), [topic]);
          expect(harness.box.mutationCount, mutations);
          expect(harness.requests, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final persistedUnsupported in [false, true]) {
    testWidgets(
      'preview failure remains separate from tracking state ($persistedUnsupported)',
      (tester) async {
        final topic = topicFixture(
          error: persistedUnsupported
              ? SearchRefreshErrorKind.unsupported
              : null,
        );
        final harness = FollowingTopicHarness(
          supported: false,
          overrides: [
            untrackedTopicPreviewProvider.overrideWith(
              (ref, _) async => throw StateError('preview failed'),
            ),
          ],
        );
        addTearDown(harness.dispose);
        await harness.seed([topic]);
        final mutations = harness.box.mutationCount;
        var opened = false;
        await harness.pump(
          tester,
          Scaffold(
            body: SizedBox(
              width: 280,
              child: FollowingTopicCard(
                topic: topic,
                config: testProfile.auth,
                refreshing: false,
                onOpen: () => opened = true,
                onAction: (_) {},
              ),
            ),
          ),
        );
        expect(
          find.text('Could not load previews. Try refreshing this topic.'),
          findsOneWidget,
        );
        expect(
          find.text('New-post tracking is unsupported for this search.'),
          findsOneWidget,
        );
        await tester.tap(find.text(topic.displayName));
        expect(opened, isTrue);
        expect(await harness.repository.getAll(), [topic]);
        expect(harness.box.mutationCount, mutations);
        expect(harness.requests, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
