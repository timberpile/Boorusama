import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/search/src/routes/params.dart';
import 'package:boorusama/core/search/search/src/types/search_bar_position.dart';
import 'package:boorusama/core/search/search/src/widgets/raw_search_page_scaffold.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/selected_tags/providers.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

import 'following_topics/following_topic_test_utils.dart';

void main() {
  for (final position in SearchBarPosition.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'editor covers displacement gaps at $position and text scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final tags = SelectedTagController(metatagExtractor: null)
            ..addTag(TagSearchItem.fromString('cat'));
          final controller = SearchPageController(
            tagsController: tags,
            textMatchers: null,
            metatagExtractor: null,
          );
          final selection = SelectionModeController();
          addTearDown(tags.dispose);
          addTearDown(controller.dispose);
          addTearDown(selection.dispose);
          final keyboard = ValueNotifier(0.0);
          addTearDown(keyboard.dispose);
          final harness = FollowingTopicHarness(
            overrides: [searchBarPositionProvider.overrideWithValue(position)],
          );
          addTearDown(harness.dispose);
          await harness.pump(
            tester,
            ValueListenableBuilder<double>(
              valueListenable: keyboard,
              builder: (context, inset, _) => MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 640),
                  textScaler: TextScaler.linear(scale),
                  viewInsets: EdgeInsets.only(bottom: inset),
                ),
                child: Scaffold(
                  body: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Colors.red),
                      RawSearchPageScaffold<Post>(
                        params: const SearchParams(),
                        tagsController: tags,
                        controller: controller,
                        selectionModeController: selection,
                        fetcher: (_, _) =>
                            throw StateError('No results requested'),
                        onQueryChanged: (_) {},
                        onPostControllerCreated: (_) {},
                        // Deliberately shorter than the reserved tag region: the
                        // difference must remain opaque, not reveal underlying posts.
                        searchRegion: const SizedBox(height: 80),
                        searchSuggestions: const SizedBox.shrink(),
                        resultHeader: const SizedBox.shrink(),
                        landingView: const Text('Options'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          final backdrop = find.byKey(
            const ValueKey('search-editor-background'),
          );
          expect(backdrop, findsNothing);
          for (final inset in [0.0, 220.0, 0.0]) {
            keyboard.value = inset;
            await tester.pump();
            for (final state in [
              SearchState.options,
              SearchState.suggestions,
              SearchState.options,
            ]) {
              controller.changeState(state);
              await tester.pump();
              final box = tester.widget<ColoredBox>(backdrop);
              expect(box.color.a, 1);
              final bounds = tester.getRect(backdrop);
              expect(bounds.width, 320);
              expect(bounds.height, 640 - inset);
              final gap = Offset(
                160,
                position == SearchBarPosition.top ? 88 : bounds.bottom - 88,
              );
              expect(bounds.contains(gap), isTrue);
              expect(tester.takeException(), isNull);
            }
          }
          controller.closeEditor();
          await tester.pump();
          expect(backdrop, findsNothing);
          expect(tags.rawTagsString, 'cat');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
