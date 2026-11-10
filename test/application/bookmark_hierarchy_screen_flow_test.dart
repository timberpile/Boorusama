import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/posts/listing/src/widgets/timeline_header_sliver.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_view_preferences.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_list_controls.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_local_group_card.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_scroll_view.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_search_bar.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/search/src/widgets/selected_tag_chip.dart';
import 'package:boorusama/core/search/suggestions/tag_suggestion_item.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

const _rootId = '10000000-0000-4000-8000-000000000001';
const _childId = '10000000-0000-4000-8000-000000000002';
const _grandchildId = '10000000-0000-4000-8000-000000000003';
const _emptyChildId = '10000000-0000-4000-8000-000000000004';

void main() {
  testWidgets('hierarchy timeline honors pinned controls and reduced motion', (
    tester,
  ) async {
    final scenario = await _mount(
      tester,
      keepControlsVisible: true,
      reduceMotion: true,
    );
    await _openGroup(tester, scenario.harness, _rootId);
    final header = tester.widget<TimelineHeaderSliver>(
      find.ancestor(
        of: find.byType(BookmarkSearchBar),
        matching: find.byType(TimelineHeaderSliver),
      ),
    );
    expect(header.keepVisible, isTrue);
    expect(header.reduceMotion, isTrue);
    expect(_groupCardTitles(tester), containsAll(['Child', 'Empty child']));
  });

  for (final subtree in [false, true]) {
    testWidgets(
      'focusing an entered timeline preserves offset subtree=$subtree',
      (tester) async {
        final scenario = await _mount(
          tester,
          dense: true,
          phone: const TestPhone(
            name: 'search focus',
            size: Size(320, 640),
            keyboardHeight: 240,
          ),
        );
        await _openGroup(tester, scenario.harness, _rootId);
        if (subtree) {
          await tester.tap(find.byKey(const Key('bookmark-group-view-mode')));
          await scenario.harness.settle(tester);
        }
        final body = find.byType(BookmarkScrollView);
        final controller = tester
            .widget<BookmarkScrollView>(body)
            .scrollController;
        final viewport = find
            .descendant(of: body, matching: find.byType(Viewport))
            .first;
        final rect = tester.getRect(viewport);
        await _animateTo(
          tester,
          scenario.harness,
          controller,
          _timelineHeaderGeometry(tester).precedingScrollExtent + rect.height,
        );
        await tester.dragFrom(
          Offset(rect.center.dx, rect.top + 100),
          const Offset(0, 36),
        );
        await scenario.harness.settle(tester);
        expect(_searchField().hitTestable(), findsOneWidget);
        final before = controller.offset;
        await tester.tap(_searchField());
        await scenario.harness.settle(tester);
        expect(controller.offset, closeTo(before, 1));
        expect(scenario.harness.keyboard.isShown, isTrue);
        await tester.enterText(_searchField(), 'hierarchy_scroll');
        await scenario.harness.settle(tester);
        expect(controller.offset, closeTo(before, 1));
        expect(find.byType(TagSuggestionItem).hitTestable(), findsWidgets);
      },
    );
  }

  for (final keepControlsVisible in [false, true]) {
    testWidgets(
      'production group screen completes measured scroll cycle with keepControlsVisible=$keepControlsVisible',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final scenario = await _mount(
          tester,
          dense: true,
          keepControlsVisible: keepControlsVisible,
          phone: const TestPhone(
            name: '320x640 dense bookmark screen',
            size: Size(320, 640),
            keyboardHeight: 240,
          ),
        );
        await _openGroup(tester, scenario.harness, _rootId);

        final body = find.byType(BookmarkScrollView);
        var scrollView = tester.widget<BookmarkScrollView>(body);
        final controller = scrollView.scrollController;
        final search = find.byType(BookmarkSearchBar, skipOffstage: false);
        final controls = find.byType(
          BookmarkListControls,
          skipOffstage: false,
        );
        final viewport = find
            .descendant(
              of: body,
              matching: find.byType(Viewport),
            )
            .first;
        final viewportRect = tester.getRect(viewport);
        expect(search, findsOneWidget);
        expect(
          find.byType(TimelineHeaderSliver, skipOffstage: false),
          findsWidgets,
        );
        final initialGeometry = _timelineHeaderGeometry(tester);

        expect(_groupCardTitles(tester), contains('Dense child 01'));
        expect(initialGeometry.precedingScrollExtent, greaterThan(0));
        expect(
          initialGeometry.precedingScrollExtent,
          greaterThan(viewportRect.height),
        );
        expect(search.hitTestable(), findsNothing);
        expect(controls.hitTestable(), findsNothing);

        await _animateTo(
          tester,
          scenario.harness,
          controller,
          initialGeometry.precedingScrollExtent + viewportRect.height,
        );
        expect(
          search.hitTestable(),
          keepControlsVisible ? findsOneWidget : findsNothing,
        );
        expect(
          controls.hitTestable(),
          keepControlsVisible ? findsOneWidget : findsNothing,
        );

        if (!keepControlsVisible) {
          await tester.dragFrom(
            Offset(viewportRect.center.dx, viewportRect.top + 100),
            const Offset(0, 36),
          );
          await scenario.harness.settle(tester);
          expect(search.hitTestable(), findsOneWidget);
          expect(controls.hitTestable(), findsOneWidget);
        }

        final notifier = ProviderScope.containerOf(
          tester.element(find.byType(BookmarkGroupBrowserPage)),
          listen: false,
        ).read(bookmarkProvider.notifier) as _MutableBookmarks;
        notifier.publish(
          _libraryState(scenario.config, dense: true, addLiveChild: true),
        );
        await scenario.harness.settle(tester);
        final insertedGeometry = _timelineHeaderGeometry(tester);
        expect(
          insertedGeometry.precedingScrollExtent,
          greaterThan(initialGeometry.precedingScrollExtent),
        );
        await _animateTo(
          tester,
          scenario.harness,
          controller,
          insertedGeometry.precedingScrollExtent - viewportRect.height / 2,
        );
        expect(_groupCardTitles(tester), contains('New child'));
        await _animateTo(
          tester,
          scenario.harness,
          controller,
          insertedGeometry.precedingScrollExtent + viewportRect.height,
        );
        expect(
          controls.hitTestable(),
          keepControlsVisible ? findsOneWidget : findsNothing,
        );

        notifier.publish(_libraryState(scenario.config, dense: true));
        await scenario.harness.settle(tester);
        final removedGeometry = _timelineHeaderGeometry(tester);
        expect(
          removedGeometry.precedingScrollExtent,
          initialGeometry.precedingScrollExtent,
        );

        await _animateTo(
          tester,
          scenario.harness,
          controller,
          removedGeometry.precedingScrollExtent - 80,
        );
        scrollView = tester.widget<BookmarkScrollView>(body);
        final measuredSearchTop = tester.getTopLeft(search).dy;
        final expectedSearchTop =
            tester.getTopLeft(viewport).dy +
            removedGeometry.precedingScrollExtent -
            controller.offset;
        expect(measuredSearchTop, closeTo(expectedSearchTop, 2));
        expect(search.hitTestable(), findsOneWidget);
        expect(controls.hitTestable(), findsOneWidget);

        final field = _searchField();
        await tester.tap(field);
        await scenario.harness.settle(tester);
        await tester.enterText(
          field,
          'hierarchy_scroll_alpha hierarchy_scroll_beta '
          'hierarchy_scroll_gamma hierarchy_scroll_delta',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await scenario.harness.settle(tester);
        final chips = find.byType(SelectedTagChip);
        expect(chips, findsNWidgets(4));
        final chipRows = {
          for (final element in chips.evaluate())
            tester.getTopLeft(find.byWidget(element.widget)).dy,
        };
        expect(chipRows.length, greaterThan(1));
        final wrappedGeometry = _timelineHeaderGeometry(tester);
        expect(
          wrappedGeometry.scrollExtent,
          greaterThan(removedGeometry.scrollExtent),
        );

        await tester.tap(field);
        await scenario.harness.settle(tester);
        expect(scenario.harness.keyboard.isShown, isTrue);
        scenario.harness.keyboard.phone = TestPhone.landscape;
        scenario.harness.keyboard.apply();
        await scenario.harness.settle(tester);
        scrollView = tester.widget<BookmarkScrollView>(body);
        final landscapeGeometry = _timelineHeaderGeometry(tester);
        expect(landscapeGeometry.precedingScrollExtent, greaterThan(0));
        expect(landscapeGeometry.scrollExtent, greaterThan(0));
        expect(
          tester.getSize(viewport).width,
          lessThanOrEqualTo(scenario.harness.keyboard.visibleArea.width),
        );
        await _animateTo(
          tester,
          scenario.harness,
          controller,
          landscapeGeometry.precedingScrollExtent,
        );
        expect(chips, findsNWidgets(4));
        final landscapeField = find.descendant(
          of: search,
          matching: find.byType(TextField, skipOffstage: false),
        );
        expect(
          landscapeField.hitTestable(),
          findsOneWidget,
          reason:
              'field=${tester.getRect(landscapeField)}, '
              'viewport=${tester.getRect(viewport)}, '
              'visible=${scenario.harness.keyboard.visibleArea}',
        );
        expect(
          tester.getRect(landscapeField).bottom,
          lessThanOrEqualTo(tester.getRect(viewport).bottom),
        );
        final committedQuery = scrollView.searchController.text;
        expect(
          scenario.harness.keyboard.coveredTargets({'search': landscapeField}),
          isEmpty,
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await scenario.harness.settle(tester);
        expect(scenario.harness.keyboard.isShown, isFalse);
        scrollView = tester.widget<BookmarkScrollView>(body);
        expect(scrollView.searchController.text, committedQuery);
        final recoveredGeometry = _timelineHeaderGeometry(tester);
        await _animateTo(
          tester,
          scenario.harness,
          controller,
          recoveredGeometry.precedingScrollExtent,
        );
        await tester.ensureVisible(controls.first);
        await scenario.harness.settle(tester);
        final controlsRect = tester.getRect(controls);
        final recoveredViewportRect = tester.getRect(viewport);
        expect(
          controls.hitTestable(),
          findsOneWidget,
          reason: 'controls=$controlsRect viewport=$recoveredViewportRect',
        );
        expect(
          controlsRect.top,
          greaterThanOrEqualTo(recoveredViewportRect.top),
        );
        expect(
          controlsRect.bottom,
          lessThanOrEqualTo(recoveredViewportRect.bottom),
        );
        expect(
          scenario.harness.keyboard.coveredTargets({
            'controls': controls,
          }),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Structure keeps child cards outside direct search and switches to a scoped subtree',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final scenario = await _mount(
        tester,
        pixelRatio: 2.25,
        phone: const TestPhone(
          name: '320x640 phone',
          size: Size(320, 640),
          keyboardHeight: 240,
        ),
      );
      await _openGroup(tester, scenario.harness, _rootId);

      var view = tester.widget<BookmarkScrollView>(
        find.byType(BookmarkScrollView),
      );
      expect(view.view, BookmarkView.group(_rootId));
      expect(_groupCardTitles(tester), containsAll(['Child', 'Empty child']));

      final search = _searchField();
      await tester.ensureVisible(search);
      await tester.tap(search);
      await scenario.harness.settle(tester);
      await tester.enterText(search, 'child_marker');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await scenario.harness.settle(tester);

      view = tester.widget<BookmarkScrollView>(find.byType(BookmarkScrollView));
      expect(view.view.kind, BookmarkViewKind.group);
      expect(view.searchController.text, 'child_marker');
      expect(_groupCardTitles(tester), containsAll(['Child', 'Empty child']));

      // The compact header remains available while the keyboard is open at
      // the narrow, enlarged-text layout. Mode switching must keep working
      // through the autocomplete overlay and retain the committed query.
      await tester.tap(search);
      await scenario.harness.settle(tester);
      expect(scenario.harness.keyboard.isShown, isTrue);
      expect(find.byKey(const Key('bookmark-group-view-mode')), findsOneWidget);
      expect(
        find.byKey(const Key('bookmark-group-view-mode')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('bookmark-group-view-mode')));
      await scenario.harness.settle(tester);
      view = tester.widget<BookmarkScrollView>(find.byType(BookmarkScrollView));
      expect(view.view.kind, BookmarkViewKind.subtree);
      expect(view.view.groupId, _rootId);
      expect(view.searchController.text, 'child_marker');
      expect(find.byType(BookmarkLocalGroupCard), findsNothing);
      final preferences = ProviderScope.containerOf(
        tester.element(find.byType(BookmarkGroupBrowserPage)),
        listen: false,
      ).read(bookmarkGroupViewPreferencesProvider);
      expect(preferences[_rootId], BookmarkGroupViewMode.allBookmarks);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'landscape IME autocomplete leaves group mode switch reachable',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final scenario = await _mount(
        tester,
        pixelRatio: 2.25,
        phone: const TestPhone(
          name: '320x640 portrait with IME',
          size: Size(320, 640),
          keyboardHeight: 260,
        ),
      );
      await _openGroup(tester, scenario.harness, _rootId);

      await tester.tap(find.byKey(const Key('bookmark-group-view-mode')));
      await scenario.harness.settle(tester);
      var view = tester.widget<BookmarkScrollView>(
        find.byType(BookmarkScrollView),
      );
      expect(view.view, BookmarkView.subtree(_rootId));

      final search = _searchField();
      expect(search.hitTestable(), findsOneWidget);
      await tester.tap(search);
      await scenario.harness.settle(tester);
      expect(scenario.harness.keyboard.isShown, isTrue);
      final suggestions = find.byType(TagSuggestionItem);
      final suggestion = suggestions.first;
      await scenario.harness.pumpUntilFound(tester, suggestions);
      expect(suggestion.hitTestable(), findsOneWidget);
      view = tester.widget<BookmarkScrollView>(
        find.byType(BookmarkScrollView),
      );
      expect(view.searchController.text, isEmpty);

      scenario.harness.keyboard.phone = const TestPhone(
        name: '711x320 landscape with compact IME',
        size: Size(1600 / 2.25, 320),
        keyboardHeight: 213.8,
      );
      scenario.harness.keyboard.apply();
      await scenario.harness.settle(tester);
      expect(scenario.harness.keyboard.isShown, isTrue);
      expect(search, findsOneWidget);
      expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);

      final mode = find.byKey(const Key('bookmark-group-view-mode'));
      final media = MediaQuery.of(tester.element(mode));
      final diagnostic = [
        'mode=${tester.getRect(mode)}',
        'search=${search.evaluate().isEmpty ? 'unmounted' : tester.getRect(search)}',
        'media=${media.size}/${media.viewInsets}',
        'appBar=${tester.getRect(find.byType(KurumiAppBar))}',
        'suggestion=${suggestions.evaluate().isEmpty ? 'suppressed' : tester.getRect(suggestion)}',
        'visible=${scenario.harness.keyboard.visibleArea}',
      ].join(' ');
      expect(mode, findsOneWidget);
      expect(
        mode.hitTestable(),
        findsOneWidget,
        reason: diagnostic,
      );
      if (suggestions.evaluate().isNotEmpty) {
        expect(
          tester.getRect(suggestion).overlaps(tester.getRect(mode)),
          isFalse,
        );
      }
      await tester.tap(mode);
      await scenario.harness.settle(tester);

      final updated = tester.widget<BookmarkScrollView>(
        find.byType(BookmarkScrollView),
      );
      expect(updated.view, BookmarkView.group(_rootId));
      expect(updated.searchController.text, isEmpty);
      expect(find.byType(SelectedTagChip), findsNothing);
      expect(_groupCardTitles(tester), containsAll(['Child', 'Empty child']));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('child navigation and system Back stay on one browser route', (
    tester,
  ) async {
    final scenario = await _mount(tester);
    await _openGroup(tester, scenario.harness, _rootId);

    await tester.tap(find.text('Child'));
    await scenario.harness.settle(tester);
    expect(find.byType(BookmarkGroupBrowserPage), findsOneWidget);
    expect(find.text('Child'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await scenario.harness.settle(tester);
    expect(find.byType(BookmarkGroupBrowserPage), findsOneWidget);
    expect(find.text('Root'), findsOneWidget);

    await tester.tap(_ancestorMenu(tester));
    await scenario.harness.settle(tester);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Root'), findsWidgets);
    expect(find.byType(BookmarkGroupBrowserPage), findsOneWidget);
    await tester.tap(find.text('Home'));
    await scenario.harness.settle(tester);
    expect(find.byType(BookmarkGroupBrowserPage), findsOneWidget);
    expect(
      find.text(appStrings(tester).bookmark.groups.selector),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty groups retain child navigation and Add Group without timeline controls',
    (
      tester,
    ) async {
      final scenario = await _mount(tester, rootHasDirectBookmark: false);
      await _openGroup(tester, scenario.harness, _rootId);

      expect(find.byType(BookmarkLocalGroupCard), findsNWidgets(2));
      expect(find.byType(BookmarkScrollView), findsNothing);
      expect(find.byType(BookmarkSearchBar), findsNothing);
      expect(find.byType(BookmarkListControls), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(KurumiAppBar),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is KurumiPopupMenuButton &&
                widget.semanticLabel == appStrings(tester).generic.action.more,
          ),
        ),
      );
      await scenario.harness.settle(tester);
      expect(find.text(appStrings(tester).bookmark.groups.add), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a filtered-empty direct timeline keeps search and controls', (
    tester,
  ) async {
    final scenario = await _mount(tester);
    await _openGroup(tester, scenario.harness, _rootId);
    final search = _searchField();
    await tester.ensureVisible(search);
    await tester.tap(search);
    await scenario.harness.settle(tester);
    await tester.enterText(search, 'missing_marker');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await scenario.harness.settle(tester);

    expect(find.byType(BookmarkScrollView), findsOneWidget);
    expect(find.byType(BookmarkSearchBar), findsOneWidget);
    expect(find.byType(BookmarkListControls), findsOneWidget);
    final view = tester.widget<BookmarkScrollView>(
      find.byType(BookmarkScrollView),
    );
    expect(view.view, BookmarkView.group(_rootId));
    expect(view.searchController.text, 'missing_marker');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'live hierarchy publication updates child cards on an open screen',
    (
      tester,
    ) async {
      final scenario = await _mount(tester);
      await _openGroup(tester, scenario.harness, _rootId);
      expect(_groupCardTitles(tester), contains('Child'));
      expect(_groupCardTitles(tester), isNot(contains('New child')));

      final notifier = ProviderScope.containerOf(
        tester.element(find.byType(BookmarkGroupBrowserPage)),
        listen: false,
      ).read(bookmarkProvider.notifier) as _MutableBookmarks;
      notifier.publish(_libraryState(scenario.config, addLiveChild: true));
      await scenario.harness.settle(tester);
      expect(_groupCardTitles(tester), contains('New child'));

      notifier.publish(_libraryState(scenario.config));
      await scenario.harness.settle(tester);
      expect(_groupCardTitles(tester), isNot(contains('New child')));
      expect(tester.takeException(), isNull);
    },
  );
}

final class _Scenario {
  const _Scenario({required this.harness, required this.config});

  final HeadlessAppHarness harness;
  final BooruConfig config;
}

Future<_Scenario> _mount(
  WidgetTester tester, {
  Size size = kMobileViewport,
  TestPhone? phone,
  double pixelRatio = 1,
  bool rootHasDirectBookmark = true,
  bool keepControlsVisible = false,
  bool reduceMotion = false,
  bool dense = false,
}) async {
  final backend = FakeBooruBackend();
  final store = _MemoryMiscDataStore();
  final initial = _libraryState(
    backend.config,
    rootHasDirectBookmark: rootHasDirectBookmark,
    dense: dense,
  );
  final harness = await HeadlessAppHarness.mount(
    tester,
    booruBackend: backend,
    viewportSize: phone == null ? size : null,
    phone: phone,
    additionalOverrides: [
      bookmarkProvider.overrideWith(() => _MutableBookmarks(initial)),
      miscDataStoreProvider.overrideWithValue(store),
      if (keepControlsVisible)
        imageListingSettingsProvider.overrideWithValue(
          Settings.defaultSettings.listing.copyWith(
            keepTimelineToolbarVisible: true,
          ),
        ),
      if (reduceMotion)
        settingsProvider.overrideWithValue(
          Settings.defaultSettings.copyWith(reduceAnimations: true),
        ),
    ],
  );
  if (phone != null && pixelRatio != 1) {
    tester.view.devicePixelRatio = pixelRatio;
    harness.keyboard.apply();
  }
  return _Scenario(harness: harness, config: backend.config);
}

Future<void> _openGroup(
  WidgetTester tester,
  HeadlessAppHarness harness,
  String groupId,
) async {
  await harness.pumpUntilFound(tester, postTile(101));
  final context = tester.element(postTile(101));
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BookmarkGroupBrowserPage(groupId: groupId),
    ),
  );
  await harness.pumpUntilFound(tester, find.byType(BookmarkGroupBrowserPage));
  await harness.settle(tester);
}

Finder _searchField() => find.descendant(
  of: find.byType(BookmarkSearchBar),
  matching: find.byType(TextField),
);

Finder _ancestorMenu(WidgetTester tester) => find.byWidgetPredicate(
  (widget) =>
      widget is KurumiPopupMenuButton &&
      widget.semanticLabel ==
          appStrings(tester).bookmark.groups.choose_ancestor,
);

List<String> _groupCardTitles(WidgetTester tester) => [
  for (final element in find.byType(BookmarkLocalGroupCard).evaluate())
    (element.widget as BookmarkLocalGroupCard).title,
];

BookmarkLibraryState _libraryState(
  BooruConfig config, {
  bool rootHasDirectBookmark = true,
  bool addLiveChild = false,
  bool dense = false,
}) {
  final denseTags = const {
    'hierarchy_scroll_alpha',
    'hierarchy_scroll_beta',
    'hierarchy_scroll_gamma',
    'hierarchy_scroll_delta',
  };
  final records = dense
      ? [
          for (var id = 101; id <= 200; id++) _record(config, id, denseTags),
        ]
      : [
          _record(config, 101, const {'root_marker'}),
          _record(config, 102, const {'child_marker'}),
          _record(config, 103, const {'grandchild_marker'}),
        ];
  final rootBookmarkIds = dense
      ? {if (rootHasDirectBookmark) ...List<int>.generate(100, (i) => i + 101)}
      : (rootHasDirectBookmark ? const {101} : const <int>{});
  final groups = [
    BookmarkGroup(
      id: _rootId,
      name: 'Root',
      bookmarkIds: rootBookmarkIds,
      position: 0,
    ),
    BookmarkGroup(
      id: _childId,
      name: 'Child',
      bookmarkIds: const {102},
      parentGroupId: _rootId,
      position: 0,
    ),
    BookmarkGroup(
      id: _grandchildId,
      name: 'Grandchild',
      bookmarkIds: const {103},
      parentGroupId: _childId,
      position: 0,
    ),
    BookmarkGroup(
      id: _emptyChildId,
      name: 'Empty child',
      bookmarkIds: const {},
      parentGroupId: _rootId,
      position: 1,
    ),
    if (dense)
      for (var n = 1; n <= 26; n++)
        BookmarkGroup(
          id: _denseChildId(n),
          name: 'Dense child ${n.toString().padLeft(2, '0')}',
          bookmarkIds: const {},
          parentGroupId: _rootId,
          position: n + 1,
        ),
    if (addLiveChild)
      BookmarkGroup(
        id: '10000000-0000-4000-8000-000000000005',
        name: 'New child',
        bookmarkIds: const {},
        parentGroupId: _rootId,
        position: dense ? 28 : 2,
      ),
  ];
  return BookmarkLibraryState(
    bookmarks: records,
    records: records,
    groups: groups,
    revision: addLiveChild ? 1 : 0,
  );
}

String _denseChildId(int n) =>
    '20000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

({double precedingScrollExtent, double scrollExtent}) _timelineHeaderGeometry(
  WidgetTester tester,
) {
  final search = find.byType(BookmarkSearchBar, skipOffstage: false);
  final header = find
      .ancestor(
        of: search,
        matching: find.byType(TimelineHeaderSliver, skipOffstage: false),
      )
      .first
      .evaluate()
      .single;
  final renderObject = header.renderObject;
  if (renderObject is! RenderSliver || renderObject.geometry == null) {
    throw StateError('Bookmark timeline header has no laid out RenderSliver');
  }
  return (
    precedingScrollExtent: renderObject.constraints.precedingScrollExtent,
    scrollExtent: renderObject.geometry!.scrollExtent,
  );
}

Future<void> _animateTo(
  WidgetTester tester,
  HeadlessAppHarness harness,
  ScrollController controller,
  double offset,
) async {
  final target = offset.clamp(
    controller.position.minScrollExtent,
    controller.position.maxScrollExtent,
  );
  final animation = controller.animateTo(
    target,
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeInOut,
  );
  await harness.pumpUntilComplete(tester, animation);
}

PostBookmark _record(BooruConfig config, int id, Set<String> tags) =>
    PostBookmark(
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

final class _MutableBookmarks extends BookmarkLibraryNotifier {
  _MutableBookmarks(this.initial);

  final BookmarkLibraryState initial;

  @override
  BookmarkLibraryState build() => initial;

  void publish(BookmarkLibraryState next) => state = AsyncValue.data(next);
}

final class _MemoryMiscDataStore implements MiscDataStore {
  final values = <String, String>{};

  @override
  String? get(String key) => values[key];

  @override
  Future<void> put(String key, String value) async {
    values[key] = value;
  }
}
