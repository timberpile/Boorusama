import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/options/search_suggestion_panel.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/selected_tags/providers.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/search/suggestions/providers.dart';
import 'package:boorusama/core/search/suggestions/tag_suggestion_item.dart';
import 'package:boorusama/core/tags/autocompletes/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

import 'following_topics/following_topic_test_utils.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'panel reacts to selected aliases without changing the IME draft at $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        addTearDown(tester.view.reset);
        final tags = SelectedTagController(metatagExtractor: null)
          ..addTag(TagSearchItem.fromString('-kitty'));
        final controller = SearchPageController(
          tagsController: tags,
          textMatchers: null,
          metatagExtractor: null,
        );
        addTearDown(controller.dispose);
        addTearDown(tags.dispose);
        final harness = FollowingTopicHarness(
          overrides: [
            suggestionProvider.overrideWith(
              (ref, key) => const [
                AutocompleteData(label: 'Cat', value: 'cat'),
                AutocompleteData(
                  label: 'Kitty',
                  value: 'cat',
                  type: AutocompleteData.alias,
                  antecedent: 'kitty',
                ),
                AutocompleteData(label: 'Dog', value: 'dog'),
              ].toIList(),
            ),
          ],
        );
        addTearDown(harness.dispose);
        const draft = TextEditingValue(
          text: 'ca',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        );
        controller.textController.value = draft;
        await harness.pump(
          tester,
          MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 640),
              textScaler: TextScaler.linear(scale),
              viewInsets: const EdgeInsets.only(bottom: 220),
            ),
            child: Scaffold(
              body: SearchSuggestionPanel(
                config: testProfile.auth,
                controller: controller,
              ),
            ),
          ),
        );
        List<String> values() => tester
            .widgetList<DefaultTagSuggestionItem>(
              find.byType(DefaultTagSuggestionItem),
            )
            .map((item) => item.tag.value)
            .toList();
        expect(values(), ['dog']);
        tags.clear();
        await tester.pump();
        expect(values(), ['cat', 'cat', 'dog']);
        expect(controller.textController.value, draft);
        tags.addTag(TagSearchItem.fromString('~cat'));
        await tester.pump();
        expect(values(), ['dog']);
        expect(controller.textController.value, draft);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
