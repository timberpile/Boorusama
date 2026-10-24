import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/cache/providers.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:boorusama/core/search/options/labels.dart';
import 'package:boorusama/core/search/options/search_option.dart';
import 'package:boorusama/core/search/options/search_options_section.dart';
import 'package:boorusama/core/search/search/src/views/search_landing_view.dart';
import 'package:boorusama/core/search/search/src/widgets/raw_search_region.dart';
import 'package:boorusama/core/search/search/src/widgets/search_app_bar.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/selected_tags/selected_tag_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../following_topics/following_topic_test_utils.dart';
import '../../../support/fakes/memory_repositories.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('all options scroll within half the editor at ${scale}x', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capabilities = SearchCapabilities([
        ...capabilitiesFor(BooruType.danbooru, 'https://example.test').options,
        const SearchOption(
          kind: SearchOptionKind.native,
          key: 'native_option',
          input: SearchOptionInput.text,
        ),
      ]);
      final harness = FollowingTopicHarness(
        overrides: [
          miscDataStoreProvider.overrideWithValue(MemoryMiscDataStore()),
          searchCapabilitiesProvider.overrideWith((_, _) => capabilities),
        ],
      );
      addTearDown(harness.dispose);
      final controller = _controller();
      final pins = ValueNotifier<List<String>>(['age']);
      addTearDown(pins.dispose);
      await harness.pump(
        tester,
        MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 640),
            textScaler: TextScaler.linear(scale),
            viewInsets: const EdgeInsets.only(bottom: 240),
          ),
          child: Scaffold(
            appBar: AppBar(title: const Text('Search')),
            body: SearchLandingView(
              disableAnimation: true,
              child: ValueListenableBuilder(
                valueListenable: pins,
                builder: (_, keys, _) => SearchOptionsSection(
                  controller: controller,
                  pinnedKeys: keys,
                  onPin: (key) async => pins.value = [...pins.value, key],
                  onUnpin: (key) async =>
                      pins.value = pins.value.where((k) => k != key).toList(),
                ),
              ),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(SearchOptionsSection));
      final t = context.t.search_options;
      expect(find.text(t.all_options), findsNothing);
      expect(find.byTooltip(t.all_options), findsOneWidget);
      final list = find.byType(ListView);
      expect(
        tester.getSize(list).height,
        lessThanOrEqualTo(
          (640 - kToolbarHeight - 240) / 2,
        ),
      );
      final age = capabilities.byKey('age')!;
      final title = find.text(searchOptionTitle(context, age));
      final description = find.text(searchOptionDescription(context, age));
      expect(
        tester.getTopLeft(description).dx,
        greaterThan(tester.getTopRight(title).dx),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('search-option.age'))).height,
        lessThanOrEqualTo(tester.getSize(list).height),
        reason: 'one option and its quick choices fit even with enlarged text',
      );
      final day = find.text(t.values.older_month);
      final month = find.text(t.values.older_five_years);
      expect(tester.getTopLeft(day).dy, tester.getTopLeft(month).dy);
      final choices = find
          .ancestor(of: day, matching: find.byType(SingleChildScrollView))
          .first;
      await tester.ensureVisible(day);
      await tester.pumpAndSettle();
      await tester.drag(choices, const Offset(-800, 0));
      await tester.pumpAndSettle();
      await tester.tap(month);
      await tester.pump();
      expect(controller.tagsController.rawTags, ['age:>5y']);
      await tester.scrollUntilVisible(
        find.text('native_option'),
        150,
        maxScrolls: capabilities.options.length * 2,
        scrollable: find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('native_option'));
      await tester.pumpAndSettle();
      expect(find.text('native_option').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.byTooltip(t.all_options));
      await tester.tap(find.byTooltip(t.all_options));
      await tester.pumpAndSettle();
      // Pin a previously unpinned option; the existing pin remains first.
      final catalogTile = find.widgetWithText(ListTile, t.labels.sort);
      await tester.tap(
        find.descendant(of: catalogTile, matching: find.byTooltip(t.pin)),
      );
      await tester.pumpAndSettle();
      expect(pins.value, ['age', 'order']);
      await tester.tap(find.byTooltip(t.cancel));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('search-option.age')),
        -150,
        maxScrolls: capabilities.options.length * 2,
        scrollable: scrollable,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('search-option.age'))).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('search-option.order')))
              .dy,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an inactive search branch does not consume system Back', (
    tester,
  ) async {
    final harness = FollowingTopicHarness();
    addTearDown(harness.dispose);
    final controller = _controller()..toggleOptions();
    await harness.pump(
      tester,
      Scaffold(
        body: TickerMode(
          enabled: false,
          child: RawSearchRegion(
            controller: controller,
            innerSearchButton: const SizedBox.shrink(),
            tagList: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(controller.state.value, SearchState.options);
  });

  testWidgets('post search typing adds no clear X and keeps its mode action', (
    tester,
  ) async {
    final harness = FollowingTopicHarness();
    addTearDown(harness.dispose);
    final controller = _controller();
    await harness.pump(
      tester,
      Scaffold(
        body: RawSearchRegion(
          controller: controller,
          innerSearchButton: const Icon(Symbols.code),
          tagList: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), 'cat');
    await tester.pump();
    expect(find.byIcon(Symbols.close), findsNothing);
    expect(find.byIcon(Symbols.code), findsOneWidget);
    expect(find.byIcon(Symbols.keyboard_hide), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(controller.state.value, SearchState.initial);
    // Other explicit-confirmation search bars retain their clear affordance.
    await harness.pump(
      tester,
      Scaffold(
        body: SearchAppBar(
          controller: controller.textController,
          leading: null,
        ),
      ),
    );
    await tester.tap(find.byIcon(Symbols.close));
    expect(controller.textController.text, isEmpty);
  });
}

SearchPageController _controller() {
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
  return controller;
}
