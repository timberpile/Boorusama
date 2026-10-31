import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_scroll_view.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_search_bar.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_list_controls.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import 'support/headless_app_harness.dart';
import 'support/app_flow_finders.dart';
import '../support/fakes/test_post.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Bookmark search and filters return together after slight upward scroll at $scale',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final harness = await HeadlessAppHarness.mount(
          tester,
          phone: TestPhone.smallPortrait,
        );
        await harness.pumpUntilFound(tester, postTile(101));
        final context = tester.element(postTile(101));
        final notifier = ProviderScope.containerOf(
          context,
          listen: false,
        ).read(bookmarkProvider.notifier);
        final config = harness.booruBackend.config;
        final group = await harness.pumpUntilComplete(
          tester,
          notifier.createGroupWithPosts('Scroll fixture', config.auth, [
            for (var id = 1000; id < 1100; id++)
              TestPost(id: id, origin: postOriginFromConfig(config)),
          ]),
        );
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                BookmarkPage(view: BookmarkView.group(group.group.id)),
          ),
        );
        final body = find.byType(BookmarkScrollView);
        await harness.pumpUntilFound(tester, body);
        await harness.settle(tester);
        final search = find.byType(BookmarkSearchBar);
        final controls = find.byType(BookmarkListControls);
        await tester.drag(body, const Offset(0, -800));
        await harness.settle(tester);
        expect(search.hitTestable(), findsNothing);
        expect(controls.hitTestable(), findsNothing);
        await tester.drag(body, const Offset(0, 32));
        await harness.settle(tester);
        expect(search.hitTestable(), findsOneWidget);
        expect(controls.hitTestable(), findsOneWidget);
        final grid = tester.widget<PostGrid<Post>>(
          find.descendant(of: body, matching: find.byType(PostGrid<Post>)),
        );
        expect(grid.scrollController!.offset, greaterThan(200));
        final field = find.descendant(
          of: search,
          matching: find.byType(TextField),
        );
        await tester.tap(field);
        await harness.settle(tester);
        expect(harness.keyboard.isShown, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
