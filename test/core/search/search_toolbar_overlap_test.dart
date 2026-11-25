import 'package:boorusama/core/posts/listing/src/widgets/post_list_configuration_header.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:boorusama/core/search/search/widgets.dart';
import 'package:boorusama/core/search/search/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

import '../../application/support/fake_booru_backend.dart';
import 'following_topics/following_topic_test_utils.dart';

void main() {
  for (final top in [true, false]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'applied Search separates toolbar and editor top=$top scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final harness = FollowingTopicHarness(
            settings: Settings.defaultSettings.copyWith(
              searchBarPosition: top
                  ? SearchBarPosition.top
                  : SearchBarPosition.bottom,
              autoFocusSearchBar: false,
            ),
          );
          addTearDown(harness.dispose);
          await harness.pump(
            tester,
            Scaffold(
              body: SearchPageScaffold<Post>(
                params: const SearchParams(query: 'cat dog'),
                fetcher: (_, _) => TaskEither.right(
                  PostResult(
                    posts: [for (var i = 0; i < 80; i++) TestPost(id: i + 1)],
                    total: 80,
                  ),
                ),
                itemBuilder: (_, index, _, _, _) => Text('Post $index'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final view = find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first;
          final position = tester.state<ScrollableState>(view).position;
          position.jumpTo(500);
          await tester.pumpAndSettle();
          await tester.drag(view, const Offset(0, 100));
          await tester.pumpAndSettle();
          expect(position.pixels, greaterThan(0));
          final toolbar = tester.getRect(
            find.byType(PostListConfigurationHeader),
          );
          final editor = tester.getRect(find.byType(RawSearchRegion));
          expect(
            toolbar.overlaps(editor),
            isFalse,
            reason: 'toolbar=$toolbar editor=$editor',
          );
          expect(
            find.byType(PostListConfigurationHeader).hitTestable(),
            findsOneWidget,
          );
          final selection = SelectionMode.of(
            tester.element(find.textContaining('Post ').hitTestable().first),
          );
          selection.enable(initialSelected: [0]);
          await tester.pumpAndSettle();
          expect(
            tester
                .getRect(find.byType(PostListConfigurationHeader))
                .overlaps(tester.getRect(find.byType(RawSearchRegion))),
            isFalse,
          );
          tester.view.viewInsets = const FakeViewPadding(bottom: 200);
          await tester.pumpAndSettle();
          expect(
            tester
                .getRect(find.byType(PostListConfigurationHeader))
                .overlaps(tester.getRect(find.byType(RawSearchRegion))),
            isFalse,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
