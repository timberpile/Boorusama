import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_page.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/widgets/widgets.dart';
import 'package:selection_mode/selection_mode.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_scroll_view.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_search_bar.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/posts/post/src/types/image_url_resolver.dart';
import 'package:boorusama/core/selection/collection_selection.dart';
import 'package:boorusama/core/selection/ordered_selection_canvas.dart';

import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  for (final enlarged in [false, true]) {
    testWidgets(
      'removing the final selected bookmark closes selection (enlarged: $enlarged)',
      (tester) async {
        if (enlarged) {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        final harness = await HeadlessAppHarness.mount(tester);
        await harness.pumpUntilFound(tester, postTile(102));
        final context = tester.element(postTile(101));
        final container = ProviderScope.containerOf(context, listen: false);
        final posts = postController(tester).items.toList();
        final notifier = ProviderScope.containerOf(
          context,
          listen: false,
        ).read(bookmarkProvider.notifier);
        final result = await notifier.createGroupWithPosts(
          'Selection target',
          harness.booruBackend.config.auth,
          posts,
        );
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                BookmarkPage(view: BookmarkView.group(result.group.id)),
          ),
        );
        await harness.settle(tester);
        await tester.longPress(postTile(101));
        await harness.settle(tester);
        await tester.tap(postTile(102));
        await harness.settle(tester);
        final selection = SelectionMode.of(tester.element(postTile(101)));
        expect(selection.selection, hasLength(2));
        await notifier.removePostsFromGroup(
          harness.booruBackend.config.auth,
          [posts.singleWhere((post) => post.id == 101)],
          result.group.id,
        );
        await harness.settle(tester);
        expect(selection.isActive, isTrue);
        expect(selection.selection, hasLength(1));
        expect(find.byType(MultiSelectionActionBar), findsOneWidget);
        if (enlarged) {
          await notifier.removePostsFromGroup(
            harness.booruBackend.config.auth,
            [posts.singleWhere((post) => post.id == 102)],
            result.group.id,
          );
        } else {
          await tester.tap(find.byType(MultiSelectPopupButton));
          await harness.settle(tester);
          await tester.tap(
            find.byKey(const Key('bookmark-remove-current-group')),
          );
          await harness.settle(tester);
        }
        await harness.settle(tester);
        expect(find.byType(MultiSelectionActionBar), findsNothing);
        expect(find.text('0 items selected'), findsNothing);
        expect(find.text(appStrings(tester).bookmark.none), findsOneWidget);
        expect(
          container.read(navigationChromeProvider).selectionActive,
          isFalse,
        );
        expect(find.byType(BookmarkScrollView), findsNothing);
        await tester.binding.handlePopRoute();
        await harness.settle(tester);
        expect(find.byType(BookmarkPage), findsOneWidget);
        expect(find.byType(BookmarkGroupBrowserPage), findsOneWidget);
        expect(
          find.text(appStrings(tester).bookmark.groups.selector),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        dismissAllToast();
        // Drain oktoast's scheduled fade through the widget's controlled clock.
        await tester.pump(const Duration(seconds: 5));
      },
    );
  }

  testWidgets(
    'group tag search leaves child cards unfiltered while IME edits filter direct posts',
    (
      tester,
    ) async {
      final backend = FakeBooruBackend();
      final initial = _selectionLibraryState(backend.config);
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        additionalOverrides: [
          bookmarkProvider.overrideWith(() => _MutableBookmarks(initial)),
        ],
      );
      await harness.pumpUntilFound(tester, postTile(101));
      Navigator.of(tester.element(postTile(101))).push(
        MaterialPageRoute<void>(
          builder: (_) => const BookmarkGroupBrowserPage(groupId: _parentId),
        ),
      );
      await harness.pumpUntilFound(
        tester,
        find.byType(BookmarkGroupBrowserPage),
      );
      await harness.settle(tester);
      expect(find.text('Beta'), findsOneWidget);
      final search = find.byType(BookmarkSearchBar);
      final field = find.descendant(
        of: search,
        matching: find.byType(EditableText),
      );
      await tester.tap(field);
      await harness.settle(tester);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
      for (final query in ['c', 'ca', 'cat']) {
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: query,
            selection: TextSelection.collapsed(offset: query.length),
            composing: TextRange(start: 0, end: query.length),
          ),
        );
        await tester.pump();
        expect(find.text('Beta'), findsOneWidget);
        expect(tester.testTextInput.isVisible, isTrue);
      }
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await harness.settle(tester);
      expect(find.text('Beta'), findsOneWidget);
      expect(
        bookmarkTile(postId: 101, booruId: harness.booruBackend.config.booruId),
        findsOneWidget,
      );
      expect(
        bookmarkTile(postId: 102, booruId: harness.booruBackend.config.booruId),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bookmark group drag skips system cards and Back exits the active selection',
    (tester) async {
      final harness = await HeadlessAppHarness.mount(
        tester,
        viewportSize: const Size(390, 1200),
      );
      await harness.pumpUntilFound(tester, postTile(101));
      final context = tester.element(postTile(101));
      final container = ProviderScope.containerOf(context, listen: false);
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;
      await notifier.createGroup('Folder');
      await notifier.createGroup('Alpha');
      await notifier.createGroup('Beta');
      final groups = container.read(bookmarkProvider).valueOrNull!.groups;
      final groupIds = {for (final group in groups) group.name: group.id};
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const BookmarkGroupBrowserPage(),
        ),
      );
      await harness.settle(tester);
      await tester.longPress(find.text('Folder'));
      await harness.settle(tester);
      expect(find.text('1 item selected'), findsOneWidget);
      final controller = tester
          .widget<CollectionSelection>(find.byType(CollectionSelection))
          .controller;
      expect(controller.entries, [
        (CollectionSelectionKind.group, groupIds['Folder']!),
        (CollectionSelectionKind.group, groupIds['Alpha']!),
        (CollectionSelectionKind.group, groupIds['Beta']!),
      ]);
      expect(find.text('Beta').hitTestable(), findsOneWidget);
      final canvasRect = tester.getRect(find.byType(OrderedSelectionCanvas));
      final betaPoint = tester.getCenter(find.text('Beta'));
      expect(
        canvasRect.contains(betaPoint),
        isTrue,
        reason: 'canvas=$canvasRect beta=$betaPoint',
      );
      final alphaPoint = tester.getCenter(find.text('Alpha'));
      final drag = await tester.startGesture(alphaPoint);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
      final defaultPoint = tester.getCenter(
        find.text(appStrings(tester).bookmark.groups.default_group),
      );
      await drag.moveTo(defaultPoint);
      await tester.pump();
      expect(controller.isDragInProgress, isTrue);
      expect(find.text('2 items selected'), findsOneWidget);
      await drag.moveTo(betaPoint);
      await tester.pump();
      expect(controller.isDragInProgress, isTrue);
      final selection = tester
          .widget<CollectionSelection>(find.byType(CollectionSelection))
          .controller
          .selectedKeys;
      expect(
        selection,
        {
          (CollectionSelectionKind.group, groupIds['Folder']!),
          (CollectionSelectionKind.group, groupIds['Alpha']!),
          (CollectionSelectionKind.group, groupIds['Beta']!),
        },
        reason:
            'canvas=$canvasRect; beta=$betaPoint; '
            'entries=${controller.entries}',
      );
      expect(
        find.text('3 items selected'),
        findsOneWidget,
        reason:
            'entries=${controller.entries}; selected=${controller.selectedKeys}; '
            'canvas=$canvasRect beta=$betaPoint',
      );
      await drag.moveTo(
        tester.getCenter(find.text(appStrings(tester).bookmark.groups.all)),
      );
      await tester.pump();
      expect(find.text('3 items selected'), findsOneWidget);
      await drag.moveTo(defaultPoint);
      await tester.pump();
      expect(find.text('3 items selected'), findsOneWidget);
      await drag.up();
      await harness.settle(tester);
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      expect(find.byType(BookmarkGroupBrowserPage), findsOneWidget);
      expect(find.text('3 items selected'), findsNothing);
      expect(find.text('Alpha'), findsOneWidget);
    },
  );

  testWidgets('Back exits child group selection without leaving that group', (
    tester,
  ) async {
    final backend = FakeBooruBackend();
    final initial = _selectionLibraryState(backend.config);
    final harness = await HeadlessAppHarness.mount(
      tester,
      booruBackend: backend,
      additionalOverrides: [
        bookmarkProvider.overrideWith(() => _MutableBookmarks(initial)),
      ],
    );
    await harness.pumpUntilFound(tester, postTile(101));
    final context = tester.element(postTile(101));
    final container = ProviderScope.containerOf(context, listen: false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BookmarkGroupBrowserPage(groupId: _parentId),
      ),
    );
    await harness.settle(tester);
    await tester.longPress(find.text('Beta'));
    await harness.settle(tester);
    expect(find.text('1 item selected'), findsOneWidget);
    expect(container.read(navigationChromeProvider).selectionActive, isTrue);
    await tester.binding.handlePopRoute();
    await harness.settle(tester);
    expect(find.byType(BookmarkGroupBrowserPage), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('1 item selected'), findsNothing);
    expect(container.read(navigationChromeProvider).selectionActive, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back exits post selection and remains in the child group', (
    tester,
  ) async {
    final backend = FakeBooruBackend();
    final initial = _selectionLibraryState(backend.config);
    final harness = await HeadlessAppHarness.mount(
      tester,
      booruBackend: backend,
      additionalOverrides: [
        bookmarkProvider.overrideWith(() => _MutableBookmarks(initial)),
      ],
    );
    await harness.pumpUntilFound(tester, postTile(101));
    final container = ProviderScope.containerOf(
      tester.element(postTile(101)),
      listen: false,
    );
    Navigator.of(tester.element(postTile(101))).push(
      MaterialPageRoute<void>(
        builder: (_) => const BookmarkGroupBrowserPage(groupId: _parentId),
      ),
    );
    await harness.settle(tester);
    await tester.tap(find.text('Beta'));
    await harness.settle(tester);
    expect(find.text('Beta'), findsOneWidget);
    await tester.longPress(
      bookmarkTile(postId: 102, booruId: backend.config.booruId),
    );
    await harness.settle(tester);
    expect(find.text('1 item selected'), findsOneWidget);
    expect(container.read(navigationChromeProvider).selectionActive, isTrue);
    await tester.binding.handlePopRoute();
    await harness.settle(tester);
    expect(find.byType(BookmarkGroupBrowserPage), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('1 item selected'), findsNothing);
    expect(container.read(navigationChromeProvider).selectionActive, isFalse);
    expect(tester.takeException(), isNull);
  });
}

const _parentId = '10000000-0000-4000-8000-000000000001';
const _childId = '10000000-0000-4000-8000-000000000002';

BookmarkLibraryState _selectionLibraryState(BooruConfig config) {
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
    record(101, const {'cat', 'blue_hair'}),
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
        name: 'Alpha',
        bookmarkIds: const {101, 102},
        position: 0,
      ),
      BookmarkGroup(
        id: _childId,
        name: 'Beta',
        bookmarkIds: const {102},
        parentGroupId: _parentId,
        position: 0,
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
