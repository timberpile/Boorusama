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
  for (final following in [false, true]) {
    testWidgets(
      'tag menu offers ${following ? 'Following' : 'Follow'} and opens the topic dialog',
      (tester) async {
        if (following) {
          await tester.runAsync(
            () => harness.seed([
              topicFixture(query: 'artist_tag'),
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
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text('Follow Topic'), findsOneWidget);
        expect(find.text('Query: artist_tag'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(harness.repository.getAll))!.length,
          following ? 1 : 0,
        );
      },
    );
  }
}

class _EmptyBlacklist extends GlobalBlacklistedTagsNotifier {
  @override
  IList<BlacklistedTag> build() => <BlacklistedTag>[].lock;
}
