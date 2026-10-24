import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/options/search_option.dart';
import 'package:boorusama/core/search/options/search_option_matching.dart';
import 'package:boorusama/core/search/options/search_suggestion_panel.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/selected_tags/selected_tag_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../following_topics/following_topic_test_utils.dart';

void main() {
  const titles = {
    'deleted_comment_count': 'Deleted comment count',
    'favcount': 'Favorite count',
    'tagcount': 'Tag count',
    'count': 'Count',
    'counter': 'Counter',
    'filesize': 'File size',
    'uploader': 'Uploaded by',
  };
  final options = [
    for (final key in titles.keys)
      SearchOption(
        kind: SearchOptionKind.metadata,
        key: key,
        input: SearchOptionInput.number,
      ),
  ];
  List<String> matches(String query) => [
    for (final option in matchSearchOptions(
      options: options,
      query: query,
      title: (option) => titles[option.key]!,
    ))
      option.key,
  ];

  test('exact and prefix matches precede concise substring matches', () {
    expect(matches('count'), [
      'count',
      'counter',
      'tagcount',
      'favcount',
      'deleted_comment_count',
    ]);
  });

  test('matches partial words in any order, case and common separators', () {
    for (final query in [
      'COUNT ta',
      'count_ta',
      'count-ta',
      '  count   ta  ',
    ]) {
      expect(matches(query), ['tagcount']);
    }
    expect(matches('siz'), ['filesize']);
    expect(matches('by'), ['uploader']);
    expect(matches('upload'), ['uploader']);
    expect(matches('count missing'), isEmpty);
    expect(matches('  '), isEmpty);
  });

  for (final query in ['count', 'COUNT ta', '-count']) {
    testWidgets('$query suggests Tag count and selects its canonical key', (
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
      controller.updateQuery(query);
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
      expect(find.text('Tag count'), findsOneWidget);
      await tester.tap(find.text('Tag count'));
      await tester.pump();
      expect(
        controller.textController.text,
        query.startsWith('-') ? '-tagcount:' : 'tagcount:',
      );
      expect(tags.tags, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
