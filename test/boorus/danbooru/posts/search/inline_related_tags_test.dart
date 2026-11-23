import 'dart:async';

import 'package:boorusama/boorus/danbooru/posts/search/src/widgets/related_tag_section.dart';
import 'package:boorusama/boorus/danbooru/tags/related/providers.dart';
import 'package:boorusama/boorus/danbooru/tags/related/types.dart';
import 'package:boorusama/boorus/danbooru/tags/related/widgets.dart';
import 'package:boorusama/core/tags/categories/types.dart';
import 'package:boorusama/core/search/selected_tags/providers.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/tags/tag/providers.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/tags/related/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/suggestions/providers.dart';
import 'package:boorusama/core/tags/autocompletes/types.dart';
import 'package:kurumi/material.dart';

import '../../../../core/search/following_topics/following_topic_test_utils.dart';

DanbooruRelatedTagItem item(String tag) => DanbooruRelatedTagItem(
  tag: tag,
  category: TagCategory.general(),
  jaccardSimilarity: 1,
  cosineSimilarity: 1,
  overlapCoefficient: 1,
  frequency: 1,
  postCount: 1,
);

class _Aliases extends SuggestionsNotifier {
  @override
  SuggestionsState build(BooruConfigAuth arg) => SuggestionsState.initial();

  void publishAlias() => state = state.addSuggestions(
    'known',
    const [
      AutocompleteData(
        label: 'One Piece',
        value: 'one_piece',
        type: AutocompleteData.alias,
        antecedent: 'op',
      ),
    ].toIList(),
  );
}

void main() {
  testWidgets(
    'committed one_piece is absent from the actual inline plus/minus row',
    (tester) async {
      final tags = SelectedTagController(metatagExtractor: null)
        ..addTag(TagSearchItem.fromString('one_piece'));
      addTearDown(tags.dispose);
      final harness = FollowingTopicHarness(
        overrides: [
          colorSchemeProvider.overrideWithValue(ThemeData().colorScheme),
          tagColorProvider.overrideWith((ref, key) => null),
          danbooruRelatedTagProvider.overrideWith(
            (ref, query) async => DanbooruRelatedTag(
              query: query,
              tags: [item('one_piece'), item('cat')],
              wikiPageTags: const [],
            ),
          ),
        ],
      );
      addTearDown(harness.dispose);
      await harness.pump(
        tester,
        Scaffold(
          body: RelatedTagSection(
            query: 'one_piece',
            selectedTags: tags,
            onAdded: (_) {},
            onNegated: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final labels = tester
          .widgetList<RelatedTagButton>(find.byType(RelatedTagButton))
          .map((button) => (button.label as Text).data)
          .toList();
      expect(labels, ['cat']);
      expect(tester.takeException(), isNull);
      tags.clear();
      await tester.pump();
      expect(find.text('one piece'), findsOneWidget);
      tags.addTag(TagSearchItem.fromString('-one_piece'));
      await tester.pump();
      expect(find.text('one piece'), findsNothing);
      expect(find.text('cat'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'inline aliases and late responses stay scoped to the current profile',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tags = SelectedTagController(metatagExtractor: null)
        ..addTag(TagSearchItem.fromString('-op'));
      addTearDown(tags.dispose);
      final first = Completer<DanbooruRelatedTag>();
      final second = Completer<DanbooruRelatedTag>();
      final harness = FollowingTopicHarness(
        overrides: [
          colorSchemeProvider.overrideWithValue(ThemeData().colorScheme),
          tagColorProvider.overrideWith((ref, key) => null),
          currentReadOnlyBooruConfigAuthProvider.overrideWith(
            (ref) => ref.watch(selectedTestProfileProvider).auth,
          ),
          suggestionsNotifierProvider.overrideWith(_Aliases.new),
          danbooruRelatedTagProvider.overrideWith((ref, query) {
            final auth = ref.watchConfigAuth;
            return auth == testProfile.auth ? first.future : second.future;
          }),
        ],
      );
      addTearDown(harness.dispose);
      await harness.pump(
        tester,
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
            viewInsets: EdgeInsets.only(bottom: 220),
          ),
          child: Scaffold(
            body: RelatedTagSection(
              query: '-op',
              selectedTags: tags,
              onAdded: (_) {},
              onNegated: (_) {},
            ),
          ),
        ),
      );
      first.complete(
        DanbooruRelatedTag(
          query: '-op',
          tags: [item('one_piece'), item('cat')],
          wikiPageTags: const [],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('one piece'), findsOneWidget);
      (harness.container.read(
        suggestionsNotifierProvider(testProfile.auth).notifier,
      ) as _Aliases).publishAlias();
      await tester.pump();
      expect(find.text('one piece'), findsNothing);
      tags.clear();
      await tester.pump();
      expect(find.text('one piece'), findsOneWidget);
      tags.addTag(TagSearchItem.fromString('op'));
      await tester.pump();
      expect(find.text('one piece'), findsNothing);
      harness.container
          .read(selectedTestProfileProvider.notifier)
          .select(otherTestProfile);
      await tester.pump();
      expect(find.text('cat'), findsNothing);
      second.complete(
        DanbooruRelatedTag(
          query: '-op',
          tags: [item('one_piece'), item('dog')],
          wikiPageTags: const [],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('one piece'), findsOneWidget);
      expect(find.text('cat'), findsNothing);
      expect(
        tester
            .widget<RelatedTagHeader>(find.byType(RelatedTagHeader))
            .relatedTag
            .tags
            .map((tag) => tag.tag),
        ['one_piece', 'dog'],
      );
      await tester.drag(
        find.descendant(
          of: find.byType(RelatedTagHeader),
          matching: find.byType(ListView),
        ),
        const Offset(-280, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('dog'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
