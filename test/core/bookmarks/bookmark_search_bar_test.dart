import 'package:boorusama/core/bookmarks/src/providers/suggestion_provider.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_search_bar.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/themes/colors/src/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:mocktail/mocktail.dart';

class _PostController extends Mock implements PostGridController {}

class _Suggestions extends TagSuggestionsNotifier {
  @override
  Future<void> loadSuggestions(BooruConfigAuth config, String text) async {
    await future;
    state = AsyncData(
      TagSuggestionsState(
        suggestions: const [TagWithColor(tag: 'glasses', count: 2)],
        lastSearchText: text,
      ),
    );
  }
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'selects a negative suggestion with keyboard at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final controller = TextEditingController(text: 'blue_hair -gla');
        addTearDown(controller.dispose);
        final posts = _PostController();
        when(() => posts.refresh()).thenAnswer((_) async {});
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tagSuggestionsProvider.overrideWith(_Suggestions.new),
              currentReadOnlyBooruConfigAuthProvider.overrideWithValue(
                BooruConfigAuth.fromConfig(BooruConfig.empty),
              ),
            ],
            child: BooruLocalization(
              child: MaterialApp(
                theme: ThemeData(
                  extensions: const [KurumiExtendedColorScheme()],
                ).withBoorusamaColors(),
                builder: (context, child) => KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                ),
                home: Scaffold(
                  body: BookmarkSearchBar(
                    controller: controller,
                    postController: posts,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(
          find
              .ancestor(of: find.text('2'), matching: find.byType(InkWell))
              .first,
        );
        await tester.pumpAndSettle();
        expect(controller.text, 'blue_hair -glasses ');
        verify(() => posts.refresh()).called(1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
