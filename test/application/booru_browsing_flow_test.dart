// Flutter imports:
import 'package:material_ui/material_ui.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import 'package:boorusama/core/home/src/widgets/home_search_bar.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/search/search/src/widgets/search_app_bar.dart';
import 'package:boorusama/core/search/search/widgets.dart';

import 'support/fake_booru_backend.dart';
import 'support/app_flow_finders.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets(
    'loads fake booru posts, filters them, and opens post details',
    (tester) async {
      final backend = FakeBooruBackend();
      final harness = HeadlessAppHarness(booruBackend: backend);
      addTearDown(() => harness.teardown(tester));

      await harness.pump(tester);
      await harness.settle(tester);
      await harness.pumpUntilFound(
        tester,
        find.descendant(
          of: postGrid(),
          matching: find.byType(SliverPostGridImageGridItem),
        ),
      );

      expect(
        backend.requests.whereType<FakeBooruPostRequest>().last.resultIds,
        containsAll(<int>[101, 102]),
      );
      expect(
        find.descendant(
          of: postGrid(),
          matching: find.byType(SliverPostGridImageGridItem),
        ),
        findsNWidgets(2),
      );

      await tester.tap(find.byType(HomeSearchBar));
      await tester.pump();
      await harness.settle(tester);
      expect(find.byType(SearchPageScaffold), findsOneWidget);

      final searchField = find.descendant(
        of: find.byType(SearchAppBar),
        matching: find.byType(EditableText),
      );
      await tester.enterText(searchField, 'cat');
      await tester.tap(searchField);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await harness.settle(tester);

      await harness.pumpUntil(
        tester,
        () {
          final ids = backend.requests
              .whereType<FakeBooruPostRequest>()
              .last
              .resultIds;
          return ids.length == 1 && ids.first == 101;
        },
      );

      await harness.pumpUntilFound(
        tester,
        find.descendant(
          of: postGrid(),
          matching: find.byType(SliverPostGridImageGridItem),
        ),
      );
      expect(
        find.descendant(
          of: postGrid(),
          matching: find.byType(SliverPostGridImageGridItem),
        ),
        findsOneWidget,
      );

      await tester.enterText(searchField, 'nonexistent_tag');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await harness.settle(tester);

      await harness.pumpUntil(
        tester,
        () =>
            backend.requests
                .whereType<FakeBooruPostRequest>()
                .last
                .resultIds
                .isEmpty &&
            find
                .descendant(
                  of: postGrid(),
                  matching: find.byType(SliverPostGridImageGridItem),
                )
                .evaluate()
                .isEmpty,
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.descendant(
          of: postGrid(),
          matching: find.byType(SliverPostGridImageGridItem),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'opens a known fake post in the real details flow',
    (tester) async {
      final harness = HeadlessAppHarness();
      addTearDown(() => harness.teardown(tester));

      await harness.pump(tester);
      await harness.pumpUntilFound(
        tester,
        find.descendant(
          of: postGrid(),
          matching: find.byType(SliverPostGridImageGridItem),
        ),
      );

      await tester.tap(
        find
            .descendant(
              of: postGrid(),
              matching: find.byType(SliverPostGridImageGridItem),
            )
            .first,
      );
      await tester.pump();
      await harness.pumpUntilFound(
        tester,
        find.byType(PostDetailsPageScaffold),
      );

      expect(find.byType(PostDetailsPageScaffold), findsOneWidget);

      expect(find.byIcon(Symbols.home), findsNothing);
      await tester.tap(find.byIcon(Symbols.arrow_back_ios).last);
      await tester.pump();
      await harness.pumpUntilFound(
        tester,
        find.byType(DefaultImageGridItem),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DefaultImageGridItem), findsNWidgets(2));
    },
  );
}
