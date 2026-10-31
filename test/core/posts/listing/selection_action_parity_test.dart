import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:boorusama/core/widgets/multi_selection_action_bar.dart';
import 'package:flutter/widgets.dart';
import 'package:kurumi/material.dart' show Dialog;
import 'package:flutter_test/flutter_test.dart';

import '../../../application/support/app_flow_finders.dart';
import '../../../application/support/fake_booru_backend.dart';
import '../../../application/support/headless_app_harness.dart';
import '../../../support/boorusama_test_runtime.dart';

void main() {
  for (final compact in [false, true]) {
    testWidgets(
      'selection transitions single → batch → single retain action parity (compact=$compact)',
      (tester) async {
        if (compact) {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        final backend = FakeBooruBackend();
        backend.posts[1] = TestPost(id: 102, tags: const {'cat'});
        final downloads = MemoryDownloadService();
        final harness = await HeadlessAppHarness.mount(
          tester,
          booruBackend: backend,
          runtime: backend.createRuntime(downloadService: downloads),
          phone: compact ? TestPhone.smallPortrait : TestPhone.portrait,
        );
        await harness.pumpUntilFound(tester, postTile(101));
        await tester.longPress(postTile(101));
        await harness.settle(tester);
        List<Widget> actions() => tester
            .widget<MultiSelectionActionBar>(
              find.byType(MultiSelectionActionBar),
            )
            .children;
        MultiSelectButton action(String label) => actions()
            .whereType<MultiSelectButton>()
            .singleWhere((button) => button.name == label);
        final single = find.byKey(const Key('selection-single-bookmark'));
        final batch = find.byKey(const Key('selection-batch-bookmarks'));
        expect(single.hitTestable(), findsOneWidget);
        expect(action('Bookmark').primary, isTrue);
        expect(action('Bookmark').onPressed, isNotNull);
        expect(batch, findsNothing);
        expect(action('Share').menuOnly, isFalse);
        expect(action('View Comments').onPressed, isNotNull);
        action('Download').onPressed!();
        await harness.pumpUntil(tester, () => downloads.requests.length == 1);
        expect(downloads.requests.single.url, contains('/101.jpg'));
        await tester.tap(single);
        await harness.pumpUntilFound(tester, find.byType(BookmarkGroupPicker));
        expect(
          tester
              .widget<BookmarkGroupPicker>(find.byType(BookmarkGroupPicker))
              .post
              .id,
          101,
        );
        expect(
          tester
              .widget<BookmarkGroupPicker>(find.byType(BookmarkGroupPicker))
              .anchored,
          isTrue,
        );
        expect(find.byType(Dialog), findsNothing);
        await tester.tapAt(const Offset(2, 2));
        await harness.settle(tester);
        await tester.tap(postTile(102));
        await harness.settle(tester);
        expect(single, findsNothing);
        expect(batch.hitTestable(), findsOneWidget);
        expect(
          actions().whereType<MultiSelectButton>().where(
            (button) => button.name == 'Share',
          ),
          isEmpty,
        );
        await tester.tap(postTile(102));
        await harness.settle(tester);
        expect(single.hitTestable(), findsOneWidget);
        expect(batch, findsNothing);
        expect(action('Share').menuOnly, isFalse);
        expect(action('View Comments').onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
