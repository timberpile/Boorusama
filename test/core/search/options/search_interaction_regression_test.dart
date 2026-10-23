import 'dart:async';

import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/cache/providers.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:boorusama/core/search/options/search_options_section.dart';
import 'package:boorusama/core/search/options/search_option_editor.dart';

import 'package:boorusama/core/posts/count/src/result_header.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/search/src/widgets/raw_search_region.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/selected_tags/selected_tag_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../support/fakes/test_post.dart';
import '../../../support/fakes/memory_repositories.dart';
import '../following_topics/following_topic_test_utils.dart';

void main() {
  testWidgets(
    'opening advanced options hides the keyboard and preserves the draft',
    (
      tester,
    ) async {
      final harness = FollowingTopicHarness();
      addTearDown(harness.dispose);
      final tags = SelectedTagController(metatagExtractor: null);
      final controller = SearchPageController(
        tagsController: tags,
        textMatchers: [],
        metatagExtractor: null,
      );
      addTearDown(controller.dispose);
      addTearDown(tags.dispose);
      await harness.pump(
        tester,
        Scaffold(
          body: RawSearchRegion(
            controller: controller,
            autoFocusSearchBar: true,
            innerSearchButton: const SizedBox.shrink(),
            tagList: const SizedBox.shrink(),
          ),
        ),
      );
      expect(controller.state.value, SearchState.initial);
      expect(controller.focus.hasFocus, isTrue);
      await tester.tap(find.byIcon(Symbols.keyboard_arrow_down));
      await tester.pump();
      expect(controller.state.value, SearchState.options);
      expect(controller.focus.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byIcon(Symbols.keyboard_arrow_up));
      await tester.pump();
      expect(controller.state.value, SearchState.initial);
      await tester.enterText(find.byType(EditableText), '(cat ~dog)');
      await tester.pump();
      expect(find.byIcon(Symbols.code), findsNothing);
      expect(controller.focus.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(controller.textController.text, '(cat ~dog)');
      await tester.tap(find.byIcon(Symbols.keyboard_arrow_down));
      await tester.pump();
      expect(controller.state.value, SearchState.options);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byIcon(Symbols.keyboard_arrow_up));
      await tester.pump();
      expect(controller.textController.text, '(cat ~dog)');
      controller.applyOption('rating', 'rating:g');
      await tester.pump();
      expect(controller.state.value, SearchState.initial);
      expect(controller.focus.hasFocus, isFalse);
      expect(tags.rawTags, ['rating:g']);
    },
  );

  testWidgets('catalog selection applies while the search field had focus', (
    tester,
  ) async {
    final harness = FollowingTopicHarness(
      overrides: [
        miscDataStoreProvider.overrideWithValue(MemoryMiscDataStore()),
        searchCapabilitiesProvider.overrideWith(
          (_, _) => capabilitiesFor(BooruType.danbooru, 'https://example.test'),
        ),
      ],
    );
    addTearDown(harness.dispose);
    final tags = SelectedTagController(metatagExtractor: null);
    final controller = SearchPageController(
      tagsController: tags,
      textMatchers: [],
      metatagExtractor: null,
    );
    addTearDown(controller.dispose);
    addTearDown(tags.dispose);
    await harness.pump(
      tester,
      Scaffold(
        body: Column(
          children: [
            RawSearchRegion(
              controller: controller,
              autoFocusSearchBar: true,
              innerSearchButton: const SizedBox.shrink(),
              tagList: const SizedBox.shrink(),
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: controller.state,
                builder: (_, state, _) => state == SearchState.options
                    ? SearchOptionsSection(controller: controller)
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
    final t = tester.element(find.byType(RawSearchRegion)).t.search_options;
    await tester.tap(find.byIcon(Symbols.keyboard_arrow_down));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(t.all_options));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rating').last);
    await tester.pumpAndSettle();
    expect(find.byType(SearchOptionEditor), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(SearchOptionEditor),
        matching: find.text('General'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.apply));
    await tester.pumpAndSettle();
    expect(tags.rawTags, ['rating:g']);
    expect(controller.state.value, SearchState.initial);
    expect(controller.focus.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  for (final outcome in ['unknown total', 'empty', 'known total', 'error']) {
    testWidgets('searching stops after $outcome', (tester) async {
      final harness = FollowingTopicHarness();
      addTearDown(harness.dispose);
      final response = Completer<Either<BooruError, PostResult<Post>>>();
      final controller = PostGridController<Post>(
        fetcher: (_) => TaskEither(() => response.future),
        blacklistedTagsFetcher: () async => {},
        mountedChecker: () => true,
        duplicateTracker: PostDuplicateTracker<Post>(),
        onError: (_) {},
      );
      addTearDown(controller.dispose);
      await harness.pump(
        tester,
        Scaffold(
          body: SizedBox(
            width: 120,
            child: ResultHeaderFromController(
              controller: controller,
              onRefresh: null,
              hasCount: true,
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final refresh = controller.refresh();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 1);
      response.complete(switch (outcome) {
        'error' => Either.left(
          ServerError(httpStatusCode: 503, message: 'Unavailable'),
        ),
        'empty' => Either.of(<Post>[].toResult(total: 0)),
        'known total' => Either.of([TestPost(id: 1)].toResult(total: 123)),
        _ => Either.of([TestPost(id: 1)].toResult()),
      });
      await refresh;
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      if (outcome == 'unknown total') {
        expect(controller.allItems.length, 1);
        expect(find.byType(Text), findsNothing);
      } else if (outcome == 'known total') {
        expect(find.textContaining('123'), findsOneWidget);
        expect(tester.widget<Text>(find.byType(Text)).maxLines, 1);
      } else if (outcome == 'empty') {
        final context = tester.element(find.byType(ResultHeaderFromController));
        expect(find.text(context.t.search.no_result_notice), findsOneWidget);
        expect(tester.widget<Text>(find.byType(Text)).maxLines, 1);
      } else {
        expect(controller.errors.value, isNotNull);
        expect(find.byType(Text), findsNothing);
      }
    });
  }
}
