import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/types.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/tags/tag/src/widgets/general_tag_context_menu.dart';
import 'package:boorusama/core/widgets/custom_context_menu_overlay.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'following_topic_test_utils.dart';

void main() {
  late FollowingTopicHarness harness;
  setUp(() => harness = FollowingTopicHarness());
  tearDown(() => harness.dispose());
  for (final scenario in [
    (count: 0, tracked: true),
    (count: 1, tracked: true),
    (count: 2, tracked: false),
  ]) {
    final following = scenario.count > 0;
    testWidgets(
      'tag menu offers ${following ? 'Following management' : 'Follow creation'} for ${scenario.count} copies (tracking: ${scenario.tracked})',
      (tester) async {
        if (following) {
          await tester.runAsync(
            () => harness.seed([
              for (var i = 0; i < scenario.count; i++)
                topicFixture(id: 'copy-$i', query: 'artist_tag'),
            ]),
          );
        }
        await tester.runAsync(
          () => harness.container.read(followingTopicsProvider.future),
        );
        await harness.pump(
          tester,
          ProviderScope(
            overrides: [
              globalBlacklistedTagsProvider.overrideWith(_EmptyBlacklist.new),
              followingTopicTrackingSupportedProvider.overrideWith(
                (ref, config) => scenario.tracked,
              ),
            ],
            child: const CustomContextMenuOverlay(
              child: Scaffold(
                body: Center(
                  child: GeneralTagContextMenu(
                    tag: 'artist_tag',
                    child: Text('Artist tag'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(
          find.text('Artist tag'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        final label = following ? 'Following' : 'Follow';
        expect(find.text('Add to feed'), findsNothing);
        expect(find.text(label), findsOneWidget);
        expect(find.byIcon(Icons.rss_feed), findsOneWidget);
        expect(
          find.text('${scenario.count}'),
          following ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text('Follow'), findsOneWidget);
        expect(find.text('artist_tag'), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(harness.repository.getAll))!.length,
          scenario.count,
        );
      },
    );
  }
}

class _EmptyBlacklist extends GlobalBlacklistedTagsNotifier {
  @override
  IList<BlacklistedTag> build() => <BlacklistedTag>[].lock;
}
