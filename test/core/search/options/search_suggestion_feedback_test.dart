import 'dart:async';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/options/search_suggestion_panel.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/selected_tags/selected_tag_controller.dart';
import 'package:boorusama/core/search/suggestions/suggestions_notifier.dart';
import 'package:boorusama/core/tags/autocompletes/providers.dart';
import 'package:boorusama/core/tags/autocompletes/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../following_topics/following_topic_test_utils.dart';

void main() {
  testWidgets(
    'raw fallback remains available after matches, empty and failed responses',
    (tester) async {
      final requests = <String, Completer<List<AutocompleteData>>>{};
      final harness = FollowingTopicHarness(
        overrides: [
          autocompleteRepoProvider.overrideWith(
            (_, _) => AutocompleteRepositoryBuilder(
              autocomplete: (query) =>
                  (requests[query.text] = Completer()).future,
            ),
          ),
        ],
      );
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
      final notifier = harness.container.read(
        suggestionsNotifierProvider(testProfile.auth).notifier,
      );
      void type(String query) {
        controller.updateQuery(query);
        notifier.getSuggestions(query);
      }

      await harness.pump(
        tester,
        Scaffold(
          body: SearchSuggestionPanel(
            config: testProfile.auth,
            controller: controller,
          ),
        ),
      );
      final context = tester.element(find.byType(SearchSuggestionPanel));
      final raw = find.text(context.t.favorite_tags.raw_badge);
      final empty = find.text(context.t.search_options.no_tag_matches);
      expect(raw, findsNothing);
      type('cat');
      await tester.pump(const Duration(milliseconds: 200));
      expect(raw, findsOneWidget);
      expect(empty, findsNothing);
      requests['cat']!.complete([
        const AutocompleteData(
          label: 'cat_result',
          value: 'cat_result',
          category: 'general',
        ),
      ]);
      await tester.pump();
      await tester.pump();
      final match = find.textContaining('cat result', findRichText: true);
      expect(match, findsOneWidget);
      expect(tester.getTopLeft(match).dy, lessThan(tester.getTopLeft(raw).dy));
      controller.suggestionsListbox.move(TraversalDirection.down);
      controller.suggestionsListbox.pick();
      await tester.pump();
      expect(tags.rawTags, ['cat_result']);
      expect(tags.tags.single.category, 'general');
      for (final query in ['missing', 'offline']) {
        type(query);
        await tester.pump(const Duration(milliseconds: 200));
        if (query == 'offline') {
          requests[query]!.completeError(StateError('offline'));
        } else {
          requests[query]!.complete([]);
        }
        await tester.pump();
        await tester.pump();
        expect(raw, findsOneWidget);
        expect(empty, findsNothing);
      }
      controller.updateQuery('(one piece ~cat)  rating:g');
      await tester.pump();
      await tester.tap(raw);
      await tester.pump();
      expect(tags.tags.last.isRaw, isTrue);
      expect(tags.rawTags.last, '(one piece ~cat)  rating:g');
      expect(controller.state.value, SearchState.initial);
      expect(controller.textController.text, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
