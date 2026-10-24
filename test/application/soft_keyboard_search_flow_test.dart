import 'package:flutter/widgets.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/home/src/widgets/home_search_bar.dart';
import 'package:boorusama/core/search/search/src/types/search_bar_position.dart';
import 'package:boorusama/core/search/search/src/widgets/desktop_search_bar.dart';
import 'package:boorusama/core/search/search/src/widgets/search_app_bar.dart';
import 'package:boorusama/core/search/options/search_suggestion_panel.dart';
import 'package:boorusama/core/search/search/src/widgets/selected_tag_chip.dart';
import 'package:boorusama/core/search/suggestions/tag_suggestion_items.dart';
import 'package:boorusama/core/settings/types.dart';

import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  for (final position in SearchBarPosition.values) {
    testWidgets(
      'hiding the empty search keyboard returns to interactive Browse at ${position.name}',
      (tester) async {
        final harness = await _mountSearch(
          tester,
          TestPhone.portrait,
          position,
        );
        expect(harness.keyboard.isShown, isTrue);
        tester.testTextInput.hide();
        await harness.settle(tester);
        expect(find.byType(SearchAppBar), findsNothing);
        expect(postTile(101).hitTestable(), findsOneWidget);
        await tester.tap(postTile(101));
        await harness.pumpUntilFound(tester, postDetailsScaffold());
      },
    );

    testWidgets(
      'opening advanced options keeps the fresh search route at ${position.name}',
      (tester) async {
        final harness = await _mountSearch(
          tester,
          TestPhone.portrait,
          position,
        );
        await tester.tap(
          find.byTooltip(appStrings(tester).search_options.title),
        );
        await harness.settle(tester);
        expect(harness.keyboard.isShown, isFalse);
        expect(find.byType(SearchAppBar), findsOneWidget);
        expect(
          find.text(appStrings(tester).search_options.title),
          findsOneWidget,
        );
      },
    );
  }

  final cases = [
    for (final phone in [
      TestPhone.smallPortrait,
      TestPhone.portrait,
      TestPhone.landscape,
    ])
      for (final position in SearchBarPosition.values)
        (phone: phone, position: position),
  ];

  for (final c in cases) {
    testWidgets(
      'search stays usable above the keyboard on a ${c.phone} with the '
      'search bar at the ${c.position.name}',
      (tester) async {
        final harness = await _mountSearch(tester, c.phone, c.position);
        final keyboard = harness.keyboard;

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is SliverPostGridImageGridItem && widget.post.id == 101,
          ),
          findsOneWidget,
          reason: 'the source timeline remains painted before submitting',
        );
        expect(
          keyboard.isShown,
          isTrue,
          reason: 'opening Search focuses input',
        );
        await tester.enterText(_searchField, 'ca');
        await harness.pumpUntilFound(tester, _suggestion('cat'));
        await harness.settle(tester);
        expect(keyboard.isShown, isTrue);
        expect(
          keyboard.coveredTargets({
            'the search field': _searchField,
            'the first suggestion': _suggestion('cat'),
            'the suggestion list': _suggestionList,
          }),
          isEmpty,
          reason: 'while typing',
        );

        await tester.tap(_suggestion('cat'));
        await harness.pumpUntilFound(tester, find.byType(SelectedTagChip));
        await harness.settle(tester);
        expect(
          keyboard.coveredTargets({
            'the search field': _searchField,
            'the selected tag': find.byType(SelectedTagChip),
          }),
          isEmpty,
          reason: 'after picking a suggestion',
        );

        expect(keyboard.isShown, isFalse);
        await harness.pumpUntilFound(tester, postTile(101));
        await harness.settle(tester);
        expect(keyboard.isShown, isFalse);
        expect(
          keyboard.coveredTargets({
            'the search bar': find.byType(SearchAppBar),
            'the first result': postTile(101),
          }),
          isEmpty,
          reason: 'after searching',
        );
        if (c.position == SearchBarPosition.bottom) {
          expect(
            tester.getTopLeft(find.byKey(const Key('nav-shortcut-browse'))).dy -
                tester.getBottomLeft(find.byType(SearchAppBar)).dy,
            moreOrLessEquals(0, epsilon: 0.5),
            reason: 'the bottom search bar should meet the navigation bar without a gap',
          );
        }
      },
    );
  }
  testWidgets(
    'large-screen search stays usable above the keyboard on a wide phone',
    (tester) async {
      final harness = await _mountHome(tester, TestPhone.largeLandscape);
      final keyboard = harness.keyboard;
      final field = find.descendant(
        of: find.byType(DesktopSearchbar),
        matching: find.byType(EditableText),
      );

      await tester.tap(field);
      await harness.pumpUntil(
        tester,
        () => keyboard.isShown,
        description: 'keyboard to open',
      );
      await tester.enterText(field, 'ca');
      await harness.pumpUntilFound(tester, _suggestion('cat'));
      await harness.settle(tester);
      expect(
        keyboard.coveredTargets({
          'the search field': field,
          'the first suggestion': _suggestion('cat'),
          'the suggestion list': _suggestionList,
        }),
        isEmpty,
        reason: 'while typing',
      );

      await tester.tap(_suggestion('cat'));
      await harness.pumpUntilFound(tester, find.byType(SelectedTagChip));
      await harness.settle(tester);
      expect(
        keyboard.coveredTargets({
          'the search field': field,
          'the selected tag': find.byType(SelectedTagChip),
        }),
        isEmpty,
        reason: 'after picking a suggestion',
      );
    },
  );

  for (final position in SearchBarPosition.values) {
    testWidgets(
      'rotating with the keyboard open keeps the typed search usable with the '
      'search bar at the ${position.name}',
      (tester) async {
        final harness = await _mountSearch(
          tester,
          TestPhone.portrait,
          position,
        );
        final keyboard = harness.keyboard;
        await _focusSearchField(tester, harness);
        await tester.enterText(_searchField, 'ca');
        await harness.pumpUntilFound(tester, _suggestion('cat'));

        for (final phone in [TestPhone.landscape, TestPhone.portrait]) {
          keyboard
            ..phone = phone
            ..apply();
          await harness.settle(tester);

          expect(
            tester.widget<EditableText>(_searchField).controller.text,
            'ca',
          );
          expect(
            keyboard.coveredTargets({
              'the search field': _searchField,
              'the suggestion list': _suggestionList,
            }),
            isEmpty,
            reason: 'after rotating to a $phone',
          );
          if (position == SearchBarPosition.bottom) {
            expect(
              keyboard.gapAbove(find.byType(SearchAppBar)),
              moreOrLessEquals(0, epsilon: 0.5),
              reason: 'the search bar should sit on the keyboard on a $phone',
            );
          }
        }
      },
    );
  }
}

final _searchField = find.descendant(
  of: find.byType(SearchAppBar),
  matching: find.byType(EditableText),
);

final _suggestionList = find.byWidgetPredicate(
  (widget) => widget is TagSuggestionItems || widget is SearchSuggestionPanel,
);

Finder _suggestion(String tag) => find.descendant(
  of: _suggestionList,
  matching: find.text(tag),
);

Future<HeadlessAppHarness> _mountSearch(
  WidgetTester tester,
  TestPhone phone,
  SearchBarPosition position,
) async {
  final harness = await _mountHome(tester, phone, position: position);

  await tester.tap(find.byType(HomeSearchBar));
  await harness.pumpUntilFound(tester, _searchField);
  await harness.settle(tester);

  return harness;
}

Future<HeadlessAppHarness> _mountHome(
  WidgetTester tester,
  TestPhone phone, {
  SearchBarPosition position = SearchBarPosition.top,
}) async {
  final backend = FakeBooruBackend()
    ..autocompleteTags.addAll([
      'cat',
      for (var i = 1; i < 30; i++) 'cat_$i',
    ]);
  final harness = await HeadlessAppHarness.mount(
    tester,
    booruBackend: backend,
    phone: phone,
    runtime: backend.createRuntime(
      settings: Settings.defaultSettings.copyWith(
        searchBarPosition: position,
        autoFocusSearchBar: false,
      ),
    ),
  );
  await harness.pumpUntilFound(tester, postTile(101));
  await harness.settle(tester);
  return harness;
}

Future<void> _focusSearchField(
  WidgetTester tester,
  HeadlessAppHarness harness,
) async {
  if (!tester.testTextInput.isVisible) {
    await tester.tap(_searchField);
  }
  await harness.pumpUntil(
    tester,
    () => harness.keyboard.isShown,
    description: 'keyboard to open',
  );
  await harness.settle(tester);
}
