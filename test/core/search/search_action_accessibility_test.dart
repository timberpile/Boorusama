import 'package:boorusama/core/search/histories/providers.dart';
import 'package:boorusama/core/search/histories/src/full_history_page.dart';
import 'package:boorusama/core/search/histories/src/types/search_history.dart';
import 'package:boorusama/core/search/histories/src/widgets/search_history_section.dart';
import 'package:boorusama/core/search/search/src/pages/selected_tag_edit_dialog.dart';
import 'package:boorusama/core/search/search/src/widgets/favorite_tags_section.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/foundation/platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../support/fakes/memory_repositories.dart';
import 'following_topics/following_topic_test_utils.dart';

void main() {
  testWidgets('compact history clear keeps the destructive confirmation', (
    tester,
  ) async {
    final repository = MemorySearchHistoryRepository();
    await repository.addHistory(
      'landscape',
      queryType: QueryType.simple,
      booruTypeName: 'danbooru',
      siteUrl: 'example.test',
    );
    final harness = FollowingTopicHarness(
      overrides: [
        searchHistoryRepoProvider.overrideWith((_) async => repository),
      ],
    );
    addTearDown(harness.dispose);
    await harness.pump(tester, FullHistoryPage(onTap: (_, _) {}));
    final t = tester.element(find.byType(FullHistoryPage)).t;
    final clear = find.byTooltip(t.search.history.clear);
    expect(clear.hitTestable(), findsOneWidget);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(repository.historiesForTest, hasLength(1));
    await tester.tap(find.text(t.generic.action.cancel));
    await tester.pumpAndSettle();
    expect(repository.historiesForTest, hasLength(1));
    await tester.tap(clear);
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.generic.action.ok));
    await tester.pumpAndSettle();
    expect(repository.historiesForTest, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search section icon actions have localized accessible names', (
    tester,
  ) async {
    var openedHistory = 0;
    final harness = FollowingTopicHarness(
      overrides: [appPlatformProvider.overrideWithValue(AppPlatform.android)],
    );
    addTearDown(harness.dispose);
    await harness.pump(
      tester,
      Scaffold(
        body: Column(
          children: [
            SearchHistorySection(
              histories: [
                SearchHistory.now(
                  'cat',
                  QueryType.simple,
                  booruTypeName: 'danbooru',
                  siteUrl: 'example.test',
                ),
              ],
              onHistoryTap: (_) {},
              onFullHistoryRequested: () => openedHistory++,
            ),
            const OptionTagsArenaNoEdit(title: 'Favorites', children: []),
          ],
        ),
      ),
    );
    final t = tester.element(find.byType(SearchHistorySection)).t;
    expect(find.byTooltip(t.favorite_tags.title).hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip(t.search.history.history));
    expect(openedHistory, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact tag confirmation fits narrow enlarged text and preserves submission',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = FollowingTopicHarness();
      addTearDown(harness.dispose);
      String? submitted;
      await harness.pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: SizedBox(
                    height: 240,
                    child: SelectedTagEditDialog(
                      tag: const TagSearchItem.raw(tag: '  cat rating:g  '),
                      onUpdated: (value) => submitted = value,
                    ),
                  ),
                ),
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final t = tester.element(find.byType(SelectedTagEditDialog)).t;
      final confirm = find.byTooltip(t.generic.action.ok);
      expect(confirm.hitTestable(), findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(submitted, 'cat rating:g');
      expect(find.byType(SelectedTagEditDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
