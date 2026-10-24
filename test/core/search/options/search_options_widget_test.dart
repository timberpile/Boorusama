import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/options/collapsible_search_section.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:boorusama/core/search/options/search_option_editor.dart';
import 'package:boorusama/core/search/options/search_suggestion_panel.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/selected_tags/selected_tag_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';

import '../following_topics/following_topic_test_utils.dart';

void main() {
  testWidgets('keyboard option selection waits for IME composition to finish', (
    tester,
  ) async {
    final harness = FollowingTopicHarness();
    addTearDown(harness.dispose);
    final tags = SelectedTagController(metatagExtractor: null);
    final controller = SearchPageController(
      tagsController: tags,
      metatagExtractor: null,
      textMatchers: [],
    );
    addTearDown(() {
      controller.dispose();
      tags.dispose();
    });
    controller.textController.value = const TextEditingValue(
      text: 'rating:',
      composing: TextRange(start: 0, end: 6),
    );
    await harness.pump(
      tester,
      Scaffold(
        body: SearchSuggestionPanel(
          config: BooruConfig.defaultConfig(
            booruType: BooruType.danbooru,
            url: 'https://example.test',
            customDownloadFileNameFormat: null,
          ).auth,
          controller: controller,
        ),
      ),
    );
    controller.suggestionsListbox.move(TraversalDirection.down);
    controller.suggestionsListbox.pick();
    expect(tags.tags, isEmpty);
    controller.textController.clearComposing();
    await tester.pump();
    controller.suggestionsListbox.move(TraversalDirection.down);
    controller.suggestionsListbox.pick();
    await tester.pump();
    expect(tags.rawTags, ['rating:g']);
  });

  testWidgets('option Apply is reachable above a nested navigation shell', (
    tester,
  ) async {
    tester.view.viewPadding = FakeViewPadding(
      bottom: 48 * tester.view.devicePixelRatio,
    );
    tester.view.padding = FakeViewPadding(
      bottom: 48 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.reset);
    final harness = FollowingTopicHarness();
    addTearDown(harness.dispose);
    final option = capabilitiesFor(
      BooruType.danbooru,
      'https://danbooru.donmai.us',
    ).byKey('age')!;
    String? result;
    await harness.pump(
      tester,
      Scaffold(
        bottomNavigationBar: const SizedBox(
          height: 100,
          child: Text('Shell navigation'),
        ),
        body: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async => result = await showSearchOptionEditor(
                  context,
                  option: option,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final editorContext = tester.element(find.byType(SearchOptionEditor));
    final apply = find.text(editorContext.t.search_options.apply);
    await tester.ensureVisible(apply);
    expect(tester.getBottomLeft(apply).dy, lessThanOrEqualTo(552));
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(result, 'age:<7d');
    expect(find.byType(SearchOptionEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'uploaded editor restores months and accepts years at ${scale}x',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = FollowingTopicHarness();
        addTearDown(harness.dispose);
        final age = capabilitiesFor(
          BooruType.danbooru,
          'https://example.test',
        ).byKey('age')!;
        String? result;
        await harness.pump(
          tester,
          MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 640),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Open'),
                  onPressed: () async => result = await showSearchOptionEditor(
                    context,
                    option: age,
                    initialValue: '>2mo',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final t = tester
            .element(find.byType(SearchOptionEditor))
            .t
            .search_options;
        expect(find.text('age:>2mo'), findsOneWidget);
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: find.byType(KurumiTextField),
                  matching: find.byType(EditableText),
                ),
              )
              .controller
              .text,
          '2',
        );
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, t.months))
              .selected,
          isTrue,
        );
        final years = find.widgetWithText(ChoiceChip, t.years);
        final units = find
            .ancestor(of: years, matching: find.byType(SingleChildScrollView))
            .first;
        await tester.ensureVisible(units);
        await tester.drag(units, const Offset(-1200, 0));
        await tester.pumpAndSettle();
        await tester.tap(years);
        await tester.pumpAndSettle();
        expect(find.text('age:>2y'), findsOneWidget);
        await tester.ensureVisible(find.text(t.apply));
        await tester.tap(find.text(t.apply));
        await tester.pumpAndSettle();
        expect(result, 'age:>2y');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a collapsed section retains its header actions and can reopen', (
    tester,
  ) async {
    final harness = FollowingTopicHarness();
    addTearDown(harness.dispose);
    var actions = 0;
    await harness.pump(
      tester,
      Scaffold(
        body: CollapsibleSearchSection(
          title: 'History',
          storageId: 'test-history',
          trailing: TextButton(
            onPressed: () => actions++,
            child: const Text('Manage'),
          ),
          child: const Text('Saved search'),
        ),
      ),
    );
    final sectionRect = tester.getRect(find.byType(CollapsibleSearchSection));
    final actionRect = tester.getRect(
      find.widgetWithText(TextButton, 'Manage'),
    );
    expect(actionRect.right, sectionRect.right);
    // The empty space before the right-aligned action belongs to the header.
    await tester.tapAt(Offset(actionRect.left - 12, actionRect.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('Saved search'), findsNothing);
    await tester.tap(find.text('Manage'));
    expect(actions, 1);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Saved search'), findsOneWidget);
  });

  testWidgets('the graphical dialog commits an exclusion only on Apply', (
    tester,
  ) async {
    final harness = FollowingTopicHarness();
    addTearDown(harness.dispose);
    final option = capabilitiesFor(
      BooruType.danbooru,
      'https://danbooru.donmai.us',
    ).byKey('age')!;
    String? committed;
    await harness.pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            child: const Text('Open'),
            onPressed: () async {
              committed = await showSearchOptionEditor(context, option: option);
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(SearchOptionEditor));
    final t = context.t.search_options;
    await tester.tap(find.text(t.exclude));
    await tester.pump();
    expect(find.text('age:>=7d'), findsOneWidget);
    expect(committed, isNull);
    await tester.ensureVisible(find.text(t.apply));
    await tester.tap(find.text(t.apply));
    await tester.pumpAndSettle();
    expect(committed, 'age:>=7d');
  });

  testWidgets(
    'a narrow enlarged keyboard-open sheet can be cancelled unchanged',
    (tester) async {
      final harness = FollowingTopicHarness();
      addTearDown(harness.dispose);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final option = capabilitiesFor(
        BooruType.gelbooru,
        'https://gelbooru.com',
      ).byKey('rating')!;
      Object? result = 'unchanged';
      await harness.pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () async {
                result = await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: const TextScaler.linear(2),
                      viewInsets: const EdgeInsets.only(bottom: 250),
                    ),
                    child: SearchOptionEditor(option: option),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final context = tester.element(find.byType(SearchOptionEditor));
      final cancel = find.text(context.t.search_options.cancel);
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
