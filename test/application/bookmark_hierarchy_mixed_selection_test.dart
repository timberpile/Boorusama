import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selection_mode/selection_mode.dart';

import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_scroll_view.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/posts/post/src/types/image_url_resolver.dart';
import 'package:boorusama/core/selection/collection_selection.dart';
import 'package:boorusama/core/selection/collection_selection_bar.dart';
import 'package:boorusama/core/widgets/multi_selection_action_bar.dart';

import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

const _parentId = '20000000-0000-4000-8000-000000000001';
const _betaId = '20000000-0000-4000-8000-000000000002';
const _gammaId = '20000000-0000-4000-8000-000000000003';

void main() {
  testWidgets(
    'parent Structure gives child registration the typed group selection scope',
    (tester) async {
      final scenario = await _mount(tester);
      await _openParent(tester, scenario.harness);

      final groupSelection = tester
          .widget<CollectionSelection>(find.byType(CollectionSelection))
          .controller;
      final postSelection = SelectionMode.of(tester.element(postTile(101)));
      final betaBuilder = find.descendant(
        of: find.byKey(const ValueKey(_betaId)),
        matching: find.byType(SelectableBuilder),
      );
      expect(betaBuilder, findsOneWidget);
      final childRegistrationSelection = SelectionMode.of(
        tester.element(betaBuilder),
      );

      expect(
        groupSelection.entries,
        const [
          (CollectionSelectionKind.group, _betaId),
          (CollectionSelectionKind.group, _gammaId),
        ],
      );
      expect(childRegistrationSelection, same(groupSelection));
      expect(groupSelection, isNot(same(postSelection)));
      expect(postSelection.isActive, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mixed Structure selection switches scopes and child navigation clears post selection',
    (tester) async {
      final scenario = await _mount(tester);
      await _openParent(tester, scenario.harness);

      final groupSelection = tester
          .widget<CollectionSelection>(find.byType(CollectionSelection))
          .controller;
      final postSelection = SelectionMode.of(tester.element(postTile(101)));
      final appContainer = ProviderScope.containerOf(
        tester.element(find.byType(BookmarkGroupBrowserPage)),
        listen: false,
      );
      final beta = find.text('Beta');
      final gamma = find.text('Gamma');

      await tester.longPress(beta);
      await scenario.harness.settle(tester);
      expect(groupSelection.selectedKeys, {
        (CollectionSelectionKind.group, _betaId),
      });
      final start = await tester.startGesture(tester.getCenter(beta));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
      await start.moveTo(tester.getCenter(gamma));
      await tester.pump();
      expect(groupSelection.isActive, isTrue);
      expect(groupSelection.isDragInProgress, isTrue);
      expect(
        groupSelection.selectedKeys,
        const {
          (CollectionSelectionKind.group, _betaId),
          (CollectionSelectionKind.group, _gammaId),
        },
      );
      expect(postSelection.isActive, isFalse);
      expect(find.byType(CollectionSelectionBar), findsOneWidget);
      expect(find.byType(MultiSelectionActionBar), findsOneWidget);
      await start.up();
      await scenario.harness.settle(tester);

      await tester.longPress(postTile(101));
      await scenario.harness.settle(tester);
      expect(groupSelection.isActive, isFalse);
      expect(postSelection.isActive, isTrue);
      expect(find.byType(CollectionSelectionBar), findsNothing);
      expect(find.byType(MultiSelectionActionBar), findsOneWidget);

      await tester.longPress(beta);
      await scenario.harness.settle(tester);
      expect(groupSelection.isActive, isTrue);
      expect(postSelection.isActive, isFalse);
      expect(find.byType(CollectionSelectionBar), findsOneWidget);
      expect(find.byType(MultiSelectionActionBar), findsOneWidget);

      await tester.binding.handlePopRoute();
      await scenario.harness.settle(tester);
      expect(groupSelection.isActive, isFalse);
      await tester.longPress(postTile(101));
      await scenario.harness.settle(tester);
      expect(postSelection.isActive, isTrue);
      final before = scenario.initial;
      expect(find.text('Parent'), findsOneWidget);
      await tester.tap(beta);
      await scenario.harness.settle(tester);
      expect(find.text('Parent'), findsNothing);
      expect(find.text('Beta'), findsOneWidget);
      expect(groupSelection.isActive, isFalse);
      expect(find.byType(CollectionSelectionBar), findsNothing);
      expect(find.byType(MultiSelectionActionBar), findsNothing);
      expect(
        appContainer.read(navigationChromeProvider).selectionActive,
        isFalse,
      );
      expect(scenario.currentState().records, same(before.records));
      expect(scenario.currentState().groups, same(before.groups));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('All Bookmarks Ctrl+A does not select hidden child groups', (
    tester,
  ) async {
    final scenario = await _mount(tester);
    await _openParent(tester, scenario.harness);
    final groupSelection = tester
        .widget<CollectionSelection>(find.byType(CollectionSelection))
        .controller;

    await tester.tap(find.byKey(const Key('bookmark-group-view-mode')));
    await scenario.harness.settle(tester);
    expect(
      tester.widget<BookmarkScrollView>(find.byType(BookmarkScrollView)).view,
      BookmarkView.subtree(_parentId),
    );
    expect(groupSelection.entries, isEmpty);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await scenario.harness.settle(tester);

    expect(groupSelection.isActive, isFalse);
    expect(groupSelection.selectedKeys, isEmpty);
    expect(find.byType(CollectionSelectionBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final class _Scenario {
  const _Scenario({
    required this.harness,
    required this.initial,
    required this.currentState,
  });

  final HeadlessAppHarness harness;
  final BookmarkLibraryState initial;
  final BookmarkLibraryState Function() currentState;
}

Future<_Scenario> _mount(WidgetTester tester) async {
  final backend = FakeBooruBackend();
  final initial = _libraryState(backend.config);
  late _MutableBookmarks notifier;
  final harness = await HeadlessAppHarness.mount(
    tester,
    booruBackend: backend,
    viewportSize: const Size(390, 1100),
    additionalOverrides: [
      bookmarkProvider.overrideWith(() {
        notifier = _MutableBookmarks(initial);
        return notifier;
      }),
    ],
  );
  return _Scenario(
    harness: harness,
    initial: initial,
    currentState: () => notifier.state.valueOrNull!,
  );
}

Future<void> _openParent(
  WidgetTester tester,
  HeadlessAppHarness harness,
) async {
  await harness.pumpUntilFound(tester, postTile(101));
  Navigator.of(tester.element(postTile(101))).push(
    MaterialPageRoute<void>(
      builder: (_) => const BookmarkGroupBrowserPage(groupId: _parentId),
    ),
  );
  await harness.pumpUntilFound(tester, find.byType(BookmarkGroupBrowserPage));
  await harness.settle(tester);
  expect(find.text('Beta'), findsOneWidget);
  expect(find.text('Gamma'), findsOneWidget);
  expect(postTile(102), findsOneWidget);
}

BookmarkLibraryState _libraryState(BooruConfig config) {
  PostBookmark record(int id, Set<String> tags) => PostBookmark(
    id: id,
    booruId: config.booruId,
    createdAt: DateTime.utc(2026, 11, 7),
    updatedAt: DateTime.utc(2026, 11, 7),
    thumbnailUrl: '',
    sampleUrl: '',
    originalUrl: '',
    sourceUrl: config.url,
    width: 100,
    height: 100,
    md5: '',
    tags: tags,
    realSourceUrl: null,
    format: 'jpg',
    imageUrlResolver: const DefaultImageUrlResolver(),
    postId: id,
    metadata: const {},
  );

  final records = [
    record(101, const {'cat'}),
    record(102, const {'landscape'}),
  ];
  return BookmarkLibraryState(
    bookmarks: records,
    records: records,
    groups: [
      BookmarkGroup(
        id: defaultBookmarkGroupId,
        name: 'Default',
        bookmarkIds: const {},
      ),
      BookmarkGroup(
        id: _parentId,
        name: 'Parent',
        bookmarkIds: const {101, 102},
        position: 0,
      ),
      BookmarkGroup(
        id: _betaId,
        name: 'Beta',
        bookmarkIds: const {},
        parentGroupId: _parentId,
        position: 0,
      ),
      BookmarkGroup(
        id: _gammaId,
        name: 'Gamma',
        bookmarkIds: const {},
        parentGroupId: _parentId,
        position: 1,
      ),
    ],
  );
}

final class _MutableBookmarks extends BookmarkLibraryNotifier {
  _MutableBookmarks(this.initial);

  final BookmarkLibraryState initial;

  @override
  BookmarkLibraryState build() => initial;
}
